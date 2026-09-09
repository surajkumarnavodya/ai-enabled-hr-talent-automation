# Persistence/

EF Core persistence layer for `HrAutomation.Infrastructure`.

## Two DbContexts — compatibility note (read this first)

- **`HrDbContext.cs`** (existing, pre-dates this package) — maps an earlier, smaller
  subset of the domain (Tenants, Candidates, JobRequisitionTans, Interviews, Offers,
  etc.) into an implicit default schema, with one migration:
  `Migrations/20260907174351_InitialCreate`. **This is not overwritten or deleted by
  this package.**
- **`HrAutomationDbContext.cs`** (added by this package) — maps the full, schema-
  qualified design in `../Database/docs/entity-relationship-diagram.md` and
  `../Database/docs/data-dictionary.md` (`ref/iam/org/recruitment/offer/onboarding/
  employee/workflow/integration/ai/audit` schemas), matching `../Database/scripts/`.

**These two contexts are not intended to run against the same database long-term** —
see `../Database/migrations/README.md` for the reconciliation plan and the decision this
requires from architecture review before either migration path is treated as
authoritative going forward.

## Folder layout

- `Configurations/` — one `IEntityTypeConfiguration<T>` per entity, grouped by schema
  subfolder (`Configurations/Iam/`, `Configurations/Recruitment/`, ...). Each
  configuration sets `ToTable("TableName", "schemaName")`, keys, `RowVersion` as a
  concurrency token, and any owned types/value conversions.
- `Interceptors/` — `SaveChanges` interceptors for audit-column population
  (`CreatedAtUtc`/`UpdatedByUserId`/etc.) and soft-delete-to-update rewriting, so every
  write path gets these consistently without repeating logic in every use case.
- `Repositories/` — repository implementations for `HrAutomation.Application`'s
  repository interfaces. See "Repositories vs. stored procedures" below.
- `Migrations/` — EF Core migrations for `HrDbContext` (existing). A parallel
  migrations folder for `HrAutomationDbContext` is created once that context's model is
  finalized and the reconciliation decision above is made — see
  `../Database/migrations/README.md`.

## When to use EF Core vs. a stored procedure (`../Database/scripts/07-*`)

- **Simple CRUD, single-aggregate reads/writes** (candidate profile edit, CV upload
  metadata, master-data lookups): EF Core via a repository, no procedure required.
- **Multi-entity, security-sensitive, or workflow-critical actions** (offer approval,
  employee conversion, discrepancy resolution, anything that must write an audit event
  and an outbox message atomically): the corresponding `../Database/scripts/07-create-
  stored-procedures.sql` procedure, invoked via `DbContext.Database
  .SqlQuery<T>()`/`ExecuteSqlInterpolatedAsync` with parameters — never string-built SQL.
  This keeps the transaction boundary, audit write, and outbox write atomic and
  reviewable in one place instead of spread across application code.
- Stored procedures are **not** mandated for every table — see
  `../Database/docs/stored-procedure-catalog.md` for exactly which actions have one.

## Conventions applied by `HrAutomationDbContext`

- Default schema is **not** set globally; every entity configuration is explicit about
  its schema via `ToTable(name, schema)`, matching `../Database/scripts/01-create-
  schemas.sql`.
- `RowVersion` (SQL `rowversion`) mapped with `.IsRowVersion()` as the concurrency token
  on every mutable business entity.
- A global soft-delete query filter (`HasQueryFilter(e => !e.IsDeleted)`) is applied per
  entity that has `IsDeleted`; use `IgnoreQueryFilters()` explicitly (and only in
  approved admin/audit paths) to see soft-deleted rows.
- `TenantId` is **not** enforced via an EF Core global query filter alone — see
  `../Database/docs/rls-design.md` "Defense-in-depth" for why SQL Server RLS is the
  backstop and the Application layer's `ICurrentTenantProvider` is the primary control.
  Where EF Core global filters on `TenantId` are used, they are explicitly documented as
  UX/correctness convenience, not the security boundary.
- Connection resiliency: `EnableRetryOnFailure` for transient Azure SQL/SQL Server
  failures, configured in `HrAutomation.Api/Program.cs` alongside `UseSqlServer`.
- `EnableSensitiveDataLogging` and `EnableDetailedErrors` are **only** enabled when
  `ASPNETCORE_ENVIRONMENT=Development`, never in staging/production — see
  `../../HrAutomation.Api/Program.cs` and `.env.example`.
