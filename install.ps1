[CmdletBinding()]
param(
    [ValidatePattern('^(latest|v?[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?)$')]
    [string]$Version = 'latest',

    [string]$InstallDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.sqlguard\bin'),

    [switch]$AddToPath,

    [Parameter(DontShow = $true)]
    [string]$AssetDirectory,

    [Parameter(DontShow = $true)]
    [switch]$SkipExecutionCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = 'xtcsystems/sqlguard'
$temporaryDirectory = $null
$stagedExecutable = $null

function Resolve-ReleaseTag {
    if ($Version -ne 'latest') {
        if ($Version.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) {
            return "v$($Version.Substring(1))"
        }

        return "v$Version"
    }

    if (-not [string]::IsNullOrWhiteSpace($AssetDirectory)) {
        $manifests = @(Get-ChildItem -LiteralPath $AssetDirectory -Filter 'sqlguard-v*-checksums.txt' -File)
        if ($manifests.Count -ne 1 -or $manifests[0].Name -notmatch '^sqlguard-(v.+)-checksums\.txt$') {
            throw 'Offline latest-version resolution requires exactly one versioned checksum file.'
        }

        return $Matches[1]
    }

    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$repository/releases/latest" `
        -Headers @{ 'User-Agent' = 'SqlGuard-Installer'; 'Accept' = 'application/vnd.github+json' }

    if ([string]::IsNullOrWhiteSpace($release.tag_name) -or $release.tag_name -notmatch '^v.+') {
        throw 'The latest SqlGuard release did not provide a valid version tag.'
    }

    return [string]$release.tag_name
}

function Copy-OrDownloadAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not [string]::IsNullOrWhiteSpace($AssetDirectory)) {
        $source = Join-Path $AssetDirectory $Name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required offline asset '$Name' was not found."
        }

        Copy-Item -LiteralPath $source -Destination $Destination
        return
    }

    Invoke-WebRequest `
        -Uri "https://github.com/$repository/releases/download/$Tag/$Name" `
        -OutFile $Destination `
        -Headers @{ 'User-Agent' = 'SqlGuard-Installer' }
}

try {
    if (-not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) {
        throw 'This installer supports Windows only. Use install.sh on Linux.'
    }

    if ([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -ne [Runtime.InteropServices.Architecture]::X64) {
        throw 'SqlGuard currently supports Windows x64 only.'
    }

    $tag = Resolve-ReleaseTag
    $versionText = $tag.Substring(1)
    $assetName = "sqlguard-v$versionText-win-x64.exe"
    $checksumName = "sqlguard-v$versionText-checksums.txt"

    $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) "sqlguard-install-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null

    $downloadedAsset = Join-Path $temporaryDirectory $assetName
    $downloadedChecksums = Join-Path $temporaryDirectory $checksumName
    Copy-OrDownloadAsset -Name $assetName -Tag $tag -Destination $downloadedAsset
    Copy-OrDownloadAsset -Name $checksumName -Tag $tag -Destination $downloadedChecksums

    $escapedAssetName = [Regex]::Escape($assetName)
    $checksumMatches = @(Get-Content -LiteralPath $downloadedChecksums | ForEach-Object {
        if ($_ -match "^\s*(?<hash>[0-9A-Fa-f]{64})\s+\*?$escapedAssetName\s*$") {
            $Matches['hash'].ToLowerInvariant()
        }
    })

    if ($checksumMatches.Count -ne 1) {
        throw "Checksum manifest must contain exactly one SHA-256 entry for '$assetName'."
    }

    $actualChecksum = (Get-FileHash -LiteralPath $downloadedAsset -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualChecksum -ne $checksumMatches[0]) {
        throw "Checksum verification failed for '$assetName'."
    }

    New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    $destination = Join-Path $InstallDirectory 'sqlguard.exe'
    $stagedExecutable = Join-Path $InstallDirectory ".sqlguard.$([Guid]::NewGuid().ToString('N')).exe"
    Copy-Item -LiteralPath $downloadedAsset -Destination $stagedExecutable

    if (-not $SkipExecutionCheck) {
        & $stagedExecutable --version
        if ($LASTEXITCODE -ne 0) {
            throw "The downloaded SqlGuard executable failed its version check with exit code $LASTEXITCODE."
        }
    }

    Move-Item -LiteralPath $stagedExecutable -Destination $destination -Force
    $stagedExecutable = $null

    if ($AddToPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $pathEntries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $alreadyPresent = $pathEntries | Where-Object {
            $_.TrimEnd('\') -eq $InstallDirectory.TrimEnd('\')
        }

        if (-not $alreadyPresent) {
            $newPath = (@($pathEntries) + $InstallDirectory) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-Host "Added '$InstallDirectory' to the user PATH. Open a new terminal to use it."
        }
    }

    Write-Host "Installed SqlGuard $tag to '$destination'."
    Write-Host "Verified SHA-256: $actualChecksum"
    if (-not $AddToPath) {
        Write-Host "Add '$InstallDirectory' to PATH or invoke '$destination' directly."
    }
}
finally {
    if ($null -ne $stagedExecutable -and (Test-Path -LiteralPath $stagedExecutable)) {
        Remove-Item -LiteralPath $stagedExecutable -Force
    }

    if ($null -ne $temporaryDirectory -and (Test-Path -LiteralPath $temporaryDirectory)) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
