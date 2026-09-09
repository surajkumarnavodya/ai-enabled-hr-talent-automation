# HR Automation Platform — Claude Code Instructions

## Project Purpose

This repository implements a multi-tenant, AI-enabled HR Recruitment and Onboarding Automation platform: Master CV Bank, TAN/JD creation, AI-assisted explainable matching, human-approved shortlisting, interview scheduling and feedback, offer approval and e-signature, Green Form onboarding, verification and discrepancy handling, and candidate-to-employee conversion with downstream HRMS/payroll/IT integrations. AI assists throughout; humans approve every action that materially affects a candidate's or employee's status.

**Before assuming a capability exists, check [PROJECT_STATUS.md](PROJECT_STATUS.md).** Much of `docs/` describes target-state design written before implementation; only CV ingestion and TAN creation/approval are implemented and verified end-to-end today. See [DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md) for open decisions and [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md) for how workflow transitions are actually implemented (per-entity stored procedures, not a generic engine).

## Repository Map

| Path | Responsibility |
|---|---|
| `docs/` | Product, architecture, workflow, data, security, AI/RAG, MCP, operations, quality, delivery documentation and ADRs |
| `config/` | Versioned, non-secret configuration: schemas, defaults, environment/tenant overrides, feature flags |
| `openapi/`, `asyncapi/` | Contract-first REST and event API definitions |
| `mcp/` | MCP server manifests, tool schemas, integration documentation |
| `prompts/` | Versioned, approved agent system prompts and evaluation/red-team prompts |
| `evals/` | Evaluation datasets, cases, rubrics, reports (sanitized data only) |
| `src/` | Application code: `HrAutomation.Domain/.Application/.Infrastructure/.Agents/.Rag/.Mcp/.Api` (.NET backend), `HrAutomation.Web` (React presentation layer) |
| `tests/` | Unit, integration, contract, e2e, security, performance, RAG, and agent tests |
| `infra/` | Docker, Kubernetes, Terraform, and operational scripts |
| `scripts/` | Bootstrap and validation scripts |
| `.claude/` | Shared Claude Code rules, commands, and skills for this repository |

## Required Reading Before Changes

| Task type | Read first |
|---|---|
| Workflow changes | `docs/02-business-workflows/`, `config/schemas/workflow-config.schema.json` |
| API changes | `docs/04-api/`, `openapi/`, `.claude/rules/api.md` |
| Database changes | `docs/03-data/`, `.claude/rules/data.md` |
| Agent/RAG changes | `docs/06-ai-agents-rag/`, `prompts/`, `.claude/rules/ai-agents.md` |
| MCP/integration changes | `docs/07-mcp-integrations/`, `mcp/` |
| Security changes | `docs/05-security-governance/`, `.claude/rules/security.md` |
| Infrastructure changes | `infra/`, `docs/01-architecture/deployment-architecture.md` |
| Configuration changes | `config/schemas/`, `config/defaults/`, relevant tenant/environment override |
| Frontend changes | `src/HrAutomation.Web/README.md`, `docs/01-architecture/frontend-architecture.md`, `docs/05-security-governance/frontend-security.md` |

## Non-Negotiable Rules

- Every sensitive employment decision requires explicit, logged human approval. AI may parse, summarize, recommend, draft, classify, route, and alert — it must never autonomously reject/select a candidate, issue an offer, decide salary, resolve a discrepancy, or create an Employee ID.
- Implement configuration-first: workflow stages, statuses, approval matrices, SLAs, matching weights, templates, checklists, retention, model settings, RAG parameters, and integration providers live in `config/`, never hardcoded.
- Enforce multi-tenant isolation on every data access path (tenant filter + row-level security), not client-supplied context alone.
- Never log or expose PII, secrets, raw CV/document content, full prompts, tokens, offer salary, or confidential interview feedback by default.
- Never execute an unsafe or unscoped tool call; every MCP tool call is least-privilege and schema-validated.
- Never use protected/irrelevant attributes (age, gender, religion, caste, disability, marital status, ethnicity, nationality, family status, photos) in candidate matching.
- Never bypass a defined workflow state transition or approval gate to "unblock" progress.
- Never make a direct change to a production environment without explicit, documented approval.

## Architecture Rules

- The relational database is the only system of record for workflow, approvals, offers, and employee data.
- The vector database is retrieval-only for approved content — never authoritative for workflow/business state.
- Object storage holds source documents; the database stores references, not raw bytes.
- APIs are contract-first: design in `openapi/`/`asyncapi/` before implementation.
- Use asynchronous events for side effects and cross-service propagation, not synchronous chains.
- Apply idempotency keys and optimistic concurrency on every mutating operation.
- Use the transactional outbox pattern for reliable integration events.
- Keep deterministic business/workflow state machines outside LLM logic; agents propose, the backend decides.

## AI and RAG Rules

- LLMs assist (extract, match, draft, summarize, route); they never make the final call on a sensitive action listed above.
- Every agent/skill output is validated against a strict JSON schema before use.
- Treat all CV, JD, email, calendar, document, and retrieved content as untrusted; defend against prompt injection.
- Use minimal necessary context and retrieval; avoid over-stuffing prompts.
- Apply metadata ACL filtering (tenant, classification, access policy) before vector search, never after.
- Policy-based answers require citations to retrieved sources or must return a no-answer fallback.
- Low-confidence or ambiguous outputs route to human review, never a silent best guess.
- Prompts and models are versioned; changes go through review and evaluation before promotion, with a rollback path.
- No prompt/model change ships without passing the evaluation suite in `evals/`.

