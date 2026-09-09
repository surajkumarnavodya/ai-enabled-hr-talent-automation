# Definition of Done

> Title: Definition of Done | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, Engineering leads, QA, Security

## Purpose and scope

Checklist a story/task must satisfy before being considered complete, enforcing the "update together" rule in Section 9 of [CLAUDE.md](../../CLAUDE.md).

## Checklist

| # | Criterion |
|---|---|
| 1 | Code implements only the configurable behavior specified; no hardcoded values that should be configuration (Section 4, CLAUDE.md) |
| 2 | Unit/integration/contract tests added and passing, including for any new state transition ([workflow-state-machine.md](../02-business-workflows/workflow-state-machine.md)) |
| 3 | OpenAPI/AsyncAPI contracts updated to match implementation exactly |
| 4 | Data schema/migration scripts updated and reviewed (see [database-migration-strategy.md](../03-data/database-migration-strategy.md)) |
| 5 | ADR created/updated if an architectural decision changed |
| 6 | Relevant `/docs` pages updated (no change ships with stale documentation) |
| 7 | Security review completed for any change touching auth, data access, file upload, or AI guardrails |
| 8 | No PII/secrets logged (spot-checked against [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)) |
| 9 | Config validated against its JSON Schema in `config/schemas/` |
| 10 | AI evaluation suite passing if a prompt/model/skill changed ([ai-evaluation-strategy.md](../06-ai-agents-rag/ai-evaluation-strategy.md)) |
| 11 | No approval gate bypassed or weakened without explicit, documented sign-off |
| 12 | CI/CD quality gates green (see [ci-cd-quality-gates.md](ci-cd-quality-gates.md)) |

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
