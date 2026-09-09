# Error Handling and Problem Details

> Title: Error Handling and Problem Details | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — API Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security

## Purpose and scope

Defines the mandatory error response format (RFC 7807 Problem Details) and handling for standard HTTP status codes, ensuring no PII leaks through error responses.

## Problem Details structure

```json
{
  "type": "https://errors.hr-automation.invalid/tan-approval-conflict",
  "title": "TAN approval conflict",
  "status": 409,
  "detail": "TAN TAN-2026-000123 was modified by another user. Refresh and retry.",
  "instance": "/v1/tans/9c3e.../approve",
  "correlationId": "b3f1c2b0-...",
  "errors": []
}
```

| Field | Notes |
|---|---|
| `type` | Stable URI identifying the error category (does not need to resolve publicly) |
| `title` | Short, human-readable, generic — never includes candidate/employee names or content |
| `status` | HTTP status code |
| `detail` | Actionable, generic guidance — no PII, no internal stack traces |
| `instance` | Request path (no query-string PII) |
| `correlationId` | Ties to trace/audit log for support investigation |
| `errors` | Optional array of field-level validation errors (field name + generic message only) |

## Status code handling

| Code | Meaning | Example |
|---|---|---|
| `400` | Malformed request | Invalid JSON, missing required field |
| `401` | Missing/invalid auth | Expired or invalid token |
| `403` | Authenticated but not authorized | Role lacks required scope, or ABAC scope mismatch |
| `404` | Resource not found (or caller not authorized to know it exists) | Unknown TAN ID — same response whether truly missing or cross-tenant, to avoid enumeration |
| `409` | Conflict — concurrency or invalid state transition | ETag mismatch, illegal workflow transition per [workflow-state-machine.md](../02-business-workflows/workflow-state-machine.md) |
| `422` | Semantically invalid | Business-rule validation failure (e.g., missing mandatory JD criteria) |
| `429` | Rate limited | Include `Retry-After` header |
| `5xx` | Server error | Generic message only; full detail goes to logs/traces, not the response body |

## PII-leakage prevention rules

- Never echo candidate/employee PII, document content, or compensation figures in an error message.
- Validation error messages reference field *names*, not submitted *values*, when the value could be PII (e.g., "email is invalid format," not "email 'jane.doe@...' is invalid").
- `404` responses for cross-tenant or unauthorized access are indistinguishable from true "not found" to prevent resource enumeration and tenant-boundary probing.
- Stack traces and internal exception messages are never returned to the client; they are logged server-side with the `correlationId`, redacted per [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
