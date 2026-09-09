# Frontend API Integration

> Title: Frontend API Integration | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Frontend Engineering / API Architecture] | Status: Draft | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: API Architecture, Frontend Engineering, Security

## Table of contents

1. [Purpose and scope](#purpose-and-scope)
2. [Contract source of truth](#contract-source-of-truth)
3. [API client layer](#api-client-layer)
4. [Development proxy](#development-proxy)
5. [Idempotency and correlation](#idempotency-and-correlation)
6. [Error handling](#error-handling)
7. [Mock development mode](#mock-development-mode)
8. [First backend endpoints needed to replace mock data](#first-backend-endpoints-needed-to-replace-mock-data)
9. [Risks and open questions](#risks-and-open-questions)
10. [Change control](#change-control)

## Purpose and scope

Defines how `src/HrAutomation.Web` integrates with `HrAutomation.Api`: contract management, the client layer, and the path from mock data to a live backend.

## Contract source of truth

`openapi/hr-onboarding-api.openapi.yaml` at the repository root is the frontend-backend contract. `HrAutomation.Web` does not duplicate it (`src/api/openapi/README.md`). Two scripts operate on it, run from `src/HrAutomation.Web/`:

```bash
npm run api:validate    # scripts/validate-openapi.mjs — confirms the spec exists and parses as valid YAML with openapi/paths keys
npm run api:generate    # scripts/generate-api-client.mjs — runs openapi-typescript, writes src/api/generated/schema.d.ts
```

Generated output is **not** committed until reviewed against the real backend contract — `src/api/generated/` ships with only a `README.md` placeholder. Until then, feature code uses temporary, hand-written types (`src/types/workflow.ts` and per-feature hook files), each marked `TODO(api-contract)`. When generation is adopted, replace these types with imports from `@/api/generated/schema` rather than maintaining both.

## API client layer

All HTTP calls go through `src/api/client/apiClient.ts` — a single Axios instance. No feature code calls `fetch`/`axios` directly.

| Concern | Implementation |
|---|---|
| Base URL | `VITE_API_BASE_URL` (default `/api`) |
| Timeout | `VITE_API_TIMEOUT_MS` |
| Auth | `attachRequestMetadata` interceptor reads the active auth provider's token (`features/auth/authProviderFactory.ts`) and attaches `Authorization: Bearer ...`, or relies on `withCredentials` for a cookie/BFF session |
| Correlation ID | `X-Correlation-Id` generated per request (`api/client/correlationId.ts`), matching `HrAutomation.Api`'s `CorrelationIdMiddleware` contract |
| Idempotency | `Idempotency-Key` generated for every `POST`/`PATCH`/`PUT`/`DELETE`, matching `HrAutomation.Api`'s `IdempotencyKeyMiddleware` contract |
| Error mapping | `onResponseError` converts every failure to `ApiError` (`api/client/apiError.ts`) with a `kind`, optional field errors, and the response's correlation ID |
| Retry | TanStack Query retries only `network_error`/`server_error` kinds, and only for queries — never mutations (see `app/providers/QueryProvider.tsx`) |
| Cancellation | Callers pass `config.signal`; TanStack Query supplies an `AbortSignal` per query/mutation automatically |
| Tenant context | Never read from a UI-selected value — derived server-side from the validated token/session only |

## Development proxy

`vite.config.ts` proxies `/api/*` to `VITE_API_PROXY_TARGET` (default `http://localhost:5219`, `HrAutomation.Api`'s local HTTP profile). The browser only ever talks to the Vite dev server; Vite forwards requests server-side. This means **no CORS policy change is required on `HrAutomation.Api` for local development** — a deliberate choice to avoid modifying the backend for frontend tooling reasons. A production deployment needs its own same-origin strategy (reverse proxy/gateway) or an explicit backend CORS policy; that is a backend/infrastructure decision tracked as a prerequisite (see [scope-assumptions-open-questions.md](../00-product/scope-assumptions-open-questions.md)).

## Idempotency and correlation

Header names (`X-Correlation-Id`, `Idempotency-Key`) are fixed constants in `src/lib/constants.ts`, matching `HrAutomation.Api`'s middleware exactly — confirmed by reading `src/HrAutomation.Api/Middleware/CorrelationIdMiddleware.cs` and `IdempotencyKeyMiddleware.cs` directly rather than assuming a convention. If the backend's header names ever change, this is the single place to update on the frontend.

## Error handling

Every `ApiError` maps to one of a fixed set of user-safe messages (`api/client/apiError.ts` `USER_SAFE_MESSAGES`) covering `401`, `403`, `404`, `409`, `422`, `429`, and `5xx` — the raw backend message/stack trace is never rendered (see [frontend-security.md](../05-security-governance/frontend-security.md)). RFC 7807 `errors` fields, when present, are surfaced as field-level form errors.

## Mock development mode

**As of 2026-09-08, `VITE_ENABLE_MSW=false` is the default** — see [PROJECT_STATUS.md](../../PROJECT_STATUS.md) and [live-sql-server-integration-verification.md](../09-quality-evaluation/live-sql-server-integration-verification.md). Setting `VITE_ENABLE_MSW=true` (together with `VITE_AUTH_MODE=mock`) starts an MSW service worker (`src/mocks/browser.ts`) intercepting every `/api/*` call in the browser with synthetic, fake-data handlers (`src/mocks/handlers/`, `src/mocks/data/`) for isolated component/demo development without a running backend. `VITE_ENABLE_MSW` is force-disabled in `VITE_APP_ENV=prod` regardless of its value (`app/config/appConfig.ts`). The same handlers back Vitest component/feature tests via `src/mocks/server.ts` (Node-side MSW) — that usage is unaffected by the runtime default change.

## First backend endpoints needed to replace mock data

In rough priority order, matching the mock handlers already wired up in `src/mocks/handlers/`. Items 2 and 3 are now genuinely connected (real API, real `HrAutomationDb` persistence, verified) — see [PROJECT_STATUS.md](../../PROJECT_STATUS.md) for the exact endpoint list and caveats. The rest are still mock-only; their controllers don't exist.

1. `GET /api/v1/dashboard/summary` — dashboard tiles (still does not exist; `DashboardPage` shows a truthful "not available" state rather than fake numbers).
2. **Connected**: `GET /api/v1/candidates`, `GET /api/v1/candidates/{id}`, `POST /api/v1/candidates/cvs` (single-file, not the originally-assumed `/v1/cvs` multi-file shape) — CV Bank list/profile/upload. `GET /api/v1/candidates/{id}/cvs` does **not** exist; `CandidateProfilePage` shows a truthful unavailable state instead of calling it.
3. **Connected**: `GET/POST /api/v1/tans`, `GET /api/v1/tans/{id}`, `POST /api/v1/tans/{id}/approve` — TAN lifecycle (the list endpoint was added this pass; it didn't exist before). `GET /api/v1/tans/{id}/matches` is not yet implemented — matching is a stub skill.
4. `GET /api/v1/interviews`, `POST /api/v1/interviews/{id}/feedback` — interview list/feedback.
5. `GET/POST /api/v1/offers`, `POST /api/v1/offers/{id}/approve`, `POST /api/v1/offers/{id}/send` — offer lifecycle.
6. `GET /api/v1/green-forms/by-token/{token}`, `POST /api/v1/green-forms/by-token/{token}/submissions` — candidate-facing Green Form (token-based auth, not the internal JWT scheme).
7. `GET /api/v1/verification`, `GET/POST /api/v1/discrepancies`, `POST /api/v1/discrepancies/{id}/resolve` — verification/discrepancy queues.
8. `GET /api/v1/employee-conversion`, `POST /api/v1/applications/{id}/employee-conversion` — conversion checklist and Employee ID issuance.
9. `GET /api/v1/approvals`, `POST /api/v1/approvals/{id}/decision` — approvals work queue.
10. `GET /api/v1/audit-log` — audit trail (an `AuditLogsController` already exists on `HrAutomation.Api`; confirm its shape matches).

## Risks and open questions

- Several endpoints above (`dashboard/summary`, `tans/{id}/matches`, `green-forms/by-token/*`, `approvals`, `employee-conversion`) do not yet exist on `HrAutomation.Api` — see `src/HrAutomation.Api/Controllers/` for the current, smaller controller set. Each needs its own contract review before implementation, not just a route added to match the mock shape.
- Candidate-facing Green Form endpoints need a distinct, token-based authorization scheme, separate from the internal JWT bearer scheme used elsewhere — [TENANT_CONFIGURATION_REQUIRED] / architecture review before implementation.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | HrAutomation.Web scaffold generation | Initial creation |
