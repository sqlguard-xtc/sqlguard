# SqlGuard

**Deterministic database validation for CI/CD pipelines**

SqlGuard is a command-line tool for testing and validating SQL Server database contracts. It ensures data consistency, query stability, and security permissions remain intact across deployments.

## What SqlGuard Is

- ✅ **Contract testing tool** - Validates database structure, data invariants, and query results
- ✅ **CI/CD native** - Designed for automated pipelines with deterministic behavior
- ✅ **Offline-capable** - No SaaS dependencies, runs entirely in your environment
- ✅ **Spec-driven** - Declarative YAML specifications for version control

## What SqlGuard Isn't

- ❌ Not a migration tool (doesn't modify databases)
- ❌ Not a monitoring service (doesn't run continuously)
- ❌ Not a performance testing tool
- ❌ No UI/dashboard (CLI only)

---

## Installation

SqlGuard is distributed as self-contained, single-file executables for Windows and Linux.

### Download

Download the latest release from the [Releases page](https://github.com/sqlguard-xtc/sqlguard/releases).

**Windows (x64)**
```powershell
curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-win-x64.exe
```

**Linux (x64)**
```bash
curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-linux-x64
chmod +x sqlguard-linux-x64
```

### Verify Installation

```bash
sqlguard --version
```

---

## Quick Start

### Overview

SqlGuard validation requires two things:
1. **A spec file** (`sqlguard-spec.yaml`) - defines what to validate
2. **A CI/CD pipeline** - runs the validation automatically

### 1. Create Your Spec File

Create `sqlguard-spec.yaml` in your repository root:

```yaml
version: 1

connections:
  default:
    connectionStringEnv: SQLGUARD_CONNECTION_STRING

suites:
  - name: database-checks
    connection: default
    checks:
      - id: verify-customer-count
        type: queryContract
        query: "SELECT COUNT(*) AS CustomerCount FROM Customers"
        expect:
          shape:
            - name: CustomerCount
              type: int
```

### 2. Add to Your CI/CD Pipeline

**Primary Use Case:** SqlGuard is designed to run in automated pipelines.

**GitHub Actions**

```yaml
name: Database Validation

on:
  pull_request:
    paths:
      - 'database/**'
  push:
    branches: [main]

jobs:
  validate-database:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Download SqlGuard
        run: |
          curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-linux-x64
          chmod +x sqlguard-linux-x64
          sudo mv sqlguard-linux-x64 /usr/local/bin/sqlguard
      
      - name: Validate database contracts
        env:
          SQLGUARD_CONNECTION_STRING: ${{ secrets.DB_CONNECTION_STRING }}
        run: sqlguard run --spec sqlguard-spec.yaml
```

**Azure Pipelines**

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - database/*

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Bash@3
  displayName: 'Download SqlGuard'
  inputs:
    targetType: 'inline'
    script: |
      curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-linux-x64
      chmod +x sqlguard-linux-x64
      sudo mv sqlguard-linux-x64 /usr/local/bin/sqlguard

- task: Bash@3
  displayName: 'Run database validation'
  env:
    SQLGUARD_CONNECTION_STRING: $(DbConnectionString)
  inputs:
    targetType: 'inline'
    script: 'sqlguard run --spec sqlguard-spec.yaml'
```

### 3. Local Testing (Optional)

For local development and testing:

```bash
# Set connection string
export SQLGUARD_CONNECTION_STRING="Server=localhost;Database=mydb;Integrated Security=true"

# Run validation

```bash
sqlguard run --spec sqlguard-spec.yaml
```

---

## Commands

SqlGuard provides the following commands:

### `version`
Display version information.

```bash
sqlguard version
```

### `validate-spec`
Validate a specification file without executing checks.

```bash
sqlguard validate-spec --spec <path>
```

**Options:**
- `--spec` - Path to the specification file (required)

**Exit Codes:**
- `0` - Spec is valid
- `2` - Spec validation errors
- `3` - Runtime errors

### `run`
Execute all checks defined in a specification.

```bash
sqlguard run --spec <path> [--out <file>] [--format json|junit]
```

**Options:**
- `--spec` - Path to the specification file (required)
- `--out` - Output file path (optional, defaults to stdout)
- `--format` - Output format: `json` (default) or `junit` (optional)

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed
- `2` - Spec/configuration errors
- `3` - Runtime/system errors

### `snapshot`
Create a baseline snapshot from a specification.

```bash
sqlguard snapshot --spec <path> --out <baseline.json>
```

**Options:**
- `--spec` - Path to the specification file (required)
- `--out` - Output baseline file path (required)

### `compare`
Compare baseline and current snapshots.

```bash
sqlguard compare --baseline <file> --current <file> [--out <file>]
```

**Options:**
- `--baseline` - Path to baseline snapshot file (required)
- `--current` - Path to current snapshot file (required)
- `--out` - Output comparison report file (optional)

---

## Exit Codes

SqlGuard uses consistent exit codes for CI/CD integration:

| Code | Meaning | Description |
|------|---------|-------------|
| `0` | Success | All checks passed |
| `1` | Validation Failures | One or more checks failed |
| `2` | Configuration Errors | Invalid spec or configuration |
| `3` | Runtime Errors | Database connectivity, SQL execution, or system errors |

**Usage in CI/CD:**

SqlGuard's deterministic behavior and semantic exit codes make it ideal for automated validation. The pipeline fails automatically when checks don't pass (exit code 1) or configuration errors occur (exit code 2).

See the [Quick Start](#quick-start) section for complete pipeline examples.

---

## Check Types

SqlGuard supports three types of validation checks:

### 1. Query Contract
Validates that a query returns expected structure and data.

```yaml
- type: queryContract
  query: "SELECT * FROM Users WHERE Active = 1"
  expect:
    shape:
      - name: UserId
        type: int
    rowCount:
      operator: greaterThan
      expectedValue: 0
```

### 2. Invariant
Validates data consistency rules and business logic.

```yaml
- type: invariant
  description: "All orders must have valid customers"
  query: |
    SELECT COUNT(*) AS OrphanedOrders
    FROM Orders o
    LEFT JOIN Customers c ON o.CustomerId = c.CustomerId
    WHERE c.CustomerId IS NULL
  expect:
    - operator: equals
      expectedValue: 0
```

### 3. Permission
Validates database security and access controls.

```yaml
- type: permission
  principal: AppUser
  object: dbo.SensitiveData
  permission: SELECT
  expect: deny
```

---

## Documentation

- [Getting Started Guide](docs/getting-started.md)
- [Spec v1 Reference](docs/spec-v1.md)
- [Examples](docs/examples/)
- [Releases](docs/releases.md)

---

## License

This documentation and examples are licensed under the MIT License. See [LICENSE](LICENSE) for details.

**Note:** The SqlGuard CLI is free for development, testing, and evaluation. Commercial and production use requires a license. Contact sales@sqlguard.dev for licensing information.

---

## Security

See [SECURITY.md](SECURITY.md) for our security policy and how to report vulnerabilities.

---

## Support

- **Issues:** Report bugs and feature requests on [GitHub Issues](https://github.com/sqlguard-xtc/sqlguard/issues)
- **Security:** security@sqlguard.dev
- **Bug Reports:** [GitHub Issues](https://github.com/sqlguard-xtc/sqlguard/issues)
- **Commercial Support:** support@sqlguard.dev

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.
