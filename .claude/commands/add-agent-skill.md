---
description: Add a new AI agent skill following governance requirements
---

Add a new specialist skill following `docs/06-ai-agents-rag/agent-architecture.md` and `docs/06-ai-agents-rag/agent-skill-catalog.md`:

1. Add a row to `agent-skill-catalog.md`: purpose, input, output schema, tools (least privilege, correct tier per `docs/07-mcp-integrations/mcp-security-and-authorization.md`), confidence threshold, human-review trigger.
2. Create the system prompt under `prompts/system/` following the existing template style (delimited untrusted-data sections, explicit non-negotiable rules, structured JSON output requirement).
3. Confirm the skill does NOT have a code path to perform any action listed in Section 5 of root `CLAUDE.md` (reject/select candidate, release offer, set compensation, close discrepancy, create Employee ID). If it appears to need one of these, stop — that requires a human-approval-gated API call from the HR Core API, not a skill capability.
4. Add the skill's model/prompt route to `config/defaults/model-routing.default.yaml` and `config/schemas/model-routing.schema.json`-conformant entry.
5. Add evaluation cases to `evals/cases/` and, if the skill touches candidate matching, a fairness test set per `docs/05-security-governance/fairness-and-bias-governance.md`.
6. Add red-team test cases to `prompts/red-team/prompt-injection-test-cases.md` if the skill processes untrusted content.
7. Complete an `docs/09-quality-evaluation/ai-evaluation-scorecard.md` entry before the skill is considered ready for staging.

Ask the user for the skill's purpose and trigger context if not already provided.
