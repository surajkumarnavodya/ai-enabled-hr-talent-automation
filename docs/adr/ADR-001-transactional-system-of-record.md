# ADR-001: Relational Database as the Transactional System of Record

> Title: ADR-001 | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Accepted | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security

## Context

The platform must guarantee that workflow status, approval history, offers, Green Form data, and employee records are consistent, auditable, and never lost — including under concurrent access and partial failures. It also uses a vector store for RAG retrieval, which raises the question of which store is authoritative.

## Decision

A relational database (PostgreSQL or SQL Server — see [technology-selection-matrix.md](../01-architecture/technology-selection-matrix.md)) is the **single system of record** for all transactional HR data: tenants, users/roles (reference), candidates, TANs, applications, interviews, offers, Green Form submissions, documents metadata, verification/discrepancy records, approvals, workflow state transitions, employee master, and audit logs. All writes to these entities go through ACID transactions. The transactional outbox pattern is used to publish events derived from these writes (see [ADR-002](ADR-002-agent-orchestration-pattern.md) note on agent state, and [integration-architecture.md](../01-architecture/integration-architecture.md)).

## Alternatives considered

1. **Event-sourced system of record** — rejected for v1: higher implementation complexity than needed; relational CRUD + audit log meets auditability needs with lower risk.
2. **Document database (e.g., MongoDB) as system of record** — rejected: weaker native support for ACID multi-entity transactions and relational integrity constraints needed for approval-gate enforcement.
3. **Vector store as a secondary system of record for candidate/JD data** — explicitly rejected; see [ADR-003](ADR-003-rag-and-vector-store-boundary.md).

## Consequences

- Positive: strong consistency, mature tooling for migrations/backup/row-level security, straightforward auditability.
- Negative: relational schema changes require migration discipline (see [database-migration-strategy.md](../03-data/database-migration-strategy.md)); horizontal write scaling is bounded by the primary instance per tenant-isolation model.
- Vector store must never be queried as the source of truth for any approval, offer, or employee-status decision — enforced by code review and this ADR.

## Status

Accepted. Superseding this decision (e.g., moving to event sourcing) requires a new ADR and a data-migration plan.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
