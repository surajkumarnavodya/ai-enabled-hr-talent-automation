# Frontend Security

> Title: Frontend Security | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Security Architecture / Frontend Engineering] | Status: Draft | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Security, Frontend Engineering

## Table of contents

1. [Purpose and scope](#purpose-and-scope)
2. [Frontend guards do not replace API authorization](#frontend-guards-do-not-replace-api-authorization)
3. [Authentication implementation options](#authentication-implementation-options)
4. [Browser storage rules](#browser-storage-rules)
5. [Logging and redaction](#logging-and-redaction)
6. [File upload validation is advisory only](#file-upload-validation-is-advisory-only)
7. [Rich text and rendering](#rich-text-and-rendering)
8. [Duplicate submission prevention](#duplicate-submission-prevention)
9. [Environment variables](#environment-variables)
10. [Risks and open questions](#risks-and-open-questions)
11. [Change control](#change-control)

## Purpose and scope

Defines the security rules specific to `src/HrAutomation.Web`, extending the platform-wide rules in [docs/05-security-governance/security-architecture.md](security-architecture.md) and [CLAUDE.md](../../CLAUDE.md) to the frontend layer.

## Frontend guards do not replace API authorization

**This is the single most important rule in this document.** `ProtectedRoute` (`app/router/ProtectedRoute.tsx`) and `PermissionRoute` (`app/router/PermissionRoute.tsx`) exist to shape the UI experience — hiding routes and actions a role shouldn't see — not to enforce security. `HrAutomation.Api` independently authorizes every request regardless of what this UI allowed to render or which client-side check passed. Never treat a passing frontend guard as proof an action is authorized; never skip a corresponding server-side check because "the UI already checked." `usePermissions()` (`hooks/usePermissions.ts`) documents this explicitly in its header comment.

## Authentication implementation options

The auth provider abstraction (`types/auth.ts` `AuthProvider` interface, selected via `VITE_AUTH_MODE`) supports exactly two production-safe patterns, documented in `features/auth/oidcAuthProvider.ts`:

1. **OAuth 2.1 / OIDC Authorization Code + PKCE** via a vetted client library — tokens held in that library's in-memory store only.
2. **Backend-for-Frontend (BFF)** — preferred where the backend architecture supports it. The BFF sets an HttpOnly, Secure, `SameSite=Strict` session cookie; the browser never sees a token at all, and `getAccessToken()` returns `null` because `apiClient.ts` relies on `withCredentials` cookie auth instead.

Neither pattern is implemented yet (`oidcAuthProvider.ts` throws on every call) — this is a documented, deliberate gap, not an oversight. The local-development default (`VITE_AUTH_MODE=mock`) uses `mockAuthProvider.ts`, which keeps a synthetic identity in module memory only, never in storage, and never makes a network call.

## Browser storage rules

**Never store in `localStorage` or `sessionStorage`:** credentials, API keys, access/refresh tokens, CV text, offer documents, candidate PII, or any sensitive workflow detail. ESLint enforces this at the language level in `eslint.config.js` — both `no-restricted-globals` (catches bare `localStorage`/`sessionStorage`) and `no-restricted-properties` (catches `window.localStorage`/`window.sessionStorage`, which the global-only rule would otherwise miss) — with a single, narrow, explicit exception for `app/providers/ThemeProvider.tsx`'s non-sensitive UI preference (light/dark mode). Any new use of browser storage requires updating that ESLint override list and a security review — it should never happen silently.

## Logging and redaction

`src/lib/safeLogger.ts` is the only sanctioned place to call `console.*` — enforced by ESLint's `no-console` rule everywhere else. It:

- Redacts any field whose key looks sensitive (`token`, `password`, `secret`, `email`, `phone`, `document`, `cv`, `feedback`, `resume`, `salary`, `compensation`, `ssn`) before logging, recursively, up to a bounded depth.
- Never logs to the console at all in production builds.
- Is the intended integration point for an OpenTelemetry-compatible exporter (`VITE_OTEL_EXPORTER_OTLP_ENDPOINT`) — not yet wired to an SDK, to avoid bundling telemetry weight before it's configured.

`src/tests/unit/safeLogger.test.ts` verifies the redaction behavior directly.

## File upload validation is advisory only

`components/common/FileUpload.tsx` and `lib/validation.ts` (`validateFileForUpload`) check file extension, MIME type, and size **client-side, for fast user feedback only**. This is never a security control: `HrAutomation.Api`'s malware scanning and content validation (see [secure-file-upload-policy.md](secure-file-upload-policy.md)) are mandatory and authoritative, and a determined attacker can trivially bypass any client-side check. The UI surfaces this explicitly with a permanent notice below every upload control.

## Rich text and rendering

No component uses `dangerouslySetInnerHTML`; ESLint's `no-restricted-syntax` rule flags any attempt to add it. Any future requirement to render API-supplied rich text must go through a vetted sanitizer (e.g., DOMPurify) added deliberately, with a corresponding update to this document — not an ad hoc `dangerouslySetInnerHTML` call.

## Duplicate submission prevention

Every mutating form disables its submit control while the mutation is pending (`Button`'s `isLoading`/`disabled` props, `ConfirmActionDialog`'s internal `isSubmitting` guard) and attaches an `Idempotency-Key` header (see [frontend-api-integration.md](../04-api/frontend-api-integration.md)) so a retried request is deduplicated server-side even if a double-click slips through.

## Environment variables

Every `VITE_*` variable is bundled into the public JS output — **never place a secret behind one.** `.env.example` documents every variable with this warning; `app/config/env.ts` is the single chokepoint reading `import.meta.env`, making it easy to audit for accidental secret exposure in a review.

## Risks and open questions

- Neither production auth pattern (OIDC or BFF) is implemented — this is a hard prerequisite before any non-local deployment, tracked in the root `NEXT_STEPS.md` [TENANT_CONFIGURATION_REQUIRED].
- CORS/same-origin strategy for a production deployment (where the dev proxy doesn't apply) is undecided — [TENANT_CONFIGURATION_REQUIRED], likely a reverse-proxy/gateway decision rather than a backend CORS policy change.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | HrAutomation.Web scaffold generation | Initial creation |
