# Changelog

All notable changes to this repository's documentation, Claude Code context, and configuration are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) categories (Added, Changed, Deprecated, Removed, Fixed, Security). This file does not claim application releases or version tags — no versioned release of the application has occurred; see [PROJECT_STATUS.md](PROJECT_STATUS.md) for implementation state instead.

## [Unreleased]

### Added (2026-09-09, Administration/Master-Management — batch 1: gap analysis + users foundation)

- `docs/09-quality-evaluation/master-management-gap-analysis.md` — full inspection of the real DDL/seed scripts and backend/frontend code against all 22 requested Administration areas: which tables exist, which don't (no MCP-tool-level table, no BusinessUnit/Client-level user access-scope table), which stored procedures exist versus were assumed, and a P0/P1/P2/P3 build-order recommendation.
- `IEffectivePermissionService` (`HrAutomation.Application.Security` / `HrAutomation.Infrastructure.Security`) — the platform's first real, database-backed permission check: `iam.UserRole` (active) → `iam.Role` (active) → `iam.RolePermission` → `iam.Permission` (active), deny-by-default. Previously every endpoint checked only a hardcoded per-skill role-string list; the 91 seeded `iam.Permission` rows were unused by any C# code until this pass.
- `HrControllerBase.RequirePermissionAsync` — reusable permission gate that writes an `authorization.denied` audit event (via the now-generic `AuditLogEntry.EntityType`/`EntityId`) before returning 403, so denied attempts are audited, not just approved actions.
- `GET /api/v1/users/me/permissions` — real effective-permissions endpoint; replaces, for the Administration module specifically, the frontend's former hardcoded `ROLE_PERMISSIONS` approximation (that approximation is unchanged for the rest of the app this pass — see gap analysis for scope).
- `GET /api/v1/admin/users` (cursor-paginated, search, status filter) and `GET /api/v1/admin/users/{userId}` (profile + department/location names + active roles + server-computed `allowed_actions`) — gated on the real `user.read` permission.
- EF Core entities for `iam.UserProfile`, `iam.UserAuthenticationProvider`, `iam.Permission`, `iam.RolePermission`, `org.Department`, `org.Location` (previously unmapped); `iam.User`/`iam.Role`/`iam.UserRole` extended from 3-6 properties to their full real columns including `RowVersion`.
- `features/administration/AdminUsersListPage.tsx`/`AdminUserDetailPage.tsx` under new `/admin/users` routes — real TanStack Query hooks (`useAdminUsers.ts`), gated by the real `user.read` check (not the coarse `admin.access` UX flag alone), verified via a live headless-browser run against the real API (17 real seeded users rendered).
- Backend tests: `AdminUsersAndPermissionsTests.cs` (8 tests — effective permissions by role, list/detail, 403 + audit-on-deny, tenant isolation with a real second tenant created and cleaned up in-test). Frontend tests: `tests/features/adminUsers.test.tsx` (5 tests).

### Added (2026-09-08, real end-to-end integration pass)

- `GET /api/v1/tans` (list, cursor-paginated) and `GET /api/v1/users/me` (current-user profile) on `HrAutomation.Api` — neither existed before; the frontend's TAN list page was calling a route that 404'd against the real backend.
- `GET /health` health check (`DatabaseHealthCheck`, `db.Database.CanConnectAsync()`), unauthenticated, leaks no connection/server details.
- `devTokenAuthProvider` (`VITE_AUTH_MODE=devToken`) — obtains a real signed JWT from the backend's dev-only token endpoint; `mockAuthProvider` is retained for MSW/Vitest use only.
- Dev-only integration status indicator (`DevIntegrationStatus`) showing API reachability, MSW state, and auth state — never database server name/connection string/user identity details.
- `docs/09-quality-evaluation/live-sql-server-integration-verification.md` — a manual, run-it-yourself verification procedure, executed once during this pass with real evidence (see below).
- Backend tests: `TanListAndUserProfileTests.cs` (health, current-user, TAN list, 401 cases). Frontend test: `tests/unit/env.test.ts` (MSW-default-off behavior).

### Changed (2026-09-08)

- `VITE_ENABLE_MSW` default flipped from `true` to `false`; `.env.example`/`.env.local` updated to `VITE_AUTH_MODE=devToken`, `VITE_ENABLE_MSW=false`.
- `types/auth.ts` `RoleName` and `lib/constants.ts` `ALL_ROLES` replaced with the real 20 `iam.Role.RoleName` codes (were the old, never-matching `HRRecruiter`/`HRAdmin`/etc.).
- `types/workflow.ts` `Tan`/`Candidate` interfaces rewritten to the real snake_case `TanDto`/`CandidateDto` shapes; new `types/api.ts` for the shared `CursorPage<T>`/`AgentActionResponse` envelope.
- `useTans.ts`, `useCandidates.ts` and the TAN/CV Bank/candidate-profile pages rewritten against the real contracts: fixed field names, fixed the real single-file CV upload endpoint/field name (was assuming multi-file at a different path), removed a call to a per-candidate-CV-list endpoint that doesn't exist, fixed the approval decision's exact required casing (`"Approved"`, not `"approved"`).
- `DashboardPage` now distinguishes "endpoint doesn't exist" (truthful, no retry button) from a real transient error (retryable), instead of one generic error state for both.
- `usePermissions.ts` role→permission mapping remapped to the real 20-role catalog.
- MSW handlers/fixtures (`mocks/handlers/tans.ts`, `mocks/handlers/candidates.ts`, `mocks/data/tans.ts`, `mocks/data/candidates.ts`) updated to match the corrected contracts so Vitest keeps passing; confirmed nothing in the normal runtime import path reaches them.

