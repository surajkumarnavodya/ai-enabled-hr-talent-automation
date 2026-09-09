# openapi/ — REST API Contracts

**Purpose:** Contract-first REST API definitions for the platform, authoritative over any implementation detail.

**What belongs here:** OpenAPI 3.x YAML/JSON files, kept in sync with `docs/04-api/rest-api-catalog.md` and the actual implementation in `src/backend/`.

**What must not be stored here:** Implementation code, real endpoint URLs/credentials, example payloads containing real candidate/employee data (use fake/demo data only).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — API Architecture]

**Main dependencies:** `docs/04-api/`, `.claude/rules/api.md`, `src/backend/`.

**Contents:** [hr-onboarding-api.openapi.yaml](hr-onboarding-api.openapi.yaml)

**Status:** Populated.
