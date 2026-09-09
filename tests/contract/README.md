# tests/contract/

**Purpose:** Verify that API/event implementations conform exactly to `openapi/hr-onboarding-api.openapi.yaml` and `asyncapi/hr-onboarding-events.asyncapi.yaml`.

**What belongs here:** Schema-conformance tests run against the actual implementation (request/response and event-payload shape validation).

**What must not be stored here:** Business-logic assertions unrelated to contract shape (→ `tests/integration/` or `tests/e2e/`).

**Owner:** API Architecture + each layer's engineering team.

**Status:** Initial scaffold — details to be added during implementation.
