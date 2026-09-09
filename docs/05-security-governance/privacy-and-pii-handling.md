# Privacy and PII Handling

> Title: Privacy and PII Handling | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Privacy/Compliance] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Legal, Security, HR

## Purpose and scope

Defines how candidate and employee PII is minimized, protected, and handled throughout the workflow. Legal requirements referenced here are placeholders — [LEGAL_REVIEW_REQUIRED] before go-live.

## Data minimization principles

- Collect only fields required for the current workflow stage (e.g., do not collect education details before an offer is accepted).
- AI extraction fields are limited to job-relevant data; protected characteristics are never extracted or inferred (see [fairness-and-bias-governance.md](fairness-and-bias-governance.md)).
- Notifications and logs include only the minimum identifying information needed for the recipient's action (see [notification-catalog.md](../02-business-workflows/notification-catalog.md), [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)).

## PII inventory (illustrative — not exhaustive)

| Field category | Examples | Classification | Encryption |
|---|---|---|---|
| Contact PII | Name, email, phone | Confidential | Column-level encryption at rest |
| Identity documents | Government ID numbers | Restricted | Column-level encryption, restricted access role |
| Employment/education history | Prior employer, dates, qualifications | Confidential | Standard at-rest encryption |
| Interview feedback | Panelist notes/scores | Confidential | Standard at-rest encryption, access limited to recruiter/HR |
| Compensation | Offer compensation reference | Confidential/Restricted | Referenced by ID only, never stored as platform-native free text |

## Mandatory redaction approach

- PII is redacted before being written to logs, traces, or notification templates by default (see [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)).
- AI outputs (e.g., match rationale) reference candidates by ID in system telemetry; display of names is confined to authorized UI contexts, not telemetry/logs.
- Documents are never embedded into the RAG vector store by default (see [ADR-003](../adr/ADR-003-rag-and-vector-store-boundary.md)).

## Data subject rights

Process for access, correction, and erasure requests is [LEGAL_REVIEW_REQUIRED]. At minimum, the platform must support: locating all records for a data subject across entities (candidate, application, interview feedback, Green Form, documents), and executing a deletion or anonymization consistent with [data-classification-and-retention.md](../03-data/data-classification-and-retention.md) and any active legal hold.

## Cross-border data transfer

Data residency and cross-border transfer constraints are [LEGAL_REVIEW_REQUIRED] and [TENANT_CONFIGURATION_REQUIRED] per deployment region.

## Consent and notice

Candidate-facing notice of data collection/processing purpose is [LEGAL_REVIEW_REQUIRED] content, to be surfaced at CV submission and Green Form issuance.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
