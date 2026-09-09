# Production Readiness Report

> Title: Production Readiness Report | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Engineering Lead] | Status: This pass complete; project is **not** fully production ready — see "Remaining blockers" | Last reviewed: 2026-09-09 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Engineering, Architecture, Security

## Purpose and scope

Records what was actually broken, what was actually fixed, and what actually remains, for the "make every navigation work end-to-end" pass triggered by `/interviews` showing "Something went wrong loading this data." See [navigation-feature-gap-analysis.md](navigation-feature-gap-analysis.md) for the full route-by-route trace this report summarizes.

## 1. Broken routes found

`/interviews`, `/offers`, `/green-form/*`, `/verification`, `/discrepancies`, `/approvals`, `/employee-conversion`, `/dashboard` all showed a generic "Something went wrong loading this data" error or a documented "not available" placeholder. Any unmatched URL fell through to React Router's unstyled default 404 (no route, no boundary).

## 2. Root causes

Every one of the 7 workflow-module routes above failed for the same structural reason: the frontend page and its TanStack Query hook were fully built against an API contract that was never implemented on the backend — either no controller endpoint existed at all, or the endpoint existed but was permanently wired to a stub skill that always returns `blocked`. This was not a bug in the sense of broken code; it was genuinely unbuilt functionality, exactly as `PROJECT_STATUS.md` already honestly documented before this pass ("Scaffolded"). The generic error message was a symptom, not the cause — see item 9 for the separate, real fix to that symptom layer.

Two additional root-cause categories, found only once real implementation started:
- **Frontend/backend URL mismatches**: offer creation and employee conversion each called a URL that never existed on any controller.
- **Stub-era DTOs never matched the real wire format**: every affected frontend type used camelCase fields and speculative status-value unions (e.g. `"scheduled"`, `"rescheduled"`) that don't correspond to the backend's real snake_case JSON convention or the real `ref.*` status codes (UPPER_SNAKE_CASE / PascalCase, depending on table). These would have produced silent `undefined` rendering, not crashes — caught only because each hook was rewritten against the real DTO and typechecked.

## 3. Fixes implemented

### Frontend routing/error reliability (applies to every route, not just the broken ones)
- `ErrorState`/`DataTable` now derive kind-specific icon, message, and retry-eligibility from the real `ApiError.kind` (401/403/404/409/422/429/5xx/network) instead of one hardcoded string. Threaded through all 22 list/detail pages.
- New `RouteErrorBoundary` (`errorElement`) on every top-level route group — catches lazy-chunk-load failures and render crashes without blanking the whole app.
- New `NotFoundPage` + wildcard `path: "*"` route — previously any unmatched URL fell through to React Router's default.

