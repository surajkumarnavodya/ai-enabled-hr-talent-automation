# Cost Management

> Title: Cost Management | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Finance/Platform] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Finance, Architecture, AI Governance

## Purpose and scope

Defines cost allocation and budget-control mechanisms across tenant, model, workflow, and feature dimensions.

## Cost allocation dimensions

| Dimension | How tracked |
|---|---|
| Tenant | All resource usage tagged with `tenant_id`; cloud cost-allocation tags mirror this |
| Model | Token usage tagged with `model_version_id` per call (see [model-routing-and-cost-controls.md](../06-ai-agents-rag/model-routing-and-cost-controls.md)) |
| Workflow stage | Each skill invocation tagged with the workflow stage that triggered it |
| Feature | Feature-flagged capabilities (e.g., RAG policy Q&A) tagged separately for cost/benefit analysis |

## Budget controls

- Per-tenant monthly token/cost budget (configurable), with alerting at configurable thresholds (e.g., 80%/100%) — see [metrics-slos-and-alerts.md](metrics-slos-and-alerts.md).
- Model routing prefers lower-cost tiers for low-risk tasks by default (see [model-routing-and-cost-controls.md](../06-ai-agents-rag/model-routing-and-cost-controls.md)); budget pressure is a valid input to routing decisions but never overrides a mandatory human-approval gate or a minimum confidence threshold.
- Infrastructure autoscaling limits (max replica counts) are configuration, preventing runaway cost from a traffic spike or misbehaving loop.

## Reporting

Monthly cost report broken down by tenant/model/workflow/feature, reviewed by Finance and AI Governance; unexpected variances trigger investigation (e.g., a prompt regression causing excessive token usage per call).

## Configurable items

Budget thresholds, alert routing, and autoscaling limits are tenant-configurable via `config/defaults/observability.default.yaml` and `config/tenants/sample-tenant.yaml`.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
