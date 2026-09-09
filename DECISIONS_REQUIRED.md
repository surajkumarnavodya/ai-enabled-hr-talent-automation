# Decisions Required

> Title: Decisions Required | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Living document | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: HR, Legal, Security, DBA, Architecture, Product

## Purpose and scope

Every decision here blocks or shapes real work and cannot be inferred from the repository alone. Each entry has a stable ID (`DEC-NNN`) — reference it from code comments, PRs, and ADRs instead of re-describing the question. When a decision is made, move it to the bottom "Resolved" table with a link to the ADR/commit that recorded it; do not delete the row.

## How to use this register

- **Status** starts `Open`. Move to `Resolved` (with a link) or `Deferred` (with a reason and revisit trigger) — never silently drop a row.
- **Default if unresolved** is what the system actually does today in the absence of a decision — not a recommendation, a factual statement of current behavior, so a reader knows the real risk of leaving it open.
- Mark legal/compliance questions `[LEGAL_REVIEW_REQUIRED]` and org-specific ones `[TENANT_CONFIGURATION_REQUIRED]` inline, per `.claude/rules/documentation.md`.

## Open decisions

### DEC-001 — Generic workflow-transition engine vs. per-entity stored procedures

- **Question:** Should the platform build the originally-designed generic `workflow_state_transition` table/engine (one shared mechanism validating transitions for every entity type), or continue the pattern used for Candidate/TAN (each entity owns a status column; each transition is its own stored procedure)?
- **Options:** (a) Keep per-entity procedures indefinitely — simplest, atomic, but no single place lists every valid transition; (b) build a generic engine once 3+ entity types need transition logic; (c) hybrid — generic engine for cross-cutting concerns (SLA tracking, escalation) layered over per-entity procedures.
- **Owner:** Architecture
- **Impact:** Determines the design of every remaining workflow (interviews, offers, Green Form, discrepancies, employee conversion) — high cost to reverse once 5+ procedures exist.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Continue the per-entity-procedure pattern (option a) — see [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md).
- **Status:** Open

### DEC-002 — Production authentication strategy (OIDC vs. BFF)

- **Question:** Which of the two supported frontend auth patterns should be implemented — OAuth 2.1/OIDC Authorization Code + PKCE via a vetted client library, or a Backend-for-Frontend with an HttpOnly session cookie? Which identity provider (Entra ID, Okta, Auth0, other)?
- **Options:** OIDC client-side token flow; BFF cookie flow (preferred per `docs/05-security-governance/frontend-security.md` where the backend architecture supports it); provider selection is a separate sub-decision.
- **Owner:** Security + Engineering
- **Impact:** Blocks any non-local deployment. Currently the frontend cannot authenticate against the real API at all (`oidcAuthProvider.ts` throws).
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Dev-only symmetric-key JWT via `/api/v1/dev/token`, gated to Development environment — unusable outside local dev.
- **Status:** Open

### DEC-003 — Vector store, message bus, and cloud provider selection

- **Question:** Which vector store (pgvector/Azure AI Search/Qdrant/Pinecone/Weaviate), messaging bus (Service Bus/RabbitMQ/Kafka), and cloud provider/region(s) should the platform target?
- **Options:** See `docs/01-architecture/technology-selection-matrix.md` for the candidate list and selection criteria.
- **Owner:** DevOps + Architecture
- **Impact:** Blocks building `HrAutomation.Rag` (retrieval) and any async integration-event delivery; blocks `infra/` population.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** No vector store, no message bus, no infrastructure-as-code exist today; `HrAutomation.Rag`/`HrAutomation.Mcp` remain empty scaffolds.
- **Status:** Open

### DEC-004 — Where do TAN/JD structured fields (Location, Grade, Budget, interview stages, criteria) live?

