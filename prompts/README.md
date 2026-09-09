# prompts/ — Versioned Agent Prompts

**Purpose:** Approved, version-controlled prompt templates for every AI agent/skill, plus evaluation and red-team prompt sets.

**What belongs here:** System prompts (`system/`), prompt fragments (`skills/`), LLM-as-judge evaluation prompts (`evaluation/`), and adversarial test prompts (`red-team/`) — all with a version tag and owner.

**What must not be stored here:** Real candidate/employee data in any example or few-shot content; unversioned or unreviewed prompt changes.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead]

**Main dependencies:** `docs/06-ai-agents-rag/prompt-management.md`, `src/agents/`, `evals/`.

**Subfolders:** [system/](system/) · [skills/](skills/) · [evaluation/](evaluation/) · [red-team/](red-team/)

**Status:** Initial scaffold — system prompts and red-team test cases populated.
