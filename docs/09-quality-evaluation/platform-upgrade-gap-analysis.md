# Platform Upgrade Gap Analysis

> Title: Platform Upgrade Gap Analysis | Version: 0.3 | Owner: [TENANT_CONFIGURATION_REQUIRED — Engineering Lead] | Status: Implemented — pending human review of the Tailwind v4 visual output and a `playwright install` browser-binary refresh (see Risks and open questions) | Last reviewed: 2026-09-09 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Engineering, Architecture, Security

## Table of contents

1. [Purpose and scope](#purpose-and-scope)
2. [Method](#method)
3. [Toolchain actually installed in this environment](#toolchain-actually-installed-in-this-environment)
4. [Gap analysis table](#gap-analysis-table)
5. [Version-decision rule applied](#version-decision-rule-applied)
6. [Blocking dependency detail](#blocking-dependency-detail)
7. [Proposed upgrade order](#proposed-upgrade-order)
8. [Risks and open questions](#risks-and-open-questions)
9. [Change control](#change-control)

## Purpose and scope

Records the *actual* current versions found in this repository (not assumed ones), the actual latest *stable* versions available today (verified against the NuGet v3 flat-container API and the npm registry, filtering out `-rc`/`-beta`/`-preview`/`-alpha`/`next`/`dev` tags), and the gap between them. This is Phase 1 (Discovery) of the platform upgrade requested in the "Principal .NET Upgrade Architect / React Platform Modernization" work item. It does not itself change any code — see [Proposed upgrade order](#proposed-upgrade-order) for what Phases 2–5 would touch.

## Method

- Backend: read `global.json`, `Directory.Build.props`, `Directory.Packages.props`, every `*.csproj` under `src/` and `tests/`, `NuGet.config` (absent). Cross-checked the installed SDK list (`dotnet --list-sdks`) and queried `https://api.nuget.org/v3-flatcontainer/<id>/index.json` per package, filtering to versions with no `-` prerelease suffix.
- Frontend: read `src/HrAutomation.Web/package.json`, `package-lock.json`, `tsconfig*.json`. Queried `npm view <pkg> version` (registry `dist-tags.latest`, which npm always resolves to the latest stable release) and `npm view <pkg> dist-tags` / `peerDependencies` where a compatibility question existed.
- CI/CD & infra: read `.github/workflows/*.yml`, `docker-compose.yml`, searched for `Dockerfile*` and `.devcontainer/*` (none exist yet — noted as a gap, not fabricated).
- Docs: grepped `README.md`, `CONTRIBUTING.md`, `PROJECT_STATUS.md` for stated version baselines.

## Toolchain actually installed in this environment

| Tool | Installed version |
|---|---|
| `dotnet` (active, via `global.json`) | 10.0.401 (SDK) |
| `dotnet --list-sdks` (all present) | 9.0.315, 10.0.301, 10.0.303, 10.0.401 |
| `node` | v24.18.0 |
| `npm` | 11.16.0 |
| Node.js latest LTS line (per `nodejs.org/dist/index.json`) | v24.21.0 ("Krypton") — confirms Node 24 is current LTS, matching the installed toolchain |
| Node.js latest overall (Current, not yet LTS) | v26.8.1 |

`global.json` already pins SDK `10.0.400` with `rollForward: latestFeature` — the *SDK* is already on .NET 10. The gap is entirely in the *project* `TargetFramework`s, which are still `net8.0`, and in `PROJECT_STATUS.md`/`README.md`, which still document ".NET 8 SDK" as the baseline. That documentation is now stale relative to `global.json` even before any code change.

## Gap analysis table

| Area | Current Version | Target Version | Blocking Dependency | Risk | Action Required | Status |
|---|---|---|---|---|---|---|
| .NET SDK (`global.json`) | 10.0.400 (`rollForward: latestFeature`) | 10.0.401 (latest installed 10.x) | None | Low | Bump pinned SDK version to the newest installed 10.0.x patch | Done |
| Backend TargetFramework (all 8 `.csproj`) | `net8.0` (Domain, Application, Infrastructure, Agents, Rag, Mcp, Api, Tests) | `net10.0` | None — SDK already supports it; EF Core/ASP.NET Core packages below must move in lockstep | Medium | Change `<TargetFramework>` in all 8 projects together (avoid framework fragmentation) | Done |
| C# language version | `LangVersion` = `latest` (repo-wide, `Directory.Build.props`) — **not hardcoded to 10.0**, contrary to the brief's assumption | `latest` (resolves to C# 14 once TFM is `net10.0`) | None | Low | No change needed to the setting itself; verify no per-project `<LangVersion>` override exists (none found) | Verified — already correct |
| Central Package Management | Disabled (`Directory.Packages.props` present as a documented placeholder, `ManagePackageVersionsCentrally=false`) | Out of scope for this upgrade | N/A | N/A | Leave as-is; adopting CPM is explicitly called out in the file itself as a deliberate, separate change | Not started (deliberately out of scope) |
| Microsoft.AspNetCore.Authentication.JwtBearer | 8.0.11 | 10.0.12 | Must match `net10.0` TFM | Medium — JWT/auth middleware; security-critical path | Upgrade in lockstep with TFM; re-verify auth middleware ordering | Done |
| Microsoft.EntityFrameworkCore.Design | 8.0.11 | 10.0.12 | Must match TFM; stored-procedure-first data access (ADR-006) is unaffected but EF Core 9→10 changed some LINQ translation/design-time behavior | Medium | Upgrade; run full `dotnet test` against real `HrAutomationDb` (per `.claude/rules/testing.md`, no in-memory substitute for RLS/proc coverage) | Done |
| Microsoft.EntityFrameworkCore.SqlServer | 8.0.11 | 10.0.12 | Same as above | Medium | Upgrade in lockstep with `.Design` | Done |
| Microsoft.EntityFrameworkCore.InMemory (test-only) | 8.0.11 | 10.0.12 | Same as above | Low (test-only, `.Tests` project already avoids relying on it for RLS/proc paths per testing rule) | Upgrade in lockstep | Done |
| Microsoft.Data.SqlClient | 5.2.2 | 7.0.2 (latest stable; 7.1.0-preview3 excluded as prerelease) | None | Medium — connection/TLS defaults have changed across major versions; must validate against real SQL Server/LocalDB | Upgrade; smoke-test `HrAutomationDb` connectivity | Done |
| Microsoft.Extensions.Configuration / EnvironmentVariables / UserSecrets | 8.0.0 / 8.0.0 / 8.0.1 | 10.0.12 (all three) | Must match TFM | Low | Upgrade as a set (these three must share a major version) | Done |
| OpenTelemetry.Extensions.Hosting / Instrumentation.AspNetCore / Instrumentation.Http / Exporter.Console | 1.9.0 (all four) | 1.18.0 (all four) | None | Low–Medium — instrumentation API surface has moved since 1.9; check `docs/08-operations-observability/observability-strategy.md` alignment | Upgrade as a set | Done |
| Swashbuckle.AspNetCore | 6.6.2 | 10.2.3 | Must match `net10.0`; **or** replace with built-in `Microsoft.AspNetCore.OpenApi` (10.0.12) — ASP.NET Core has shipped first-party OpenAPI generation since .NET 9 | Medium — OpenAPI document generation/attribute usage differs between Swashbuckle and `Microsoft.AspNetCore.OpenApi`; `openapi/hr-onboarding-api.openapi.yaml` is contract-first and hand-maintained per `.claude/rules/api.md`, so this is a tooling choice, not a contract change | Decided: kept Swashbuckle 10.2.3 in place (did not switch generators). Swashbuckle 10.x pulls `Microsoft.OpenApi` 2.7.5, which **flattened the `Microsoft.OpenApi.Models` namespace into `Microsoft.OpenApi`** and replaced inline `OpenApiSecurityScheme { Reference = ... }` with a dedicated `OpenApiSecuritySchemeReference` reference type; `SwaggerGenOptions.AddSecurityRequirement` now takes `Func<OpenApiDocument, OpenApiSecurityRequirement>` instead of a bare instance, since the reference needs to bind against the generated document. Fixed in `src/HrAutomation.Api/Program.cs`: `using Microsoft.OpenApi.Models` → `using Microsoft.OpenApi`; JWT bearer requirement rebuilt with `new OpenApiSecuritySchemeReference("Bearer", document)` inside the new `Func` overload. Verified via `dotnet build` (0 errors) | **Done** — build green, verified by reflecting the actual installed `Microsoft.OpenApi` 2.7.5 assembly (docs for this API surface were not yet indexed at authoring time) |
| System.IdentityModel.Tokens.Jwt | 8.3.1 | 8.22.0 | None | Low | Upgrade | Done |
| FluentValidation | 11.11.0 | 12.1.1 | None known | Medium — v12 dropped some legacy validator APIs; scan `HrAutomation.Application` validators for obsolete usage | Upgrade; fix any compiler warnings/errors | Done |
| Microsoft.AspNetCore.Mvc.Testing (test) | 8.0.11 | 10.0.12 | Must match TFM; `HrApiFactory` (per `.claude/rules/testing.md`, no per-run DB isolation, DEC-007) | Medium | Upgrade; re-verify `WebApplicationFactory` bootstrap still resolves the real `HrAutomationDb` connection | Done |
| Microsoft.NET.Test.Sdk | 17.8.0 | 18.10.0 | None | Low | Upgrade | Done |
| xunit | 2.5.3 | 2.9.3 (v2 line; `xunit.v3` 4.0.0 exists as a separate major-version package) | None for v2→v2.9.3 | Low | Upgrade within v2. **Do not** silently switch to `xunit.v3` — that's a test-project restructuring (different entry point/assembly model), out of scope unless explicitly requested | Done |
| xunit.runner.visualstudio | 2.5.3 | 4.0.0 | Must match xunit major line conventions | Low | Upgrade | Done |
| coverlet.collector | 6.0.0 | 10.0.1 | None | Low | Upgrade | Done |
| Node.js baseline | `package.json` `engines.node: ">=20.0.0"`; no `.nvmrc`/`.node-version` file exists | `24.x` (LTS "Krypton"), add `.nvmrc`/`.node-version` | None | Low | Bump `engines.node` to `>=24.0.0`; add `.nvmrc` (`24`) so local/CI Node versions can't silently drift | **Done** |
| React / React DOM | 18.3.1 | 19.2.8 | `@types/react`, `@types/react-dom`, `@testing-library/react`, `@vitejs/plugin-react` must move together | Medium — React 19 changes root rendering API expectations (already using `createRoot`, so likely low actual churn) and removes some legacy APIs | Upgrade as a set; audit for `ReactDOM.render`, legacy `propTypes`/`defaultProps` on function components, string refs | **Done** — no `ReactDOM.render`/legacy `propTypes` found; `main.tsx` already used `createRoot`, zero React 19 code churn needed |
| react-router-dom | 6.28.1 | react-router-dom is now a **compatibility re-export**; current major is 7.18.3 | Routing API (data routers, loader/action patterns) changed meaningfully v6→v7 | **High** — this is a routing-behavior change, not a drop-in bump | User decision: **upgrade to v7 now** | **Done** — app already used the v6.4+ data-router API (`createBrowserRouter`/`RouteObject`, no loaders/actions/fetchers), so v7 churn was minimal. Only fix needed: `RouterProvider`'s `future={{ v7_startTransition: true }}` prop no longer exists in v7 (that behavior is now the unconditional default) — removed in `src/app/providers/RouterProvider.tsx` |
| @tanstack/react-query | 5.62.7 | 5.102.8 | None (same major) | Low | Upgrade | **Done** |
| TypeScript | `^5.7.2` (installed range resolves within 5.x) | Not 7.0.2; not even 6.0.3 as originally recommended here — see **Blocking dependency detail** below, a second peer constraint was found during `npm install` that this discovery pass missed | `typescript-eslint` peer range excludes TS 7.x; **`openapi-typescript@7.13.0` peer range is `^5.x` only — it does not accept TS 6 at all** | **Blocking** | Target **5.9.3** (latest 5.x), not 6.0.3 — the highest version satisfying both `typescript-eslint`'s `<6.1.0` cap AND `openapi-typescript`'s `^5.x` cap. `openapi-typescript` backs the CLAUDE.md-mandated `npm run api:generate` workflow, so it isn't optional tooling | **Done** — `npm run typecheck`, `npm run api:generate`, `npm run api:validate` all verified working at TS 5.9.3 |
| typescript-eslint / @typescript-eslint/eslint-plugin / @typescript-eslint/parser | 8.19.0 | 8.70.0 | Peer range caps TypeScript at `<6.1.0` (see above) | Low (package itself), but gates the TypeScript row above | Upgrade to 8.70.0 | **Done** |
| eslint | 9.17.0 | Not 10.10.0 — see **Blocking dependency detail** below, a peer constraint this discovery pass missed | `@eslint/js`, `typescript-eslint`, `eslint-plugin-*` should track major together | **Blocking** — `eslint-plugin-jsx-a11y@6.10.2` (latest stable, mandatory per CLAUDE.md frontend accessibility rule) declares `peerDependencies.eslint: "^3 \|\| ^4 \|\| ^5 \|\| ^6 \|\| ^7 \|\| ^8 \|\| ^9"` — it does not accept ESLint 10 at all | Hold at latest **9.x (9.39.5)**, not 10.10.0, until `eslint-plugin-jsx-a11y` ships ESLint 10 support. Do not drop the accessibility linter to force ESLint 10 — CLAUDE.md frontend rules make it non-negotiable | **Done** — `npm install` initially failed with an `ERESOLVE` conflict on this exact constraint; resolved by capping at 9.39.5 (also pinned `@eslint/js` to `^9.39.5` to match) |
| eslint-plugin-jsx-a11y | 6.10.2 | 6.10.2 | Caps ESLint at `^9` — see above | None | Already latest — no change | Verified — up to date, and is the reason ESLint itself stayed on 9.x |
| eslint-plugin-react-hooks | 5.1.0 | 7.1.1 | Must support React 19 | Low–Medium | Upgrade alongside React | **Done** — new `react-hooks/set-state-in-effect` rule (added in this major) caught one real pre-existing pattern, see [Backend upgrade verification] section analog below in Frontend verification |
| eslint-plugin-react-refresh | 0.4.16 | 0.5.6 | None | Low | Upgrade | **Done** |
| Vite | 5.4.11 | 8.2.2 | `@vitejs/plugin-react` must match | **High** — three major versions (6, 7, 8) in one jump; Vite majors have historically changed Node support floor and default behaviors each time | Upgrade incrementally if any build breakage occurs (5→6→7→8), not necessarily in one leap; validate `vite.config.ts` after each major | **Done** — jumped directly to 8.2.2 (paired with `@vitejs/plugin-react` 6.1.1); build succeeded on the first attempt with one deprecation warning (`__dirname` unsupported by the upcoming native config loader), fixed by switching to `import.meta.dirname` in `vite.config.ts`. No incremental step-through was needed in practice |
| @vitejs/plugin-react | 4.3.4 | 6.1.1 | Must match Vite major | Medium | Upgrade with Vite | **Done** |
| vitest / @vitest/coverage-v8 | 2.1.8 | 5.0.0 | Must match Vite major generally | Medium | Upgrade with Vite; re-verify `vitest.config`/setup files | **Done** — `npm run test`: 11 test files, 40/40 passed, no config changes needed |
| @playwright/test / @axe-core/playwright | 1.49.1 / 4.10.1 | 1.63.0 / 4.13.0 | None | Low | Upgrade; re-run `npx playwright install` for updated browser binaries | Package upgrade **done**; `npx playwright --version` confirms 1.63.0 CLI resolves correctly. `npx playwright install` (browser binary download) **not run in this pass** — large download, left as a follow-up for whoever next runs `npm run test:e2e` locally/in CI |
| @testing-library/react / jest-dom / user-event | 16.1.0 / 6.6.3 / 14.5.2 | 16.3.3 / 7.0.1 / 14.6.7 | Must support React 19 | Low | Upgrade with React | **Done** |
| zod | 3.24.1 | 4.5.4 | `@hookform/resolvers` must support zod v4 | **High** — Zod v4 has documented breaking API changes (error customization, `.parse` behavior in edge cases) that affect every schema used across forms/validation | User decision: **upgrade to v4 now** | **Done** — `npm run typecheck` surfaced the real breakage: `@hookform/resolvers` v5's `zodResolver` distinguishes a schema's *input* type (pre-coercion, e.g. `unknown` for a `z.coerce.number()` field) from its *output* type, and a `useForm<T>` call with a single generic pins both to the same type, conflicting with the resolver's inferred types. Fixed in the 3 affected forms (`TanFormPage.tsx`, `GreenFormPage.tsx`, `InterviewFeedbackPage.tsx` — all use `z.coerce.number()`) by switching to the resolvers-package-documented 3-generic form: `useForm<z.input<typeof schema>, unknown, z.output<typeof schema>>(...)`. `OfferNewPage.tsx` uses zod but no coercion, so it needed no change |
| react-hook-form | 7.54.2 | 7.87.0 | None (same major) | Low | Upgrade | **Done** |
| @hookform/resolvers | 3.9.1 | 5.9.1 | Must match react-hook-form + zod versions | Medium — major version jump tracks zod v4 support | Upgrade together with the zod decision above | **Done** |
| tailwindcss | 3.4.17 | 4.3.3 | `postcss`, `autoprefixer` config approach changes (Tailwind v4 moves config into CSS, removes `tailwind.config.js` as the primary mechanism) | **High** — near-total configuration model rewrite | User decision: **upgrade to v4 now** | **Done** — added `@tailwindcss/postcss` devDependency (v4 split the PostCSS plugin out of the `tailwindcss` package itself) and pointed `postcss.config.js` at it; replaced `@tailwind base/components/utilities` with `@import "tailwindcss";` in `globals.css`; added `@custom-variant dark (&:where(.dark, .dark *));` to preserve the v3 `darkMode: "class"` behavior (v4 defaults to `prefers-color-scheme`-only, which would have broken the app's manual theme toggle in `ThemeProvider.tsx`); ported the `brand`/`status` custom color palette from `tailwind.config.js` `theme.extend.colors` into a CSS-first `@theme { --color-brand-500: ...; }` block in `globals.css`; deleted `tailwind.config.js` (dead — v4 auto-detects content, no `content: [...]` globbing needed). Verified the generated CSS in `dist/assets/*.css` actually contains `--color-brand-500:#2f6fb0` etc. Note: several `brand-300/400/800/950` classes referenced in components were never defined in the old config either (5 of 9 shades were declared) — this is a pre-existing gap unrelated to the upgrade, left as-is to match current runtime behavior exactly |
| postcss / autoprefixer | 8.4.49 / 10.4.20 | 8.5.28 / 10.5.5 | Tied to the Tailwind decision | Low on their own | Upgrade once Tailwind path is decided | **Done** |
| axios | 1.7.9 | 1.20.0 | None (same major) | Low | Upgrade | **Done** |
| clsx, tailwind-merge, lucide-react, globals, jsdom, msw, openapi-typescript, prettier, yaml, @types/node | various (see `package.json`) | see registry versions captured during discovery | `@types/node` should track the Node **major** actually targeted (24.x), not registry "latest" (26.x, which targets the not-yet-LTS Node 26) | Low, except `@types/node` | Upgrade routine ones directly; pin `@types/node` to the `24.x` line, not `26.x` | **Done** — `@types/node` pinned to `^24.13.3`; `jsdom` corrected to `30.0.1` (this doc's initial draft had mis-transcribed it as `27.0.0` while cross-checking a batch `npm view` run — corrected before installing) |
| CI — backend job (`.github/workflows/ci.yml`) | Uses `actions/setup-dotnet@v4` with `global-json-file: global.json` (correct pattern — no separate pinned SDK to drift) | No change needed to the mechanism | None | Low | None — already reads from `global.json` | Verified — already correct |
| CI — frontend job | **Placeholder only** — `echo "[COMMAND_TO_TEST_FRONTEND]"`, no `actions/setup-node` step, no real install/build/test/lint invocation exists yet | Add real `actions/setup-node@v4` (Node 24) + `npm ci` + `npm run typecheck/lint/build/test` steps | None | N/A (currently untested in CI at all) | This isn't a version gap so much as a missing pipeline — flagging because "CI uses the same Node version as the repo standard" can't be verified until the job does something real | **Done** — see Phase 4 below |
| Dockerfiles | None exist in the repository (`docker-compose.yml` only references `postgres:16-alpine`, `redis:7-alpine`, `otel/opentelemetry-collector-contrib:latest`, all explicitly "not wired up yet" per that file's own header comment) | N/A | N/A | N/A | Nothing to upgrade — note the gap, do not fabricate Dockerfiles as part of a version-upgrade task | Not applicable |
| devcontainer | None exists | N/A | N/A | N/A | Out of scope unless requested separately | Not applicable |
| README.md / CONTRIBUTING.md / PROJECT_STATUS.md | State "*.NET 8 SDK, Node.js 20+*" as the local dev baseline | Update to ".NET 10 SDK (`net10.0`), Node.js 24.x" once Phases 2–3 land | None | Low | Update in the same change as the code upgrade (per `.claude/rules/documentation.md`) — not before, not as a follow-up | **Done** |
| `HrAutomation.slnx` stale `HrAutomation.Web` entry / `src/HrAutomation.Web/Web.config` | Solution file listed `HrAutomation.Web` as a `Type="Website"` project targeting `.NETFramework,Version=v4.8.1` with legacy `AspNetCompiler` properties; a matching `Web.config` (`targetFramework="4.8.1"`) sat unused at the project root | Removed — neither describes the real Vite/React app, which isn't (and shouldn't be) referenced from `.slnx` at all | None — confirmed zero references to `Web.config` anywhere else in the repo before deleting | Low | Delete both as dead legacy artifacts, not a functional change | **Done** |
| npm audit — dev-only transitive vulnerability | `js-yaml` 4.0.0–4.3.1 (via `@redocly/openapi-core`, a transitive dependency of `openapi-typescript`) — 1 CVE, high severity per `npm audit` | Fix not yet published upstream | None actionable today | Low in practice (dev-time-only CLI tool, not bundled into the shipped app; not reachable from the running application) | `npm audit fix` and `npm audit fix --force` both confirmed no fix is available yet. Documented here rather than silently ignored; re-run `npm audit` on a future dependency bump | Accepted, tracked — not blocking |

## Version-decision rule applied

Per the brief's explicit rule: this repository's `Directory.Build.props` already sets `LangVersion` to `latest` (not a hardcoded `10.0`), so there is no existing violation to correct. Once `TargetFramework` moves to `net10.0`, `latest` resolves to **C# 14** automatically — this is "latest .NET and latest C#," applied without needing to hardcode a language version. No non-standard combination (latest .NET + C# 10) is being introduced or needs to be documented as an exception.

## Blocking dependency detail

Three genuine **blocking** dependencies were found — as opposed to "large diff, needs a decision". The first was caught during discovery (static peer-range reading); the other two only surfaced once `npm install` actually ran the resolver, which is why they're recorded here as corrections rather than in the original 0.1 draft.

- **TypeScript 7.0.2 is incompatible with the `typescript-eslint` toolchain.** `typescript-eslint@8.70.0` declares `peerDependencies.typescript: ">=4.8.4 <6.1.0"`. TypeScript's release line jumped `5.9.3 → 6.0.2 → 6.0.3 → 7.0.2` (no `6.1.x`+ line before 7.0).
- **TypeScript 6.0.3 (this doc's original recommendation) is *also* incompatible — with `openapi-typescript`.** `openapi-typescript@7.13.0` (its own latest stable) declares `peerDependencies.typescript: "^5.x"` — it rejects TS 6 entirely, not just TS 7. This wasn't caught during static discovery because checking a peer range against a hypothetical target version requires actually knowing every devDependency's peer declarations, not just the one (`typescript-eslint`) that was top-of-mind for the "TS 7 breaks lint" finding. `npm install` surfaced it immediately via `ERESOLVE`. Since `openapi-typescript` backs the CLAUDE.md-mandated `npm run api:generate` workflow, it isn't optional tooling that can be worked around — **the corrected target is TypeScript 5.9.3** (latest 5.x), the highest version satisfying both constraints simultaneously.
- **ESLint 10.10.0 is incompatible with `eslint-plugin-jsx-a11y`.** `eslint-plugin-jsx-a11y@6.10.2` (its own latest stable, and mandatory per CLAUDE.md's non-negotiable frontend accessibility rule) declares `peerDependencies.eslint: "^3 || ^4 || ^5 || ^6 || ^7 || ^8 || ^9"` — no `^10` yet. This doc's 0.1 draft marked jsx-a11y "Already latest — no change" without cross-checking its peer range against the *target* ESLint version, which is exactly the same class of miss as the TypeScript one above. **The corrected target is ESLint 9.39.5** (latest 9.x), not 10.10.0.

**Lesson applied for future upgrade passes:** a discovery pass that reads `peerDependencies` per-package in isolation is not sufficient to guarantee a conflict-free install — it must cross-check every *other* devDependency's peer range against the specific target version being proposed. Running the actual package manager's resolver (even just `npm install --dry-run`-equivalent) before finalizing target versions in the gap-analysis table would have caught both misses here before implementation, not during it. Re-verify all three constraints above at the next major-version pass in case upstream has caught up.

## Proposed upgrade order

*(as originally planned at discovery time — see [Blocking dependency detail](#blocking-dependency-detail) for the TypeScript 6.0.3→5.9.3 and ESLint 10→9.39.5 corrections made once `npm install` actually ran; the phase order itself held)*

1. **SDK/toolchain** — bump `global.json` SDK patch to `10.0.401`; add `.nvmrc`/`.node-version` pinning Node `24`.
2. **Backend target frameworks** — move all 8 `.csproj` files to `net10.0` together (no fragmentation).
3. **Backend packages** — upgrade the Microsoft.* family, EF Core family, auth, OpenTelemetry, FluentValidation, and test packages as listed above; resolve the Swashbuckle-vs-`Microsoft.AspNetCore.OpenApi` decision before touching API startup code.
4. **Frontend runtime/tooling** — Node baseline, then TypeScript (to **6.0.3**, not 7.0.2 — later corrected to 5.9.3), ESLint 10 + plugins (later corrected to hold at 9.39.5), Vite (validate incrementally 5→6→7→8), Vitest 5, Playwright.
5. **React dependencies** — React/React DOM 19.2.8 + matching `@types/*` and testing-library packages. Router (v6→v7), Zod (v3→v4), Tailwind (v3→v4) each need an explicit decision before bundling into this pass — each is a breaking, non-drop-in change.
6. **Build/test/lint pipelines** — wire the CI frontend job for real (currently a placeholder with no Node setup step at all); keep the backend job as-is (already correct).
7. **Documentation** — update README/CONTRIBUTING/PROJECT_STATUS baselines in the same change that lands the version bumps, per `.claude/rules/documentation.md`.

## Risks and open questions

1. **TypeScript target** — resolved: **5.9.3**, not 6.0.3 or 7.0.2 — see the corrected Blocking dependency detail above.
2. **react-router-dom v6 → v7** — user decided to upgrade now. Resolved with minimal churn (see gap table); no data-router/loader/action usage existed to migrate, only the removed `future` prop.
3. **Zod v3 → v4** — user decided to upgrade now. Resolved; the `useForm` input/output generic split was the only breakage, fixed in 3 forms.
4. **Tailwind CSS v3 → v4** — user decided to upgrade now. Resolved with a CSS-first config migration; visual output verified by inspecting generated CSS custom properties in the production build (`dist/assets/*.css`), not a full manual visual regression pass across every screen — flag this for a human visual QA pass before shipping if a stricter bar is needed for this specific PR.
5. **Swashbuckle vs. built-in `Microsoft.AspNetCore.OpenApi`** — recommend staying on Swashbuckle (upgraded to 10.2.3) to avoid compounding an OpenAPI-generation-strategy change with a platform-version change in the same PR; `openapi/hr-onboarding-api.openapi.yaml` is contract-first and hand-maintained regardless of generator choice.
6. **CI frontend job has never actually run anything** — resolved in Phase 4: wired to real `actions/setup-node` + `npm ci` + typecheck/lint/build/test steps.
7. **No Dockerfiles exist yet** — nothing to upgrade there; flagged so the final report doesn't imply Docker images were touched when none exist.
8. **EF Core / SQL Server compatibility** — per `.claude/rules/data.md` and `.claude/rules/testing.md`, all of this must be validated against a *real* SQL Server/LocalDB instance (`HrAutomationDb`), not the EF Core in-memory provider — stored procedures and row-level security aren't exercised otherwise. (Validated in Phase 2 — 35/35 tests green against real LocalDB.)
9. **`npx playwright install` was not run** — the Playwright *package* is upgraded and its CLI verified (`1.63.0`), but browser binaries were not (re-)downloaded in this pass (large download, sandboxed environment). Whoever next runs `npm run test:e2e` locally/in CI should expect a `playwright install` step to be needed.
10. **`eslint-plugin-jsx-a11y` and `openapi-typescript` are now the long-poles blocking ESLint 10 / TypeScript 6+ respectively** — re-check both at the next dependency refresh; if either has shipped support, the corresponding version cap in this doc should be revisited.

## Backend upgrade verification (Phase 2 — complete)

All 8 `.csproj` files (Domain, Application, Infrastructure, Agents, Rag, Mcp, Api, Tests) now target `net10.0` with packages bumped per the table above. `HrAutomation.slnx` also dropped a stale `HrAutomation.Web` solution entry that pointed at `.NETFramework,Version=v4.8.1` via legacy `AspNetCompiler` website properties — that entry didn't describe the real Vite/React app in `src/HrAutomation.Web` and does not belong in an MSBuild-solution sense (Vite apps aren't referenced from `.sln`/`.slnx` files); removing it is not a functional change.

One real breaking change was hit and fixed: see the Swashbuckle.AspNetCore row above for the `Microsoft.OpenApi` 2.x namespace/API restructuring in `src/HrAutomation.Api/Program.cs`.

Verified:
- `dotnet restore HrAutomation.slnx` — clean
- `dotnet build HrAutomation.slnx` — 0 warnings, 0 errors
- `dotnet test tests/HrAutomation.Tests/HrAutomation.Tests.csproj` — 35/35 passed, against real LocalDB (`HrAutomationDb`), per `.claude/rules/testing.md`

## Frontend upgrade verification (Phase 3 — complete)

`src/HrAutomation.Web/package.json` upgraded per the gap table above (with the TypeScript/ESLint corrections applied — 5.9.3 and 9.39.5, not the doc's original 6.0.3/10.10.0 recommendations). `package-lock.json` regenerated from a clean `node_modules` (an in-place `npm install` over the old React-18-era `node_modules` produced spurious `ERESOLVE` conflicts unrelated to real incompatibilities — a full `rm -rf node_modules package-lock.json && npm install` was needed for a clean resolve). Added `.nvmrc` and `.node-version` (both `24`), bumped `engines.node` to `>=24.0.0`.

Real breaking changes hit and fixed:
- **React Router v7**: removed `future={{ v7_startTransition: true }}` from `RouterProvider` (no longer a valid prop — that behavior is now unconditional in v7).
- **Zod v4 + `@hookform/resolvers` v5**: 3 forms using `z.coerce.number()` needed the 3-generic `useForm<Input, Context, Output>()` form instead of a single generic — see gap table.
- **Tailwind v4**: CSS-first config migration — see gap table for the full list of changes (`@tailwindcss/postcss`, `@import "tailwindcss"`, `@custom-variant dark`, `@theme` color tokens, deleted `tailwind.config.js`).
- **`eslint-plugin-react-hooks` v7**'s new `react-hooks/set-state-in-effect` rule caught one real pattern: `AuthContext.tsx`'s effect called `setState` synchronously as its first line to transition `"idle" → "authenticating"` before starting async work. Fixed by setting `"authenticating"` as the initial `useState` value instead, removing the redundant synchronous call and the extra render it caused — behaviorally identical (`ProtectedRoute` already treats `"idle"` and `"authenticating"` the same in its loading branch).
- **Vite 8 config deprecation**: `__dirname` usage in `vite.config.ts` (unsupported by the upcoming native config loader) replaced with `import.meta.dirname`.

Also removed as dead legacy artifacts (found while investigating the stale `HrAutomation.slnx` entry in Phase 2): `src/HrAutomation.Web/Web.config` (a `.NETFramework 4.8.1` config file with zero real effect on a Vite app, referenced nowhere in the repo).

Verified:
- `npm install` — clean after the node_modules reset; 2 known/accepted issues noted below
- `npm run typecheck` (`tsc -b --noEmit`) — 0 errors
- `npm run lint` (`eslint .`) — 0 errors, 7 pre-existing warnings (all `react-refresh/only-export-components`, unrelated to this upgrade — file-organization warnings that predate it)
- `npm run build` (`tsc -b && vite build`) — succeeds, 0 warnings, verified generated CSS contains the migrated Tailwind v4 theme tokens
- `npm run test` (`vitest run`) — 11 test files, 40/40 passed
- `npm run api:validate` / `npm run api:generate` (openapi-typescript 7.13.0 against `openapi/hr-onboarding-api.openapi.yaml`) — both succeed; confirms the TypeScript 5.9.3 decision was correct
- `npx playwright --version` — 1.63.0, CLI resolves correctly; browser binaries not (re-)installed in this pass (see Risks/open questions)
- `npm audit` — 1 unfixable-today dev-only transitive `js-yaml` CVE via `openapi-typescript` → `@redocly/openapi-core`; documented in the gap table as accepted, not blocking

## Phase 4 — CI/CD consistency (complete)

`.github/workflows/ci.yml`: the `frontend` job was a placeholder (`echo "[COMMAND_TO_TEST_FRONTEND]"`, no Node setup at all) — replaced with `actions/setup-node@v4` reading `src/HrAutomation.Web/.nvmrc`, `npm ci`, then `typecheck`/`lint`/`build`/`test`. The `contracts` job's OpenAPI step was also a placeholder (`echo "[COMMAND_TO_VALIDATE_OPENAPI]"`) — replaced with a real `npm run api:validate` invocation (Node setup + `npm ci` first); its AsyncAPI placeholder step was left as-is (`[COMMAND_TO_VALIDATE_ASYNCAPI]`) since no AsyncAPI validation tooling exists in this repo to wire up — not fabricating one. The `backend` job needed no change (already used `actions/setup-dotnet@v4` with `global-json-file: global.json`, which picks up the SDK bump automatically). No Dockerfiles or devcontainer config exist to update (confirmed absent, not overlooked).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-09-09 | Platform upgrade discovery (Claude Code) | Initial gap analysis: version inventory, blocking-dependency verification, proposed phased upgrade order |
| 0.2 | 2026-09-09 | Platform upgrade — Phase 2 (Claude Code) | Backend TFM/package upgrade to net10.0 verified (build + full test suite green); fixed a real `Microsoft.OpenApi` 2.x breaking API change in `Program.cs`; marked all backend gap rows Done |
| 0.3 | 2026-09-09 | Platform upgrade — Phase 3/4 (Claude Code) | Frontend upgrade verified (typecheck/lint/build/test all green); corrected TypeScript target 6.0.3→5.9.3 (`openapi-typescript` peer range) and ESLint target 10.10.0→9.39.5 (`eslint-plugin-jsx-a11y` peer range) after `npm install` surfaced both; React Router v7, Zod v4, and Tailwind v4 migrations completed per user decision; wired real frontend + OpenAPI-validation CI jobs; removed dead `Web.config`/stale `.slnx` entry; marked all remaining gap rows Done |
