# mcp/ — MCP Server Manifests and Tool Schemas

**Purpose:** Tool schemas, server manifests, and integration documentation for every isolated MCP server (calendar, email, HRMS, e-signature, document management, background verification, payroll, IT provisioning).

**What belongs here:** Tool manifest JSON Schemas (`tool-schemas/`), server registry/documentation (`servers/`), and tool-use prompt fragments (`prompts/`).

**What must not be stored here:** Access tokens, OAuth client secrets, or live vendor credentials — see `.env.example` for the environment-variable reference pattern instead.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Integration Architecture]

**Main dependencies:** `docs/07-mcp-integrations/`, `src/integration-adapters/`, `.claude/rules/ai-agents.md`.

**Subfolders:** [servers/](servers/) · [tool-schemas/](tool-schemas/) · [prompts/](prompts/)

**Status:** Initial scaffold — architecture and schema populated; no server implementations yet.
