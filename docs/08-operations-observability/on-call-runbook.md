# On-Call Runbook

> Title: On-Call Runbook | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — DevOps/SRE] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: DevOps, Architecture

## Purpose and scope

Operational (non-security) incident response for on-call engineers, complementing [incident-response-runbook.md](../05-security-governance/incident-response-runbook.md) (security-specific).

## Alert triage

| Alert | First checks | Likely cause | Runbook link |
|---|---|---|---|
| API error-rate spike | Recent deploy? DB health? Upstream provider status? | Bad deploy, DB connection exhaustion, dependency outage | Rollback procedure, DB connection-pool tuning |
| Outbox/DLQ depth growing | Which adapter? Circuit breaker open? | Downstream integration outage | Check [integration-adapter-catalog.md](../07-mcp-integrations/integration-adapter-catalog.md), manual replay after root cause fixed |
| Agent Plane latency spike | Model provider status? Token budget exhaustion? | Provider throttling, runaway prompt size | Check [model-routing-and-cost-controls.md](../06-ai-agents-rag/model-routing-and-cost-controls.md) fallback routing |
| RAG retrieval failures | Vector store health? | Vector store outage (non-critical, no-answer fallback should engage) | Verify graceful degradation is active; escalate to vector store provider if prolonged |
| SLA-breach escalation flood | Recent workflow-config change? | Misconfigured SLA thresholds | Check `config/defaults/workflow.default.yaml` recent changes |

## Escalation path

On-call engineer → Service owner → Architecture on-call → Engineering leadership, per [TENANT_CONFIGURATION_REQUIRED] paging policy. Security-flavored incidents (suspected breach, injection success) are immediately escalated per [incident-response-runbook.md](../05-security-governance/incident-response-runbook.md) instead of this runbook.

## Standard operating procedures

- Always check the correlation ID from the alert against traces before taking action.
- Never manually edit production data to "fix" a stuck workflow state — use the documented replay/remediation tooling so the audit log stays accurate.
- Any rollback of a prompt/model version follows [prompt-management.md](../06-ai-agents-rag/prompt-management.md#rollback).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
