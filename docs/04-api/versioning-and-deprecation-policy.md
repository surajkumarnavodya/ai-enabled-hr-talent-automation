# Versioning and Deprecation Policy

> Title: Versioning and Deprecation Policy | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — API Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Product

## Purpose and scope

Defines how REST APIs ([hr-onboarding-api.openapi.yaml](../../openapi/hr-onboarding-api.openapi.yaml)) and events ([hr-onboarding-events.asyncapi.yaml](../../asyncapi/hr-onboarding-events.asyncapi.yaml)) evolve without breaking consumers.

## Versioning scheme

- REST: URL path major version (`/v1/...`). A new major version is introduced only for breaking changes.
- Events: version embedded in the event payload (`eventVersion`) and/or a versioned event type suffix; consumers must tolerate additive unknown fields.
- Config schemas: `$id`/`version` field in each JSON Schema under `config/schemas/`; schema changes follow the same additive-first principle as [database-migration-strategy.md](../03-data/database-migration-strategy.md).

## What counts as breaking

| Change | Breaking? |
|---|---|
| Add optional field to request/response | No |
| Add new endpoint/event | No |
| Add new enum value to an existing field | Potentially — treat as breaking unless consumers are documented to ignore unknown enum values |
| Remove/rename a field | Yes |
| Change a field's type or semantics | Yes |
| Change required-ness of a request field (optional → required) | Yes |
| Change an approval-gate requirement (Section 5, CLAUDE.md) | Yes — always, regardless of wire format, requires ADR + stakeholder sign-off |

## Deprecation process

1. Mark the old version/field as deprecated in the OpenAPI/AsyncAPI spec (`deprecated: true`) with a `sunset` date.
2. Announce via [notification-catalog.md](../02-business-workflows/notification-catalog.md)-equivalent developer communication channel (integration partners) — [TENANT_CONFIGURATION_REQUIRED] channel.
3. Maintain the deprecated version for a minimum deprecation window (default: 6 months — [TENANT_CONFIGURATION_REQUIRED]) with usage monitored via [metrics-slos-and-alerts.md](../08-operations-observability/metrics-slos-and-alerts.md).
4. Remove only after the window elapses and usage telemetry shows no active consumers, or after explicit stakeholder sign-off.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
