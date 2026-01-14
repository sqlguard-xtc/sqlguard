# Getting Started with SqlGuard

This guide walks you through setting up SqlGuard in your CI/CD pipeline and running database validations.

## What You'll Need

- **SQL Server** (2019 or later)
- **Database access** with at least `SELECT` permissions
- **CI/CD pipeline** (GitHub Actions, Azure Pipelines, etc.)
- **A spec file** defining what to validate

## Quick Start

### Step 1: Create Your Spec File

Create `sqlguard-spec.yaml` in your repository root. This declares what database behavior to validate:

```yaml
version: 1

connections:
  default:
    connectionStringEnv: SQLGUARD_CONNECTION_STRING

suites:
  - name: basic-validation
    connection: default
    checks:
      # Validate query result structure
      - id: customer-count
        type: queryContract
        query: "SELECT COUNT(*) AS Total FROM Customers WHERE Active = 1"
        expect:
          shape:
            - name: Total
              type: int
              nullable: false
      
      # Assert data invariant
      - id: no-orphaned-orders
        type: invariant
        query: |
          SELECT COUNT(*) AS Orphans
          FROM Orders o
          LEFT JOIN Customers c ON o.CustomerId = c.CustomerId
          WHERE c.CustomerId IS NULL
        expect:
          operator: equals
          expectedValue: 0
```

### Step 2: Add to CI/CD Pipeline

**SqlGuard is designed to run in automated pipelines.** Choose your platform:

### GitHub Actions

Add this workflow to `.github/workflows/database-validation.yml`:

```yaml
name: Database Validation

on:
  pull_request:
    paths:
      - 'database/**'
      - 'sqlguard-spec.yaml'
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
      
      - name: Verify installation
        run: sqlguard version
      
      - name: Validate database contracts
        env:
          SQLGUARD_CONNECTION_STRING: ${{ secrets.DB_CONNECTION_STRING }}
        run: sqlguard run --spec sqlguard-spec.yaml --format junit --out test-results.xml
      
      - name: Publish test results
        if: always()
        uses: dorny/test-reporter@v1
        with:
          name: SqlGuard Results
          path: test-results.xml
          reporter: java-junit
```

### Azure Pipelines

Add this to `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - database/*
      - sqlguard-spec.yaml

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Bash@3
  displayName: 'Install SqlGuard'
  inputs:
    targetType: 'inline'
    script: |
      curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-linux-x64
      chmod +x sqlguard-linux-x64
      sudo mv sqlguard-linux-x64 /usr/local/bin/sqlguard
      sqlguard version

- task: Bash@3
  displayName: 'Run database validation'
  env:
    SQLGUARD_CONNECTION_STRING: $(DbConnectionString)
  inputs:
    targetType: 'inline'
    script: 'sqlguard run --spec sqlguard-spec.yaml'
```

### Step 3: Configure Secrets

Store your database connection string securely:

**GitHub Actions:**
1. Go to repository Settings → Secrets and variables → Actions
2. Add secret: `DB_CONNECTION_STRING`
3. Value: `Server=yourserver;Database=yourdb;User Id=user;Password=pass;TrustServerCertificate=true`

**Azure Pipelines:**
1. Go to Pipelines → Library → Variable groups
2. Create variable: `DbConnectionString`
3. Mark as secret

---

## Local Testing (Optional)

For testing locally before pushing to CI:

### Install SqlGuard

Download the appropriate binary for your platform from the [releases page](releases.md):

**Windows:**
```powershell
# Download latest release
curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-win-x64.exe

# Rename for convenience
Rename-Item sqlguard-win-x64.exe sqlguard.exe
```

**Linux:**
```bash
# Download latest release
curl -LO https://github.com/sqlguard-xtc/sqlguard/releases/latest/download/sqlguard-linux-x64

# Make executable
chmod +x sqlguard-linux-x64

# Rename for convenience
mv sqlguard-linux-x64 sqlguard
```

Verify it works:

```bash
./sqlguard version
```

### Set Connection String

**Windows (PowerShell):**
```powershell
$env:SQLGUARD_CONNECTION_STRING = "Server=localhost;Database=MyDatabase;User Id=myuser;Password=mypass;TrustServerCertificate=true"
```

**Linux (Bash):**
```bash
export SQLGUARD_CONNECTION_STRING="Server=localhost;Database=MyDatabase;User Id=myuser;Password=mypass;TrustServerCertificate=true"
```

**Connection String Tips:**
- Use `Integrated Security=true` for Windows Authentication
- Add `TrustServerCertificate=true` for dev/test environments with self-signed certificates
- Use `Encrypt=true` for production connections
- **Never hardcode credentials** in spec files

