# SqlGuard Releases

SqlGuard releases are distributed as self-contained executables for Windows and Linux.

## Getting Releases

All releases are published on GitHub:

**[View All Releases →](https://github.com/xtcsystems/sqlguard/releases)**

## Installation

The supported installers verify the selected release asset against its exact SHA-256 manifest entry before replacing the local executable. Pin a version when reproducibility matters.

### Windows

Install the latest Windows x64 executable:

```powershell
irm https://raw.githubusercontent.com/xtcsystems/sqlguard/main/install.ps1 | iex
```

Use `./install.ps1 -Version 1.0.0` after downloading the script to pin a release or `-InstallDirectory` to select another user-writable location.

### Linux

Install the latest Linux x64 executable:

```bash
curl -fsSLO https://raw.githubusercontent.com/xtcsystems/sqlguard/main/install.sh
bash install.sh
```

Use `bash install.sh --version 1.0.0` to pin a release or `--install-dir` to select another user-writable location.

## Verifying Downloads

All releases include SHA256 checksums for integrity verification:

**Windows:**
```powershell
$expected = (Get-Content sqlguard-v1.0.0-checksums.txt | Select-String "win-x64.exe").Line.Split()[0]
$actual = (Get-FileHash sqlguard-v1.0.0-win-x64.exe -Algorithm SHA256).Hash.ToLower()
if ($expected -eq $actual) { 
    Write-Host "✅ Checksum verified" -ForegroundColor Green
} else { 
    Write-Host "❌ Checksum mismatch - do not use this file" -ForegroundColor Red
}
```

**Linux:**
```bash
sha256sum -c sqlguard-v1.0.0-checksums.txt --ignore-missing
```

## Version History

See [CHANGELOG.md](../CHANGELOG.md) for complete version history and release notes.

## Licensing

SqlGuard is free to use for development, testing, and evaluation. Commercial and production use requires a license.

For licensing information, contact sales@sqlguard.dev or see the main [README](../README.md).

## Support

- **Bug reports:** [GitHub Issues](https://github.com/xtcsystems/sqlguard/issues)
- **Security issues:** See [SECURITY.md](../SECURITY.md)
- **Documentation:** [Getting Started Guide](getting-started.md)
