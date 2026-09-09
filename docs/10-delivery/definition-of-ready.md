# Definition of Ready

> Title: Definition of Ready | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, Engineering leads

## Purpose and scope

Checklist a story/task must satisfy before entering a sprint/iteration.

## Checklist

| # | Criterion |
|---|---|
| 1 | Acceptance criteria defined and traceable to [acceptance-criteria.md](../09-quality-evaluation/acceptance-criteria.md) or a new entry added there |
| 2 | If the change affects a workflow state or approval gate, [human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md) and [workflow-state-machine.md](../02-business-workflows/workflow-state-machine.md) reviewed/updated first |
| 3 | If the change affects an API/event, the relevant OpenAPI/AsyncAPI contract is drafted (even if not yet finalized) |
| 4 | If the change affects data, [data-dictionary.md](../03-data/data-dictionary.md) and migration approach identified |
| 5 | If the change touches AI/RAG/MCP, security/guardrail implications identified and any new abuse case added to [threat-model.md](../05-security-governance/threat-model.md) |
| 6 | Configurable items identified with schema/default location named (Section 4, CLAUDE.md) |
| 7 | Dependencies on other epics/stories identified |
| 8 | Legal/HR/security open questions flagged rather than assumed (Section 9, CLAUDE.md) |

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
