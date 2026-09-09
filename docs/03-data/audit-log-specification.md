# Audit Log Specification

> Title: Audit Log Specification | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Security Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Security, Compliance, Architecture

## Purpose and scope

Defines the structure, coverage, and integrity requirements for the audit log — the authoritative record of who (or what) did what, when, to which entity, and under what approval. Supports [incident-response-runbook.md](../05-security-governance/incident-response-runbook.md) and [compliance-review-checklist.md](../05-security-governance/compliance-review-checklist.md).

## Coverage — mandatory audit events

| Category | Examples |
|---|---|
| Authentication/authorization | Login, token issuance, permission denial |
| Workflow state transitions | Every transition in [workflow-state-machine.md](../02-business-workflows/workflow-state-machine.md) |
| Approvals | Every decision recorded in [human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md) |
| AI actions | Every skill invocation (extraction, matching, drafting), including model/prompt version and confidence |
| Data access | Access to Confidential/Restricted-classified records (read, not just write) |
| Configuration changes | Any change to workflow config, approval matrix, RAG config, model routing |
| Integration calls | Every MCP tool invocation, including outcome |
| Security events | Guardrail triggers, prompt-injection flags, cross-tenant access denials |

## Record structure

| Field | Description |
|---|---|
| `id` | Unique audit record ID |
| `tenant_id` | Tenant scope |
| `occurred_at` | UTC timestamp |
| `actor_type` | `human` \| `agent` \| `system` |
| `actor_id` | User ID, agent/skill identifier, or system principal |
| `action` | Canonical action name (e.g., `tan.approve`, `offer.send`) |
| `subject_type` / `subject_id` | Entity acted upon |
| `approval_id` | Linked approval record, if applicable |
| `outcome` | `success` \| `denied` \| `error` |
| `metadata` | Structured, **redacted** context (no raw PII/documents/secrets — see [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)) |
| `correlation_id` | Ties the record to the originating request/trace |

## Integrity requirements

- Audit records are **append-only**; no update or delete API exists for audit records (exception: retention/legal-hold-driven purge per policy, itself logged).
- Written in the **same database transaction** as the state change it records (see [ADR-001](../adr/ADR-001-transactional-system-of-record.md)) — a state change without a corresponding audit record must not be possible.
- Tamper-evidence: [TENANT_CONFIGURATION_REQUIRED — e.g., periodic hash-chaining or WORM storage export] for high-assurance tenants.

## Query and retention

Audit logs are queryable via the `GET /audit-log` API ([rest-api-catalog.md](../04-api/rest-api-catalog.md)), scoped by RBAC to `compliance_reviewer` and `hr_approver` roles. Retention is generally longer than operational data retention — see [data-classification-and-retention.md](data-classification-and-retention.md).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
