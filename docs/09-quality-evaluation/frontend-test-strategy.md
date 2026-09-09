# Frontend Test Strategy

> Title: Frontend Test Strategy | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Frontend Engineering / QA] | Status: Draft | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: QA, Frontend Engineering, Security

## Table of contents

1. [Purpose and scope](#purpose-and-scope)
2. [Test tiers](#test-tiers)
3. [Starter test coverage](#starter-test-coverage)
4. [Known testing constraints and how they were resolved](#known-testing-constraints-and-how-they-were-resolved)
5. [Test data policy](#test-data-policy)
6. [Coverage expectations for new work](#coverage-expectations-for-new-work)
7. [Risks and open questions](#risks-and-open-questions)
8. [Change control](#change-control)

## Purpose and scope

Defines the testing approach for `src/HrAutomation.Web`, extending [docs/09-quality-evaluation/test-strategy.md](test-strategy.md) with frontend-specific tooling and patterns.

## Test tiers

| Tier | Tooling | Scope |
|---|---|---|
| Unit | Vitest | Framework-agnostic logic in `lib/`, `api/client/` |
| Component | Vitest + React Testing Library | Individual components/pages, MSW-mocked network |
| Feature/integration | Vitest + React Testing Library + MSW | Multi-component flows within a feature (e.g., confirm-then-mutate) |
| Accessibility | axe-core (via `vitest-axe`) + `eslint-plugin-jsx-a11y` | Candidate-facing screens especially; lint runs on every file |
| End-to-end | Playwright | Full user journeys against the real dev server with MSW mocking |

Run via `npm run test` (Vitest, all non-e2e tiers) and `npm run test:e2e` (Playwright) from `src/HrAutomation.Web/`.

## Starter test coverage

| Requirement | Test file |
|---|---|
| Application bootstrapping | `src/tests/components/App.test.tsx` |
| Protected route behavior | `src/tests/components/ProtectedRoute.test.tsx` |
| Permission-denied state | `src/tests/components/ProtectedRoute.test.tsx` (`PermissionRoute` describe block) |
| API error mapper | `src/tests/unit/apiError.test.ts` |
| Correlation ID generation | `src/tests/unit/correlationId.test.ts` |
| Safe logger redaction behavior | `src/tests/unit/safeLogger.test.ts` |
| Candidate matching labels AI output as a recommendation | `src/tests/features/candidateMatching.test.tsx` |
| Shortlist/send-offer/employee-conversion require confirmation | `src/tests/features/candidateMatching.test.tsx`, `src/tests/features/sensitiveActionsRequireConfirmation.test.tsx` |
| Unauthorized UI routes show access-denied state | `src/tests/components/ProtectedRoute.test.tsx`, `e2e/critical-workflows.spec.ts` |
| File-upload client validation | `src/tests/unit/fileUploadValidation.test.ts`, `e2e/critical-workflows.spec.ts` |
| Critical Green Form accessibility checks | `src/tests/accessibility/greenForm.a11y.test.tsx` |

Additional e2e coverage: `e2e/auth.spec.ts` (sign-in/sign-out redirects), `e2e/dashboard.spec.ts` (dashboard tiles, sidebar navigation).

## Known testing constraints and how they were resolved

Two real, non-obvious constraints were hit building this scaffold — documented here so they aren't rediscovered the hard way:

1. **`createBrowserRouter` under jsdom + MSW.** React Router's data routers construct an internal `Request` object on every client-side navigation. Under Vitest's jsdom environment, that `Request`'s `AbortSignal` comes from a different realm than the one `msw/node`'s interceptors expect, crashing with `TypeError: RequestInit: Expected signal to be an instance of AbortSignal`. Fix: `app/router/routes.tsx` exports `routeObjects` (a plain array) separately from the created `router`, so tests build a `createMemoryRouter(routeObjects, ...)` instead via the injectable `router` prop threaded through `App` → `AppProviders` → `RouterProvider`. Component tests that must exercise a client-side *redirect* (not just render) instead use plain `<Routes>`/`<Route>` (non-data-router API), which isn't affected — see `ProtectedRoute.test.tsx`.
2. **In-memory mock auth session + `page.goto()` in Playwright.** `mockAuthProvider.ts` deliberately keeps its session in module memory, never in storage (see [frontend-security.md](../05-security-governance/frontend-security.md)). A Playwright `page.goto()` performs a full browser reload, which reinitializes the app and loses that in-memory session — the same as an unauthenticated reload would in production without a persisted session. E2E specs sign in once per test and then navigate via UI clicks (`page.getByRole("link", ...).click()`), never a second `page.goto()`, to stay within the same in-memory session.

Both are documented in code comments at the exact site they matter (`tests/components/App.test.tsx`, `e2e/critical-workflows.spec.ts`), not only here.

## Test data policy

No real candidate, employee, CV, compensation, or document data appears anywhere in this project's tests, fixtures, or mock data (`src/mocks/data/`). All names, IDs, and documents are synthetic and marked `(demo)` where they resemble a name, per [CLAUDE.md](../../CLAUDE.md) Section 7.

## Coverage expectations for new work

Per the Frontend Rules in [CLAUDE.md](../../CLAUDE.md): any new route requires loading/error/empty states and tests in the same change; any new sensitive action requires a test asserting it is confirmation-gated and never optimistic; any new candidate-facing screen requires an accessibility test.

## Risks and open questions

- Test coverage thresholds (`vitest run --coverage`) are not yet enforced in CI — [TENANT_CONFIGURATION_REQUIRED] minimum before merge.
- Visual regression testing is not yet in scope — [TENANT_CONFIGURATION_REQUIRED] if the design system stabilizes enough to warrant it.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | HrAutomation.Web scaffold generation | Initial creation |
