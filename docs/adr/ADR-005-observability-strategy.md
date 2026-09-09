# ADR-005: Observability Strategy

> Title: ADR-005 | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Platform/DevOps] | Status: Accepted | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security, DevOps

## Context

The platform spans synchronous APIs, async workflow/event processing, and AI agent/tool calls. Debugging and governance both require end-to-end traceability, while PII/secret exposure through telemetry must be prevented by design.

## Decision

Adopt **OpenTelemetry** as the vendor-neutral instrumentation standard across all services (HR Core API, Workflow Engine, Agent Orchestrator, Integration Adapters, MCP servers), exporting traces, metrics, and structured logs to a centralized backend (dashboard/alerting platform is a configurable choice — see [technology-selection-matrix.md](../01-architecture/technology-selection-matrix.md)). Every request carries a correlation ID propagated across service and MCP boundaries. AI-specific spans additionally record: model identifier, prompt version, skill name, retrieval count, document version, token usage, latency, tool calls made, guardrail outcomes, approval state, and error category — **never** the raw prompt/response content or PII by default (redaction applied before export; see [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)).

## Alternatives considered

1. **Vendor-specific SDKs per backend (e.g., Datadog SDK directly)** — rejected as the default: creates lock-in and inconsistent instrumentation across polyglot services (ASP.NET Core + Python agent service).
2. **Logging only, no distributed tracing** — rejected: insufficient for diagnosing cross-service, async, agent-involving failures.
3. **Full prompt/response logging for debuggability** — rejected by default: conflicts with the non-negotiable prohibition on logging PII/secrets/full prompts; sampled, redacted, opt-in debug capture only, gated by role and retention policy.

## Consequences

- Positive: consistent, swappable observability backend; strong AI-specific telemetry supports both operations and AI governance/evaluation; redaction-by-default reduces breach blast radius.
- Negative: requires disciplined instrumentation conventions across two runtimes (.NET and Python) and all MCP servers; redaction logic must be kept in sync with evolving data-classification rules.

## Status

Accepted.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