### Backend modules built for real (see `navigation-feature-gap-analysis.md` for full detail per module)
- **Interviews**: 2 new stored procedures, 2 real skills replacing stubs, real GET list/detail, missing `InterviewFeedbackTemplate` seed row added.
- **Offers**: 1 new stored procedure (acceptance), 4 real skills replacing stubs (create/approve/send/accept), real GET list/detail, frontend URL fixed.
- **Green Form**: 3 new stored procedures, a genuine RLS/security-model extension for anonymous token-authorized access (see item 6), real GET/POST for the full candidate-facing flow.
- **Verification / Discrepancies**: new `VerificationController` (didn't exist), real GET list/detail for discrepancies, real `resolve` and new `reupload-request` (1 new stored procedure) actions.
- **Employee Conversion / Approvals**: new `EmployeeConversionController` and `ApprovalsController` (neither existed), real 2-step gated conversion skill, real shortlist-approval skill, real cross-entity-type approval queue read.
- **Dashboard**: new `DashboardController` — every tile is a real, live-computed count against real tables; `sla_breaches` is honestly `0` (no SLA tracking mechanism exists in this schema).

## 4. Endpoints added/repaired

| Endpoint | Status before | Status after |
|---|---|---|
| `GET /api/v1/interviews`, `GET .../{id}` | Did not exist | Real |
| `POST /api/v1/interviews`, `POST .../{id}/feedback` | Stub | Real |
| `GET /api/v1/offers`, `GET .../{id}` | Did not exist | Real |
| `POST /api/v1/offers`, `.../approve`, `.../send`, `.../acceptance` | Stub | Real |
| `GET/POST /api/v1/green-forms/by-token/{token}`, `GET .../submission/{id}`, `POST .../submissions` | Did not exist | Real (anonymous, token-authorized) |
| `POST /api/v1/green-forms/{applicationId}/issue-link` | Stub | Real |
| `GET /api/v1/verification`, `GET .../{applicationId}` | Did not exist (no controller) | Real |
| `GET /api/v1/discrepancies`, `GET .../{id}` | Did not exist | Real |
| `POST /api/v1/discrepancies/{id}/resolve` | Stub | Real |
| `POST /api/v1/discrepancies/{id}/reupload-request` | Did not exist | Real |
| `GET /api/v1/employee-conversion`, `GET .../{applicationId}` | Did not exist (no controller) | Real |
| `POST /api/v1/applications/{id}/convert-to-employee` | Stub | Real |
| `POST /api/v1/applications/{id}/shortlist-approval` | Stub | Real |
| `GET /api/v1/approvals` | Did not exist (no controller) | Real |
| `POST /api/v1/approvals/{id}/decision` | Did not exist | Real for `offer.Offer`/`onboarding.Discrepancy`; honest 422 for other entity types |
| `GET /api/v1/dashboard/summary` | Did not exist | Real |

Left as documented stubs (out of scope this pass, each comparable in size to one module above): `POST /documents/{id}/verify`, `POST /applications/{id}/progression-approval`, candidate matching (`match_candidates_skill`), admin user create/edit/activate/deactivate/role-assignment.

## 5. Auth/permission issues fixed

- `ApproveOffer`/`SendOffer`/`RecordAcceptance`/`SubmitFeedback`/`Resolve`/`RequestReupload` endpoints previously returned `200 OK` unconditionally, even when the underlying skill failed — now return `422` on failure, matching how `create` endpoints already behaved.
- No tenant-isolation gaps found or introduced: every new query filters by `TenantId` and is independently enforced by row-level security (verified live — see item 9).
- **Green Form's anonymous access required a genuine RLS/security-model extension**, not a bypass: added a new, narrowly-scoped database role (`db_hr_public_token_resolver`) and a dedicated login-less user (`db_hr_green_form_token_resolver`), granted `EXECUTE` on exactly the 2 token-resolution procedures (never schema- or table-wide), and extended `security.fn_tenant_access_predicate` with one new, documented exemption clause. Authorization for these procedures comes from possession of an unguessable token (the row's own primary key), resolved server-side — never a client-supplied tenant id. This was caught and fixed only because an initial `EXECUTE AS OWNER` attempt silently returned 404 at runtime (not a compile error) — the fix was verified with a real anonymous `HttpClient` carrying no `Authorization` header at all.

## 6. Master-data gaps fixed

`ref.InterviewFeedbackTemplate` had zero seed rows despite `InterviewFeedback.InterviewFeedbackTemplateId` being a `NOT NULL` foreign key — feedback submission was structurally impossible even after the endpoint existed. Added the missing seed row to `06-seed-recruitment-configuration.sql`.

## 7. Tests added

59 backend integration tests now pass (35 pre-existing + 24 new), all against a real LocalDB instance, none mocked:

| Test file | Coverage |
|---|---|
| `InterviewSchedulingAndFeedbackTests.cs` | Schedule→list→get, feedback→status change, wrong-role→403, not-found→404, no-token→401 |
| `OfferLifecycleTests.cs` | Full create→approve×2 (2-step matrix)→send→accept lifecycle with real state checks at each step, send-before-approval correctly rejected (422), wrong-role→403 |
| `GreenFormLifecycleTests.cs` | Full anonymous issue→get→submit→status flow with a real unauthenticated `HttpClient`, resubmission correctly rejected, unknown-token→404 |
| `DiscrepancyAndVerificationTests.cs` | List/resolve/reupload/wrong-role/not-found for discrepancies, verification queue read |
| `EmployeeConversionAndApprovalsTests.cs` | Approvals queue read, ineligible-candidate conversion correctly refused server-side, wrong-role→403 |
| `DashboardSummaryTests.cs` | Real non-fabricated counts, no-token→401 |

