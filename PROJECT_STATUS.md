# Project Status

> Title: Project Status | Version: 1.1 | Owner: [TENANT_CONFIGURATION_REQUIRED — Engineering Lead] | Status: Living document | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED — recommend every 2 weeks or at every milestone] | Reviewers: Engineering, Product, Architecture

## Purpose and scope

The authoritative, maintained record of what is actually built versus planned in this repository, as evidence-based as possible: every "Implemented" claim below reflects a real, run command (`dotnet build`, `dotnet test`, live HTTP calls against a running API and a real database) or direct code inspection performed in the session that recorded it — not an inference from documentation. Update this file whenever implementation status changes; it is the single place other documents point to for "is X actually done."

## How to read the status labels

| Label | Meaning |
|---|---|
| Implemented | Real code exists, builds, and has been exercised (test or live call) against a real dependency (real database, real HTTP server) |
| Partially implemented | Some real code/data path exists but a materially significant piece is missing, stubbed, or unverified |
| Scaffolded | A project/folder/file exists (possibly with a README) but contains no real logic — a placeholder for future work |
| Planned | Described in documentation/config schemas but no code exists |
| Deferred | Explicitly out of scope for the current phase |
| Requires decision / HR / security / legal / DBA review | See [DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md) for the specific open item |

## Current milestone

First vertical slice of the recruitment workflow (CV ingestion → Master CV Bank; TAN creation → approval) implemented database-first against a real SQL Server schema, **and now the React frontend (`HrAutomation.Web`) is genuinely wired to it end-to-end** for that same slice: TAN list/create/approve and CV upload/candidate list/candidate profile all make real HTTP calls to `HrAutomation.Api`, persist into `HrAutomationDb`, and read back server-authoritative data — verified via a real headless-browser run against the live API and confirmed independently with a direct SQL query (see [docs/09-quality-evaluation/live-sql-server-integration-verification.md](docs/09-quality-evaluation/live-sql-server-integration-verification.md)). MSW is now OFF by default at runtime; a `VITE_AUTH_MODE=devToken` provider obtains a real signed JWT from the backend's dev-only token endpoint. **New this pass**: the first slice of the Administration/Master-Management module — real, database-backed effective-permission checking (`iam.RolePermission`) and User read/list/detail (`/admin/users`) — see [docs/09-quality-evaluation/master-management-gap-analysis.md](docs/09-quality-evaluation/master-management-gap-analysis.md) for the full 22-area gap analysis and priority order. Next milestone: user creation/role assignment (with anti-escalation checks) and role/permission management, per that gap analysis's P0 list.

## Capability status

