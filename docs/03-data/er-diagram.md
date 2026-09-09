# Entity-Relationship Diagram

> Title: ER Diagram | Version: 1.1 | Owner: [TENANT_CONFIGURATION_REQUIRED — Data Architecture] | Status: Draft (original target-state baseline; superseded in part — see notice below) | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: DBA, Architecture, Security

> **Implementation reality notice (2026-09-08):** this diagram visualizes the original target-state design in [data-dictionary.md](data-dictionary.md), which does not match the real, implemented `HrAutomationDb` schema (243 tables, schema-qualified PascalCase, no single `TAN`/`APPROVAL`/`WORKFLOW_STATE_TRANSITION` entity). See the notice at the top of [data-dictionary.md](data-dictionary.md) for the specifics and [ADR-006](../adr/ADR-006-database-first-stored-procedure-workflow.md) for the reasoning. No ER diagram generated from the real schema exists yet — that is a `Planned` item.

## Purpose and scope

Visualizes the core entity relationships backing [sample-relational-schema.sql](sample-relational-schema.sql) and [data-dictionary.md](data-dictionary.md). This is a technical baseline, not a final physical design — requires DBA/security review before implementation.

## Diagram

```mermaid
erDiagram
    TENANT ||--o{ USER_ACCOUNT : has
    TENANT ||--o{ ROLE : defines
    USER_ACCOUNT }o--o{ ROLE : assigned

    TENANT ||--o{ CANDIDATE : owns
    CANDIDATE ||--o{ CV_DOCUMENT : has
    CANDIDATE ||--o{ CANDIDATE_HISTORY : audit

    TENANT ||--o{ TAN : owns
    TAN ||--o{ JD_VERSION : has
    TAN ||--o{ APPLICATION : receives

    CANDIDATE ||--o{ APPLICATION : submits
    APPLICATION ||--o{ MATCH_SCORE : scored_by
    APPLICATION ||--o{ INTERVIEW : has
    INTERVIEW ||--o{ INTERVIEW_FEEDBACK : produces
    APPLICATION ||--o| OFFER : results_in
    OFFER ||--o| GREEN_FORM : triggers
    GREEN_FORM ||--o{ CANDIDATE_DOCUMENT : collects
    GREEN_FORM ||--o{ EMPLOYMENT_HISTORY_ENTRY : collects
    GREEN_FORM ||--o{ EDUCATION_ENTRY : collects
    CANDIDATE_DOCUMENT ||--o{ VERIFICATION_RESULT : verified_by
    VERIFICATION_RESULT ||--o{ DISCREPANCY : may_raise
    DISCREPANCY ||--o| APPROVAL : closed_by

    APPLICATION ||--o{ APPROVAL : gated_by
    TAN ||--o{ APPROVAL : gated_by
    OFFER ||--o{ APPROVAL : gated_by

    APPLICATION ||--o{ WORKFLOW_STATE_TRANSITION : logs
    TAN ||--o{ WORKFLOW_STATE_TRANSITION : logs
    OFFER ||--o{ WORKFLOW_STATE_TRANSITION : logs

    APPLICATION ||--o| EMPLOYEE : converts_to
    TENANT ||--o{ EMPLOYEE : employs
    EMPLOYEE ||--|| EMPLOYEE_ID_REGISTRY : registered_in

    TENANT ||--o{ INTEGRATION_OUTBOX : emits
    TENANT ||--o{ AUDIT_LOG : records

    TENANT ||--o{ RAG_DOCUMENT : indexes
    RAG_DOCUMENT ||--o{ RAG_CHUNK : chunked_into

    TENANT ||--o{ MODEL_VERSION : configures
    TENANT ||--o{ PROMPT_VERSION : configures
    APPLICATION ||--o{ EVALUATION_RECORD : evaluated_by
```

## Notes

- All entities carry `tenant_id`, `id` (UUID), `created_at`, `created_by`, `updated_at`, `updated_by`, and most carry a `version` (optimistic concurrency) and `is_deleted` (soft delete) — see [data-dictionary.md](data-dictionary.md).
- `APPROVAL` is modeled as a first-class entity referenced by TAN, APPLICATION (shortlist/final selection), OFFER, and DISCREPANCY to give a single auditable approval trail (see [audit-log-specification.md](audit-log-specification.md)).
- `RAG_DOCUMENT`/`RAG_CHUNK` are logically separate from transactional entities and may live in a different physical store (vector store) — see [ADR-003](../adr/ADR-003-rag-and-vector-store-boundary.md).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