Frontend: 40 Vitest tests pass (2 pre-existing tests fixed because they used stale mock shapes that no longer matched the real DTOs), `npm run typecheck`/`lint`/`build` all clean.

## 8. Production hardening changes

- Added a deny-by-default CORS policy (`Cors:AllowedOrigins` config-driven; empty in `appsettings.json`, `localhost:5173` in `appsettings.Development.json`) — no CORS policy existed at all before this pass.
- Normalized action-endpoint failure responses to `422` instead of a false `200 OK` (see item 5).
- Every new list endpoint enforces a clamped page size (`Math.Clamp(limit, 1, 100)`).
- Every new write path goes through a stored procedure with `TRY/CATCH`, an audit-event write, and a uniform `Success/Message/EntityId/ErrorCode` result — consistent with the existing ADR-006 pattern, not a new one invented for this pass.

## 9. Remaining blockers

- **Admin user create/edit/activate/deactivate/role-assignment** — genuinely unbuilt, tracked as "next batch" in `PROJECT_STATUS.md` before this pass, not attempted here (comparable in size to one of the 6 modules built above).
- **Document verification** (`POST /documents/{id}/verify`) — still a stub; no `onboarding.VerificationCheck`/`VerificationResult` write path exists.
- **Progression approval** — still a stub; depends on a generic workflow-transition concept this schema doesn't model as a distinct capability from `InterviewOutcome`.
- **Candidate matching** (`match_candidates_skill`) — still a stub; a genuinely large AI-matching feature, unchanged by this pass.
- **Generic approval decision routing** — real only for `offer.Offer` and `onboarding.Discrepancy`; TAN, shortlist, and employee-conversion approvals still go through their own dedicated endpoints rather than the generic `/approvals/{id}/decision` route.
- **`npx playwright install`** (e2e browser binaries) not run — from the earlier platform-upgrade pass, still outstanding.
- **DEC-007 (no per-test-run database isolation)** — confirmed again this pass: one new test initially failed on rerun because it collided with its own prior run's data via a legitimate unique constraint. Fixed by making that specific test idempotency-aware; the underlying shared-database limitation itself is unchanged and remains tracked in `PROJECT_STATUS.md`.

## 10. Required environment variables

No new environment variables were introduced. `Cors:AllowedOrigins` (new config key, not an env var) defaults to empty (closed) and must be set explicitly for any non-same-origin production deployment — see `appsettings.json`.

## 11. Local startup verification steps

```bash
# Backend
dotnet build HrAutomation.slnx
dotnet test tests/HrAutomation.Tests/HrAutomation.Tests.csproj   # expect 59/59 passing, real LocalDB required
dotnet run --project src/HrAutomation.Api/HrAutomation.Api.csproj --urls "http://localhost:5219"
curl http://localhost:5219/health   # expect {"status":"Healthy",...}

# Frontend (separate terminal)
cd src/HrAutomation.Web
npm install
npm run typecheck && npm run lint && npm run build && npm run test
npm run dev   # http://localhost:5173

# Live check of a previously-broken route (requires the backend running):
# obtain a dev token, then GET /api/v1/interviews with it — see
# HrAutomation.Web/README.md "Development proxy" for the VITE_AUTH_MODE=devToken flow.
```

## Do not claim "production ready" beyond this pass's actual scope

Per this task's own instruction: the project is **not** fully production ready. It is materially more complete than before this pass — 7 previously-broken navigation routes now work end-to-end against real data, with real tests proving it — but admin user management, document verification, progression approval, and AI-assisted candidate matching remain genuinely unbuilt, and production authentication (`DEC-002`, OIDC vs. BFF) is still unresolved. See `PROJECT_STATUS.md` for the authoritative, continuously-updated capability table.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-09 | Navigation/feature reliability pass (Claude Code) | Initial creation |
