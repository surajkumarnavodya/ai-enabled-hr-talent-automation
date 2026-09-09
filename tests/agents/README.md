# tests/agents/

**Purpose:** Agent/tool-safety tests: structured-output schema conformance, tool-scope enforcement, prompt-injection resistance, and confirmation that no skill can commit a sensitive workflow action directly.

**What belongs here:** Tests exercising `src/agents/` skills against the cases in `prompts/red-team/` and `evals/cases/security/`.

**What must not be stored here:** Real candidate/employee data in any fixture or prompt example.

**Owner:** Data/AI Engineering, jointly with Security.

**Status:** Initial scaffold — details to be added during implementation.
