---
description: Add a new REST API endpoint following project conventions
---

Add a new endpoint following `docs/04-api/api-standards.md`:

1. Add the path/operation to `openapi/hr-onboarding-api.openapi.yaml` with: operationId, tags, parameters (including `Idempotency-Key` if mutating with side effects, `X-Tenant-Id`/tenant claim, `If-Match` if updating an existing resource), request/response schemas, and standard error responses (`400`/`401`/`403`/`404`/`409`/`422`/`429`/`5XX` via `#/components/responses/*`).
2. Add a row to `docs/04-api/rest-api-catalog.md` with required scope and whether it is approval-gated.
3. If the endpoint can trigger a sensitive action (Section 5, root CLAUDE.md), cross-check `docs/02-business-workflows/human-approval-matrix.md` and ensure the implementation independently verifies a recorded approval server-side.
4. Add contract tests asserting the implementation matches the OpenAPI schema.
5. Update `docs/03-data/data-dictionary.md` if a new entity/field is introduced, and add a migration per `docs/03-data/database-migration-strategy.md`.

Ask for the endpoint's purpose, method/path, and required role if not already clear from context.
