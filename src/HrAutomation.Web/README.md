# HrAutomation.Web

React + TypeScript presentation layer for the HR Recruitment and Onboarding Automation platform.

## Purpose

Provides the enterprise UI for HR staff (recruiters, hiring managers, interviewers, document verifiers, HR admins) and a candidate-facing Green Form flow. This project renders screens and calls `HrAutomation.Api` over HTTP — it contains no business logic, no workflow-transition validation, and no direct data access of its own.

## Architecture boundary

**Read this before adding anything to this project.**

- `HrAutomation.Web` is presentation only. It never accesses a database, and never references the `HrAutomation.Domain`, `.Application`, `.Infrastructure`, `.Agents`, `.Rag`, or `.Mcp` assemblies — the only integration point is HTTP calls to `HrAutomation.Api`'s versioned REST endpoints (`/api/v1/...`).
- All business rules, workflow-transition validation, authorization, approval enforcement, audit logging, and tenant isolation are enforced **server-side** in `HrAutomation.Api` and its backend layers. This UI may guide users and validate basic form input for UX purposes, but it is never the final authority on a business decision.
- **Frontend guards do not replace API authorization.** Every route guard (`ProtectedRoute`, `PermissionRoute`) and every `usePermissions()` check exists to shape the UI experience — hide buttons the user can't use, redirect away from screens they can't see. HrAutomation.Api independently re-validates every request regardless of what this UI allowed to render. Treat every guard here as a UX convenience, never a security control.
- Sensitive actions (shortlist approval, offer send, discrepancy resolution, employee conversion) always call a backend endpoint that itself enforces the approval matrix — the UI's confirmation dialog is a human-in-the-loop UX pattern, not the enforcement point.
- AI-generated content (candidate match scores, rationale) is always rendered inside `components/common/AiRecommendationPanel.tsx`, explicitly labeled "AI recommendation — human approval required." Never present AI output as a final decision.

## Prerequisites

- Node.js 20+ and npm.
- `HrAutomation.Api` running locally (optional for most development — see "Mock development mode" below) at the URL configured by `VITE_API_PROXY_TARGET`.

## Setup instructions

```bash
cd src/HrAutomation.Web
npm install
cp .env.example .env.local   # adjust values; never commit this file
npm run dev
```

The dev server starts at `http://localhost:5173`. By default (`VITE_AUTH_MODE=mock`, `VITE_ENABLE_MSW=true`) it runs entirely against an in-browser mock API (MSW) with a mock sign-in — no running backend required.

## Environment variables

See `.env.example` for the full list and inline documentation. Highlights:

| Variable | Purpose |
|---|---|
| `VITE_API_BASE_URL` | Base path the API client targets (default `/api`, proxied in dev — see below) |
| `VITE_API_PROXY_TARGET` | Dev-server-only: where `/api/*` is proxied to (real `HrAutomation.Api` URL) |
| `VITE_AUTH_MODE` | `mock` (default, local dev) or `oidc` (real auth — not yet implemented, see `features/auth/oidcAuthProvider.ts`) |
| `VITE_ENABLE_MSW` | Toggles the in-browser mock API server |
| `VITE_DEFAULT_TIMEZONE` | Display timezone for all date/time rendering |

**Never put a secret behind a `VITE_*` variable** — anything with that prefix is bundled into the public JS output and is visible to anyone who opens the app.

### Development proxy

