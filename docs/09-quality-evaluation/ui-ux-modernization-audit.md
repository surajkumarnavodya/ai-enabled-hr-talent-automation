# UI/UX Modernization Audit

> Title: UI/UX Modernization Audit | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Design Lead] | Status: Complete — see [ui-modernization-report.md](ui-modernization-report.md) for what was implemented from this audit | Last reviewed: 2026-09-09 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Design, Frontend Engineering, Accessibility

## Purpose and scope

Grounds the UI/UX modernization pass in the actual state of `src/HrAutomation.Web`, not assumptions about what a "typical" enterprise scaffold looks like. Every finding below was verified by reading the real component/page source. See [ui-modernization-report.md](ui-modernization-report.md) for what was changed as a result.

## Honest starting-point assessment

Before the gap table: this is **not** a generic Bootstrap-template codebase. It is a hand-built React 19 + Tailwind v4 system with genuinely good bones:

- Native `<dialog>` for modals (real focus trapping, Escape-to-close, top-layer rendering — no modal library needed).
- `StatusBadge` deliberately pairs icon + text + color, never color alone (a real, enforced accessibility rule, not just a guideline).
- `:focus-visible` outline applied globally at the base layer — never silently stripped per-component.
- `FormField` auto-wires `aria-describedby`/`aria-invalid`/`aria-required` onto its child control.
- A working light/dark/system theme engine (`ThemeProvider`, `localStorage`-persisted, `prefers-color-scheme`-aware) already exists.
- A sensible, pre-grouped navigation IA (Overview / Recruitment / Onboarding / Governance / Administration) — this is not something this pass needs to invent.
- Consistent `lucide-react` icon sizing discipline (`h-3.5` in badges, `h-4` in nav/buttons, `h-5` on dashboard tiles).

What's actually missing is **polish, visual identity, and token discipline** — not correctness or accessibility fundamentals. The gaps below are real, but the framing is "take a solid, plain system to premium," not "fix a broken one."

## Gap analysis table

