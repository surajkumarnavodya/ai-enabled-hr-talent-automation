# HrAutomation.Database

Authoritative Microsoft SQL Server 2022+ database design and deployment package for the
HR Recruitment and Onboarding Automation platform. This folder is the **source of truth
for schema-level DDL** (tables, keys, indexes, security, functions, procedures, views,
triggers, seed/reference data). It is deployed independently of the EF Core migration
pipeline described in [`../Persistence/README.md`](../Persistence/README.md) — see
**"Which mechanism owns the schema?"** below before changing either.

## Why a database project instead of (or alongside) EF Core migrations

This platform's `HrAutomation.Infrastructure` project already has EF Core migrations
under `Persistence/Migrations/` (see `20260907174351_InitialCreate`). Per
[docs/03-data/database-migration-strategy.md](../../../docs/03-data/database-migration-strategy.md)
and `.claude/rules/data.md`, every schema change is a versioned, additive-first migration.

This `Database/` package exists because the required deliverable — Row-Level Security
policies, `SESSION_CONTEXT`-based predicates, system-versioned temporal tables, SQL
Server Audit, database roles/grants, and stored-procedure-based sensitive-write paths —
is SQL Server-specific programmability that EF Core's migration DSL does not model.
**EF Core owns table/column/index shape. This package owns everything SQL-Server-native
that sits on top of those tables.**

### Which mechanism owns the schema? (read this before touching either)

- **EF Core migrations** (`Persistence/Migrations/`) are authoritative for: table
  existence, columns, primitive constraints, FK shape, and are what `dotnet ef database
  update` applies at deploy time.
- **This `Database/` package** is authoritative for: schemas, RLS predicates/policies,
  database roles and grants, stored procedures, views, functions, triggers, temporal
  table enablement, SQL Server Audit configuration, and reference/seed data.
- **Deployment order:** `scripts/00` → `01` → EF Core `dotnet ef database update` (creates
  tables in the schemas from step 01) → `scripts/04` onward (keys/indexes not already
  covered by EF, security, functions, procedures, views, triggers, seed data) →
  `99-validate-database.sql`. See
  [docs/database-deployment-guide.md](docs/database-deployment-guide.md) for the full
  sequence and `migrations/README.md` for the reconciliation plan between the two
  mechanisms.
- **Do not** let developers hand-edit table shape directly against a database and then
  reverse-engineer it into either mechanism — this is unmanaged drift and is explicitly
  disallowed.

## Folder map

| Folder | Contents |
|---|---|
| `scripts/` | Idempotent, numbered, ordered T-SQL deployment scripts (00 through 99) |
| `publish/` | SqlPackage/dacpac publish profile examples (placeholders only, no secrets) |
| `migrations/` | Reconciliation plan/notes between this package and EF Core migrations |
| `seed/` | Synthetic demo data for local development and manual testing |
| `docs/` | Architecture, ERD, data dictionary, catalogs, security, retention, deployment docs |
| `tests/` | T-SQL validation and behavioral test scripts (tenant isolation, workflow integrity, etc.) |

## Quick start (local development)

```bash
# 1. Confirm the LocalDB instance is available
sqllocaldb info MSSQLLocalDB

# 2. Create the database (name is configurable — see scripts/00-create-database.sql)
sqlcmd -S "(localdb)\MSSQLLocalDB" -U sa -P "$HR_AUTOMATION_DB_SA_PASSWORD" -C -v DatabaseName="HrAutomationDb" -i scripts/00-create-database.sql

# 3. Run the rest of the numbered scripts in order (01, 02, ...) against that database,
#    OR let `dotnet ef database update` create tables between steps 01 and 04 — see
#    docs/database-deployment-guide.md for the exact interleaving.

# 4. Validate
sqlcmd -S "(localdb)\MSSQLLocalDB" -U sa -P "$HR_AUTOMATION_DB_SA_PASSWORD" -C -d HrAutomationDb -i scripts/99-validate-database.sql
```

Never pass a real password on a shell command line in a shared/logged environment;
`$HR_AUTOMATION_DB_SA_PASSWORD` above is illustrative for a local, single-user dev
machine only. See [docs/database-deployment-guide.md](docs/database-deployment-guide.md)
for staging/production, which use a managed identity or vault-issued credential instead
of a SQL login.

## Database name

Default: `HrAutomationDb`. Configurable via the `DatabaseName` sqlcmd variable in every
script (see `scripts/00-create-database.sql`) and via `ConnectionStrings:HrAutomationDb`
/ `HR_AUTOMATION_DB_CONNECTION_STRING` at the application layer — see
[HrAutomation.Api/appsettings.json](../../HrAutomation.Api/appsettings.json) and
[.env.example](../../../.env.example).

## Non-negotiables enforced throughout this package

These mirror the root [CLAUDE.md](../../../CLAUDE.md) and `.claude/rules/*.md` and are
re-verified by `scripts/99-validate-database.sql`:

- Every tenant-owned table carries `TenantId UNIQUEIDENTIFIER NOT NULL` and is covered
  by a Row-Level Security policy in the `security` schema.
- No table stores a plaintext password, secret, token, or raw connection string.
- No document/CV binary content is stored in a relational column — only object-storage
  references and metadata.
- Every sensitive state transition (offer send, discrepancy closure, Employee ID
  creation, candidate rejection) requires an approval/workflow record — the database
  provides defense-in-depth validation, the API is the primary authorization layer.
- Audit tables (`audit.*`) are append-only; a trigger blocks `UPDATE`/`DELETE`.
- Money uses `decimal(19,4)` with an ISO-style `char(3)` currency code; timestamps use
  UTC `datetime2(7)`.
