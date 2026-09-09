# Data Quality Rules

> Title: Data Quality Rules | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Data Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, HR Operations

## Purpose and scope

Defines validation and quality rules applied at ingestion and throughout the workflow, to keep matching, verification, and reporting reliable.

## Rules by entity

| Entity | Rule | Enforcement point | On failure |
|---|---|---|---|
| Candidate | Deduplication: match on configurable composite key (email + phone + name-similarity threshold) | CV ingestion | Flag as possible duplicate, route to manual review |
| CV extraction | Mandatory fields (name, contact, experience summary) must be present with confidence ≥ configurable threshold | Post-extraction | Route to manual-review queue, block matching eligibility until reviewed |
| JD / TAN | Mandatory criteria must be explicit and machine-checkable (not free text only) | TAN creation | Block TAN approval submission until criteria structured |
| Match score | Score must include rationale referencing specific JD criteria | Matching skill output validation | Reject skill output, retry or route to human review |
| Interview feedback | Structured outcome field required; free text alone is insufficient | Feedback submission | Block submission until structured fields completed |
| Offer | Compensation value must reference an external comp-system record, not free text entry | Offer drafting | Block offer generation |
| Green Form documents | File type/size within configured checklist; required documents present before verification starts | Green Form submission | Block submission, prompt candidate for missing items |
| Verification | Cross-check document-derived data against Green Form self-reported data | Verification skill | Discrepancy raised if mismatch exceeds configurable tolerance |
| Employee conversion | All gate-checklist items must independently resolve to "pass" | Conversion gate | Block conversion, route to remediation |

## Data quality monitoring

Quality metrics (extraction confidence distribution, duplicate rate, discrepancy rate, gate-check failure rate) are tracked per [metrics-slos-and-alerts.md](../08-operations-observability/metrics-slos-and-alerts.md) and reviewed on a configurable cadence.

## Configurable items

Confidence thresholds, dedup matching sensitivity, tolerance for verification mismatches, and required-field lists are all tenant-configurable.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