| Area | Current Issue | UX Impact | Visual Impact | Recommended Change | Priority |
|---|---|---|---|---|---|
| Design tokens | `src/styles/theme.css` defines `--hr-radius-*`, `--hr-space-*`, `--hr-shadow-card` but **no component actually references them** — every component hardcodes raw Tailwind utilities (`rounded-md`, `p-4`, `shadow-sm`) instead | None directly, but blocks any future systematic re-theme | Token file is dead weight; two sources of truth that can silently drift | Fold real tokens into the Tailwind v4 `@theme` block (globals.css) so they generate real utility classes, delete the unused parallel `--hr-*` file | P0 |
| Color system | Only `brand` (5 shades) + 5 flat status colors defined in `@theme`; everything else (surfaces, borders, text) uses Tailwind's default `slate-*` scale hardcoded per component | Fine today, but "brand" never actually differentiates the product visually — every enterprise Tailwind app defaults to the same slate+blue look | Product has no distinct visual identity | Add a full semantic surface/border/text token layer (`--color-surface`, `--color-surface-raised`, `--color-border-subtle`, `--color-text-secondary`, etc.) on top of a considered neutral scale, and a slightly warmer/more distinct brand hue | P0 |
| Typography | No type scale exists; page titles are `text-xl font-semibold`, KPI numbers `text-2xl font-semibold`, chosen ad hoc per component | Inconsistent hierarchy between screens (e.g. dashboard KPI size vs. detail page heading size have no defined relationship) | Screens don't feel like they belong to one system | Define a small explicit scale (display/title/section/body/caption + tabular-nums for metrics) as `@theme` font-size tokens | P0 |
| Status-tone duplication | Every list page hand-declares its own `STATUS_TONE` record (e.g. `InterviewsListPage`'s local `Scheduled: "info"` map) rather than reading from one registry | Two modules can silently diverge on what color a semantically-equivalent status gets over time | Minor now, real drift risk later | Centralize per-domain status→tone maps in one `lib/statusTones.ts`, imported everywhere | P1 |
| Dashboard hierarchy | 10 KPI tiles rendered in one uniform grid with identical visual weight; only the icon-chip tint varies by tone (`neutral`/`warning`/`danger`) — the number itself is never colored | User must read every icon before knowing what needs attention; a P0 metric ("High-severity discrepancies") looks exactly as urgent as "Active TANs" until you notice the icon tint | Dashboard feels like a wall of equal boxes, not a triaged view | Group into "needs attention" vs. "informational" bands, color the metric value itself for warning/danger tiles, add a pending-approvals/recent-activity panel | P0 |
| Sidebar | Fixed `w-64` on desktop with no collapse-to-icon mode; mobile-only show/hide via `open` boolean overlay | Desktop users on smaller laptop screens permanently lose 256px of width with no way to reclaim it | Sidebar never adapts to available space | Add a collapsed (icon-only, tooltip-on-hover) desktop state, persisted preference | P1 |
| Header / topbar | No profile dropdown (plain text name + role + a bare "Sign out" link), no breadcrumb slot (breadcrumbs are opt-in per-page via `PageHeader`, and several list pages pass none), no global search, no theme toggle despite a fully working theme engine underneath | Theme engine (light/dark/system, persisted) is invisible — there is no control anywhere in the UI to invoke it | Header reads as a placeholder, not a finished product surface | Add profile menu, theme toggle, consistent breadcrumb rendering | P0 |
| Table density & scanning | `DataTable` header is not `sticky`; no page-size control (only "Showing page N · total" + Prev/Next); loading state renders 4 generic pulse bars instead of column-shaped skeleton rows; sort is client-side only against the *currently loaded page*, which silently misleads when pagination is server-side | Sorting a paginated table only reorders what's visible, not the full result set — this can look like a bug to a user who doesn't realize | Loading state doesn't resemble the table it's replacing (jarring swap) | Sticky header, skeleton rows shaped like real columns, either disable/hide the sort affordance when pagination is server-driven or make it clear it's page-local, add page-size selector | P0 |
| Cards | Every `Card` looks identical (same border, same `shadow-sm`, same radius) regardless of whether it holds a KPI, a detail panel, or a status summary — no elevation hierarchy | Nothing visually signals "this card is the primary thing on this screen" vs. "this is supporting detail" | Flat, undifferentiated surfaces everywhere | Add 1-2 elevation variants (raised/emphasized) used deliberately, not as a new default | P1 |
| Forms | `FormField` itself is well-built (accessible, good error/hint pattern), but nothing above it groups related fields into visual sections — forms read as a flat vertical list of fields regardless of length | Longer forms (e.g. TAN creation) have no visual chunking to aid scanning/completion | Forms look plain | Add a `FormSection`/`FieldGroup` primitive with heading + description, sticky action footer for long forms | P1 |
| Empty states | Generic dashed-border box + `Inbox` icon + title/description everywhere, including places where a more specific icon/action would help (e.g. "Feedback visibility is role-restricted" uses the same visual treatment as "no rows found") | Can't visually distinguish "nothing here yet" from "you're not allowed to see this" at a glance | Minor — mostly consistent, which is a strength | Allow `EmptyState` variants (`empty` vs `restricted`) with distinct icon/tone while keeping the same layout | P2 |
| Toasts / notifications | No toast/notification component exists in `components/ui` or `components/common` at all — confirmed by directory listing | Sensitive actions (approve, send, resolve) currently rely entirely on inline state changes for feedback; no ambient confirmation pattern | N/A (doesn't exist yet) | Add an accessible toast primitive (`aria-live="polite"` region) for non-blocking confirmations, reserving `ConfirmActionDialog` for the actual approval gate | P1 |
| Motion | No motion tokens; the only transition in the codebase is a bare `transition-transform` on the sidebar slide and Tailwind's default `transition-colors` on interactive elements | Fine — nothing janky — but no consistent, intentional motion language (e.g. page-content fade-in, list-item stagger, dialog enter/exit easing) | Feels static/utilitarian rather than "smooth and premium" | Define 2-3 motion tokens (duration/easing) and apply consistently to dialogs, drawers, and route transitions only — not everywhere | P2 |
| Breakpoint discipline | Only ad hoc `sm:`/`lg:` usage spot-checked in `PageContainer`, `PageHeader`, `Header`, `DataTable` (`min-w-[600px]` forces horizontal scroll on narrow tablets rather than an adaptive card/list fallback) | Acceptable, standard enterprise pattern (horizontal-scroll tables), not a real defect | Minor | Keep horizontal-scroll pattern for dense tables (standard, not worth replacing), just ensure it's applied consistently everywhere `DataTable` is used | P2 |

## Top 10 visual inconsistencies

1. Design-token file (`theme.css`) exists but is entirely unreferenced by any component — a dead parallel system.
2. No semantic surface/border/text tokens — every component hardcodes `slate-*` directly, so a future rebrand means find-and-replace across dozens of files.
3. No defined typography scale — heading/KPI/label sizes are each a one-off judgment call.
4. Status-tone maps duplicated per-feature instead of centralized.
5. Cards have exactly one visual treatment regardless of content importance.
6. Dashboard KPI values are never color-coded by severity — only icon chips are, which is easy to miss while scanning.
7. `EmptyState` uses one visual treatment for both "genuinely empty" and "permission restricted" situations.
8. Table loading skeleton doesn't resemble the table it replaces (generic bars vs. columns).
9. No motion tokens — transitions exist but aren't a deliberate, named system.
10. Breadcrumbs are opt-in per page rather than a guaranteed, consistent chrome element.

## Top 10 UX pain points

1. Theme toggle has no UI entry point despite the underlying engine being fully implemented — dead feature from the user's perspective.
2. No profile/account menu — just a static name/role string and a bare sign-out link.
3. Desktop sidebar can't collapse — permanently costs 256px of width with no way to reclaim it.
4. Dashboard is a flat, equal-weight grid — nothing communicates "look here first."
5. No pending-approvals or recent-activity view on the dashboard despite that being the most operationally useful thing for HR staff opening the app.
6. Table sort silently operates only on the loaded page when pagination is server-side — a correctness-flavored UX trap, not just cosmetics.
7. Pagination is Prev/Next only — no page-size control or jump-to-page for longer result sets.
8. No toast/notification system — sensitive-action confirmations rely solely on the page re-rendering.
9. Forms present as an undifferentiated flat list of fields with no sectioning, even for longer flows like TAN creation.
10. No global search or quick-jump — finding a specific candidate/TAN/interview requires navigating into the right list first.

## Top 10 high-value screens to modernize first

1. Dashboard — first thing every user sees; currently the least differentiated screen in the app.
2. App shell (Sidebar + Header) — touches every single screen; the single highest-leverage change in the whole pass.
3. Interviews list/detail — the module the original bug report centered on; already fully wired to real data.
4. TAN list/detail/form — the most mature, most-used existing workflow.
5. Candidate profile — dense, high-information-content page that benefits most from sectioning/tabs.
6. Offers list/detail/approval — sensitive-action screens where "trustworthy" visual language matters most.
7. Approvals queue — the cross-cutting decision screen; should feel the most deliberate/serious in the app.
8. Verification queue/detail — dense checklist-style content, a good test of table/list density work.
9. Employee conversion — the terminal, highest-stakes step in the whole pipeline (creates an Employee ID).
10. Admin/master data screens — lowest-traffic but most template-like today; good candidates for the shared-pattern payoff to show clearly.

## Method

Read the actual source for: `package.json`, `postcss.config.js`, `src/styles/theme.css`, `src/styles/globals.css`, `app/layout/{AppShell,Sidebar,Header,PageContainer,Breadcrumbs}.tsx`, `app/router/{routes.tsx,routeConfig.ts}`, `app/providers/ThemeProvider.tsx`, `components/ui/{Button,Card,Badge,Dialog}.tsx`, `components/common/{PageHeader,StatusBadge,EmptyState,LoadingState,ErrorState,DataTable/DataTable}.tsx`, `components/forms/FormField.tsx`, and representative pages (`DashboardPage`, `InterviewsListPage`, `InterviewDetailPage`). Directory-listed `components/ui` and `components/common` in full to confirm what does and doesn't exist (e.g. confirmed no toast component). Findings are based on this concrete inspection, not inferred from the app's category.

## Not found in this pass

- No evidence of a component library (MUI/Ant/Chakra/shadcn) — confirms the system is fully custom, which the modernization pass should build on, not replace.
- No inline `style={}` usage or ad hoc one-off CSS files found in the inspected sample — styling discipline (Tailwind utilities + `cn()` merge helper) is consistent, just visually plain.
- No broken accessibility fundamentals found in the inspected sample (focus rings, ARIA wiring, semantic status communication all present and deliberate).
