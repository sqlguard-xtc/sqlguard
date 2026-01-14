# SqlGuard Specification Format v1

**Version:** 1  
**Status:** Current  
**Last Updated:** January 2026

This document describes the SqlGuard specification format version 1 in precise detail, validated against the actual parser and validator implementation.

---

## Table of Contents

- [Overview](#overview)
- [Root Structure](#root-structure)
- [Connections](#connections)
- [Suites](#suites)
- [Checks](#checks)
  - [Query Contract Check](#query-contract-check)
  - [Invariant Check](#invariant-check)
  - [Permission Check](#permission-check)
- [Validation Rules](#validation-rules)
- [Determinism Requirements](#determinism-requirements)
- [Examples](#examples)

---

## Overview

A SqlGuard specification is a YAML file that defines:
- **Connections**: Named database connections using environment variables
- **Suites**: Logical groupings of related checks
- **Checks**: Validation rules (query contracts, invariants, permissions)

**Key Principles:**
- **Security First**: Connection strings MUST use environment variables (never hardcoded)
- **Deterministic**: Queries requiring row order MUST include explicit `ORDER BY`
- **Validated**: All specs are validated before execution via `sqlguard validate-spec`

---

## Root Structure

The root of a SqlGuard specification contains three required properties:

```yaml
version: 1
connections: [...]
suites: [...]
```

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `version` | integer | ✅ Yes | Spec format version. Currently only `1` is supported. |
| `connections` | array | ✅ Yes | List of named database connections. Must contain at least one connection. |
| `suites` | array | ✅ Yes | List of test suites. Must contain at least one suite. |

### Validation Rules

- **version**: MUST be exactly `1`. Other values will fail validation.
- **connections**: MUST NOT be empty.
- **suites**: MUST NOT be empty.

---

## Connections

Connections define named database connections that suites reference. Each connection loads its connection string from an environment variable for security.

```yaml
connections:
  - name: primary-db
    connectionStringEnv: SQLGUARD_CONN_PRIMARY
  
  - name: analytics-db
    connectionStringEnv: SQLGUARD_CONN_ANALYTICS
```

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | ✅ Yes | Unique connection name. Case-insensitive for uniqueness checks. |
| `connectionStringEnv` | string | ✅ Yes | Environment variable name containing the connection string. |

### Validation Rules

- **name**: 
  - MUST NOT be empty or whitespace-only
  - MUST be unique across all connections (case-insensitive)
- **connectionStringEnv**:
  - MUST NOT be empty or whitespace-only
  - The environment variable itself is not validated at spec validation time (only at runtime)

### Security Constraint

**CRITICAL**: SqlGuard specifications MUST NOT contain hardcoded connection strings or credentials. All connection strings MUST be loaded from environment variables. This is a fundamental security requirement.

❌ **NEVER DO THIS:**
```yaml
connections:
  - name: bad-example
    connectionString: "Server=prod-db;Database=app;User=sa;Password=secret123"
```

✅ **ALWAYS DO THIS:**
```yaml
connections:
  - name: good-example
    connectionStringEnv: SQLGUARD_CONN_PRIMARY
```

Set the environment variable before running SqlGuard:
```bash
export SQLGUARD_CONN_PRIMARY="Server=prod-db;Database=app;User=app_user;Password=..."
sqlguard run --spec sqlguard-spec.yaml
```

---

## Suites

Suites group related checks together and specify which connection to use. Each suite executes its checks in the order defined.

```yaml
suites:
  - name: api-contracts
    connection: primary-db
    checks: [...]
  
  - name: data-quality
    connection: analytics-db
    checks: [...]
```

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | ✅ Yes | Human-readable suite name. |
| `connection` | string | ✅ Yes | Name of a connection defined in the `connections` list. |
| `checks` | array | ✅ Yes | List of checks to execute. Must contain at least one check. |

### Validation Rules

- **name**: MUST NOT be empty or whitespace-only
- **connection**: 
  - MUST NOT be empty or whitespace-only
  - MUST reference a connection defined in the spec's `connections` list (case-insensitive match)
  - Validation fails if the referenced connection does not exist
- **checks**: MUST NOT be empty

### Execution Order

Checks within a suite are executed **sequentially in the order defined**. This is deterministic and guaranteed.

---

## Checks

Checks are the core validation units in SqlGuard. Each check executes a SQL query and validates the result according to type-specific rules.

### Common Properties (All Check Types)

All check types share these required properties:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `type` | string | ✅ Yes | Check type: `queryContract`, `invariant`, or `permission` |
| `name` | string | ✅ Yes | Unique check name within the suite. |
| `description` | string | ✅ Yes | Human-readable description of what this check validates. |
| `query` | string | ✅ Yes | SQL query to execute. |

### Common Validation Rules

- **type**: MUST be one of: `queryContract`, `invariant`, `permission` (case-sensitive)
- **name**: 
  - MUST NOT be empty or whitespace-only
  - MUST be unique within the suite
- **description**: MUST NOT be empty or whitespace-only
- **query**: MUST NOT be empty or whitespace-only

---

### Query Contract Check

**Purpose**: Validates that a query's result structure (columns and optionally row count) remains stable over time. Used to detect breaking changes in API queries, reports, or data exports.

**Type**: `queryContract`

```yaml
- type: queryContract
  name: user-profile-api
  description: User profile endpoint - consumed by mobile app
  query: |
    SELECT UserId, Username, Email, DisplayName
    FROM Users
    WHERE IsActive = 1
    ORDER BY UserId
  expectedColumns:
    - name: UserId
      sqlType: int
      nullable: false
    - name: Username
      sqlType: nvarchar
      nullable: false
    - name: Email
      sqlType: nvarchar
      nullable: true
    - name: DisplayName
      sqlType: nvarchar
      nullable: false
  expectedRowCount: 100  # Optional
```

#### Type-Specific Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `expectedColumns` | array | ✅ Yes | Ordered list of expected columns. |
| `expectedRowCount` | integer | ❌ No | Exact number of rows expected. If omitted, row count is not validated. |

#### Expected Column Properties

Each entry in `expectedColumns` has these properties:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | ✅ Yes | Column name (case-sensitive). |
| `sqlType` | string | ✅ Yes | SQL Server data type (e.g., `int`, `nvarchar`, `datetime2`, `decimal`). |
| `nullable` | boolean | ✅ Yes | Whether the column allows NULL values. |

#### Validation Rules

- **expectedColumns**:
  - MUST NOT be empty
  - MUST contain at least one column
  - Each column's `name` MUST NOT be empty or whitespace-only
  - Each column's `sqlType` MUST NOT be empty or whitespace-only
  - Column order matters: columns are validated in the order specified
- **expectedRowCount**:
  - If specified, MUST be non-negative (>= 0)
  - If omitted, row count is not validated

#### Execution Behavior

At runtime, the check:
1. Executes the query
2. Validates the result has the exact columns in the exact order specified
3. Validates each column's SQL type and nullability match
4. If `expectedRowCount` is specified, validates the exact row count
5. Fails if any mismatch is detected

---

### Invariant Check

**Purpose**: Validates that a scalar query result matches an expected condition. Used for data quality rules, business logic constraints, and assertions (e.g., "no orphaned records", "all amounts are positive").

**Type**: `invariant`

```yaml
- type: invariant
  name: no-orphaned-orders
  description: Every order must belong to an existing customer
  query: |
    SELECT COUNT(*) AS ViolationCount
    FROM Orders o
    LEFT JOIN Customers c ON o.CustomerId = c.CustomerId
    WHERE c.CustomerId IS NULL
  operator: equals
  expectedValue: '0'
```

#### Type-Specific Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `operator` | string | ✅ Yes | Comparison operator. See [Supported Operators](#invariant-operators) below. |
| `expectedValue` | string | ✅ Yes | Expected value to compare against. All values are compared as strings. |

#### Invariant Operators

The `operator` field supports the following values (case-sensitive):

| Operator | Description | Example |
|----------|-------------|---------|
| `equals` | Exact string equality | `expectedValue: '0'` |
| `notEquals` | String inequality | `expectedValue: 'Invalid'` |
| `greaterThan` | Numeric comparison (> ) | `expectedValue: '100'` |
| `lessThan` | Numeric comparison (< ) | `expectedValue: '50'` |
| `greaterThanOrEqual` | Numeric comparison (>=) | `expectedValue: '1'` |
| `lessThanOrEqual` | Numeric comparison (<=) | `expectedValue: '999'` |
| `contains` | Substring match (case-sensitive) | `expectedValue: 'Success'` |
| `startsWith` | Prefix match (case-sensitive) | `expectedValue: 'OK-'` |
| `endsWith` | Suffix match (case-sensitive) | `expectedValue: '.txt'` |
| `regexMatch` | Regular expression match | `expectedValue: '^[A-Z]{3}-\d{4}$'` |
| `isTrue` | Boolean true (any of: `'true'`, `'1'`, `'yes'`) | `expectedValue: 'true'` |
| `isFalse` | Boolean false (any of: `'false'`, `'0'`, `'no'`) | `expectedValue: 'false'` |

#### Validation Rules

- **operator**: 
  - MUST NOT be empty or whitespace-only
  - MUST be one of the supported operators listed above (case-sensitive)
- **expectedValue**: MUST NOT be empty or whitespace-only

#### Execution Behavior

At runtime, the check:
1. Executes the query
2. Expects the query to return exactly ONE row with ONE column (scalar result)
3. Converts the result value to a string
4. Applies the specified operator to compare against `expectedValue`
5. Fails if the comparison does not match

**Common Pattern**: Most invariant checks count violations and expect `equals` with `expectedValue: '0'`:

```yaml
# Pattern: Count violations, expect zero
- type: invariant
  name: check-name
  description: Description of the constraint
  query: SELECT COUNT(*) FROM TableName WHERE <violation condition>
  operator: equals
  expectedValue: '0'
```

---

### Permission Check

**Purpose**: Validates effective permissions for a specific database principal (user or role). Verifies that expected permissions are granted (allow) and that forbidden permissions are not granted (deny). Used for security auditing and privilege regression protection.

**Type**: `permission`

```yaml
- type: permission
  name: app-user-no-ddl
  description: Application user must not have DDL permissions
  query: |
    SELECT permission_name
    FROM fn_my_permissions(NULL, 'DATABASE')
    WHERE permission_name IN ('ALTER ANY TABLE', 'CREATE TABLE', 'DROP TABLE')
  principal: app_user
  expectedDeny:
    - ALTER ANY TABLE
    - CREATE TABLE
    - DROP TABLE
```

#### Type-Specific Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `principal` | string | ✅ Yes | Database principal (user or role) to check. |
| `expectedAllow` | array | ❌ No | Permissions that MUST be granted. Check fails if any are missing. |
| `expectedDeny` | array | ❌ No | Permissions that MUST NOT be granted. Check fails if any are present. |

#### Validation Rules

- **principal**: MUST NOT be empty or whitespace-only
- **expectedAllow and expectedDeny**:
  - At least ONE of `expectedAllow` or `expectedDeny` MUST be specified (both can be specified)
  - If specified, each list entry MUST NOT be empty or whitespace-only
  - **No overlap allowed**: A permission CANNOT appear in both `expectedAllow` and `expectedDeny` for the same check (validation error)
- **Query**: Must return a single column containing permission names

#### Execution Behavior

At runtime, the check:
1. Executes the query to retrieve effective permissions for the principal
2. If `expectedAllow` is specified: verifies ALL listed permissions are present (fails if any are missing)
3. If `expectedDeny` is specified: verifies NONE of the listed permissions are present (fails if any are found)
4. Reports which permissions are missing (for allow) or present (for deny)

#### Common Query Patterns

**SQL Server - Database-level permissions:**
```sql
SELECT permission_name
FROM fn_my_permissions(NULL, 'DATABASE')
WHERE permission_name IN ('CREATE TABLE', 'ALTER ANY TABLE', 'DROP')
```

**SQL Server - Object-level permissions:**
```sql
SELECT permission_name
FROM fn_my_permissions('dbo.Users', 'OBJECT')
WHERE permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
```

**SQL Server - Check all database permissions:**
```sql
SELECT permission_name
FROM fn_my_permissions(NULL, 'DATABASE')
```

---

## Validation Rules

This section summarizes all validation rules enforced by `sqlguard validate-spec`.

### Root Level

| Rule | Severity | Message |
|------|----------|---------|
| Version must be 1 | Error | `Unsupported spec version: {version}. Only version 1 is supported.` |
| Connections must not be empty | Error | `Spec must define at least one connection.` |
| Suites must not be empty | Error | `Spec must define at least one suite.` |

### Connections

| Rule | Severity | Message |
|------|----------|---------|
| Name must not be empty | Error | `Connection 'name' field is required and cannot be empty.` |
| Names must be unique | Error | `Duplicate connection name: {name}` |
| ConnectionStringEnv must not be empty | Error | `Connection 'connectionStringEnv' field is required and cannot be empty.` |

### Suites

| Rule | Severity | Message |
|------|----------|---------|
| Name must not be empty | Error | `Suite 'name' field is required and cannot be empty.` |
| Connection must reference valid connection | Error | `Suite references undefined connection '{connection}'.` |
| Checks must not be empty | Error | `Suite must contain at least one check.` |

### Checks (Common)

| Rule | Severity | Message |
|------|----------|---------|
| Type must be valid | Error | `Unknown check type: {type}. Must be one of: queryContract, invariant, permission.` |
| Name must not be empty | Error | `Check 'name' field is required and cannot be empty.` |
| Description must not be empty | Error | `Check 'description' field is required and cannot be empty.` |
| Query must not be empty | Error | `Check 'query' field is required and cannot be empty.` |

### Query Contract Checks

| Rule | Severity | Message |
|------|----------|---------|
| ExpectedColumns must not be empty | Error | `QueryContract check 'expectedColumns' field is required and must contain at least one column.` |
| Column name must not be empty | Error | `Expected column at index {index} has empty or missing 'name'.` |
| Column sqlType must not be empty | Error | `Expected column at index {index} has empty or missing 'sqlType'.` |
| ExpectedRowCount must be non-negative | Error | `QueryContract check 'expectedRowCount' must be non-negative.` |

### Invariant Checks

| Rule | Severity | Message |
|------|----------|---------|
| Operator must not be empty | Error | `Invariant check 'operator' field is required and cannot be empty.` |
| Operator must be valid | Error | `Invalid operator: {operator}. Must be one of: equals, notEquals, greaterThan, lessThan, ...` |
| ExpectedValue must not be empty | Error | `Invariant check 'expectedValue' field is required and cannot be empty.` |

### Permission Checks

| Rule | Severity | Message |
|------|----------|---------|
| Principal must not be empty | Error | `Permission check 'principal' field is required and cannot be empty.` |
| Must specify expectedAllow or expectedDeny | Error | `Permission check must specify at least one of 'expectedAllow' or 'expectedDeny'.` |
| ExpectedAllow entries must not be empty | Error | `Permission in 'expectedAllow' at index {index} cannot be empty.` |
| ExpectedDeny entries must not be empty | Error | `Permission in 'expectedDeny' at index {index} cannot be empty.` |
| No overlap between allow and deny | Error | `Permission check has overlapping permissions in both 'expectedAllow' and 'expectedDeny': {permissions}` |

---

## Determinism Requirements

SqlGuard enforces determinism to ensure consistent results across runs and environments. These requirements apply at both spec validation time and runtime.

### Query Ordering

**Rule**: Queries that compare row-by-row results MUST include explicit `ORDER BY` clauses.

**Applies to**:
- Query Contract checks (if row count is validated or baseline comparison is used)
- Any check where row order affects the result

**Rationale**: Without explicit `ORDER BY`, SQL Server (and other databases) may return rows in non-deterministic order, causing spurious failures in CI/CD pipelines.

✅ **Good** (deterministic):
```yaml
query: |
  SELECT UserId, Username, Email
  FROM Users
  WHERE IsActive = 1
  ORDER BY UserId  -- ✅ Explicit ordering
```

❌ **Bad** (non-deterministic):
```yaml
query: |
  SELECT UserId, Username, Email
  FROM Users
  WHERE IsActive = 1  -- ❌ No ORDER BY - row order is undefined
```

### Culture and Formatting

- **Timestamps**: Always use UTC timestamps in output
- **Number formatting**: Use invariant culture for all numeric conversions
- **String comparisons**: Case-sensitive by default unless otherwise specified
- **Sorting**: All output lists (suites, checks, columns, permissions) are sorted deterministically

### Recommendations

1. **Always use ORDER BY** in queries for query contract checks
2. **Use explicit column lists** instead of `SELECT *`
3. **Avoid functions that return non-deterministic values** in checks (e.g., `NEWID()`, `GETDATE()` without fixed reference)
4. **Use parameterized date ranges** for invariant checks when possible

---

## Examples

### Minimal Valid Spec

The smallest valid SqlGuard spec:

```yaml
version: 1

connections:
  - name: db
    connectionStringEnv: SQLGUARD_CONN

suites:
  - name: basic-checks
    connection: db
    checks:
      - type: queryContract
        name: simple-check
        description: Basic query contract
        query: SELECT 1 AS Value
        expectedColumns:
          - name: Value
            sqlType: int
            nullable: false
```

### Query Contract Example

```yaml
- type: queryContract
  name: customer-list-api
  description: Customer list endpoint structure
  query: |
    SELECT 
      CustomerId,
      CustomerName,
      Email,
      CreatedAt,
      IsActive
    FROM Customers
    WHERE IsActive = 1
    ORDER BY CustomerId
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
    - name: CreatedAt
      sqlType: datetime2
      nullable: false
    - name: IsActive
      sqlType: bit
      nullable: false
```

### Invariant Example

```yaml
- type: invariant
  name: referential-integrity
  description: All orders must have valid customer references
  query: |
    SELECT COUNT(*) AS ViolationCount
    FROM Orders o
    LEFT JOIN Customers c ON o.CustomerId = c.CustomerId
    WHERE c.CustomerId IS NULL
  operator: equals
  expectedValue: '0'
```

### Permission Example

```yaml
- type: permission
  name: readonly-user-permissions
  description: Read-only user should only have SELECT
  query: |
    SELECT permission_name
    FROM fn_my_permissions('dbo.Users', 'OBJECT')
    WHERE permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
  principal: readonly_user
  expectedAllow:
    - SELECT
  expectedDeny:
    - INSERT
    - UPDATE
    - DELETE
```

### Complete Multi-Suite Example

See the full examples in the examples directory:
- [`examples/minimal.yaml`](examples/minimal.yaml) - Minimal but complete spec
- [`examples/query-contract.yaml`](examples/query-contract.yaml) - Query contract validation examples
- [`examples/invariant.yaml`](examples/invariant.yaml) - Invariant check examples
- [`examples/permission.yaml`](examples/permission.yaml) - Permission check examples

---

## Validation Testing

To validate a spec file:

```bash
sqlguard validate-spec --spec sqlguard-spec.yaml
```

**Exit Codes:**
- `0` - Spec is valid
- `2` - Spec has validation errors
- `3` - Runtime errors (file not found, YAML parse errors, etc.)

**Example Output (Valid):**
```
✅ Spec validation passed
Path: sqlguard-spec.yaml
Connections: 2
Suites: 3
Checks: 12
```

**Example Output (Invalid):**
```
❌ Spec validation failed with 3 errors:

[suites[0].connection] Suite references undefined connection 'nonexistent-db'.
[suites[1].checks[0].expectedColumns] QueryContract check 'expectedColumns' field is required and must contain at least one column.
[suites[2].checks[3].principal] Permission check 'principal' field is required and cannot be empty.
```

---

## Report Output Schema

SqlGuard generates a JSON report when executed with the `run` command. The report has a stable schema that follows semantic versioning.

### Top-Level Report Structure

```json
{
  "toolVersion": "1.0.0",
  "startedUtc": "2026-01-09T10:30:00.0000000Z",
  "finishedUtc": "2026-01-09T10:30:01.2340000Z",
  "specHash": "a3f5e9b2...",
  "summary": { /* ReportSummary */ },
  "suites": [ /* SuiteResult[] */ ]
}
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `toolVersion` | string | Version of SqlGuard that produced this report (semantic versioning) |
| `startedUtc` | string | UTC timestamp when execution started (ISO 8601 format) |
| `finishedUtc` | string | UTC timestamp when execution finished (ISO 8601 format) |
| `specHash` | string | SHA-256 hash of the spec file used for this execution |
| `summary` | object | Summary statistics for this execution |
| `suites` | array | Ordered list of suite results (matches spec file order) |

### Report Summary

```json
{
  "totalChecks": 5,
  "passedChecks": 3,
  "failedChecks": 1,
  "erroredChecks": 1,
  "skippedChecks": 0,
  "errorCategory": 1
}
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `totalChecks` | number | Total number of checks executed |
| `passedChecks` | number | Number of checks that passed |
| `failedChecks` | number | Number of checks that failed validation |
| `erroredChecks` | number | Number of checks that encountered execution errors |
| `skippedChecks` | number | Number of checks that were skipped |
| `errorCategory` | number | Overall error category (see mapping below) |

**Error Category Mapping:**
- `0` (`None`) → Exit code 0 (all checks passed)
- `1` (`ValidationFailure`) → Exit code 1 (one or more checks failed assertions)
- `2` (`ConfigurationError`) → Exit code 2 (spec is invalid or has configuration issues)
- `3` (`RuntimeError`) → Exit code 3 (connectivity, SQL execution, or system errors)

### Suite Result

```json
{
  "name": "contract-validation",
  "status": 1,
  "durationMs": 567,
  "checks": [ /* CheckResult[] */ ]
}
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Name of the suite (from spec file) |
| `status` | number | Overall status: `0` (Pass), `1` (Fail), `2` (Error), or `3` (Skipped) |
| `durationMs` | number | Total duration of all checks in this suite (milliseconds) |
| `checks` | array | Ordered list of check results (matches spec file order) |

### Check Result

```json
{
  "id": "suite-name.check-name",
  "type": "queryContract",
  "name": "check-name",
  "status": 0,
  "durationMs": 234,
  "diagnostics": { /* type-specific */ },
  "errorMessage": null
}
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier: `{suite-name}.{check-name}` |
| `type` | string | Check type: `"queryContract"`, `"invariant"`, or `"permission"` |
| `name` | string | Human-readable name of the check |
| `status` | number | Status: `0` (Pass), `1` (Fail), `2` (Error), or `3` (Skipped) |
| `durationMs` | number | Execution duration (milliseconds) |
| `diagnostics` | object | Type-specific diagnostic information (see below) |
| `errorMessage` | string | Error message (only present when `status` is `1` (Fail) or `2` (Error)) |

### Diagnostics by Check Type

#### Query Contract Diagnostics

Present only when a query contract check fails. Contains shape differences and/or row count mismatches.

```json
{
  "shapeDifferences": [
    {
      "kind": "TypeMismatch",
      "columnIndex": 2,
      "columnName": "Email",
      "details": {
        "expectedType": "nvarchar",
        "actualType": "varchar",
        "expectedNullable": false,
        "actualNullable": false
      }
    },
    {
      "kind": "MissingColumn",
      "columnIndex": 3,
      "columnName": "PhoneNumber",
      "details": {
        "expectedType": "nvarchar",
        "expectedNullable": true
      }
    }
  ],
  "rowCountMismatch": {
    "expected": 100,
    "actual": 95
  }
}
```

**Shape Difference Kinds:**
- `"TypeMismatch"` - Column type or nullability doesn't match
- `"MissingColumn"` - Expected column is missing from query result
- `"ExtraColumn"` - Query result contains unexpected column
- `"NullabilityMismatch"` - Column nullability doesn't match

#### Invariant Diagnostics

Present for all invariant checks (pass or fail). Shows the comparison result.

```json
{
  "operator": "equals",
  "expected": "100",
  "actual": "95",
  "passed": false,
  "failureReason": "Expected value '100' but got '95'"
}
```

**Fields:**
- `operator`: The comparison operator used (`equals`, `greaterThan`, `lessThan`, etc.)
- `expected`: The expected value (as string)
- `actual`: The actual value from the query (as string)
- `passed`: Boolean indicating if the check passed
- `failureReason`: Human-readable explanation (only present when `passed` is `false`)

#### Permission Diagnostics

Present only when a permission check fails. Shows which permissions are missing or unexpectedly granted.

```json
{
  "missingAllowed": ["SELECT", "INSERT"],
  "unexpectedDenied": ["DELETE", "ALTER"]
}
```

**Fields:**
- `missingAllowed`: Permissions expected to be granted but are missing
- `unexpectedDenied`: Permissions expected to be denied but are granted

Both fields are optional and only present when there are violations.

### Sample Reports

See complete sample reports in the examples directory:
- [`examples/sample-report-pass.json`](examples/sample-report-pass.json) - All checks passing
- [`examples/sample-report-fail.json`](examples/sample-report-fail.json) - Mixed results with failures and errors

### Schema Stability

The report schema follows semantic versioning:
- **Major version changes**: Breaking changes to field names, types, or removal of fields
- **Minor version changes**: Addition of new optional fields
- **Patch version changes**: No schema changes, only tooling or documentation updates

When the report schema changes, sample reports and documentation must be updated in the same PR.

---

## See Also

- [Getting Started Guide](getting-started.md)
- [Examples](examples/README.md)
- [Main README](../README.md)
