# ADR-006: Database-First Schema with Per-Entity Status and Stored-Procedure-Owned Transitions

> Title: ADR-006 | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Accepted | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, DBA, Security

## Context

[ADR-001](ADR-001-transactional-system-of-record.md) establishes the relational database as the system of record, and [ADR-002](ADR-002-agent-orchestration-pattern.md) establishes that a deterministic mechanism — never an LLM — owns workflow-state transitions. Neither ADR mandates *how* that deterministic mechanism is implemented. The original target-state design (see [docs/03-data/data-dictionary.md](../03-data/data-dictionary.md) and [docs/02-business-workflows/workflow-state-machine.md](../02-business-workflows/workflow-state-machine.md), both written before implementation began) assumed a generic `workflow_state_transition` table and a single application-layer "Workflow Engine" component that would validate and apply every transition for every entity type through one shared code path.

When the real database (`HrAutomationDb`, SQL Server) was implemented, no generic workflow-engine table was built. Instead, each business entity carries its own status column (e.g. `recruitment.JobRequisition.RequisitionStatusCode`), and each state-changing business action has a dedicated stored procedure (e.g. `recruitment.usp_SubmitJobRequisitionForApproval`, `usp_ApproveJobRequisition`, `usp_RejectJobRequisition`) that validates the current status, applies the transition, writes the status-history row, and writes the audit event — all in one atomic transaction. Approval gating is a separate, reusable set of tables (`workflow.ApprovalRequest`/`ApprovalStep`/`ApprovalDecision`) keyed by `EntityType`/`EntityId` against whatever entity they gate, rather than a single polymorphic `approval` table.

This ADR records that divergence as a deliberate decision, not an oversight, so future work (and future Claude Code sessions) build on the real mechanism rather than the original generic-engine design.

## Decision

1. There is no generic, cross-entity workflow-state-machine table or engine. Each entity's valid states and valid transitions are expressed as: a status column with a `CHECK` constraint or reference-table lookup, plus one stored procedure per transition that enforces the current-status precondition before writing the new status.
2. Approval gating is a shared, reusable subsystem (`workflow.ApprovalRequest`/`ApprovalStep`/`ApprovalDecision`, driven by `ref.ApprovalMatrix`/`ApprovalMatrixRule`), not a shared *state machine* — it does not itself decide what the "next state" of an entity is; the entity's own procedures do that, consulting an approval request's status where a gate applies.
3. The C# application layer's job for a gated action is: run guardrails, check the current approval-gate status (`IApprovalGateService`) if the action requires a prior approval to already exist, call the one stored procedure that performs the action, and write an audit event. It does not itself validate transition legality — the stored procedure is the authority and returns a structured `Success`/`ErrorCode` result if the transition is invalid (e.g. `INVALID_TRANSITION`).
4. The `HrAutomation.Application.Orchestration.IWorkflowOrchestrator` interface is retained as the API-layer's guardrail/approval-gate/audit coordination point, but it does not load or own a `WorkflowInstance` row — see its class-level doc comment in `HrAutomation.Agents/Orchestration/WorkflowOrchestrator.cs`.
5. Every RLS-protected table's stored procedure sets `SESSION_CONTEXT('TenantId')` on its own connection defensively (each procedure is independently callable, e.g. by a DBA script, outside a fully-authorized API request). The API also sets it once per HTTP request via `TenantSessionContextMiddleware`, since a plain EF Core read/write that never calls a stored procedure would otherwise see zero rows under the row-level-security filter predicate.

## Alternatives considered

1. **Build the originally-designed generic `workflow_state_transition` engine** — rejected for this phase: a fully generic, config-driven transition table adds real complexity (a rules interpreter, generic validation) for a benefit (uniformity across entity types) that hasn't yet been needed across the two entity types actually implemented (Candidate, JobRequisition/TAN). Revisit once 3+ entity types need transition logic, per [DECISIONS_REQUIRED.md](../../DECISIONS_REQUIRED.md).
2. **Keep transition validation in C# (a `WorkflowStateMachine` class), persistence in the database** — rejected: this was the original code-first (`HrDbContext`) approach and was retired this session in favor of database-first; keeping business-rule validation in two places (C# and stored procedures) risks drift, and [ADR-001](ADR-001-transactional-system-of-record.md) already establishes the database as authoritative for workflow state.

## Consequences

- Positive: each entity's transition rules are atomic with the write (no read-modify-write race between a C# check and a database write); the stored procedure is independently testable and callable outside the API; RLS and audit are enforced at the same boundary as the state change.
- Positive: adding a new entity's workflow does not require touching a shared, increasingly complex generic engine.
- Negative: no single place lists "every valid transition for every entity" the way a generic table would — this ADR and each procedure's own precondition checks are the source of truth instead. `docs/03-data/data-dictionary.md`, `er-diagram.md`, and `docs/02-business-workflows/workflow-state-machine.md` still describe the original generic design and are marked as target-state/superseded-in-part pending a rewrite from the real schema.
- Negative: `docs/06-ai-agents-rag/agent-skill-catalog.md` and related docs must be kept in sync by hand with which skills call which procedures, since there's no generic catalog to introspect.

## Status

Accepted, reflecting the implementation as built for the Candidate and TAN/JobRequisition flows. Applying the same pattern to interviews, offers, Green Form/onboarding, discrepancies, and employee conversion (all currently unimplemented stub skills) is the expected default for future work unless a specific case demonstrates a real need for a generic engine — see [DECISIONS_REQUIRED.md](../../DECISIONS_REQUIRED.md).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | Documentation reconciliation pass | Initial creation, recording the database-first divergence from the original target-state workflow-engine design |
