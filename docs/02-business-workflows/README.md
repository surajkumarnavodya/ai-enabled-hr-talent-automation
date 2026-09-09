# 02-business-workflows/

**Purpose:** The authoritative definition of the recruitment-to-onboarding workflow: end-to-end flow, formal state machine, human-approval matrix, SLAs, notifications, and exception handling.

**What belongs here:** Workflow diagrams, state/transition tables, approval-gate definitions, SLA targets, and the exception catalog.

**What must not be stored here:** Implementation code, real candidate data in examples, or configuration values themselves (those live in `config/`, referenced from here).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — HR Process Owner]

**Main dependencies:** `config/schemas/workflow-config.schema.json` and `config/schemas/approval-matrix.schema.json` implement what's defined here; `docs/03-data/` models the entities; `openapi/`/`asyncapi/` expose it.

**Contents:** [end-to-end-recruitment-onboarding-workflow.md](end-to-end-recruitment-onboarding-workflow.md) · [workflow-state-machine.md](workflow-state-machine.md) · [human-approval-matrix.md](human-approval-matrix.md) · [sla-escalation-rules.md](sla-escalation-rules.md) · [notification-catalog.md](notification-catalog.md) · [exception-handling-playbook.md](exception-handling-playbook.md)

**Status:** Initial scaffold — details to be added during implementation.
