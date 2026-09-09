---
description: Validate documentation/config consistency across the project
---

Run a consistency check across the repository:

1. Verify every file under `config/defaults/`, `config/environments/`, and `config/tenants/` validates against its corresponding schema in `config/schemas/`.
2. Verify every endpoint in `docs/04-api/rest-api-catalog.md` has a matching operation in `openapi/hr-onboarding-api.openapi.yaml`, and every event in `docs/02-business-workflows/end-to-end-recruitment-onboarding-workflow.md`/notification catalog has a matching message in `asyncapi/hr-onboarding-events.asyncapi.yaml`.
3. Verify every sensitive action in `docs/02-business-workflows/human-approval-matrix.md` has: an API endpoint marked approval-gated, a corresponding entry in `config/schemas/approval-matrix.schema.json`'s fixed enum, and a mention in `docs/05-security-governance/threat-model.md`.
4. `docs/03-data/data-dictionary.md` and `docs/03-data/sample-relational-schema.sql` describe each other's target-state design, not the real schema — do not use them as the check for what exists. Instead verify claims about the real database against `src/HrAutomation.Infrastructure/Database/scripts/03-create-tables.sql` and the live schema (`sqlcmd`/SSMS), and cross-check `PROJECT_STATUS.md`'s capability table against actual running code (does the claimed skill/endpoint/procedure exist and get called?).
5. Verify every document under `docs/` has a document-control block and a change-control section.
6. Report any inconsistency found, file and line where possible, and do not silently fix — surface findings for review first unless explicitly asked to fix.
