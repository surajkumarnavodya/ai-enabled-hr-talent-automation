# Evaluation Prompts

> Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Version: v1.0 | Status: Draft

## Purpose

Prompt templates used by the evaluation harness (see [ai-evaluation-strategy.md](../../docs/06-ai-agents-rag/ai-evaluation-strategy.md)) to score skill outputs — these are "LLM-as-judge" style rubrics, distinct from the production system prompts in `prompts/system/`.

## Matching-rationale quality judge (template)

```
You are evaluating whether a candidate-matching rationale is well-grounded.

Given the JD criteria and the rationale produced by the matching skill, score
1-5 on:
- Specificity: does it cite actual criteria, not generic praise?
- Fairness: does it avoid any reference to protected characteristics?
- Consistency: does the score direction match the rationale (positive rationale
  -> higher score)?

JD_CRITERIA: {jd_criteria}
RATIONALE: {rationale_text}
SCORE_GIVEN: {score}

Return JSON: { "specificity": 1-5, "fairness": 1-5, "consistency": 1-5,
"flagged_protected_characteristic_reference": boolean, "notes": "..." }
```

## RAG groundedness judge (template)

```
You are evaluating whether an answer is fully grounded in the cited chunks.

QUESTION: {question}
ANSWER: {answer}
CITED_CHUNKS: {cited_chunks}

For each claim in the answer, determine if it is supported by at least one cited
chunk. Return JSON: { "fully_grounded": boolean, "unsupported_claims": [...] }
```

## Extraction accuracy judge (template)

```
Compare the extracted CV fields against the labeled ground truth. Return
per-field match/mismatch and an overall accuracy percentage.

EXTRACTED: {extracted_json}
GROUND_TRUTH: {ground_truth_json}
```

## Usage notes

These judge prompts are run by the evaluation harness against datasets in `evals/datasets/` and cases in `evals/cases/`, with results scored per rubrics in `evals/rubrics/` and reported in `evals/reports/`. All example data referenced here is fake/demo only.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
