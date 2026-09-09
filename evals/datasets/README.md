# Evaluation Datasets

> Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft

Holds labeled/ground-truth datasets used by [ai-evaluation-strategy.md](../../docs/06-ai-agents-rag/ai-evaluation-strategy.md): CV extraction ground truth, JD/candidate matching relevance judgments, fairness test profile sets (`fairness/`), and RAG groundedness question/answer sets (`rag/`).

All data in this directory must be fake/demo or properly de-identified — never real candidate/employee data (Section 7, root CLAUDE.md).

## Planned subfolders

- `cv-extraction/` — labeled CV field-extraction ground truth
- `matching/` — JD + candidate batches with relevance judgments
- `fairness/` — de-identified profile variants differing only in excluded characteristics (see [fairness-and-bias-governance.md](../../docs/05-security-governance/fairness-and-bias-governance.md))
- `rag/` — policy Q&A pairs with expected citations

No datasets are populated yet in this documentation-only phase.
