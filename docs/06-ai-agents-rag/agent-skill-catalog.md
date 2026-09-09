# Agent Skill Catalog

> Title: Agent Skill Catalog | Version: 1.1 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft (target-state catalog; most rows are unimplemented — see Status column) | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: AI Governance, Architecture

## Purpose and scope

Catalogs every specialist skill planned for the platform ([agent-architecture.md](agent-architecture.md)), its inputs/outputs, tool access, and confidence threshold. **This is a target catalog, not a list of what's live** — see the Status column below; only 3 of 7 rows have real backing logic today. Each skill has a corresponding system prompt in `prompts/system/`, but a prompt file existing does not imply the skill is implemented (prompts were authored independently of the backend build-out).

## Catalog

| Skill | Status | Purpose | Input | Output (JSON-Schema validated) | Tools (least privilege) | Confidence threshold | Human-review trigger |
|---|---|---|---|---|---|---|---|
| CV Extraction | **Implemented** (`parse_cv_skill`, `HrAutomation.Agents/CvIngestion/`) | Parse CV into structured fields | Raw CV (untrusted) | Structured candidate fields + confidence per field | None (pure NLP task) | 0.75 | Below threshold, or dedup flag |
| Candidate Matching | Planned (stub only — always returns `blocked`) | Score candidates against approved JD | Approved JD criteria + CV Bank subset | Ranked list with per-candidate rationale | Read-only CV Bank query tool | 0.60 (score inclusion) | Any candidate below threshold excluded, not force-included |
| Interview Coordination Drafting | Planned (stub only) | Suggest interview slots, draft invite text | Panelist calendars (via MCP, read-only) | Proposed slot list + draft invite text | `mcp-calendar` (read-only availability) | N/A (proposal only, no threshold) | Any conflict/no-availability case routed to recruiter |
| Offer Drafting | Planned (stub only) | Draft offer letter from template + compensation reference | Approved template + compensation reference (external) | Draft offer document (no compensation figure authored by AI — reference only) | None (template rendering only) | N/A | Always human-approved before send (mandatory gate) |
| Document Verification Assist | Planned (stub only) | Cross-check submitted documents against Green Form data | Document OCR/extraction + self-reported data | Match/mismatch flags with confidence | Document OCR tool (internal) | 0.80 | Below threshold → `needs_review`, never auto-pass |
| Employee Conversion Assist | Planned (stub only) | Summarize gate-checklist status for approver | Gate-checklist data (read-only) | Summary of pass/fail per check | Read-only gate-checklist query | N/A | N/A — decision always human |
| Policy Q&A (RAG) | Planned (no code at all — `HrAutomation.Rag` is an empty scaffold) | Answer HR-policy questions with citations | User question + retrieved chunks | Answer + citations, or no-answer fallback | RAG retrieval tool (read-only) | 0.65 (retrieval relevance) | Below threshold → no-answer fallback |

Also implemented but not in the original catalog above: **TAN creation** (`create_tan_skill`) and **TAN approval/rejection** (`tan_approval_skill`), both in `HrAutomation.Agents/Tan/` — added once the real database-first TAN workflow was built. Every "stub only" skill above is registered in `HrAutomation.Agents/Stubs/StubSkillCatalog.cs` and always returns `ActionStatus.blocked` with a "not yet implemented" risk note — it never proposes a state transition and never writes to the database.

## Least-privilege tool mapping

Every tool grant above is scoped to read-only or propose-only per [ADR-004](../adr/ADR-004-mcp-security-model.md); no skill is granted a write-capable tool to a sensitive external system (e.g., no skill can directly send a calendar invite without the Interview Coordination workflow step confirming with the recruiter first, per [mcp-tool-governance.md](../07-mcp-integrations/mcp-tool-governance.md)).

## Structured output requirement

All skills return JSON-Schema-validated output; free-text fields are limited to designated "draft"/"rationale" fields and never interpreted as executable instructions downstream (see [prompt-injection-defense.md](../05-security-governance/prompt-injection-defense.md)).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
