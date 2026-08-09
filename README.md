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

## Evaluate and License SqlGuard

### Free Evaluation

You can download and evaluate SqlGuard in development, testing, evaluation, or personal projects without an account, payment card, trial license, or online activation. Commercial and production use requires a license.

- [Start a free evaluation](https://github.com/xtcsystems/sqlguard/releases)
- [Follow the getting started guide](docs/getting-started.md)

### Commercial License

Commercial licenses are time-limited, issued per company, and validated locally without a license server. One signed license file can be used across the organization's machines and CI environments.

[Request a commercial license](mailto:sales@sqlguard.dev?subject=SqlGuard%20commercial%20license%20request&body=Company%20name%3A%0ACompany%20domain%3A%0AIntended%20commercial%20use%3A%0A) by email with your company name, domain, and intended commercial use.

See the [evaluation and licensing paths](https://www.sqlguard.dev/#commercial) for the same public terms.

---

## Installation

SqlGuard is distributed as self-contained, single-file executables for Windows and Linux.

### Install

The installers resolve a versioned [GitHub Release](https://github.com/xtcsystems/sqlguard/releases), verify the exact asset against its SHA-256 manifest entry, and replace the user-local executable atomically. They do not require administrator access or edit your shell profile.

**Windows (x64)**
```powershell
irm https://raw.githubusercontent.com/xtcsystems/sqlguard/main/install.ps1 | iex
```

**Linux (x64)**
```bash
curl -fsSLO https://raw.githubusercontent.com/xtcsystems/sqlguard/main/install.sh
bash install.sh
```

Pin a release with `./install.ps1 -Version 1.0.0` or `bash install.sh --version 1.0.0`. Use `-InstallDirectory` or `--install-dir` to choose a different user-writable directory. macOS and ARM are not currently supported.

### Verify Installation

```bash
sqlguard --version
```

---

## Quick Start

### Overview

SqlGuard validation requires a specification and a SQL Server connection string supplied through an environment variable.

### 1. Generate a Starter Spec

From your repository root:

```bash
sqlguard init
```

This creates a safe `sqlguard-spec.yaml` that proves connectivity without assuming any application tables:

```yaml
version: 1

connections:
  - name: default
    connectionStringEnv: SQLGUARD_CONNECTION_STRING

suites:
  - name: first-run
    connection: default
    checks:
      - type: invariant
        name: database-is-reachable
        description: Confirm SqlGuard can query this database.
        query: SELECT CAST(0 AS int) AS ViolationCount
        operator: equals
        expectedValue: "0"
```

SqlGuard never writes a connection string into the spec. Set `SQLGUARD_CONNECTION_STRING`, then run:

```bash
sqlguard validate-spec --spec sqlguard-spec.yaml
sqlguard run --spec sqlguard-spec.yaml
```

After this succeeds, replace or extend the starter check with your application-specific contracts.

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

      - name: Validate database contracts with SqlGuard
        uses: xtcsystems/sqlguard@v1
        with:
          spec: sqlguard-spec.yaml
          format: junit
          output: sqlguard-results.xml
        env:
          SQLGUARD_CONNECTION_STRING: ${{ secrets.DB_CONNECTION_STRING }}
```

The action installs a checksum-verified Linux x64 release, validates the spec, runs the checks, and exposes the configured report path as its `report` output. Set `SQLGUARD_LICENSE_FILE` in `env` when a commercial license is required; the action does not accept or persist secret values as inputs.

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
      curl -fsSLO https://raw.githubusercontent.com/xtcsystems/sqlguard/main/install.sh
      bash install.sh --install-dir "$(Agent.TempDirectory)/sqlguard-bin"
      echo "##vso[task.prependpath]$(Agent.TempDirectory)/sqlguard-bin"

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

### `init`
Create a deterministic starter specification without connecting to a database.

```bash
sqlguard init [--out <path>]
```

**Options:**
- `--out`, `-o` - Output path (default: `sqlguard-spec.yaml`)

The command refuses to overwrite an existing file. Exit code `0` means the file was created; `2` means the output path was unavailable or already existed.

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

**Note:** The SqlGuard CLI is free for development, testing, and evaluation. Commercial and production use requires a license. [Request a commercial license](mailto:sales@sqlguard.dev?subject=SqlGuard%20commercial%20license%20request&body=Company%20name%3A%0ACompany%20domain%3A%0AIntended%20commercial%20use%3A%0A) by email.

---

## Security

See [SECURITY.md](SECURITY.md) for our security policy and how to report vulnerabilities.

---

## Support

- **Issues:** Report bugs and feature requests on [GitHub Issues](https://github.com/xtcsystems/sqlguard/issues)
- **Security:** security@sqlguard.dev
- **Bug Reports:** [GitHub Issues](https://github.com/xtcsystems/sqlguard/issues)
- **Commercial Support:** support@sqlguard.dev

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.
