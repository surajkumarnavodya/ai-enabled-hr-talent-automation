# Metrics, SLOs, and Alerts

> Title: Metrics, SLOs, and Alerts | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Platform/DevOps] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, DevOps, Product

## Purpose and scope

Defines SLOs and alert thresholds (configurable defaults) for API, workflow, document processing, interview scheduling, offer delivery, employee conversion, and AI evaluation quality.

## SLOs (illustrative defaults — [TENANT_CONFIGURATION_REQUIRED] for contractual values)

| SLO | Target | Alert threshold |
|---|---|---|
| API availability | 99.9% monthly | Alert if 5-min error rate > 5% |
| Workflow completion rate (TAN → employee, excluding legitimately closed/rejected) | Track trend, no hard target | Alert on week-over-week drop > 20% |
| Document processing latency (CV parse) | p95 ≤ 60s | Alert if p95 > 120s for 15 min |
| Interview scheduling success rate (slot found within SLA) | ≥ 90% | Alert if < 75% over rolling 24h |
| Offer delivery latency (approve → sent) | p95 ≤ 1 hour | Alert if p95 > 4 hours |
| Employee conversion latency (approval → Employee ID issued) | p95 ≤ 15 minutes | Alert if p95 > 1 hour |
| AI evaluation quality (per [ai-evaluation-scorecard.md](../09-quality-evaluation/ai-evaluation-scorecard.md)) | Meets release-criteria thresholds | Alert on any metric dropping below threshold in production sampling |

## Key metrics by category

| Category | Metrics |
|---|---|
| API | Request rate, error rate, latency percentiles, rate-limit rejections |
| Workflow | Transition counts per state, time-in-state, approval SLA breach counts |
| AI/Agents | Token usage, latency, confidence-score distribution, guardrail trigger rate, human-review-queue depth |
| Integration | Outbox depth, DLQ depth, circuit-breaker state per adapter, retry counts |
| Security | Auth failures, ABAC denials, prompt-injection flags, cross-tenant access denials |

## Alert routing

Alert severity and routing follow [incident-response-runbook.md](../05-security-governance/incident-response-runbook.md) (security-flavored) and [on-call-runbook.md](on-call-runbook.md) (operational). All thresholds above are configuration, not hardcoded — see `config/defaults/observability.default.yaml`.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