### Verify Database Access

TestRun Validation

```bash
sqlguard run --spec sqlguard-spec.yaml
```

---

## Next Steps
-- Ensure you can connect and query
SELECT GETDATE() AS CurrentTime
```

---

## Step 3: Create Your First Spec File

Create a file named `my-first-spec.yaml`:

```yaml
version: 1

connections:
  - name: my-database
    connectionStringEnv: SQLGUARD_CONNECTION_STRING

suites:
  - name: basic-validations
    connection: my-database
    checks:
      - type: queryContract
        name: verify-customers-exist
        description: Ensure Customers table has expected structure
        query: |
          SELECT 
            CustomerId,
            CustomerName,
            Email
          FROM dbo.Customers
          WHERE CustomerId = 1
        expectedColumns:
          - name: CustomerId
            sqlType: int
            nullable: false
          - name: CustomerName
            sqlType: nvarchar
            nullable: false
          - name: Email
            sqlType: nvarchar
            nullable: true
```

### Understanding the Spec Structure

**`version: 1`**  
Specifies the SqlGuard spec format version (always `1` for now).

**`connections`**  
Defines named database connections. Each connection references an environment variable for security.

**`suites`**  
Logical groupings of related checks. Each suite runs against one connection.

**`checks`**  
Individual validations to perform. This example uses a `queryContract` check to validate query result structure.

> **Adapt to your database**: Replace `Customers` table/columns with tables that exist in your database.

---

## Step 4: Validate Your Spec

Before running checks, validate that your spec file is correctly formatted:

```bash
./sqlguard validate-spec --spec my-first-spec.yaml
```

**If successful**, you'll see:
```
✓ Specification is valid
```

**If there are errors**, you'll see detailed messages:
```
✗ Validation failed:
  - Line 15: expectedColumns cannot be empty
  - Line 8: Unknown connection 'invalid-connection' referenced in suite 'basic-validations'
```

Common validation errors:
- Typos in property names (`expectedColumns` vs `expectedColumn`)
- Empty required fields
- Referencing undefined connections
- Invalid YAML syntax

**Exit codes:**
- `0` - Spec is valid
- `2` - Validation errors found

---

## Step 5: Run Your First Check

Now execute the checks against your database:

```bash
./sqlguard run --spec my-first-spec.yaml
```

### Understanding the Output

**Success case:**
```
✓ Suite: basic-validations
  ✓ verify-customers-exist
    Expected columns: CustomerId, CustomerName, Email
    Actual columns: CustomerId, CustomerName, Email
    Result: PASS

Summary: 1 check, 1 passed, 0 failed
Exit code: 0
```

**Failure case:**
```
✗ Suite: basic-validations
  ✗ verify-customers-exist
    Expected columns: CustomerId, CustomerName, Email
    Actual columns: CustomerId, CustomerCode, Email
    Difference: Missing 'CustomerName', Unexpected 'CustomerCode'
    Result: FAIL

Summary: 1 check, 0 passed, 1 failed
Exit code: 1
```

### Exit Codes

SqlGuard uses specific exit codes for automation:

- **`0`** - All checks passed
- **`1`** - One or more checks failed (validation detected issues)
- **`2`** - Configuration errors (invalid spec, missing connection string)
- **`3`** - Runtime errors (database unreachable, timeout, SQL syntax error)

Use these exit codes in CI/CD to fail builds when validations don't pass.

---

## Step 6: Understanding Results

### Query Contract Checks

Query contract checks validate that query results match expected structure:

**What it validates:**
- Column names (exact match, case-sensitive)
- Column data types (`int`, `nvarchar`, `datetime`, etc.)
- Column nullability (`nullable: true/false`)
- Column order (if `strictOrder: true`)

**When to use:**
- Verify stored procedure result sets haven't changed
- Validate view structures after schema migrations
- Ensure report queries return expected columns

### Reading Diagnostics

When a check fails, SqlGuard shows:

```
Expected: CustomerId (int, not null), CustomerName (nvarchar, not null)
Actual:   CustomerId (int, not null), CustomerCode (nvarchar, not null)
```

This tells you:
- `CustomerName` column is missing
- `CustomerCode` column was not expected

---

## Step 7: Common Patterns

### Pattern 1: Invariant Checks (Data Quality)

Validate data invariants that must always be true:

```yaml
checks:
  - type: invariant
    name: no-customers-without-email
    description: All active customers must have an email
    query: |
      SELECT COUNT(*) AS ViolationCount
      FROM dbo.Customers
      WHERE IsActive = 1 AND Email IS NULL
    expectZero: true
