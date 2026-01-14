# Changelog

All notable changes to SqlGuard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-14

**First stable release of SqlGuard** — A deterministic, CI-first CLI tool for SQL Server contract testing and validation.

### Features

#### Core Commands
- **`version`** — Display version information
- **`validate-spec`** — Validate spec file syntax and configuration
- **`run`** — Execute validation checks against SQL Server
- **`snapshot`** — Capture database state baseline
- **`compare`** — Compare baselines for regression detection

#### Check Types
- **Query Contracts** — Validate result shapes (columns, types, nullability) and expected data
- **Invariants** — Assert database state with operators: `rowCount`, `exists`, `notExists`, `isEmpty`, `isNotEmpty`, `scalar`
- **Permissions** — Verify effective permissions for principals (EXECUTE, SELECT, INSERT, UPDATE, DELETE)

#### Key Capabilities
- Deterministic execution with consistent, reproducible results
- Fixture support with setup/teardown scripts
- Baseline snapshots for deployment validation
- Self-contained executables (Windows and Linux)
- Commercial licensing with file-based license discovery
- Clear exit codes (0=success, 1=failure, 2=config error, 3=execution error)

### Platform Support
- Windows (win-x64)
- Linux (linux-x64)
- SQL Server 2019+

### Documentation
- Getting started guide
- Complete spec format reference (v1.0)
- Example specifications for all check types
- Security policy

### Installation

Download the appropriate binary for your platform from the [v1.0.0 release](https://github.com/sqlguard-xtc/sqlguard/releases/tag/v1.0.0):

**Windows:**
```powershell
curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/download/v1.0.0/sqlguard-v1.0.0-win-x64.exe
```

**Linux:**
```bash
curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/download/v1.0.0/sqlguard-v1.0.0-linux-x64
chmod +x sqlguard-v1.0.0-linux-x64
```

Verify integrity using SHA256 checksums provided in the release assets.
