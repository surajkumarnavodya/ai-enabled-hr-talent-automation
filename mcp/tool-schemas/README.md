# mcp/tool-schemas/

**Purpose:** JSON Schema definitions for MCP tool manifests — the contract every MCP server's tool catalog must satisfy (tool tier, input/output schema, required scopes, timeouts, retry policy).

**What belongs here:** `*.schema.json` files describing tool manifest shape.

**What must not be stored here:** Actual tool implementations, live credentials, or vendor-specific secrets.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Integration Architecture / Security]

**Contents:** [hr-tools.schema.json](hr-tools.schema.json)

**Status:** Populated.
