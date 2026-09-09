# ADR-004: MCP Security Model

> Title: ADR-004 | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Security Architecture] | Status: Accepted | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Security, Architecture, AI Governance

## Context

Agents need access to external systems (calendar, email, HRMS, e-signature, document management, background verification, payroll, IT provisioning). Direct, broad credentials granted to the agent runtime would create a large blast radius if an agent is manipulated via prompt injection or a bug.

## Decision

Each external system domain is fronted by its **own isolated MCP server**, independently deployed and authenticated (OAuth 2.1 / OIDC, short-lived tokens sourced from a vault — never long-lived static credentials). Tools are classified as **read-only**, **propose-only**, or **approval-required write**; only propose-only and read-only tools may be invoked by an agent without a synchronous human confirmation step, and any write to a sensitive system (e.g., sending an offer, creating an HRMS record) requires the workflow engine to have already recorded the corresponding human approval before the MCP call is permitted. Every MCP server enforces input validation, output sanitization, network egress allowlists, per-tool scopes, timeouts, retries, circuit breakers, and full audit logging of every call. See [mcp-architecture.md](../07-mcp-integrations/mcp-architecture.md) and [mcp-security-and-authorization.md](../07-mcp-integrations/mcp-security-and-authorization.md).

## Alternatives considered

1. **Single shared MCP gateway with per-system routing but shared credentials** — rejected: a compromise of the gateway would expose all downstream systems; isolation is weaker.
2. **Direct SDK/API calls from the agent runtime, no MCP layer** — rejected: no consistent policy enforcement point for scopes, audit, or approval-gating across heterogeneous vendor SDKs.
3. **Allow agents to hold long-lived API keys for external systems** — rejected: violates least-privilege and secrets-management non-negotiables ([secrets-and-key-management.md](../05-security-governance/secrets-and-key-management.md)).

## Consequences

- Positive: blast radius of a single compromised or manipulated agent is limited to the scopes of the specific MCP tools it was granted for that task; consistent audit trail across all external integrations; independent versioning/rollback per server.
- Negative: more services to operate and secure than a single gateway; requires a defined onboarding/offboarding process per MCP server (see [mcp-tool-governance.md](../07-mcp-integrations/mcp-tool-governance.md)).

## Status

Accepted.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
