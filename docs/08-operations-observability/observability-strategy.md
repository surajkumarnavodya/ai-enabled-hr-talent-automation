# Observability Strategy

> Title: Observability Strategy | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Platform/DevOps] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security, DevOps

## Purpose and scope

Operationalizes [ADR-005](../adr/ADR-005-observability-strategy.md): OpenTelemetry-based traces, metrics, and structured logs across all services.

## Instrumentation plan

| Signal | Source | Backend (configurable) |
|---|---|---|
| Traces | HR Core API, Workflow Engine, Agent Orchestrator, Integration Adapters, MCP servers | OTel Collector → [TENANT_CONFIGURATION_REQUIRED backend] |
| Metrics | All services (RED/USE metrics) + AI-specific metrics | OTel Collector → Prometheus/Azure Monitor/Datadog |
| Logs | All services, structured JSON, redacted before export | Centralized log store |

## Required correlation fields

`correlationId`, `tenantId`, `subjectType`/`subjectId` (where applicable), `traceId`/`spanId` — propagated across every service and MCP boundary per [api-standards.md](../04-api/api-standards.md).

## AI-specific telemetry (mandatory fields on every agent/skill span)

`modelVersion`, `promptVersion`, `skillName`, `retrievalCount`, `documentVersion` (RAG), `tokenUsage` (input/output), `latencyMs`, `toolCallsMade`, `guardrailOutcome`, `approvalState`, `errorCategory`. See [ADR-005](../adr/ADR-005-observability-strategy.md) for the redaction rule: never the raw prompt/response content or PII.

## Redaction

See [logging-and-redaction-standard.md](logging-and-redaction-standard.md) for the mandatory redaction pipeline applied before any signal leaves the service boundary.

## Sampling

Trace sampling ratio is configurable (`TRACES_SAMPLING_RATIO` in `.env.example`, default 0.1 in non-prod-critical paths); sensitive-action traces (approvals, employee conversion) are always sampled at 100% regardless of the global ratio.

## Dashboards and alerts

See [dashboard-specification.md](dashboard-specification.md) and [metrics-slos-and-alerts.md](metrics-slos-and-alerts.md).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
