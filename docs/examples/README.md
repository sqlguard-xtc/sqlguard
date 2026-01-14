# SqlGuard Examples

This directory contains validated SqlGuard spec examples demonstrating all check types.

## Available Examples

- **`minimal.yaml`** - Minimal valid spec (single query contract check)
- **`query-contract.yaml`** - Query contract checks (pass) - 5 comprehensive examples
- **`query-contract-fail.yaml`** - Query contract checks (fail) - 6 intentional failure scenarios
- **`invariant.yaml`** - Invariant checks (pass) - 10 data quality patterns
- **`invariant-fail.yaml`** - Invariant checks (fail) - 8 intentional failure scenarios
- **`permission.yaml`** - Permission checks (pass) - 8 security validation patterns
- **`permission-fail.yaml`** - Permission checks (fail) - 6 intentional failure scenarios

## Running Examples

All examples use environment variables for connection strings:

```yaml
connections:
  - name: my-database
    connectionStringEnv: SQLGUARD_CONNECTION_STRING
```

Set the environment variable before running:

```powershell
# Windows (PowerShell)
$env:SQLGUARD_CONNECTION_STRING = "Server=localhost;Database=MyDb;Integrated Security=true;"
sqlguard run minimal.yaml

# Linux/macOS
export SQLGUARD_CONNECTION_STRING="Server=localhost;Database=MyDb;User Id=user;Password=pass;"
sqlguard run minimal.yaml
```

## Adapting Examples

These examples assume a database with:
- **Customers** table (CustomerId, CustomerName, CustomerCode, Email, IsActive)
- **Products** table (ProductId, ProductName, UnitPrice, IsActive)
- **Orders** table (OrderId, CustomerId, OrderDate, TotalAmount)
- **OrderItems** table (OrderItemId, OrderId, ProductId, Quantity, UnitPrice)

Modify the queries and table/column names to match your database schema.

For permission examples, you'll need database users with appropriate permissions:
- `app_user` - Application user with SELECT permissions
- `readonly_user` - Read-only user
- `writer_user` - User with SELECT and INSERT permissions
- `admin_user` - Administrative user

**Never commit hardcoded credentials to version control.**
