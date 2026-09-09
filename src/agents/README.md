# src/agents/

**Purpose:** AI agent orchestration and skills only (Python/LangGraph or Semantic Kernel by default — see `docs/01-architecture/technology-selection-matrix.md`): CV extraction, candidate matching, offer drafting, verification assistance, interview-coordination drafting.

**What belongs here:** Supervisor/specialist agent code, prompt-loading logic (reading from `prompts/`), MCP tool-calling clients, and output-schema validation.

**What must not be stored here:** Deterministic employment-decision or workflow-state logic — that remains in `src/backend/`'s workflow engine. Agents call backend APIs and respect the result; they never implement their own copy of approval-matrix or state-machine logic. Also: no real candidate data in fixtures/examples, no unscoped tool credentials.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Data/AI Engineering]

**Main dependencies:** `prompts/`, `docs/06-ai-agents-rag/`, `mcp/`, `evals/`.

**Related documents:** [.claude/rules/ai-agents.md](../../.claude/rules/ai-agents.md) · [docs/06-ai-agents-rag/agent-architecture.md](../../docs/06-ai-agents-rag/agent-architecture.md)

**Status:** Initial scaffold — details to be added during implementation. (Note: an existing `HrAutomation.Agents` .NET project also exists under `src/`, hosting orchestration on the backend side per ADR-002; reconcile before starting new agent work.)
