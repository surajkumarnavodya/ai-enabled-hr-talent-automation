# Environment Strategy

> Title: Environment Strategy | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — DevOps] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: DevOps, Architecture, Security

## Purpose and scope

Defines environment purpose, data policy, and promotion flow, aligned to [deployment-architecture.md](../01-architecture/deployment-architecture.md) and `config/environments/`.

## Environments

| Environment | Config file | Data policy | Access |
|---|---|---|---|
| dev | `config/environments/dev.yaml` | Synthetic/fake only | All engineers |
| test (CI) | `config/environments/test.yaml` | Synthetic, reset per run | CI system only |
| staging | `config/environments/staging.yaml` | De-identified or synthetic | Engineering, QA, HR UAT participants |
| prod | `config/environments/prod.yaml` | Real, protected data | Restricted per [identity-access-control.md](../05-security-governance/identity-access-control.md) |

## Promotion flow

`dev → test (CI, automatic) → staging (manual/scheduled promotion, gated) → prod (gated, per ci-cd-quality-gates.md)`. No environment skips a stage; hotfixes still traverse test at minimum before prod.

## Configuration promotion

Configuration changes (workflow, approval matrix, RAG, model routing) follow the same promotion flow as code — a config change is validated in staging before prod, never edited directly in prod.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
