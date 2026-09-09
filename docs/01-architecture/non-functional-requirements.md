# Non-Functional Requirements

> Title: Non-Functional Requirements | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security, Product

## Purpose and scope

Defines target NFRs as configurable defaults. Actual contractual SLAs are [TENANT_CONFIGURATION_REQUIRED].

## Availability

| Component | Target (default) | Notes |
|---|---|---|
| HR Core API | 99.9% | Business-hours-weighted for tenants that need it |
| Workflow Engine | 99.9% | Coupled to RDBMS availability |
| Document Service | 99.5% | Object storage SLA dependent |
| RAG Retrieval | 99.0% | Degrades gracefully to "no-answer" fallback |
| MCP Servers | 99.0% each | Circuit breaker isolates failures per system |

## Latency

| Operation | Target p95 (default) |
|---|---|
| API read (candidate/TAN lookup) | ≤ 300 ms |
| API write (command) | ≤ 800 ms (excluding async side effects) |
| CV parsing (async) | ≤ 60 s per document |
| AI matching run (per TAN, up to configurable CV Bank size) | ≤ 2 min |
| RAG retrieval (policy Q&A) | ≤ 3 s |

## Scalability

Horizontal scaling of stateless services (API, Agent Orchestrator, Integration Adapters) behind the API gateway/load balancer. Database scaling via read replicas for reporting; write path stays on the primary system-of-record instance per tenant-isolation model. Target: support configurable peak concurrent TAN volume per tenant — [TENANT_CONFIGURATION_REQUIRED].

## Security

See [security-architecture.md](../05-security-governance/security-architecture.md) for full detail: zero-trust, encryption in transit (TLS 1.2+) and at rest (AES-256 or equivalent), RBAC+ABAC, secrets in vault, audit logging of all sensitive actions.

## Accessibility

Candidate-facing and recruiter-facing UI target WCAG 2.1 AA (default; contractual target is [TENANT_CONFIGURATION_REQUIRED]). Notifications and Green Form must be usable with screen readers and support configurable locale/language.

## Maintainability

- Configuration-first design (Section 4, CLAUDE.md) to minimize code changes for business-rule updates.
- All contracts (OpenAPI/AsyncAPI/JSON Schema) versioned; breaking changes follow [versioning-and-deprecation-policy.md](../04-api/versioning-and-deprecation-policy.md).

## Cost

Cost allocation tracked by tenant, model, workflow, and feature — see [cost-management.md](../08-operations-observability/cost-management.md). Default posture: prefer smaller/cheaper models for low-risk tasks (extraction) and reserve higher-cost models for tasks requiring stronger reasoning (matching rationale), per [model-routing-and-cost-controls.md](../06-ai-agents-rag/model-routing-and-cost-controls.md).

## Assumptions and dependencies

Numeric targets above are illustrative defaults for planning; contractual SLOs require tenant sign-off — [TENANT_CONFIGURATION_REQUIRED].

## Risks and open questions

- Peak load profile (e.g., bulk CV import size) not yet characterized — pending real usage data.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
