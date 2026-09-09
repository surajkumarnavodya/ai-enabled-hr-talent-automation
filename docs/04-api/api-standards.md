# API Standards

> Title: API Standards | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — API Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security

## Purpose and scope

Defines mandatory conventions for every REST API in the platform, implemented in [hr-onboarding-api.openapi.yaml](../../openapi/hr-onboarding-api.openapi.yaml). Complements [error-handling-and-problem-details.md](error-handling-and-problem-details.md), [versioning-and-deprecation-policy.md](versioning-and-deprecation-policy.md), and [webhook-security.md](webhook-security.md).

## Conventions

| Concern | Standard |
|---|---|
| Style | REST over HTTPS, JSON bodies, resource-oriented URLs |
| Versioning | URL path versioning (`/v1/...`); see [versioning-and-deprecation-policy.md](versioning-and-deprecation-policy.md) |
| Auth | OAuth 2.1 / OIDC bearer tokens; scopes map to roles in [personas-and-roles.md](../00-product/personas-and-roles.md) |
| Tenant scoping | `X-Tenant-Id` header **or** tenant claim in token (configurable which is authoritative — token claim preferred) |
| Idempotency | `Idempotency-Key` header required on all state-mutating (`POST`/`PATCH`) endpoints with side effects |
| Concurrency | `ETag` response header + `If-Match` request header for updates; mismatch → `409 Conflict` |
| Correlation | `X-Correlation-Id` header, propagated to all downstream calls and the audit log |
| Pagination | Cursor-based (`?page_size=&page_token=`), response includes `next_page_token` |
| Filtering/sorting | `?filter=field:value` (allow-listed fields only), `?sort=field,-field2` |
| Errors | RFC 7807 Problem Details — see [error-handling-and-problem-details.md](error-handling-and-problem-details.md) |
| PII in errors | Never included — see [error-handling-and-problem-details.md](error-handling-and-problem-details.md) |
| Rate limiting | Per-tenant, per-client token bucket; `429` with `Retry-After` header |

## Request/response conventions

- All timestamps: ISO 8601 UTC.
- All monetary/compensation fields: referenced by ID into the compensation system, never inlined as editable free text (see [ADR-002](../adr/ADR-002-agent-orchestration-pattern.md) rationale).
- All list responses wrap items in `{ "items": [...], "next_page_token": "..." }`.
- Every mutating endpoint that can trigger a sensitive action (Section 5, CLAUDE.md) validates the caller's role against [human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md) server-side — never trusts client-supplied role claims alone without the matrix check.

## Security headers (see [security-architecture.md](../05-security-governance/security-architecture.md))

`Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy` (on any HTML-serving endpoint), no caching of responses containing PII (`Cache-Control: no-store`).

## Assumptions and dependencies

Assumes an API gateway terminates TLS and enforces coarse-grained auth/rate-limiting before requests reach the HR Core API (see [technology-selection-matrix.md](../01-architecture/technology-selection-matrix.md)).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
