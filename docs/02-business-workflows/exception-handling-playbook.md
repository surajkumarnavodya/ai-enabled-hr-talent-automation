# Exception Handling Playbook

> Title: Exception Handling Playbook | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — HR Operations] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: HR Operations, Security, Compliance

## Purpose and scope

Defines how the platform handles exceptions to the normal workflow: stalled approvals, expired offers, failed integrations, duplicate candidates, ambiguous AI extraction, and discrepancy exceptions. Complements [sla-escalation-rules.md](sla-escalation-rules.md) (timing) and [incident-response-runbook.md](../05-security-governance/incident-response-runbook.md) (security incidents).

## Exception catalog

| Exception | Detection | Immediate system action | Human action required |
|---|---|---|---|
| Duplicate candidate detected on CV upload | Dedup rule match ≥ configurable threshold | Flag as "possible duplicate," do not auto-merge | Recruiter confirms merge or keeps separate |
| Low-confidence CV field extraction | Extraction confidence < configurable threshold | Route to manual review queue | Recruiter corrects fields before candidate enters matching pool |
| AI match score below mandatory threshold for all candidates | Matching run completes with 0 qualifying candidates | Notify recruiter; suggest broadening JD criteria (never lowers mandatory criteria automatically) | Recruiter/Hiring Manager decides next step |
| Offer expires unaccepted | SLA timer | Auto-transition to `Expired`, notify recruiter | Recruiter decides whether to re-offer or close |
| Green Form link expires | SLA timer | Deactivate link | HR Operations decides whether to reissue |
| Discrepancy re-upload cycles exceed configured max | Cycle counter | Auto-escalate to HR Approver | HR Approver decides: extend, grant exception, or close candidate |
| Discrepancy exception requested | HR Operations flags | Draft rationale (AI-assisted) held for approval | HR Approver approves/rejects exception — **never automatic** |
| MCP tool/integration failure (e.g., calendar unavailable) | Circuit breaker trips | Retry per policy, then queue to dead-letter | Recruiter notified to schedule manually if breaker stays open beyond threshold |
| Downstream integration failure post-employee-creation | Event delivery failure | Retry with backoff, then dead-letter + alert | Integration engineer investigates; Employee ID record is unaffected (already committed) |
| Suspected prompt injection in CV/JD/feedback content | Guardrail pipeline flag | Quarantine content, do not pass to downstream model calls | Security/compliance reviewer investigates per [prompt-injection-defense.md](../05-security-governance/prompt-injection-defense.md) |
| Cross-tenant data access attempt | ABAC/tenant-isolation check failure | Deny request, log security event | Security reviewer investigates |

## General principles

1. No exception path may bypass a mandatory approval gate defined in [human-approval-matrix.md](human-approval-matrix.md).
2. Every exception is logged with enough context for audit (see [audit-log-specification.md](../03-data/audit-log-specification.md)) without including raw PII/documents in the exception log entry itself.
3. Automatic actions on exceptions are limited to: retries, timers/expirations, routing/queuing, and notifications — never approvals, rejections, or data merges.
4. Exception thresholds (confidence levels, retry counts, max cycles) are configurable defaults, tenant-overridable, and must start conservative.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
