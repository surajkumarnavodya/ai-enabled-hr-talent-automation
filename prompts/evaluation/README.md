# prompts/evaluation/

**Purpose:** "LLM-as-judge" prompt templates used by the evaluation harness to score skill outputs (rationale quality, groundedness, extraction accuracy) — distinct from the production prompts in `prompts/system/`.

**What belongs here:** Judge-prompt templates with clear scoring rubrics/output schemas.

**What must not be stored here:** Real candidate data in examples; actual evaluation run results (→ `evals/reports/`).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead]

**Contents:** [evaluation-prompts.md](evaluation-prompts.md)

**Status:** Populated.
