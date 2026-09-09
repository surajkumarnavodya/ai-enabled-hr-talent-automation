# MCP Servers

> Owner: [TENANT_CONFIGURATION_REQUIRED — Integration Architecture] | Status: Draft

## Purpose

Registry of MCP server deployments for this platform. See [mcp-architecture.md](../../docs/07-mcp-integrations/mcp-architecture.md) for the architectural pattern and [mcp-tool-governance.md](../../docs/07-mcp-integrations/mcp-tool-governance.md) for onboarding/offboarding process.

## Registered servers

| Server | Status | Manifest version | Owner | Endpoint config key |
|---|---|---|---|---|
| `mcp-calendar` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_CALENDAR_ENDPOINT` |
| `mcp-email` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_EMAIL_ENDPOINT` |
| `mcp-hrms` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_HRMS_ENDPOINT` |
| `mcp-esignature` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_ESIGNATURE_ENDPOINT` |
| `mcp-document-management` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_DOCUMENT_MGMT_ENDPOINT` |
| `mcp-background-verification` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_BACKGROUND_VERIFICATION_ENDPOINT` |
| `mcp-payroll` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_PAYROLL_ENDPOINT` |
| `mcp-it-provisioning` | Planned | — | [TENANT_CONFIGURATION_REQUIRED] | `MCP_IT_PROVISIONING_ENDPOINT` |

No server implementation exists yet — this documentation package defines the architecture and governance in advance of build. Each server's tool manifest will live under `mcp/tool-schemas/` (starting with the shared [hr-tools.schema.json](../tool-schemas/hr-tools.schema.json)) and be referenced here once implemented.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
