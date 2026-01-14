# SqlGuard Releases

SqlGuard releases are distributed as self-contained executables for Windows and Linux.

## Getting Releases

All releases are published on GitHub:

**[View All Releases →](https://github.com/sqlguard/sqlguard/releases)**

## Installation

> **Note:** The examples below use v0.2.0. Check the [releases page](https://github.com/sqlguard/sqlguard/releases) for the latest version and update the version number in the commands below.

### Windows

Download the latest Windows executable:

```powershell
# Download latest release (replace version number)
curl -LO https://github.com/sqlguard/sqlguard/releases/download/v0.2.0/sqlguard-v0.2.0-win-x64.exe

# Verify checksum (recommended)
curl -LO https://github.com/sqlguard/sqlguard/releases/download/v0.2.0/sqlguard-v0.2.0-checksums.txt
Get-FileHash sqlguard-v0.2.0-win-x64.exe -Algorithm SHA256

# Rename for convenience
Rename-Item sqlguard-v0.2.0-win-x64.exe sqlguard.exe

# Verify it works
.\sqlguard.exe version
```

### Linux

Download the latest Linux executable:

```bash
# Download latest release (replace version number)
curl -LO https://github.com/sqlguard/sqlguard/releases/download/v0.2.0/sqlguard-v0.2.0-linux-x64

# Verify checksum (recommended)
curl -LO https://github.com/sqlguard/sqlguard/releases/download/v0.2.0/sqlguard-v0.2.0-checksums.txt
sha256sum -c sqlguard-v0.2.0-checksums.txt --ignore-missing

# Make executable
chmod +x sqlguard-v0.2.0-linux-x64

# Rename for convenience
mv sqlguard-v0.2.0-linux-x64 sqlguard

# Verify it works
./sqlguard version
```

## Verifying Downloads

All releases include SHA256 checksums for integrity verification:

**Windows:**
```powershell
$expected = (Get-Content sqlguard-v0.2.0-checksums.txt | Select-String "win-x64.exe").Line.Split()[0]
$actual = (Get-FileHash sqlguard-v0.2.0-win-x64.exe -Algorithm SHA256).Hash.ToLower()
if ($expected -eq $actual) { 
    Write-Host "✅ Checksum verified" -ForegroundColor Green
} else { 
    Write-Host "❌ Checksum mismatch - do not use this file" -ForegroundColor Red
}
```

**Linux:**
```bash
sha256sum -c sqlguard-v0.2.0-checksums.txt --ignore-missing
```

## Version History

See [CHANGELOG.md](../CHANGELOG.md) for complete version history and release notes.

## Licensing

SqlGuard is free to use for development, testing, and evaluation. Commercial and production use requires a license.

For licensing information, contact sales@sqlguard.dev or see the main [README](../README.md).

## Support

- **Bug reports:** [GitHub Issues](https://github.com/sqlguard/sqlguard/issues)
- **Security issues:** See [SECURITY.md](../SECURITY.md)
- **Documentation:** [Getting Started Guide](getting-started.md)
