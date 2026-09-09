# 07-mcp-integrations/

**Purpose:** MCP server architecture, security/authorization model, tool governance, and the integration-adapter-to-MCP-server catalog.

**What belongs here:** MCP design and governance documentation. Actual tool schemas and server manifests live in `mcp/`.

**What must not be stored here:** Access tokens, vendor credentials, or live endpoint URLs (those are environment configuration, referenced via `.env.example`).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Integration Architecture]

**Main dependencies:** `mcp/`, `src/integration-adapters/`, `docs/05-security-governance/`.

**Contents:** [mcp-architecture.md](mcp-architecture.md) · [mcp-security-and-authorization.md](mcp-security-and-authorization.md) · [mcp-tool-governance.md](mcp-tool-governance.md) · [integration-adapter-catalog.md](integration-adapter-catalog.md)

**Status:** Initial scaffold — details to be added during implementation.
