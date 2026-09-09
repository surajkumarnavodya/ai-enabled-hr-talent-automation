# SLA and Escalation Rules

> Title: SLA and Escalation Rules | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — HR Operations] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: HR Operations, Product

## Purpose and scope

Defines default SLA targets per workflow stage and the escalation path when an SLA is breached. All values below are **configurable defaults** in `config/defaults/workflow.default.yaml`, overridable per tenant/business unit/grade.

## Default SLA targets (illustrative — [TENANT_CONFIGURATION_REQUIRED])

| Stage | SLA target | Escalation trigger | Escalates to |
|---|---|---|---|
| TAN approval | 2 business days | SLA breached | Requester's manager + HR Approver reminder |
| AI matching to recommendation review | 1 business day | SLA breached | Recruiter reminder |
| Shortlist approval | 2 business days | SLA breached | HR Approver's manager |
| Interview scheduling | 3 business days from shortlist approval | No slot confirmed | Recruiter + Hiring Manager reminder |
| Interview feedback submission | 1 business day post-interview | Feedback missing | Panelist reminder, then recruiter escalation |
| Final selection approval | 3 business days | SLA breached | HR Approver's manager |
| Offer approval | 2 business days | SLA breached | HR Approver's manager |
| Candidate offer response | Configurable per offer (default 5 business days) | Expiry | Auto-transition to `Expired`, notify recruiter |
| Green Form submission | 7 calendar days from issuance | Expiry | Reminder at day 3 and day 6, then recruiter escalation |
| Verification turnaround | 3 business days | SLA breached | HR Operations lead |
| Discrepancy re-upload window | 5 calendar days per request, max 3 cycles (configurable) | Max cycles exceeded | Auto-escalate to HR Approver for exception decision |
| Employee conversion approval | 2 business days after gate check passes | SLA breached | HR Approver's manager |

## Escalation mechanics

1. Each SLA is tracked as a timer attached to the relevant workflow state (see [workflow-state-machine.md](workflow-state-machine.md)).
2. Breach triggers a notification per [notification-catalog.md](notification-catalog.md), not an automatic state change (except explicitly listed auto-transitions like offer expiry).
3. Repeated breach (configurable threshold) triggers escalation to the next role in the tenant's escalation chain (`config/tenants/sample-tenant.yaml`).
4. All escalations are logged for reporting (see [metrics-slos-and-alerts.md](../08-operations-observability/metrics-slos-and-alerts.md)).

## Configurable items

SLA durations, business-day calendars, reminder cadence, max discrepancy cycles, and escalation chains are all tenant-configurable. Defaults must remain conservative (i.e., not silently auto-approve or auto-reject on breach).

## Risks and open questions

- Whether SLA breach on discrepancy cycles should ever auto-close a discrepancy: **no** — always requires HR approval per [human-approval-matrix.md](human-approval-matrix.md); breach only forces escalation, never auto-resolution.
- Regional holiday calendars for business-day calculation — [TENANT_CONFIGURATION_REQUIRED].

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
