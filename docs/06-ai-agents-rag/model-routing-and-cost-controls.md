# Model Routing and Cost Controls

> Title: Model Routing and Cost Controls | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: AI Governance, Architecture, Finance

## Purpose and scope

Defines how models are selected per task by sensitivity/cost, and the resilience/cost controls applied to every model call. Configuration lives in `config/schemas/model-routing.schema.json` and `config/defaults/model-routing.default.yaml`.

## Routing principles

- Route by task sensitivity and reasoning demand, not a single global model for everything.
- Prefer smaller/cheaper models for well-defined extraction tasks; reserve higher-capability models for tasks needing nuanced rationale (matching explanation, discrepancy summarization).
- Every route has a configured fallback model in case the primary is unavailable or rate-limited.

## Illustrative routing table (tune per tenant/provider — [TENANT_CONFIGURATION_REQUIRED])

| Skill | Primary model tier | Fallback model tier | Rationale |
|---|---|---|---|
| CV Extraction | Small/fast | Small/fast (secondary provider) | Structured extraction, low reasoning complexity |
| Candidate Matching | Mid/high reasoning | Mid reasoning | Needs to weigh multiple criteria and produce coherent rationale |
| Interview Coordination Drafting | Small/fast | Small/fast | Templated drafting task |
| Offer Drafting | Small/fast | Small/fast | Template rendering, no figures authored |
| Document Verification Assist | Mid reasoning (+ OCR tool) | Mid reasoning | Cross-checking requires some inference |
| Policy Q&A (RAG) | Mid reasoning | Small/fast | Balance answer quality with per-query cost at scale |

## Resilience controls per model call

| Control | Default |
|---|---|
| Token budget | Per-skill max input/output tokens, configurable |
| Timeout | Configurable per skill (e.g., 15–30s) |
| Retries | Bounded retries with backoff on transient provider errors |
| Caching | Cache identical, deterministic requests (e.g., repeated policy questions) with a short TTL, never caching responses containing candidate PII beyond session scope |
| Circuit breaker | Trip to fallback model/provider after configurable consecutive failures |
| Fallback behavior | On exhausted retries/fallbacks, return `needs_review` rather than a degraded/unvalidated answer |

## Cost allocation

Token usage and cost are tagged by tenant, workflow stage, and skill for allocation and budgeting — see [cost-management.md](../08-operations-observability/cost-management.md).

## Change governance

Changing a model route (including provider or version) follows the same approval/testing process as a prompt change (see [prompt-management.md](prompt-management.md)) and must pass [ai-evaluation-strategy.md](ai-evaluation-strategy.md) before promotion.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
