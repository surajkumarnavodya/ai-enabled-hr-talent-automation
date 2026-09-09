---
description: Run the AI evaluation suite for changed prompts/models/skills
---

Run (or describe how to run, if tooling is not yet implemented) the evaluation suite per `docs/06-ai-agents-rag/ai-evaluation-strategy.md`:

1. Identify which skill(s) changed (prompt, model route, or RAG config) since the last evaluated version.
2. Run functional accuracy tests against datasets in `evals/datasets/` and cases in `evals/cases/`.
3. Run the fairness check for any skill touching candidate matching (`evals/datasets/fairness/`) per `docs/05-security-governance/fairness-and-bias-governance.md`.
4. Run the red-team/prompt-injection suite (`prompts/red-team/prompt-injection-test-cases.md`, `evals/cases/security/`) for any skill processing untrusted content.
5. Run RAG groundedness/citation checks (`evals/datasets/rag/`) for any RAG-config change.
6. Compare results against the release criteria table in `docs/06-ai-agents-rag/ai-evaluation-strategy.md`.
7. Produce a scorecard per `docs/09-quality-evaluation/ai-evaluation-scorecard.md` and save it under `evals/reports/`.
8. If any metric fails its threshold, report the failure clearly and do NOT recommend promoting the change to production.

Note: no evaluation harness implementation exists yet in this documentation-only phase of the project — if asked to actually execute tests, say so explicitly rather than fabricating results.
