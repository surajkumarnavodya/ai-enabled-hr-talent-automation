# AI Evaluation Strategy

> Title: AI Evaluation Strategy | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: AI Governance, QA, Security

## Purpose and scope

Defines how every AI skill is evaluated before and after release. Complements [ai-evaluation-scorecard.md](../09-quality-evaluation/ai-evaluation-scorecard.md) (scorecard fields) and [red-team-plan.md](red-team-plan.md) (adversarial testing).

## Evaluation dimensions

| Dimension | What it measures | Dataset location |
|---|---|---|
| Functional accuracy | Extraction field accuracy, matching relevance vs. labeled ground truth | `evals/datasets/`, `evals/cases/` |
| Explainability | Whether rationale references actual JD criteria, not generic text | `evals/rubrics/` |
| Fairness | Score parity across de-identified profile variants (see [fairness-and-bias-governance.md](../05-security-governance/fairness-and-bias-governance.md)) | `evals/datasets/fairness/` |
| Security / prompt injection resistance | Resistance to embedded-instruction attacks | `prompts/red-team/prompt-injection-test-cases.md`, `evals/cases/security/` |
| RAG groundedness | % of answers with valid citations, no-answer rate calibration | `evals/datasets/rag/` |
| Human-review sampling | Manual audit of a sample of production outputs | `evals/reports/` |
| Cost/latency | Token usage and latency against budget | Telemetry (see [model-routing-and-cost-controls.md](model-routing-and-cost-controls.md)) |

## Release criteria (illustrative defaults — [TENANT_CONFIGURATION_REQUIRED] to finalize)

| Metric | Minimum to release |
|---|---|
| Extraction field accuracy | ≥ 90% on labeled test set |
| Matching relevance (precision@k) | ≥ 80% |
| Fairness disparity | Below configured statistical significance threshold |
| Prompt-injection block rate | 100% on known test-case catalog |
| RAG citation validity | 100% of citations resolve to retrieved chunks |
| RAG no-answer calibration | False "confident but wrong" rate below configured threshold |

## Evaluation cadence

- Pre-release: full suite on every prompt/model/skill change.
- Post-release: continuous sampling of production outputs (de-identified where possible) reviewed on a configurable cadence.
- Full regression suite re-run quarterly even without changes, to catch drift from underlying model provider updates.

## Human-review sampling process

A configurable percentage of AI outputs per skill (default starting point: 100% during initial rollout, tapering as confidence grows — [TENANT_CONFIGURATION_REQUIRED]) are reviewed by a human and compared to the AI output, feeding back into the evaluation dataset.

## Reporting

Evaluation run results are stored in `evaluation_record` ([data-dictionary.md](../03-data/data-dictionary.md)) and summarized in `evals/reports/`, queryable via `GET /v1/evaluations/{runId}` ([rest-api-catalog.md](../04-api/rest-api-catalog.md)).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
