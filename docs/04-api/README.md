# 04-api/

**Purpose:** REST/event API conventions and the human-readable endpoint catalog backing the machine-readable contracts in `openapi/` and `asyncapi/`.

**What belongs here:** API standards, error-handling conventions, versioning/deprecation policy, webhook security requirements, and the endpoint index.

**What must not be stored here:** The actual OpenAPI/AsyncAPI YAML (→ `openapi/`, `asyncapi/`), API implementation code (→ `src/backend/`).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — API Architecture]

**Main dependencies:** `openapi/hr-onboarding-api.openapi.yaml`, `asyncapi/hr-onboarding-events.asyncapi.yaml`, `.claude/rules/api.md`.

**Contents:** [api-standards.md](api-standards.md) · [rest-api-catalog.md](rest-api-catalog.md) · [error-handling-and-problem-details.md](error-handling-and-problem-details.md) · [versioning-and-deprecation-policy.md](versioning-and-deprecation-policy.md) · [webhook-security.md](webhook-security.md) · [frontend-api-integration.md](frontend-api-integration.md)

**Status:** Initial scaffold — details to be added during implementation.
