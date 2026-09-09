# Navigation / Feature Gap Analysis

> Title: Navigation / Feature Gap Analysis | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Engineering Lead] | Status: Implemented this pass — see [production-readiness-report.md](production-readiness-report.md) for verification evidence | Last reviewed: 2026-09-09 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Engineering, Architecture, Security

## Purpose and scope

Traces every registered frontend navigation item through its full stack — route → page → data hook → API endpoint → Application handler → database — as of the start of this pass (`/interviews` showing "Something went wrong loading this data" was the reported symptom). Records what was actually found by inspection and live testing, not assumed. See [production-readiness-report.md](production-readiness-report.md) for what was fixed and how it was verified.

## Method

Read every route in `src/app/router/routes.tsx`, its page component, its TanStack Query hook, the backend controller it calls (or the absence of one), the skill/procedure behind any write action, and the underlying table. Verified live via `dotnet test` (backend), `npm run test`/`typecheck`/`lint`/`build` (frontend), and direct `curl` calls against a running instance with a real dev JWT. Unknown items are marked `Requires verification`, not guessed.

## Gap analysis table

| Navigation / Feature | Frontend Route Exists | Page Exists | Loader/Hook Exists | API Endpoint Exists | Application Handler Exists | Database Support Exists | Auth/Permission Ready | Current Runtime Result (before this pass) | Root Cause | Fix Required | Priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `/` , `/dashboard` | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes (real tables) | Yes | "Not available yet" honest state | No dashboard-summary endpoint existed | New `DashboardController`, real live counts | P1 |
| `/tans`, `/tans/:id`, `/tans/new` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Working (real, prior pass) | — | — | — |
| `/cv-bank`, `/cv-bank/upload`, `/candidates/:id` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Working (real, prior pass) | — | — | — |
| `/tans/:id/matches` (candidate matching) | Yes | Yes | Yes | Yes (read) / stub (match run) | Partial | Yes | Yes | Read path works; AI matching itself is a documented stub | `match_candidates_skill` never implemented | Out of scope this pass — large AI-matching feature, not a routing/wiring bug | P3 |
| **`/interviews`, `/interviews/:id`, `/interviews/:id/feedback`** | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes (tables existed, seed data existed) | Yes | **"Something went wrong loading this data"** | `GET /interviews` and `/interviews/{id}` never existed; only `POST` (create/feedback) existed, wired to permanent stubs | New GET endpoints, real `CreateInterviewSkill`/`InterviewFeedbackSkill`, 2 new stored procedures, missing `InterviewFeedbackTemplate` seed row added | **P0 — the reported bug** |
| `/offers`, `/offers/:id`, `/offers/new/:applicationId`, `/offers/:id/approval` | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes (procs for draft/submit/approve/send already existed, unused) | Yes | Generic error | No GET endpoints; frontend also called a URL (`/applications/:id/offers`) that never existed | New GET endpoints, 4 real skills wired to existing procs, 1 new procedure (`usp_RecordOfferAcceptance`), frontend URL fixed | P0 |
| `/green-form/:token`, `/green-form/submission/:id` | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes (tables existed, no seed template) | N/A — anonymous, token-authorized | Generic error | No endpoints at all existed; `ref.InterviewFeedbackTemplate`-equivalent gap (`ref.GreenFormFeedbackTemplate`... actually `GreenFormSubmission` had no write path) | 3 new procedures, 1 new RLS exemption role for anonymous token access, real seed data | P0 |
| `/verification`, `/verification/:applicationId` | Yes | Yes | Yes | **No** → **Done** | N/A (read-only) | Yes | Yes | Generic error | No `VerificationController` existed at all | New controller, real reads over `onboarding.VerificationCase` | P0 |
| `/discrepancies`, `/discrepancies/:id` | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes | Yes | Generic error | No GET endpoints; `resolve` was a stub; `reupload-request` had no backing capability at all | New GET endpoints, real `DiscrepancyResolveSkill`, new `usp_RequestDocumentReupload` procedure | P0 |
| `/approvals` | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes | Yes | Generic error | No generic approval work-queue endpoint existed | New `ApprovalsController` — real GET queue; decision dispatch real for offer/discrepancy entity types, honest 422 for others | P0 |
| `/employee-conversion`, `/employee-conversion/:id` | Yes | Yes | Yes | **No** → **Done** | **No** → **Done** | Yes (procs existed, unused) | Yes | Generic error | No GET endpoints; convert action was a stub; frontend called a URL that never existed | New `EmployeeConversionController`, real 2-step skill chaining `usp_ApproveEmployeeConversion` → `usp_CreateEmployeeFromCandidate` (both independently re-validate eligibility server-side), frontend URL fixed | P0 |
| `/admin/users`, `/admin/users/:id` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Working (real, prior pass) | — | — | — |
| `/admin/roles`, `/admin/feature-flags`, `/admin/configuration`, `/admin/integrations` | Yes | Yes | N/A — static/local data, no API call | N/A | N/A | N/A | Yes | Working (never broken — nothing to fetch) | — | — | — |
| Admin user create/edit/activate/deactivate/role-assignment | No dedicated route (actions live on the detail page) | Partial | No | **No** | **No** | Yes (tables exist) | N/A | Buttons not present / not wired | Genuinely unbuilt feature (per `PROJECT_STATUS.md`'s own "next batch" note, predates this pass) | Out of scope this pass — comparable in size to one of the 6 modules built above | P2 — flagged, not silently dropped |
| `/audit` | Yes | Yes | Yes | Yes (read) | Yes | Yes | Yes | MSW-mock data only (documented, not this pass's scope) | Frontend-connection not attempted this pass | Out of scope — audit log UI wiring, not a routing bug | P2 |
| `/access-denied`, `/login`, `/logout` | Yes | Yes | N/A | N/A | N/A | N/A | Yes | Working | — | — | — |
| Any unmatched path | **No route existed for this case** | N/A | N/A | N/A | N/A | N/A | N/A | React Router's unstyled default 404 | No catch-all route, no router-level `errorElement` anywhere | Added `NotFoundPage` + wildcard route + `RouteErrorBoundary` on every top-level route group | P0 |
| Document verification (`POST /documents/:id/verify`) | N/A (not a route — an action from Discrepancy/Verification pages) | N/A | N/A | Yes (stub) | **No** | Yes (tables exist, no write path) | Yes | Stub — always returns `blocked` | `document_verify_skill` never implemented | Out of scope this pass — comparable in size to the modules above | P2 — flagged, not silently dropped |
| Progression approval (`POST /applications/:id/progression-approval`) | N/A (no dedicated frontend UI calls this) | N/A | N/A | Yes (stub) | **No** | Partial | Yes | Stub — always returns `blocked` | Depends on a generic workflow-transition concept not present in this schema | Out of scope this pass | P2 — flagged, not silently dropped |

## Root cause categories found (matching Phase 2's checklist)

- **Route not registered**: only for the wildcard/unmatched-path case — fixed.
- **Missing page component**: none found — every registered route had a real page.
- **Missing API endpoint**: the dominant root cause — 6 of 7 major workflow modules had zero or partial GET endpoints despite full frontend pages already built against them.
- **Stub skill wired but never implemented**: `create_interview_skill`, `interview_feedback_skill`, `green_form_issue_link_skill`, `discrepancy_resolve_skill`, `shortlist_approval_skill`, `employee_conversion_skill`, `create_offer_skill`, `offer_approval_skill`, `offer_send_skill`, `offer_acceptance_skill` — all replaced with real implementations. `match_candidates_skill`, `document_verify_skill`, `progression_approval_skill` remain stubs (documented, out of scope).
- **DTO shape mismatch**: found and fixed everywhere — every stub-era frontend type used camelCase field names and speculative status-value unions that never matched the backend's real snake_case wire format or the real `ref.*` status codes (which are UPPER_SNAKE_CASE or PascalCase depending on table).
- **Wrong URL**: 2 real cases — offer creation and employee conversion frontend calls targeted URLs that never existed on any controller.
- **Missing seed/master data**: 1 real case — `ref.InterviewFeedbackTemplate` had zero rows despite being a `NOT NULL` FK dependency, making feedback submission structurally impossible even after the endpoint existed.
- **RLS/security-model gap**: 1 real case — Green Form's candidate-facing, token-only access pattern had no way to satisfy row-level security (no authenticated tenant context exists for an anonymous candidate). Required a genuine, reviewed RBAC extension (see `production-readiness-report.md`), not a workaround.
- **Generic frontend error message**: `ErrorState`/`DataTable` had the plumbing for kind-specific messaging (`ApiError.kind`, `userSafeMessage()`) but no page actually used it — fixed across all 22 list/detail pages app-wide, not just the reported route.

## Not found in this pass

- No missing page components.
- No lazy-import/chunk-loading failures (none reproducible; a `RouteErrorBoundary` now catches this class of failure if it occurs in production).
- No CORS issues (none configured at all before this pass — see `production-readiness-report.md`).
- No tenant-isolation bypass found in any new or existing endpoint (every new query filters by `TenantId` and is additionally enforced by row-level security).