`vite.config.ts` proxies `/api/*` requests to `VITE_API_PROXY_TARGET` (default `http://localhost:5219`, matching `HrAutomation.Api`'s local HTTP profile). This means the browser only ever talks to the Vite dev server (same-origin), and Vite forwards requests server-side to the real API — so no CORS policy change is needed on `HrAutomation.Api` for local development. A production deployment needs its own same-origin strategy (reverse proxy/gateway) or an explicit CORS policy on the backend; that is a backend/infrastructure decision, not something this project can or should configure.

## Development commands

| Command | Purpose |
|---|---|
| `npm run dev` | Start the Vite dev server |
| `npm run build` | Type-check (`tsc -b`) and produce a production build in `dist/` |
| `npm run preview` | Preview the production build locally |
| `npm run typecheck` | Strict TypeScript check, no emit |
| `npm run lint` / `npm run lint:fix` | ESLint (includes `jsx-a11y`) |
| `npm run format` / `npm run format:check` | Prettier |
| `npm run test` / `npm run test:watch` | Vitest unit/component/integration/accessibility tests |
| `npm run test:coverage` | Vitest with coverage report |
| `npm run test:e2e` | Playwright end-to-end tests (starts the dev server automatically) |

## API contract and client generation

The frontend-backend contract source of truth is `openapi/hr-onboarding-api.openapi.yaml` at the **repository root** — not a copy inside this project.

```bash
npm run api:validate    # confirms the spec exists and is well-formed YAML
npm run api:generate    # generates TypeScript types into src/api/generated/schema.d.ts
```

Until `api:generate` has been run and its output reviewed and wired in, feature code uses temporary, hand-written types (see `src/types/workflow.ts` and per-feature hook files), each marked `TODO(api-contract)`. **Do not hand-write a DTO that duplicates a shape already defined in the OpenAPI spec once generation is available** — replace the temporary type with an import from `@/api/generated/schema` instead.

## Testing

- **Unit/component (Vitest + React Testing Library):** `npm run test`. MSW (`src/mocks/server.ts`) intercepts network calls; no real backend needed.
- **Accessibility:** `axe-core` (via `vitest-axe`) runs against the candidate-facing Green Form in `src/tests/accessibility/`; `eslint-plugin-jsx-a11y` runs on every lint.
- **End-to-end (Playwright):** `npm run test:e2e`, against the real dev server with MSW mocking enabled. See `e2e/`.
- All test data is synthetic/fake — see `src/mocks/data/`. Never use real candidate, employee, CV, compensation, or document data in tests, fixtures, or examples.

## Security rules (summary — see `docs/05-security-governance/frontend-security.md` for the full policy)

- No secrets, API keys, refresh tokens, CV text, offer documents, or PII in `localStorage`/`sessionStorage`.
- The mock auth provider keeps its session in module memory only (never storage) — a full page reload intentionally loses it, same as a real app with no persisted session would.
- All API calls go through `src/api/client/apiClient.ts` — never an ad hoc `fetch`/`axios` call elsewhere. It attaches a correlation ID (`X-Correlation-Id`) and, on mutating requests, an `Idempotency-Key`, matching `HrAutomation.Api`'s middleware contract.
- Errors are mapped centrally (`src/api/client/apiError.ts`) to user-safe messages — raw backend stack traces are never rendered.
- `src/lib/safeLogger.ts` is the only sanctioned place to call `console.*` (enforced by ESLint); it redacts anything that looks like PII, a token, or a document before logging, and never logs in production builds.
- File uploads are validated client-side (extension/MIME/size) as a UX convenience only — server-side malware scanning and validation remain mandatory and authoritative.

## Folder structure

```
src/
├── app/            # providers, router, layout, environment config — the app shell
├── api/            # HTTP client, generated types (once produced), API-layer docs
├── components/     # ui/ (primitives), common/ (shared app components), forms/
├── features/       # one folder per business area — feature-first, lazy-loaded routes
├── hooks/          # cross-cutting hooks (auth, permissions, feature flags, debounce)
├── lib/            # framework-agnostic utilities (formatting, validation, logging)
├── types/          # shared TypeScript types (temporary until OpenAPI-generated)
├── styles/         # Tailwind entry + design tokens
├── mocks/          # MSW handlers and synthetic fixture data
└── tests/          # Vitest setup, test utilities, and test suites
e2e/                # Playwright specs
scripts/            # OpenAPI validation/generation scripts
```

Each `features/<area>/` folder owns its pages and, where needed, its TanStack Query hooks — keeping feature modules independent so routes can be lazy-loaded per area (see `src/app/router/routes.tsx`).

## Relationship with HrAutomation.Api

This project has exactly one runtime dependency: `HrAutomation.Api`, called over its versioned REST contract. It does not reference any other project in this solution, does not read `HrAutomation.Api`'s configuration files, and does not share code with it beyond the OpenAPI contract (see "API contract and client generation" above). Adding this project to `HrAutomation.slnx` is for solution-explorer convenience only — it does not create a build or project-reference dependency between `HrAutomation.Web` and any `.NET` project.

## Status

Initial scaffold. Route shells, shared components, the API client, mock-mode development, and starter tests exist for every listed screen; most feature pages are intentionally minimal placeholders pending real backend endpoints (see `docs/04-api/frontend-api-integration.md` for the list of endpoints needed to replace mock data).
