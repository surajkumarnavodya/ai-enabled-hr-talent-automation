# AI Evaluation Scorecard

> Title: AI Evaluation Scorecard | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: AI Governance, QA

## Purpose and scope

Defines the scorecard template completed for every skill release, per [ai-evaluation-strategy.md](../06-ai-agents-rag/ai-evaluation-strategy.md).

## Scorecard template

| Field | Description |
|---|---|
| Skill name | e.g., Candidate Matching |
| Prompt version / Model version | From `prompt_version`/`model_version` tables |
| Evaluation date | — |
| Dataset(s) used | Reference to `evals/datasets/` |
| Functional accuracy score | vs. release criteria in [ai-evaluation-strategy.md](../06-ai-agents-rag/ai-evaluation-strategy.md) |
| Explainability score | Rationale specificity/consistency (see [evaluation-prompts.md](../../prompts/evaluation/evaluation-prompts.md)) |
| Fairness result | Pass/fail vs. disparity threshold ([fairness-and-bias-governance.md](../05-security-governance/fairness-and-bias-governance.md)) |
| Security/red-team result | Pass/fail per [red-team-plan.md](../06-ai-agents-rag/red-team-plan.md) |
| RAG groundedness (if applicable) | Citation validity %, no-answer calibration |
| Cost/latency | Token usage, p95 latency vs. budget |
| Reviewer sign-off | AI Governance Lead + domain owner |
| Release decision | Approved / Rejected / Approved with conditions |
| Conditions/follow-ups | e.g., "monitor fairness metric weekly for 1 month" |

## Example scorecard (fake/demo data)

| Field | Value |
|---|---|
| Skill name | Candidate Matching |
| Prompt version | matching-v1.3 |
| Model version | model-tier-mid-v2 |
| Functional accuracy | 84% precision@5 (threshold: 80%) — Pass |
| Fairness result | No significant disparity detected — Pass |
| Security/red-team result | 10/10 test cases blocked — Pass |
| Cost/latency | p95 1.8s, within budget — Pass |
| Release decision | Approved |

## Storage

Completed scorecards are stored in `evals/reports/` and referenced from the `evaluation_record` table ([data-dictionary.md](../03-data/data-dictionary.md)).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
