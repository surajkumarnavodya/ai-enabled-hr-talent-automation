# migrations/ — reconciliation with EF Core migrations

This folder intentionally holds **no SQL**. Table/column/index/FK shape is owned by
EF Core migrations in
[`../../Persistence/Migrations/`](../../Persistence/Migrations/) — see the
authoritative split in [`../README.md`](../README.md) ("Which mechanism owns the
schema?").

## Existing state (do not overwrite)

An EF Core migration already exists: `20260907174351_InitialCreate`, generated from
`HrDbContext` against a database literally named `HrAutomation` (see
`src/HrAutomation.Infrastructure/Persistence/HrDbContext.cs`). Per this package's
instructions, that migration is **not** overwritten here.

## Reconciliation plan

This `Database/` package introduces a second, more complete `HrAutomationDbContext`
(see `../../Persistence/HrAutomationDbContext.cs`) that supersedes `HrDbContext` for the
full schema described in `docs/entity-relationship-diagram.md` and
`docs/data-dictionary.md` (multi-schema, ~250 tables across `ref/iam/org/recruitment/
offer/onboarding/employee/workflow/integration/ai/audit`). `HrDbContext` covered a
smaller, earlier subset of the same domain (Tenants, Candidates, Tans, Interviews,
Offers, etc., all in one implicit `dbo`-style mapping).

Recommended path (requires an explicit decision — flagged for architecture review, see
final report "Decisions requiring review"):

1. **Do not run both DbContexts against the same database concurrently long-term.**
   They will produce colliding or divergent table definitions for overlapping concepts
   (e.g., `Candidate`, `JobRequisitionTan`, `Offer`).
2. Recommended: retire `HrDbContext` and its `InitialCreate` migration in a dedicated,
   reviewed migration PR that (a) generates a fresh EF Core migration from
   `HrAutomationDbContext` against a **new** empty database, (b) migrates any already-
   deployed local/dev data with a one-time data-migration script (out of scope for this
   package — write one only if a real dev database with data to preserve exists), and
   (c) deletes `HrDbContext`/its migration once nothing references it.
3. Until that decision is made and executed, run this package's `scripts/00`–`01`
   (database + schema creation) against a **separate** database name (default
   `HrAutomationDb`, distinct from the existing `HrAutomation` database created by
   `HrDbContext`) so the two do not collide. This is why `scripts/00-create-database.sql`
   defaults to `HrAutomationDb`, not `HrAutomation`.
4. Once `HrAutomationDbContext` migrations are generated (`dotnet ef migrations add
   InitialCreate --project src/HrAutomation.Infrastructure --startup-project
   src/HrAutomation.Api --context HrAutomationDbContext`), review the generated SQL
   against `scripts/03-create-tables.sql` and `scripts/04-create-keys-indexes-
   constraints.sql` in this package for drift before applying to any shared environment.

## Migration review checklist (every future migration)

- [ ] Generated migration reviewed line-by-line, not just `dotnet ef database update`'d blind.
- [ ] Additive-first: no `DROP COLUMN`/`DROP TABLE` in the same release that stops writing to it.
- [ ] Any new tenant-owned table has `TenantId` + a corresponding RLS policy added to
      `../scripts/05-create-security.sql` PART B in the same change.
- [ ] Any new sensitive table has a data-dictionary entry and retention classification.
- [ ] Rollback script or `dotnet ef migrations remove`/down-migration verified locally.
