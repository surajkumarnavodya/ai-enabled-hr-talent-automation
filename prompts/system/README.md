# prompts/system/

**Purpose:** Production system prompts for each agent skill — the source of truth for how each skill is instructed to behave, including its non-negotiable boundaries.

**What belongs here:** One versioned Markdown file per skill, following the existing template style (delimited untrusted-data sections, explicit non-negotiable rules, structured JSON output requirement).

**What must not be stored here:** Real candidate/JD/feedback content used as examples — fake/demo only.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead], each prompt individually owned per `docs/06-ai-agents-rag/prompt-management.md`.

**Contents:** [hr-orchestrator-system-prompt.md](hr-orchestrator-system-prompt.md) · [cv-parsing-system-prompt.md](cv-parsing-system-prompt.md) · [candidate-matching-system-prompt.md](candidate-matching-system-prompt.md) · [interview-coordination-system-prompt.md](interview-coordination-system-prompt.md) · [offer-management-system-prompt.md](offer-management-system-prompt.md) · [document-verification-system-prompt.md](document-verification-system-prompt.md) · [employee-conversion-system-prompt.md](employee-conversion-system-prompt.md)

**Status:** Populated.
