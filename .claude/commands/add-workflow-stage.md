---
description: Add a new workflow stage or state transition
---

Add a new workflow stage following the **real** mechanism ([ADR-006](../../docs/adr/ADR-006-database-first-stored-procedure-workflow.md)): there is no generic `workflow_state_transition` table. Read [PROJECT_STATUS.md](../../PROJECT_STATUS.md) first to confirm whether the target entity's workflow is implemented yet or still a stub.

1. Inspect the target entity's real table and status column in `src/HrAutomation.Infrastructure/Database/scripts/03-create-tables.sql`, and its existing transition procedures in `07-create-stored-procedures.sql` (e.g. `recruitment.usp_ApproveJobRequisition` as the reference pattern: precondition check on current status, atomic update, status-history insert, `audit.usp_WriteAuditEvent` call, uniform `Success`/`Message`/`EntityId`/`ErrorCode` result set).
2. Add a new stored procedure for the transition following that pattern, or extend an existing one if it's a new outcome of an existing action (e.g. `usp_RejectJobRequisition` was added this way, alongside `usp_ApproveJobRequisition`).
3. Determine whether the new stage introduces a sensitive action. If so, it MUST be added to `docs/02-business-workflows/human-approval-matrix.md` (noting its actual enforcement status) and to `ref.ApprovalMatrix`/`ApprovalMatrixRule` seed data if it needs a new approval gate — this requires explicit confirmation from the user, since the gated-action set is intentionally not casually extensible; see DEC-006 in `DECISIONS_REQUIRED.md` for the current unresolved approver-mapping question.
4. Update the corresponding `ISkill` in `src/HrAutomation.Agents/` (or add a new one) to call the new/changed procedure via `StoredProcedureExecutor`, and the controller in `src/HrAutomation.Api/Controllers/` that exposes it.
5. Update `docs/02-business-workflows/workflow-state-machine.md`'s notice/table for the affected entity, and `docs/06-ai-agents-rag/agent-skill-catalog.md`'s Status column if a skill moved from stub to implemented.
6. Add SLA defaults to `docs/02-business-workflows/sla-escalation-rules.md` and `config/defaults/workflow.default.yaml` if applicable (note: `config/` is not currently wired to any running code — see DEC-008 in `DECISIONS_REQUIRED.md`).
7. Add xUnit test cases for the new transition (legal and illegal paths) in `tests/HrAutomation.Tests/`, run against a real `HrAutomationDb` instance.
8. Update `openapi/hr-onboarding-api.openapi.yaml` and `docs/04-api/rest-api-catalog.md` if the stage needs new endpoints/events, and `PROJECT_STATUS.md`'s capability table.

Ask the user to confirm the new stage's position in the flow and whether it requires human approval before proceeding.
