# Notification Catalog

> Title: Notification Catalog | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — HR Operations] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: HR Operations, Product, Security

## Purpose and scope

Catalogs every system notification, its trigger event, recipients, channel, and template reference. Templates themselves are configuration (`config/schemas/notification-template.schema.json`), not code — see also [privacy-and-pii-handling.md](../05-security-governance/privacy-and-pii-handling.md) for what may/may not appear in a notification body.

## Catalog

| Notification | Trigger event | Recipient(s) | Channel(s) | Contains PII? | Template key |
|---|---|---|---|---|---|
| TAN pending approval | `tan.created` | HR Approver | Email, in-app | No | `tan.pending_approval` |
| TAN approved | `tan.approved` | Recruiter, Hiring Manager | Email, in-app | No | `tan.approved` |
| Shortlist ready for review | `application.shortlist_requested` | HR Approver / Hiring Manager | Email, in-app | Minimal (candidate name only, config-gated) | `shortlist.ready` |
| Shortlist approved | `application.shortlist_approved` | Recruiter | In-app | Minimal | `shortlist.approved` |
| Interview scheduled | `interview.scheduled` | Candidate, Panelist(s), Recruiter | Email, calendar invite | Yes (candidate contact/name) | `interview.scheduled` |
| Interview reminder | SLA timer (T-24h) | Candidate, Panelist(s) | Email | Yes | `interview.reminder` |
| Feedback submission reminder | SLA breach | Panelist | Email, in-app | No (reference ID only) | `feedback.reminder` |
| Candidate rejected (this TAN) | `application.rejected` | Candidate (configurable), Recruiter | Email | Yes (candidate) | `application.rejected` |
| Offer approved | `offer.approved` | Recruiter | In-app | No | `offer.approved` |
| Offer sent | `offer.sent` | Candidate | Email + secure portal link | Yes | `offer.sent` |
| Offer accepted | `offer.accepted` | Recruiter, HR Operations | Email, in-app | Minimal | `offer.accepted` |
| Green Form issued | `green_form.issued` | Candidate | Email (secure link, time-bound) | Yes (link is single-use/expiring) | `green_form.issued` |
| Green Form reminder | SLA timer | Candidate | Email | Yes | `green_form.reminder` |
| Discrepancy raised | `discrepancy.created` | Candidate (re-upload request), HR Operations | Email, in-app | Yes (candidate), redacted for HR summary view | `discrepancy.created` |
| Discrepancy resolved | `discrepancy.resolved` | Candidate, HR Operations | Email, in-app | Minimal | `discrepancy.resolved` |
| Employee ID created | `employee.created` | New employee, HR Operations, IT Provisioning | Email, integration event | Yes (employee) | `employee.created` |
| Escalation notice | SLA breach threshold | Escalation chain role | Email, in-app | No (reference ID only) | `escalation.notice` |

## Design rules

- Notification bodies never include: compensation figures, confidential interview feedback text, full document contents, or raw identifiers beyond what's needed for the recipient's action (see [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md) — the same minimization principle applies to notifications).
- Candidate-facing notifications always use plain, non-technical language and never reveal internal scoring/rationale.
- All templates are versioned and tenant-overridable; see `config/schemas/notification-template.schema.json`.

## Configurable items

Channel selection per notification, template content/branding, language/locale, send-time windows, and opt-out rules are tenant-configurable.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