### Fixed (2026-09-08)

- `CvBankListPage`'s search box previously assumed a server-side `q` query parameter that doesn't exist; now documented as filtering only the current page's already-fetched rows, not silently sending a no-op parameter.

### Prior entries

- `PROJECT_STATUS.md` — authoritative, evidence-based implemented/scaffolded/planned/deferred status per capability.
- `DECISIONS_REQUIRED.md` — decision register (11 open decisions) with owner, options, impact, and default-if-unresolved for each.
- `CHANGELOG.md` — this file.
- `docs/adr/ADR-006-database-first-stored-procedure-workflow.md` — records the real, implemented divergence from the original generic-workflow-engine design (ADR-002/`workflow-state-machine.md`): per-entity status columns plus stored-procedure-owned transitions, no generic `workflow_state_transition` table.
- Real dev/build/test/validate commands into `CLAUDE.md`'s Validation Commands section, `CONTRIBUTING.md`'s prerequisites/required-checks, and `README.md`'s Local development section, replacing `[COMMAND_TO_...]` placeholders (verified: `dotnet build`, `dotnet test`, `npm run typecheck`/`lint`/`test`, `npm run api:validate`, `scripts/validate-config.sh`).
- "Implementation reality notice" callouts to the documents with the most severe drift against the real implementation: `docs/01-architecture/solution-architecture.md`, `docs/03-data/data-architecture.md`/`data-dictionary.md`/`er-diagram.md`/`sample-relational-schema.sql`, `docs/06-ai-agents-rag/agent-architecture.md`/`agent-skill-catalog.md`, `docs/02-business-workflows/workflow-state-machine.md`/`human-approval-matrix.md`.
- Status column (Implemented / Planned-stub-only) added directly to the skill table in `docs/06-ai-agents-rag/agent-skill-catalog.md`.
- "Current implementation status" section in `README.md`.
- Real `src/`/`tests/` code index (with status per project) added to `GENERATED_FILES.md`, alongside its existing docs/config index.
- "Superseded original plan" section in `PROJECT_STRUCTURE.md` explaining why the originally-planned `src/frontend/`/`src/backend/`/`src/agents/`(Python)/`src/shared/`/`src/integration-adapters/` layout was not built.

### Changed

- `README.md` — removed "no application source code is included yet" framing (a real, working implementation exists); "application source code" removed from the Out-of-scope list; solution-structure tree now notes `Database/` and `tests/`.
- `PROJECT_STRUCTURE.md` — full directory tree rewritten to reflect the real repository (previously showed an aspirational, never-built tree as primary, with the real `.NET`/React tree only as a caveat); dependency-direction diagram updated to the real per-project graph; "Future implementation order" checklist updated with what's actually done.
- `NEXT_STEPS.md` — checked items with direct evidence (backend bootstrap, dev-only auth/tenant isolation, CV Bank, TAN create/approve); corrected the Python-agent-service and React/Next.js-under-`src/frontend/` line items to reflect what was actually built.
- `GENERATED_FILES.md` — Purpose section reframed as a documentation-navigation aid rather than an implementation-status source; recommended reading order now points to `PROJECT_STATUS.md` early.
- `docs/03-data/data-dictionary.md`, `er-diagram.md`, `data-architecture.md` — added notices correcting the database engine (fixed to SQL Server, not a Postgres/SQL Server tenant choice) and the entity model (no single `tan`/`approval`/`workflow_state_transition` table; real schema is ~243 schema-qualified tables).
- `docs/03-data/sample-relational-schema.sql` — header comment updated to flag it as superseded by the real schema, not a migration source.
- `docs/adr/README.md` — added ADR-006 to the index; noted it as the more current source for workflow-transition mechanics versus ADR-002.

### Deprecated

- The generic `workflow_state_transition`-table design in `docs/02-business-workflows/workflow-state-machine.md` and the single `tan`/`approval` entities in `docs/03-data/` — superseded by [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md) for anything already implemented; still valid as target-state reference for unimplemented workflows (interviews, offers, Green Form, discrepancies, employee conversion).
- The `src/frontend/`/`src/backend/`/`src/agents/`(Python)/`src/shared/`/`src/integration-adapters/` layout described in the original `PROJECT_STRUCTURE.md` — not built, not the current direction; see that document's "Superseded original plan" section.

### Removed

- Nothing deleted. All superseded content is marked in place with an implementation-reality notice rather than removed, per the instruction to preserve accurate history and avoid silently erasing prior design intent.

### Fixed

- N/A this pass (documentation-only; no application code changed).

### Security

- No security-relevant documentation changes this pass beyond noting, in `DECISIONS_REQUIRED.md` (DEC-002), that no production authentication mechanism exists yet — only a dev-only JWT gated to the Development environment.

## Maintenance note

Add an entry here whenever `CLAUDE.md`, a `.claude/rules/*.md`, an ADR, or a `docs/` page changes in a way another contributor or Claude Code session needs to know about — see `.claude/rules/documentation.md` and `CONTRIBUTING.md`. This file tracks documentation/context/configuration change history; it is not a substitute for `PROJECT_STATUS.md` (current state) or `git log` (code change history).