- **Question:** `CreateTanRequest` accepts `Location`, `Grade`, `BudgetMin`/`BudgetMax`, `InterviewStagesCount`, `ClientInterviewRequired`, `MandatoryCriteriaJson`, `PreferredCriteriaJson` — none have a column on `recruitment.JobRequisition`/`JobDescriptionVersion` today (`Location`/`Grade` there are FK lookups into `org.Location`/`org.JobGrade`, not free text). Same gap for `PatchCandidateRequest.CurrentLocation` against `recruitment.Candidate.CurrentLocationId`. Should these become FK-resolved lookups (requiring a name→ID resolution strategy), new free-text columns, or be dropped from the API contract?
- **Options:** (a) Add FK-lookup resolution (exact/fuzzy match against `org.Location`/`org.JobGrade`, with a disambiguation UX for no-match); (b) add dedicated columns for the currently-unmapped fields; (c) remove the fields from `CreateTanRequest`/`PatchCandidateRequest` and update `openapi/hr-onboarding-api.openapi.yaml` to match reality.
- **Owner:** Architecture + Product
- **Impact:** Currently these fields are silently accepted by the API and dropped — a caller reasonably assumes they were saved. This is a real, live correctness gap, not just a documentation gap.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Fields continue to be accepted and silently dropped (documented in code comments in `CreateTanSkill.cs`/`CandidatesController.cs`, but not surfaced to API callers via the contract or a response warning).
- **Status:** Open

### DEC-005 — Data residency, retention periods, right-to-erasure handling, background-check scope [LEGAL_REVIEW_REQUIRED]

- **Question:** What are the legally-required data residency constraints, per-category retention periods, right-to-erasure process, and permitted background-check scope for candidate/employee data?
- **Options:** N/A — requires Legal/Privacy input, not an engineering choice.
- **Owner:** Legal/Privacy
- **Impact:** Blocks finalizing `config/schemas/retention-policy.schema.json` defaults and `docs/03-data/data-classification-and-retention.md`.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** No retention/erasure automation exists; the schema has `IsDeleted`/soft-delete columns and audit tables but no scheduled purge process.
- **Status:** Open

### DEC-006 — Approval matrix: approver role mapping, quorum, delegation [TENANT_CONFIGURATION_REQUIRED] [Requires HR review]

- **Question:** Beyond the fixed set of gated actions (see `docs/02-business-workflows/human-approval-matrix.md`), who specifically approves each action per tenant, how many approvers, and can it be delegated? The seeded `ref.ApprovalMatrix`/`ApprovalMatrixRule` demo data (`TAN_APPROVAL_STD`: `TALENT_ACQUISITION_MANAGER` step 1) is synthetic/demo, not a real HR-approved policy.
- **Options:** Per-tenant configuration via `ref.ApprovalMatrix`/`ApprovalMatrixRule` (mechanism already built); content requires HR sign-off per tenant.
- **Owner:** HR
- **Impact:** Every implemented approval gate (currently just TAN) runs on unapproved demo configuration.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Demo seed data (`src/HrAutomation.Infrastructure/Database/seed/05-seed-workflow-approval-sla.sql`) remains in effect — not appropriate for any real tenant.
- **Status:** Open

### DEC-007 — Test data isolation strategy for `tests/HrAutomation.Tests`

