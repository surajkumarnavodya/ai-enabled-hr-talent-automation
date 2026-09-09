# Rule: Architecture

- Read [docs/01-architecture/solution-architecture.md](../../docs/01-architecture/solution-architecture.md) and relevant ADRs under `docs/adr/` before proposing or implementing any structural change.
- The relational database is the only system of record for workflow, approvals, offers, and employee data. Never propose the vector store, cache, or any derived store as authoritative for these — see [ADR-001](../../docs/adr/ADR-001-transactional-system-of-record.md) and [ADR-003](../../docs/adr/ADR-003-rag-and-vector-store-boundary.md).
- Keep deterministic workflow-transition logic outside any LLM/agent code path — see [ADR-002](../../docs/adr/ADR-002-agent-orchestration-pattern.md) for the principle and [ADR-006](../../docs/adr/ADR-006-database-first-stored-procedure-workflow.md) for how it's actually implemented (per-entity status column + stored procedure per transition, not a generic workflow-engine table).
- Before assuming a component described in `docs/01-architecture/solution-architecture.md` exists as a separate service, check [PROJECT_STATUS.md](../../PROJECT_STATUS.md) — most of that document is still target-state; the real system is one .NET solution plus the React frontend.
- All external system access goes through an isolated, authenticated MCP server — never a direct SDK call from agent code. See [ADR-004](../../docs/adr/ADR-004-mcp-security-model.md).
- Any technology choice not already fixed by an ADR is configuration, not a hard dependency — check [docs/01-architecture/technology-selection-matrix.md](../../docs/01-architecture/technology-selection-matrix.md) before assuming a specific vendor/library is mandatory.
- A new architectural decision (new bounded context, new sync/async choice, new resilience pattern) requires a new or updated ADR in the same change — do not leave architecture decisions undocumented.
- Avoid broad, unrelated refactoring when making a targeted change; match the scope of the request.
