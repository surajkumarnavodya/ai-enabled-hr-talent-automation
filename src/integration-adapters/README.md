# src/integration-adapters/

**Purpose:** Adapters translating internal domain events into calls against external systems (HRMS, payroll, calendar, email, e-signature, IT provisioning, document management, background verification), each fronted by an isolated MCP server per `docs/07-mcp-integrations/mcp-architecture.md`.

**What belongs here:** Outbox-relay consumers, per-system adapter implementations, idempotency/inbox handling, and retry/circuit-breaker wiring.

**What must not be stored here:** Vendor credentials (reference the vault via `.env.example`), business/workflow decision logic (→ `src/backend/`).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Integration Engineering]

**Main dependencies:** `mcp/`, `asyncapi/`, `docs/07-mcp-integrations/integration-adapter-catalog.md`.

**Related documents:** [docs/01-architecture/integration-architecture.md](../../docs/01-architecture/integration-architecture.md)

**Status:** Initial scaffold — details to be added during implementation.