```

**When to use:**
- Data integrity rules ("no orphaned records")
- Business rules ("no negative prices")
- Referential integrity ("all orders have valid customer IDs")

### Pattern 2: Permission Checks (Security)

Validate database permissions for principals:

```yaml
checks:
  - type: permission
    name: app-user-can-select-customers
    description: Verify app user has SELECT permission
    principal: app_readonly_user
    query: |
      SELECT permission_name 
      FROM fn_my_permissions('dbo.Customers', 'OBJECT')
    expectedAllow:
      - SELECT
```

**When to use:**
- Verify service accounts have correct permissions
- Ensure least-privilege is enforced
- Validate role-based access after deployment

### Pattern 3: Multiple Suites

Organize checks by concern:

```yaml
suites:
  - name: schema-structure
    connection: my-database
    checks:
      - type: queryContract
        name: customers-table-structure
        # ...

  - name: data-quality
    connection: my-database
    checks:
      - type: invariant
        name: no-duplicate-emails
        # ...

  - name: security
    connection: my-database
    checks:
      - type: permission
        name: readonly-user-permissions
        # ...
```

---

## Step 8: Next Steps

### Explore More Examples

Check the [examples/](examples/) directory for real-world patterns:

- **[minimal.yaml](examples/minimal.yaml)** - Simplest valid spec
- **[query-contract.yaml](examples/query-contract.yaml)** - Result set validation
- **[invariant.yaml](examples/invariant.yaml)** - Data quality assertions
- **[permission.yaml](examples/permission.yaml)** - Security validation

### Learn the Full Spec Format

Read the [Spec v1 Reference](spec-v1.md) for complete details on:
- All check types and options
- Validation rules
- Determinism requirements
- Advanced patterns

### Integrate with CI/CD

**GitHub Actions example:**

```yaml
- name: Run SqlGuard Validation
  env:
    SQLGUARD_CONNECTION_STRING: ${{ secrets.DB_CONNECTION }}
    SQLGUARD_LICENSE_FILE: ./sqlguard.license.json
  run: |
    ./sqlguard run --spec sqlguard-spec.yaml
```

**Azure DevOps example:**

```yaml
- script: |
    ./sqlguard run --spec sqlguard-spec.yaml
  displayName: 'Run Database Validation'
  env:
    SQLGUARD_CONNECTION_STRING: $(DatabaseConnectionString)
    SQLGUARD_LICENSE_FILE: $(System.DefaultWorkingDirectory)/sqlguard.license.json
```

### Save Baselines for Comparison

Create snapshots to track changes over time:

```bash
# Create baseline
./sqlguard snapshot --spec my-spec.yaml --out baseline.json

# Later, compare current state
./sqlguard run --spec my-spec.yaml --out current.json
./sqlguard compare --baseline baseline.json --current current.json
```

### Get Help

- **Command reference:** [README.md](../README.md)
- **Bug reports:** [GitHub Issues](https://github.com/sqlguard-xtc/sqlguard/issues)
- **Security issues:** security@sqlguard.dev
- **Commercial support:** support@sqlguard.dev

---

## Troubleshooting

### "No valid SqlGuard license found"

**Note:** This is a warning, not an error. SqlGuard runs without a license for development, testing, and evaluation.

**For commercial/production use:** If you purchased a license, follow the setup instructions provided in your license email. You can set the `SQLGUARD_LICENSE_FILE` environment variable to point to your license file location, which will remove this warning.

### "Connection string not found"

**Solution:** Set the `SQLGUARD_CONNECTION_STRING` environment variable. Check for typos in the connection string environment variable name in your spec file.

### "Invalid spec file"

**Solution:** Run `sqlguard validate-spec` first to see specific validation errors. Common issues:
- YAML syntax errors (indentation, quotes)
- Missing required fields
- References to undefined connections

### "SQL Server connection timeout"

**Solution:** 
- Verify SQL Server is running and accessible
- Check firewall rules allow connection
- Test connection string directly with SQL Server Management Studio
- Ensure `TrustServerCertificate=true` is set if using self-signed certificates

### "Permission denied on table"

**Solution:** Ensure the database user has at least `SELECT` permission on tables referenced in queries. For permission checks, user needs `VIEW DEFINITION` on securable objects.

---

## Summary

You've learned how to:

✅ Install SqlGuard and verify it works  
✅ Set up database connections securely  
✅ Create and validate spec files  
✅ Run checks against your database  
✅ Interpret results and exit codes  
✅ Use common validation patterns

**Next:** Explore [real-world examples](examples/) or dive into the [complete spec reference](spec-v1.md).
