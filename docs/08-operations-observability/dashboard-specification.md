# Dashboard Specification

> Title: Dashboard Specification | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Platform/DevOps] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: DevOps, Product, Security

## Purpose and scope

Defines the required dashboards built on the metrics in [metrics-slos-and-alerts.md](metrics-slos-and-alerts.md). Actual dashboard platform is configurable (see [technology-selection-matrix.md](../01-architecture/technology-selection-matrix.md)).

## Dashboard catalog

| Dashboard | Audience | Key panels |
|---|---|---|
| Platform Health | DevOps/On-call | API availability/latency/error rate, DB connection pool, message bus lag, circuit-breaker states |
| Workflow Funnel | HR Operations/Product | Candidates per stage, conversion rates stage-to-stage, SLA breach counts, time-in-state histograms |
| AI Operations | AI Governance/Engineering | Token usage/cost by skill, confidence-score distributions, guardrail trigger rate, human-review-queue depth, model/prompt version in use |
| Security Posture | Security/Compliance | Auth failures, ABAC denials, prompt-injection flags, cross-tenant access denial attempts, MCP call audit summary |
| Integration Health | Integration Engineering | Outbox depth per adapter, DLQ depth, retry/circuit-breaker status per external system |
| Executive Summary | HR Leadership | Time-to-shortlist, time-to-offer, time-to-employee-ID, approval turnaround times (see [product-requirements-document.md](../00-product/product-requirements-document.md) goals) |

## Design principles

- No dashboard displays raw PII; all candidate/employee references are by count or aggregate, or by ID for drill-down by an authorized role only.
- Dashboards are tenant-scoped by default; cross-tenant aggregate views (if any) are restricted to a platform-level role and explicitly de-identified.
- Every dashboard panel maps to a metric defined in [metrics-slos-and-alerts.md](metrics-slos-and-alerts.md) — no ad hoc, undocumented panels in production dashboards.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
