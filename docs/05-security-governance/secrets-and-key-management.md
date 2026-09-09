# Secrets and Key Management

> Title: Secrets and Key Management | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Security Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Security, DevOps

## Purpose and scope

Defines how secrets (credentials, API keys, signing keys, encryption keys) are stored, accessed, rotated, and never exposed. See `.env.example` for the reference variable list (all secret values are references, never literals).

## Principles

- No secret is ever committed to source control, configuration YAML, or container images. `config/` files reference secrets by key (`kv://...`), never by value — enforced by the `.gitignore` rules and CI secret-scanning ([ci-cd-quality-gates.md](../10-delivery/ci-cd-quality-gates.md)).
- All secrets live in a managed vault (Azure Key Vault, AWS KMS/Secrets Manager, HashiCorp Vault, or equivalent — see [technology-selection-matrix.md](../01-architecture/technology-selection-matrix.md)).
- Services authenticate to the vault using workload identity (managed identity / IRSA / workload federation), not a static vault credential.
- Secrets are injected into the runtime environment at startup or fetched just-in-time; never written to disk or logs.

## Secret categories

| Category | Examples | Rotation cadence (default — [TENANT_CONFIGURATION_REQUIRED]) |
|---|---|---|
| Database credentials | DB user/password or managed-identity config | 90 days or on-demand upon suspected compromise |
| Object storage credentials | Storage account keys/SAS | 90 days |
| Model provider API keys | LLM provider key | 90 days |
| Identity provider client secret | OIDC client secret | 180 days |
| MCP shared auth secret | OAuth client credentials per MCP server | 90 days |
| Webhook signing secrets | Per-vendor HMAC secret | 180 days or per vendor requirement |
| Field-level encryption keys | Column encryption key | Per KMS key-rotation policy, versioned (old key retained for decrypt-only) |

## Key management for encryption

Data-encryption keys are managed by the KMS provider, with envelope encryption: a data-encryption key (DEK) encrypts the data, and a key-encryption key (KEK) in the vault encrypts the DEK. KEK rotation does not require re-encrypting all data; DEK rotation follows a scheduled re-encryption job.

## Access control on secrets

Only the specific service/workload that needs a secret is granted access (least privilege); no shared "god" credential across services. Access to read/rotate secrets is itself audited (see [audit-log-specification.md](../03-data/audit-log-specification.md)).

## Incident handling

Suspected secret compromise triggers the [incident-response-runbook.md](incident-response-runbook.md) with immediate rotation of the affected secret and audit-log review of its usage window.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
