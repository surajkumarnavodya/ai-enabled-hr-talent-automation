# 06-ai-agents-rag/

**Purpose:** Agent orchestration architecture, RAG design, prompt management, model routing/cost controls, AI evaluation strategy, red-teaming, and the model risk register.

**What belongs here:** Design and governance documentation for AI capabilities. Actual prompt text lives in `prompts/`; evaluation datasets/cases live in `evals/`.

**What must not be stored here:** Real candidate data used as examples, unversioned prompt changes, or production model API keys.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead]

**Main dependencies:** `prompts/`, `evals/`, `config/schemas/rag-config.schema.json`, `config/schemas/model-routing.schema.json`, `.claude/rules/ai-agents.md`.

**Contents:** [agent-architecture.md](agent-architecture.md) · [agent-skill-catalog.md](agent-skill-catalog.md) · [agent-state-and-orchestration.md](agent-state-and-orchestration.md) · [rag-architecture.md](rag-architecture.md) · [rag-ingestion-and-chunking.md](rag-ingestion-and-chunking.md) · [retrieval-and-grounding-policy.md](retrieval-and-grounding-policy.md) · [model-routing-and-cost-controls.md](model-routing-and-cost-controls.md) · [prompt-management.md](prompt-management.md) · [ai-evaluation-strategy.md](ai-evaluation-strategy.md) · [red-team-plan.md](red-team-plan.md) · [model-risk-register.md](model-risk-register.md)

**Status:** Initial scaffold — details to be added during implementation.