| Capability | Status | Evidence / detail |
|---|---|---|
| CV upload, parsing, Master CV Bank | **Implemented, frontend-connected** | `POST /api/v1/candidates/cvs` → `parse_cv_skill` → `recruitment.usp_CreateCandidate` + `CandidateCv`/`CandidateCvVersion`/`CvParsingResult`/`CvExtractionField`. Duplicate detection is suggestion-only (`usp_CreateDuplicateReview`), never auto-merged. `CvUploadPage` uploads one file per real API call (the endpoint takes a single `IFormFile`) and shows the server's actual per-file result. Verified via live HTTP call, `dotnet test`, and a real headless-browser run. |
| Candidate profile read/list/patch | **Implemented, frontend-connected (list/get only)** | `GET /api/v1/candidates`, `GET /api/v1/candidates/{id}`, `PATCH /api/v1/candidates/{id}` (RowVersion/`If-Match` optimistic concurrency, no frontend UI for this yet). Cursor pagination verified live. `CurrentLocation` field accepted but not persisted — see DEC-004. `GET /api/v1/candidates/{id}/cvs` (a per-candidate CV list) does **not exist** — `CandidateProfilePage` shows a truthful "not available yet" state instead of calling it. |
| TAN / Job Requisition creation | **Implemented, frontend-connected** | `POST /api/v1/tans` → `create_tan_skill` → `recruitment.usp_CreateTalentAcquisitionNumber` + `usp_CreateJobRequisition` + JD version rows, auto-submitted for approval (`usp_SubmitJobRequisitionForApproval`). `Location`/`Grade`/`Budget*`/`InterviewStagesCount`/`ClientInterviewRequired`/criteria-JSON fields accepted by the API but not persisted — see DEC-004. `TanFormPage` submits real values and navigates to the server-generated `tan_id` on success, then re-fetches. |
| TAN approval / rejection | **Implemented, frontend-connected** | `POST /api/v1/tans/{id}/approve` → `tan_approval_skill` → `recruitment.usp_ApproveJobRequisition` / `usp_RejectJobRequisition` (the latter added this pass — no reject procedure existed before). "Returned for info" is audit-only, no state change, by design. `TanDetailPage`'s Approve button calls this for real, behind a confirmation dialog. |
| TAN list | **Implemented, frontend-connected** | `GET /api/v1/tans` (added this pass — did not exist before; `TanListPage` was calling a route that 404'd against the real backend). Cursor-paginated, mirrors `ListCandidates`'s pattern. |
| Current user profile | **Implemented, frontend-connected** | `GET /api/v1/users/me` (added this pass) — returns tenant/user/role/display name from the validated JWT, enriched with `iam.User.DisplayName`. Used by `devTokenAuthProvider` right after login. |
| Admin: effective permissions | **Implemented, frontend-connected** | `GET /api/v1/users/me/permissions` (new) — real `iam.UserRole`→`iam.Role`→`iam.RolePermission`→`iam.Permission` resolution, deny-by-default. First endpoint gated by the new `IEffectivePermissionService` rather than a role-string list; used by `RequirePermissionAsync` (new `HrControllerBase` helper) on every `/admin/*` endpoint, and by `useHasPermission()` on the frontend. |
| Admin: user read/list/detail | **Implemented, frontend-connected** | `GET /api/v1/admin/users` (cursor-paginated, search by name/email, filter by status), `GET /api/v1/admin/users/{userId}` (profile, department/location names, active role list, server-computed `allowed_actions`). Gated on the real `user.read` permission (403 + audit event on denial, verified live). `AdminUsersListPage`/`AdminUserDetailPage` under `/admin/users`, verified via a live headless-browser run against the real API — 17 real seeded users render, detail page shows real department/role data. User create/edit/activate/deactivate/role-assignment are **not yet implemented** — next batch. |
| Health check | **Implemented** | `GET /health` (added this pass, unauthenticated by design) — verifies `HrAutomationDb` reachability via `db.Database.CanConnectAsync()`, never leaks connection string/server name/exception text. Polled by the frontend's dev-only status indicator every 30s. |
| TAN / candidate read + audit log | **Implemented (audit log not yet frontend-connected)** | `GET /api/v1/audit-logs`, `GET /api/v1/workflows/{approvalRequestId}` (repurposed to read `workflow.ApprovalRequest`, since no generic `WorkflowInstance` table exists — see ADR-006). `AuditPage` still shows MSW-only mock data — not touched this pass. |
| Candidate matching (AI) | **Scaffolded** | `match_candidates_skill` registered but is a stub — always returns `blocked`/"not yet implemented." No matching logic, no `CandidateMatchScore` writes. |
| Shortlist approval | **Scaffolded** | `shortlist_approval_skill` stub only. |
| Interview scheduling / feedback | **Scaffolded** | `create_interview_skill`, `interview_feedback_skill`, `progression_approval_skill` stubs only. `recruitment.Interview*` tables exist in the database with no application code reading/writing them. |
| Offer drafting / approval / send / acceptance | **Scaffolded** | `create_offer_skill`, `offer_approval_skill`, `offer_send_skill`, `offer_acceptance_skill` stubs only. `offer.*` tables exist, unused. |
| Green Form / document upload / verification | **Scaffolded** | `green_form_issue_link_skill`, `document_verify_skill` stubs only. `onboarding.*` tables exist, unused. |
| Discrepancy management | **Scaffolded** | `discrepancy_resolve_skill` stub only. `onboarding.Discrepancy*` tables exist, unused. |
| Employee conversion / Employee ID | **Scaffolded** | `employee_conversion_skill` stub only. `employee.*` tables exist (including `usp_GenerateEmployeeId`/`usp_CreateEmployeeFromCandidate`/`usp_ApproveEmployeeConversion` stored procedures — written but never called from application code). |
| Downstream integrations (HRMS, payroll, calendar, email, e-signature, background-verification, IT provisioning) | **Not present** | No adapter code, no MCP tool servers. `integration.*` tables (outbox, external-system mapping) exist, unused. |
| RAG (policy retrieval) | **Not present** | `HrAutomation.Rag` project is an empty scaffold. No ingestion pipeline, no retrieval, no vector store integration. `ai.Rag*` tables exist, unused. |
| MCP tool servers | **Not present** | `HrAutomation.Mcp` project is an empty scaffold. `mcp/` folder holds only manifests/schemas as documentation, not a running server. |
| Database (`HrAutomationDb`) | **Implemented** | SQL Server, database-first, ~243 tables across 11 schemas, RLS via `SESSION_CONTEXT`, ~30+ stored procedures, triggers, functions, views, seeded reference/demo data. Deployed and verified against LocalDB this session. Far ahead of the application code that uses it — most tables have no C# code wired to them yet. |
| Authentication | **Partially implemented** | Dev-only symmetric-key JWT via `/api/v1/dev/token`, gated to Development environment. Row-level security enforced via `TenantSessionContextMiddleware` setting `SESSION_CONTEXT('TenantId')` per request. No production OIDC/OAuth 2.1 provider — `oidcAuthProvider.ts` (frontend) is an intentional stub that throws. |
| Frontend (`HrAutomation.Web`) | **Partially implemented, TAN + CV Bank/candidates frontend-connected** | Real React/TypeScript app, builds and runs (Vite), typechecks and lints clean. MSW is now **off by default** (`VITE_ENABLE_MSW=false`); `VITE_AUTH_MODE=devToken` (new) obtains a real signed JWT from `/api/v1/dev/token` and every subsequent call hits the real API. Verified via a real headless-browser run: login → TAN list → create TAN (real POST, server-generated `tan_id`/TAN number, re-fetched detail page) → approve TAN → CV Bank list/upload, all against the real database, cross-checked with a direct SQL query. A dev-only status strip shows API reachability/MSW state/auth state. Interviews, Offers, Verification, Discrepancies, Employee Conversion, Approvals, Audit, and the dashboard summary still show only MSW/mock data or a truthful "not available" state — their backend endpoints don't exist yet (see rows above/below). MSW handlers/fixtures are retained for Vitest only; nothing in the normal runtime path imports them. |
| Testing | **Partially implemented** | `tests/HrAutomation.Tests`: 35 xUnit tests, all passing, run against a real `HrAutomationDb` instance (not mocked) — covers CV upload, TAN create/approve/reject/wrong-role flows, health/current-user/TAN-list, and the new admin effective-permissions/user-list/detail/tenant-isolation suite. Frontend: 40 Vitest tests passing (`npm run test`), typecheck/lint clean. No contract, e2e (Playwright `test:e2e` exists but unverified this pass), performance, or security test run confirmed. No test isolation between runs beyond manual cleanup (see DEC-007). |
| Config-first (`config/`) | **Scaffolded** | Schemas and defaults exist and pass syntax validation (`scripts/validate-config.sh`). Not yet wired to any running application code — the real backend's configuration (roles, approval matrix, numbering rules) lives in `HrAutomationDb` seed data instead, not `config/`. This is a real, unreconciled duplication — see DEC-008. |
| API contract (`openapi/`) | **Partially implemented** | `openapi/hr-onboarding-api.openapi.yaml` validates (`npm run api:validate`, 29 paths). Response DTO shapes for the implemented endpoints are already string-based (not enum-coupled), so they did not need to change during this session's database migration. Not confirmed to be 100% in sync with every implemented endpoint's actual behavior (e.g. `GET /api/v1/workflows/{id}` semantics changed — see ADR-006). |
| CI/CD | **Scaffolded** | `.github/workflows/ci.yml`, `docs-validation.yml`, `security-scan.yml` exist; none confirmed to run green against the current solution. |

## Open risks

- The documentation package (`docs/`, `config/`, `openapi/` in part) was generated independently of, and before, the real database/backend build-out. Several documents described a different data model, a different engine (Postgres as an option), and a generic workflow-engine table that was never built. Reconciliation notices have been added to the highest-drift documents (see git history / CHANGELOG for this pass) but not every document under `docs/` has been individually re-verified against the real system — treat any document without an "Implementation reality notice" as unverified, not necessarily accurate.
- `config/` and the database's own seed data (`src/HrAutomation.Infrastructure/Database/seed/`) both claim to own tenant/role/approval-matrix configuration, with no reconciliation between them (DEC-008).
- No production secrets/auth story exists — everything runs on dev-only mechanisms today.
- Test data cleanup after manual/live-API testing is a manual `DELETE` script, not automated — a shared dev database will accumulate stray rows without discipline (DEC-007).

## Pending decisions

See [DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md) for the full register with owners and defaults. Highlights: JD/TAN structured fields (Location/Grade/Budget) have no schema home yet (DEC-004); `config/` vs. database-seed-data ownership of tenant configuration is unresolved (DEC-008); production auth strategy (OIDC vs. BFF) is unresolved (DEC-002); whether/when to build a generic workflow-transition table vs. continuing the per-entity-procedure pattern (DEC-001, tracked from ADR-006).

## Dependencies

- SQL Server / LocalDB for the database.
- .NET 8 SDK, Node.js 20+ for local development.
- No external managed services (identity provider, object storage, vector store, message bus) are wired up yet — all deferred pending the decisions in `DECISIONS_REQUIRED.md`.

## Required stakeholder reviews

Every item in [DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md) marked HR/Legal/Security/DBA review is outstanding. No formal review of this repository has been recorded — `Last reviewed` dates across `docs/` reflect authoring/reconciliation passes, not specialist sign-off.

## Next priority items

1. Extend the per-entity-status + stored-procedure pattern (ADR-006) to candidate matching and shortlist approval — the next vertical slice, now that the frontend integration pattern (real hooks, real auth, honest empty/unavailable states) is established and proven for TAN/CV Bank.
2. Resolve DEC-004 (TAN/JD structured fields) so `CreateTanRequest`'s Location/Grade/Budget fields have a real column to land in.
3. Resolve DEC-007 (test data isolation) — confirmed empirically this pass: repeated `dotnet test` runs against the shared LocalDB instance leave stray "Jane Doe"/"Senior Backend Engineer"/"QA Engineer" rows in the demo tenant that then show up in the real UI's TAN/CV Bank lists. Manual cleanup was required twice during this pass.
4. Build a real `GET /api/v1/dashboard/summary` endpoint so `DashboardPage` can show real counts instead of its current honest "not available" state.
5. Generate a real data dictionary/ER diagram from the live `HrAutomationDb` schema to replace the superseded originals under `docs/03-data/`.
6. Confirm CI workflows actually run green against the current solution.
7. Decide DEC-002 (production auth) before any non-local deployment — `devToken` mode is explicitly dev-only.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | Documentation reconciliation pass | Initial creation |
