# Project Structure

> Status: Reconciled against the real repository (2026-09-08) — the tree below is the actual current layout, not a target scaffold. See [PROJECT_STATUS.md](PROJECT_STATUS.md) for what's implemented within it.

## Table of contents

1. [Purpose](#purpose)
2. [Full directory tree](#full-directory-tree)
3. [Folder responsibilities](#folder-responsibilities)
4. [Where responsibilities belong](#where-responsibilities-belong)
5. [What must not be placed where](#what-must-not-be-placed-where)
6. [Ownership recommendations](#ownership-recommendations)
7. [Dependency direction](#dependency-direction)
8. [Agents must not bypass backend rules](#agents-must-not-bypass-backend-rules)
9. [Superseded original plan](#superseded-original-plan)
10. [Future implementation order](#future-implementation-order)

## Purpose

Describes the real repository layout, what belongs where, and the dependency direction between layers, so that new work lands in the right place.

## Full directory tree

```
/
├── CLAUDE.md, README.md, PROJECT_STRUCTURE.md, NEXT_STEPS.md
├── PROJECT_STATUS.md, DECISIONS_REQUIRED.md, CHANGELOG.md
├── CONTRIBUTING.md, SECURITY.md, LICENSE
├── .gitignore, .gitattributes, .editorconfig, .env.example
├── docker-compose.yml, Makefile
├── global.json, Directory.Build.props, Directory.Packages.props, HrAutomation.slnx
├── .github/                    # CI/CD workflows, issue/PR templates, CODEOWNERS
├── .claude/                    # Shared Claude Code rules, commands, skills
├── docs/                       # Product, architecture, workflow, data, security, AI, MCP, ops, quality, delivery docs + ADRs
├── config/                     # Schemas, defaults, environment/tenant overrides, feature flags
├── openapi/                    # REST API contracts
├── asyncapi/                   # Event contracts
├── mcp/                        # MCP server manifests, tool schemas, integration docs (no real MCP server implementation yet)
├── prompts/                    # Agent system prompts, evaluation and red-team prompts
├── evals/                      # Evaluation datasets, cases, rubrics, reports (no evaluation harness yet)
├── infra/                      # Docker, Kubernetes, Terraform, operational scripts (not populated for this stack yet)
├── scripts/                    # Bootstrap and config-validation scripts
├── src/
│   ├── HrAutomation.Domain/          # Entities, enums — no dependencies on other layers
│   ├── HrAutomation.Application/     # Use-case contracts, guardrail/approval/skill/orchestration interfaces
│   ├── HrAutomation.Infrastructure/  # EF Core persistence (HrAutomationDbContext), audit/approval-gate implementations,
│   │                                 #   and Database/ — the hand-written, database-first SQL Server DDL/seed/tests for
│   │                                 #   HrAutomationDb (scripts/, seed/, tests/, publish/, migrations/, docs/ [empty])
│   ├── HrAutomation.Agents/          # ISkill implementations: real (CV ingestion, TAN create/approve) + Stubs/ (everything else)
│   ├── HrAutomation.Rag/             # Policy/document retrieval skill — empty scaffold, no real pipeline yet
│   ├── HrAutomation.Mcp/             # MCP tool implementations — empty scaffold, no real server yet
│   ├── HrAutomation.Api/             # ASP.NET Core REST API — the only integration point for the frontend
│   └── HrAutomation.Web/             # React + TypeScript presentation layer (real, running; currently mock-API mode only)
└── tests/
    └── HrAutomation.Tests/           # xUnit integration tests, run against a real HrAutomationDb instance
```

## Folder responsibilities

| Folder | Responsibility |
|---|---|
| `docs/` | Approved documentation and ADRs — the source of truth for intent and decisions |
| `config/` | Non-secret, versioned configuration and its JSON schemas |
| `openapi/` / `asyncapi/` | Machine-readable API/event contracts |
| `mcp/` | Tool schemas and server manifests for external-system access (docs/schemas only — no server implementation yet, see `src/HrAutomation.Mcp/`) |
| `prompts/` | Versioned, approved prompt templates |
| `evals/` | Evaluation assets — sanitized/de-identified only |
| `src/HrAutomation.Domain/` | Core entities/enums — no dependency on any other project |
| `src/HrAutomation.Application/` | Use-case contracts: `ISkill`, `IWorkflowOrchestrator`, `IApprovalGateService`, `IGuardrailPipeline`, DTOs |
| `src/HrAutomation.Infrastructure/` | EF Core persistence, audit/approval-gate implementations, and the real database (`Database/` subfolder) |
| `src/HrAutomation.Agents/` | AI skill implementations — advisory only, never commits workflow state itself |
| `src/HrAutomation.Rag/` | Retrieval-only content access for AI grounding (not yet implemented) |
| `src/HrAutomation.Mcp/` | External-system tool servers, least-privilege (not yet implemented) |
| `src/HrAutomation.Api/` | API surface, authentication/authorization, guardrail/orchestrator composition |
| `src/HrAutomation.Web/` | User-facing web application — HTTP calls to `HrAutomation.Api` only |
| `tests/HrAutomation.Tests/` | Integration tests against a real `HrAutomationDb` instance, synthetic data only |
| `infra/` | Infrastructure as code and operational scripts (placeholder — not populated for this stack) |

## Where responsibilities belong

- Deterministic workflow/approval logic → stored procedures in `src/HrAutomation.Infrastructure/Database/scripts/` plus `HrAutomation.Application`'s orchestration contracts — never `HrAutomation.Agents`. See [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md) for why there's no generic workflow-engine table.
- AI extraction/matching/drafting logic → `HrAutomation.Agents`, calling `HrAutomation.Infrastructure`'s stored procedures/EF Core for anything state-changing.
- External system calls → future MCP servers in `HrAutomation.Mcp`, described by manifests in `mcp/` (not yet built).
- Cross-cutting types/contracts used by more than one layer → `HrAutomation.Application` or `HrAutomation.Domain`, not duplicated per layer.

## What must not be placed where

- No production secrets or credentials anywhere in `src/`, `config/`, `mcp/`, or `tests/`.
- No real candidate/employee data anywhere in the repository, including tests, prompts, and evaluation datasets.
- No direct database access from `HrAutomation.Web` — HTTP calls to `HrAutomation.Api` only.
- No deterministic employment-decision logic in `HrAutomation.Agents`.
- No infrastructure state files or environment-specific production credentials in `infra/`.

## Ownership recommendations

| Area | Recommended owner |
|---|---|
| `src/HrAutomation.Web/` | Frontend engineering |
| `src/HrAutomation.Api/`, `.Application/`, `.Infrastructure/` | Backend/platform engineering |
| `src/HrAutomation.Infrastructure/Database/` | Backend/platform engineering, with DBA review per change |
| `src/HrAutomation.Agents/`, `prompts/`, `evals/` | AI/ML engineering, with AI governance sign-off |
| `src/HrAutomation.Mcp/`, `mcp/` | Integration engineering |
| `config/` | Platform engineering, changes reviewed by the relevant domain owner (HR, Security) |
| `infra/` | DevOps/SRE |
| `docs/`, `docs/adr/` | Architecture, with domain owners contributing |
| `tests/` | Owned jointly by the layer's engineering team and QA |

## Dependency direction

```
HrAutomation.Web          → HrAutomation.Api (HTTP only)
HrAutomation.Api          → HrAutomation.Application, .Infrastructure, .Agents, .Rag, .Mcp (composition root)
HrAutomation.Agents       → HrAutomation.Application (contracts), .Infrastructure (persistence/stored procs)
HrAutomation.Infrastructure → HrAutomation.Application, .Domain
HrAutomation.Application  → HrAutomation.Domain only
HrAutomation.Domain       → nothing
tests                     → all implementation layers (never the reverse)
```

## Agents must not bypass backend rules

Skill code in `HrAutomation.Agents` must never implement its own copy of workflow-state, approval, or employment-decision logic. Deterministic transition rules live in the database's stored procedures ([ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md)); skills call them and respect whatever result comes back, including rejections (`Success = false`, `ErrorCode`).

## Superseded original plan

An earlier version of this document described a different, not-yet-realized target layout: `src/frontend/`, `src/backend/`, `src/agents/` (Python/LangGraph or Semantic Kernel), `src/shared/`, `src/integration-adapters/`. That plan was never built — the real implementation went a different direction (one .NET solution, C# agent skills inside `HrAutomation.Agents`, no separate Python agent service, no `src/shared`/`src/integration-adapters` folders). This section exists only so old references to those paths elsewhere in the repo aren't mistaken for real, current folders — do not create them without a new ADR superseding this decision.

## Future implementation order

1. ~~Documentation and configuration.~~ Done (this package), with known drift now called out inline — see [PROJECT_STATUS.md](PROJECT_STATUS.md).
2. ~~API contracts and data model (first slice).~~ Done for CV ingestion and TAN — `openapi/hr-onboarding-api.openapi.yaml` and `HrAutomationDb`.
3. ~~Authentication/authorization and tenant foundation.~~ Done server-side (JWT dev-token issuance, RLS via `SESSION_CONTEXT`); no real frontend auth provider yet.
4. ~~TAN and candidate workflow (CV ingestion, TAN create/approve).~~ Done.
5. Remaining candidate workflow: matching, shortlist approval.
6. Interview scheduling and feedback.
7. Offer, Green Form, verification, discrepancy management.
8. Employee conversion and downstream integrations.
9. AI matching/RAG/MCP integrations (`HrAutomation.Rag`, `HrAutomation.Mcp` currently empty).
10. Frontend wired to the real API (real auth provider, MSW mock mode turned off for non-local environments).
11. Evaluation, hardening, and production readiness.

## Related documents

[README.md](README.md) · [PROJECT_STATUS.md](PROJECT_STATUS.md) · [NEXT_STEPS.md](NEXT_STEPS.md) · [CLAUDE.md](CLAUDE.md) · [docs/01-architecture/](docs/01-architecture/) · [ADR-006](docs/adr/ADR-006-database-first-stored-procedure-workflow.md)
