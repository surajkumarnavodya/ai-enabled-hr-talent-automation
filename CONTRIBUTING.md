# Contributing

> Status: Reconciled against real implementation (2026-09-08) — commands below are verified, not placeholders.

## Prerequisites

- .NET SDK matching `global.json` (backend: `HrAutomation.Domain/.Application/.Infrastructure/.Agents/.Api/.Rag/.Mcp` + `tests/HrAutomation.Tests`)
- Node.js 24+ (frontend: `src/HrAutomation.Web` — see its `.nvmrc`)
- SQL Server or SQL Server LocalDB (the real database, `HrAutomationDb`, is SQL Server-only — see [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md))
- Docker, only once `docker-compose.yml` is populated for this stack — it currently targets a different, not-yet-adopted Postgres-based layout; see `DECISIONS_REQUIRED.md`
- Access to a local `.env` copied from `.env.example` (never commit `.env`)

## Branch naming

- `feature/<short-description>`
- `fix/<short-description>`
- `docs/<short-description>`
- `chore/<short-description>`
- `security/<short-description>`

## Commit format (Conventional Commits)

`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `security:` — e.g. `feat: add TAN approval endpoint`.

## Required checks before opening a pull request

- Build passes: `dotnet build HrAutomation.slnx`
- Backend/agent tests pass: `dotnet test tests/HrAutomation.Tests/HrAutomation.Tests.csproj` (runs against a real `HrAutomationDb` instance — see [src/HrAutomation.Infrastructure/Database/](src/HrAutomation.Infrastructure/Database/) for how to deploy one locally)
- Frontend checks pass: `npm run typecheck && npm run lint && npm run test` (from `src/HrAutomation.Web`)
- OpenAPI validated if contracts changed: `npm run api:validate` (from `src/HrAutomation.Web`)
- Configuration validated against its schema if changed: `scripts/validate-config.sh` (or `.ps1`)
- No secrets, real candidate/employee data, or production endpoints introduced

## Pull request requirements

- Small, focused change with a clear description of intent.
- Linked issue/requirement where applicable.
- Documentation, contracts, and tests updated in the same PR as the code — not deferred.
- Any new sensitive action maps to an approval gate, audit event, and authorization check.
- Any new configurable value has a schema entry and a safe default.
- ADR added/updated for any architectural decision.

## Documentation update expectations

If behavior changes, update the relevant page(s) under `docs/`, the ADR log if a decision changed, and `GENERATED_FILES.md`/`PROJECT_STRUCTURE.md` if the file tree changed.

## Secure coding expectations

Follow `.claude/rules/security.md` and `docs/05-security-governance/`: no PII/secrets in logs, no unvalidated tool calls, tenant isolation on every data path, least-privilege by default.

## Configuration-change process

Configuration changes touch the schema (`config/schemas/`), the default (`config/defaults/`), and — if tenant/environment-specific — the relevant override file, in the same change. Never edit a value only in one place.

## ADR creation criteria

Create an ADR (`/create-adr` or see `docs/adr/README.md`) for: a new bounded context or service boundary, a new sync/async or resilience pattern, a change to the approval-matrix enforcement model, a new external system integration pattern, or a change to the AI/RAG/MCP security boundary.

## Data handling

Do not use real candidate/employee data in source control, examples, tests, prompts, evaluation datasets, or screenshots — fake/demo data only.

## Related documents

[SECURITY.md](SECURITY.md) · [CLAUDE.md](CLAUDE.md) · [PROJECT_STATUS.md](PROJECT_STATUS.md) · [.claude/rules/git-workflow.md](.claude/rules/git-workflow.md) · [docs/09-quality-evaluation/test-strategy.md](docs/09-quality-evaluation/test-strategy.md)
