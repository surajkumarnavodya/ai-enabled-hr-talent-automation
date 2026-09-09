# ADR-002: Deterministic Workflow Engine with Supervisor/Specialist Agent Orchestration

> Title: ADR-002 | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Accepted | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security, AI Governance

## Context

AI must assist (extract, match, draft, summarize, route) without ever autonomously performing a sensitive action (reject/select candidates, release offers, set compensation, close discrepancies, create Employee IDs). We need an orchestration pattern that makes this boundary structural, not just a prompt instruction.

## Decision

1. The **Workflow Engine** (part of HR Core API, backed by the relational system of record — [ADR-001](ADR-001-transactional-system-of-record.md)) owns all state transitions and is the only component that commits a workflow-state change. It is a plain deterministic state machine, not an LLM.
2. A **Supervisor Agent** routes tasks to **Specialist Skills** (CV extraction, candidate matching, offer drafting, verification assistance, interview-coordination drafting). Skills return structured, JSON-Schema-validated outputs (recommendations, drafts, extracted fields) — never a direct state mutation.
3. Every skill output that could lead to a sensitive action is routed back through the HR Core API's approval-matrix check ([human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md)) before any state transition is attempted.
4. Agents call external systems only via MCP tools, scoped least-privilege, with write actions to sensitive systems marked propose-only pending human confirmation (see [ADR-004](ADR-004-mcp-security-model.md)).

## Alternatives considered

1. **Single monolithic "autopilot" agent with tool access to commit state directly** — rejected: violates human-in-the-loop non-negotiable; no structural barrier against autonomous decisions.
2. **LLM-driven state machine (next-state decided by prompt)** — rejected: non-deterministic, hard to audit/version, fails "deterministic, validated, versioned" architecture principle.
3. **Fully separate, uncoordinated single-purpose scripts per skill** — rejected: loses the benefit of a consistent guardrail/observability layer (Supervisor provides one enforcement point).

## Consequences

- Positive: clear, auditable separation between "AI proposes" and "system/human decides"; easier to reason about failure modes; skills are independently testable and versionable.
- Negative: additional orchestration layer to build/operate; requires strict discipline that no skill is ever granted write scope to commit workflow state.

## Status

Accepted. Any future skill design must be reviewed against Section 5 of [CLAUDE.md](../../CLAUDE.md) before implementation.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
