# adr/ — Architecture Decision Records

**Purpose:** Immutable log of significant architectural decisions, their context, alternatives considered, and consequences.

**What belongs here:** One file per decision, named `ADR-{NNN}-{kebab-case-title}.md`, following [ADR-000-template.md](ADR-000-template.md). Use the `/create-adr` command to scaffold a new one correctly.

**What must not be stored here:** Reversible/tactical decisions that don't affect architecture boundaries (use a regular doc or PR description instead), real data of any kind.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Architecture]

**Main dependencies:** Referenced from `docs/01-architecture/`, `.claude/rules/architecture.md`, and `.claude/commands/create-adr.md`.

**Existing ADRs:** ADR-001 (transactional system of record) · ADR-002 (agent orchestration pattern) · ADR-003 (RAG/vector store boundary) · ADR-004 (MCP security model) · ADR-005 (observability strategy) · ADR-006 (database-first schema, per-entity status, stored-procedure-owned transitions)

**Rule:** Never delete or edit history out of an accepted ADR to reverse a decision — mark its Status as "Superseded by ADR-{NNN}" and create a new one.

**Status:** ADR-001–005 are target-state decisions recorded before implementation began. ADR-006 records a real, implemented divergence from the original workflow-engine design in ADR-002/docs/02-business-workflows/workflow-state-machine.md — see its Context section. Treat ADR-006 as the more current source for how workflow-state transitions actually work today.
