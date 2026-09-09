# Integration Adapter Catalog

> Title: Integration Adapter Catalog | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Integration Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Integration Engineering

## Purpose and scope

Maps each Integration Adapter ([component-architecture.md](../01-architecture/component-architecture.md)) to its MCP server, triggering events, and reliability configuration.

## Catalog

| Adapter | MCP server | Triggering event(s) | Outbound action | Reliability config |
|---|---|---|---|---|
| Calendar Adapter | `mcp-calendar` | `interview.scheduled` (internal command, not the public event) | Create/update calendar invite | Retry x3, circuit breaker after 5 consecutive failures |
| Email Adapter | `mcp-email` | `offer.approved`, `green_form.issued`, `discrepancy.created`, various notifications | Send templated email | Retry x5 with backoff (email is often eventually-consistent tolerant) |
| HRMS Adapter | `mcp-hrms` | `employee.conversion_approved` | Create employee record in HRMS | Retry x3, DLQ on exhaustion, manual replay tooling |
| E-signature Adapter | `mcp-esignature` | `offer.approved` | Send offer for e-signature | Retry x3, webhook callback for completion (see [webhook-security.md](../04-api/webhook-security.md)) |
| Background Verification Adapter | `mcp-background-verification` | `green_form.submitted` (if BGV configured) | Initiate check | Retry x3, async result via webhook |
| Payroll Adapter | `mcp-payroll` | `employee.created` | Send new-hire feed | Retry x3, DLQ on exhaustion |
| IT Provisioning Adapter | `mcp-it-provisioning` | `employee.created` | Request account/access provisioning | Retry x3, DLQ on exhaustion |
| Document Management Adapter | `mcp-document-management` | `document.verification_completed` (if external DMS used) | Sync verified document metadata | Retry x3 |

## Reliability pattern reference

All adapters implement the outbox-relay, idempotency, retry, circuit-breaker, and DLQ patterns defined in [integration-architecture.md](../01-architecture/integration-architecture.md#reliability-patterns).

## Configurable items

Retry counts/backoff, circuit-breaker thresholds, and which events trigger which adapters are configurable per tenant (some tenants may not use payroll/IT-provisioning integration, for example).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
