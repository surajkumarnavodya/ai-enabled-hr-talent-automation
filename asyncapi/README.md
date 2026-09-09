# asyncapi/ — Event Contracts

**Purpose:** Contract-first async event definitions for cross-service and integration-adapter communication.

**What belongs here:** AsyncAPI YAML/JSON files, kept in sync with the events referenced throughout `docs/02-business-workflows/` and `docs/07-mcp-integrations/`.

**What must not be stored here:** Implementation/consumer code, message-bus credentials, example payloads with real candidate/employee data.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — API Architecture]

**Main dependencies:** `docs/04-api/`, `src/backend/` (publishers), `src/integration-adapters/` (consumers).

**Contents:** [hr-onboarding-events.asyncapi.yaml](hr-onboarding-events.asyncapi.yaml)

**Status:** Populated.
