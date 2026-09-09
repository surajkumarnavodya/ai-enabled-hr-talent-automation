# evals/ — AI Evaluation Assets

**Purpose:** Datasets, executable cases, scoring rubrics, and run reports backing `docs/06-ai-agents-rag/ai-evaluation-strategy.md` and `docs/09-quality-evaluation/ai-evaluation-scorecard.md`.

**What belongs here:** Sanitized/de-identified datasets (`datasets/`), executable test cases (`cases/`), scoring rubrics (`rubrics/`), and run reports (`reports/`).

**What must not be stored here:** Real candidate/employee data in any form — every dataset must be fake/demo or properly de-identified before it lands here.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead], QA co-owns test execution.

**Main dependencies:** `prompts/evaluation/`, `prompts/red-team/`, `docs/06-ai-agents-rag/ai-evaluation-strategy.md`, `.github/workflows/ci.yml`.

**Subfolders:** [datasets/](datasets/) · [cases/](cases/) · [rubrics/](rubrics/) · [reports/](reports/)

**Status:** Initial scaffold — structure defined, no datasets populated yet.
