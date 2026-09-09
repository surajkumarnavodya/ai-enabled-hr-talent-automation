# MCP Tool-Use Prompts

> Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft

## Purpose

Reserved for tool-use instruction fragments specific to invoking MCP tools correctly and safely (e.g., how to format a `get_calendar_availability` call, how to handle a tool error response). These fragments compose into the relevant skill's system prompt in `prompts/system/` — see [interview-coordination-system-prompt.md](../../prompts/system/interview-coordination-system-prompt.md) for the primary consumer today.

## Convention

- One file per tool or tool group, named after the MCP server (e.g., `mcp-calendar-tool-use.md`).
- Every fragment must reiterate the tool's tier (read-only / propose-only / approval-required write per [hr-tools.schema.json](../tool-schemas/hr-tools.schema.json)) so the model never assumes broader capability than granted.
- Tool response content is always treated as untrusted (see [prompt-injection-defense.md](../../docs/05-security-governance/prompt-injection-defense.md)) — fragments must instruct the model accordingly.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