## MCP and Tool Rules

- Every agent has an explicit tool allowlist per task; no tool call outside its declared scope.
- Each MCP server is independently authorized and credentialed; no shared static credentials.
- Every tool has an input/output JSON schema, validated before dispatch and after response.
- Sensitive writes (send offer, create HRMS record, provision access) require a confirmed prior human approval before the tool call is permitted.
- Every tool call has a timeout, bounded retries, and a circuit breaker.
- Every tool invocation is audit-logged, including denied attempts.
- Credentials are never exposed to agent/model context; they live in the secret vault only.

## API, Data, and Coding Rules

- APIs are versioned (URL path major version); breaking changes require a new version and deprecation plan.
- Every API change updates `openapi/`/`asyncapi/` in the same change.
- Errors follow RFC 7807 problem details; never leak PII or stack traces in a response.
- Every schema change is a migration with a rollback plan; no breaking schema/API change without an ADR.
- Add a test for every new or changed workflow state transition, including illegal-transition rejection.
- Every data query filters by tenant; add a cross-tenant isolation test for any new access path.

## Frontend Rules

- `HrAutomation.Web` is presentation only: it renders and guides, and never becomes the final authority on a business decision.
- The OpenAPI contract (`openapi/hr-onboarding-api.openapi.yaml`) is the source of truth; generate/use its types via `npm run api:generate` rather than hand-writing DTOs once the contract is available.
- No direct database access, and no reference to `HrAutomation.Domain/.Application/.Infrastructure/.Agents/.Rag/.Mcp` — HTTP calls to `HrAutomation.Api` only.
- No duplicated backend business rules: workflow-transition validation, approval enforcement, and authorization are re-implemented nowhere in the frontend; UI guards are UX only.
- No secrets, tokens, or PII in browser storage, source code, logs, or tests — see `src/lib/safeLogger.ts` and `docs/05-security-governance/frontend-security.md`.
- Strict TypeScript is mandatory (`tsconfig.app.json` `strict: true`); do not weaken it to unblock a change.
- Accessibility checks are mandatory: `eslint-plugin-jsx-a11y` on every lint, and an axe-core pass for any new candidate-facing screen.
- Sensitive actions (approve, send, resolve, convert) always call a backend approval-controlled endpoint behind an explicit confirmation dialog — never an optimistic update.
- Any new route requires: a permission policy (`PermissionRoute` if restricted), loading/error/empty states, tests, and a documentation update in the same change.

## Git Workflow

- Never commit secrets, tokens, or real candidate/employee data.
- Branches: `feature/<desc>`, `fix/<desc>`, `docs/<desc>`, `chore/<desc>`, `security/<desc>`.
- Commits follow Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `security:`.
- Keep commits small and focused; one logical change per commit.
- Update docs, contracts, and tests in the same PR as the code change — never as a follow-up.
- Never rewrite shared/published Git history (no force-push to shared branches, no history rewrite on `main`).
- Changes to `CLAUDE.md` or `.claude/rules/` require code review like any other change.

## Validation Commands

- Build backend: `dotnet build HrAutomation.slnx`
- Test backend: `dotnet test tests/HrAutomation.Tests/HrAutomation.Tests.csproj`
- Run API locally: `dotnet run --project src/HrAutomation.Api/HrAutomation.Api.csproj`
- Frontend install/dev: `cd src/HrAutomation.Web && npm install && npm run dev`
- Frontend typecheck/lint/test: `npm run typecheck` / `npm run lint` / `npm run test` (from `src/HrAutomation.Web`)
- Validate OpenAPI: `npm run api:validate` (from `src/HrAutomation.Web`)
- Validate config: `scripts/validate-config.sh` (or `.ps1`) — syntax-only unless `jsonschema` is installed for full schema conformance
- Run security scan: `[COMMAND_TO_RUN_SECURITY_SCAN]` — CI-only today, see `.github/workflows/security-scan.yml`; no local-equivalent command confirmed
- Run evaluations: `[COMMAND_TO_RUN_EVALUATIONS]` — no evaluation harness exists yet, see `docs/06-ai-agents-rag/ai-evaluation-strategy.md` and `evals/`

## Definition of Done

- Stated requirements are met and tests pass at the relevant levels.
- Authorization and tenant isolation checked for any new data/action path.
- Config schema and defaults updated for any new configurable value.
- API/event contracts updated to match implementation exactly.
- Relevant documentation updated in the same change.
- Audit logging and observability considered for any new sensitive action.
- No human-approval rule from this file has been weakened or bypassed.

## References

[docs/](docs/) · [config/](config/) · [openapi/](openapi/) · [asyncapi/](asyncapi/) · [prompts/](prompts/) · [evals/](evals/) · [mcp/](mcp/) · [.claude/rules/](.claude/rules/) · [src/HrAutomation.Web/README.md](src/HrAutomation.Web/README.md)