- **Question:** Tests run against a real, shared `HrAutomationDb` LocalDB instance (not an isolated per-run database), because stored procedures and row-level security don't exist in EF Core's in-memory provider. Should a dedicated per-test-run database (spun up and torn down per CI run) be built, or is a shared dev database with disciplined manual cleanup acceptable for now?
- **Options:** (a) Per-test-run database via the same DDL/seed scripts, torn down after; (b) transaction-per-test rollback pattern; (c) continue shared-instance-with-manual-cleanup (current state).
- **Owner:** Engineering + QA
- **Impact:** Current state risks test-data accumulation/collisions once run in shared CI, or by more than one developer concurrently.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Shared LocalDB instance, manual cleanup (as documented in `tests/HrAutomation.Tests/HrApiFactory.cs`'s class comment).
- **Status:** Open

### DEC-008 — `config/` vs. database seed data: who owns tenant/role/approval configuration?

- **Question:** `config/schemas/`+`config/defaults/` describe a JSON/YAML-based configuration system for tenant metadata, roles, workflow stages, and approval matrices. The real implementation instead seeds this into `HrAutomationDb` directly (`iam.Role`, `ref.ApprovalMatrix`, etc.) via SQL scripts, with no code path connecting the two. Should `config/` become the authoring source that's synced into the database, should it be retired in favor of database-native configuration tooling (admin UI, migration scripts), or does it serve a different purpose (e.g., pre-provisioning/bootstrap only) that needs clarifying?
- **Options:** (a) `config/` YAML becomes the source of truth, synced into the DB by a bootstrap script; (b) retire `config/` for these domains, rely on seed SQL + a future admin UI; (c) split — some config genuinely belongs in `config/` (feature flags, model routing) while tenant/role/approval config belongs in the database.
- **Owner:** Architecture
- **Impact:** Two parallel, unreconciled configuration systems risk drifting apart; a new tenant onboarding process can't be built until this is resolved.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Database seed SQL is what's actually in effect; `config/` is unused by running code.
- **Status:** Open

### DEC-009 — Tenant model: single-tenant-per-deployment vs. shared multi-tenant

- **Question:** Is `HrAutomationDb` shared across tenants (as currently built — RLS via `SESSION_CONTEXT('TenantId')`, all tenants in one database) the permanent model, or will some tenants require physically isolated databases/deployments?
- **Options:** (a) Shared database, RLS isolation (current, implemented); (b) database-per-tenant for specific compliance tiers; (c) hybrid.
- **Owner:** Engineering + Product
- **Impact:** Affects backup/DR strategy, blast radius of an RLS bug, and per-tenant scaling.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Shared database with RLS (current implementation).
- **Status:** Open

### DEC-010 — Compensation/grade policy content [TENANT_POLICY_REQUIRED]

- **Question:** What are the real job grades, compensation bands, and associated policy content per tenant?
- **Options:** N/A — requires HR/Compensation input.
- **Owner:** HR
- **Impact:** `org.JobGrade` and compensation-reference tables exist but are seeded with fake/demo values only; no real offer-compensation flow exists yet regardless (offer skills are stubs).
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** Demo/fake grade data only; not usable for a real offer.
- **Status:** Open

### DEC-011 — CI pipeline verification

- **Question:** `.github/workflows/ci.yml`/`docs-validation.yml`/`security-scan.yml` exist but have not been confirmed to run green against the current solution (they may predate the real backend build-out, similar to the documentation package).
- **Options:** Run and fix, or rewrite against the real project structure.
- **Owner:** DevOps
- **Impact:** No enforced quality gate exists today beyond what a developer runs locally.
- **Deadline:** [TENANT_CONFIGURATION_REQUIRED]
- **Default if unresolved:** No verified CI gate; rely on local `dotnet build`/`dotnet test`/`npm run lint`/`npm run typecheck`.
- **Status:** Open

## Resolved decisions

| ID | Decision | Recorded in | Date |
|---|---|---|---|
| — | Database engine fixed to SQL Server (not a per-tenant Postgres/SQL Server choice) | [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md) | 2026-09-08 |
| — | Workflow transitions owned by per-entity stored procedures, not a generic workflow-engine table | [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md) | 2026-09-08 |
| — | AI agent skills implemented as in-process C# (`HrAutomation.Agents`), not a separate Python agent service | [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) "Superseded original plan" | 2026-09-08 |

## Related documents

[PROJECT_STATUS.md](PROJECT_STATUS.md) · [CLAUDE.md](CLAUDE.md) · [docs/00-product/scope-assumptions-open-questions.md](docs/00-product/scope-assumptions-open-questions.md) · [docs/adr/](docs/adr/)

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | Documentation reconciliation pass | Initial creation |
