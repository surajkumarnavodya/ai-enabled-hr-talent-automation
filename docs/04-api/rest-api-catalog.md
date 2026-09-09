# REST API Catalog

> Title: REST API Catalog | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — API Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Product, Security

## Purpose and scope

Human-readable index of the endpoints formally defined in [hr-onboarding-api.openapi.yaml](../../openapi/hr-onboarding-api.openapi.yaml). Required scopes align to roles in [personas-and-roles.md](../00-product/personas-and-roles.md); approval-gated endpoints are cross-referenced to [human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md).

## Endpoint catalog

| Method | Path | Purpose | Required scope | Approval-gated? |
|---|---|---|---|---|
| POST | `/v1/cvs` | Upload CV(s), initiate parsing | `cv:write` | No |
| GET | `/v1/cvs/{cvId}` | Read CV metadata/extraction status | `cv:read` | No |
| GET | `/v1/candidates` | Search candidates in CV Bank | `candidate:read` | No |
| GET | `/v1/candidates/{candidateId}` | Read candidate profile | `candidate:read` | No |
| POST | `/v1/tans` | Create TAN + JD | `tan:write` | No (approval is a separate step) |
| GET | `/v1/tans/{tanId}` | Read TAN | `tan:read` | No |
| PATCH | `/v1/tans/{tanId}` | Update TAN/JD (pre-approval only) | `tan:write` | No |
| POST | `/v1/tans/{tanId}/approve` | Approve TAN | `tan:approve` | **Yes** |
| POST | `/v1/tans/{tanId}/matches` | Trigger AI matching run | `matching:execute` | No |
| GET | `/v1/tans/{tanId}/matches` | Read ranked, explainable recommendations | `matching:read` | No |
| POST | `/v1/applications/{applicationId}/shortlist-approval` | Approve/reject shortlist | `shortlist:approve` | **Yes** |
| POST | `/v1/applications/{applicationId}/interviews` | Schedule interview | `interview:write` | No |
| PATCH | `/v1/interviews/{interviewId}` | Reschedule/cancel interview | `interview:write` | No |
| POST | `/v1/interviews/{interviewId}/feedback` | Submit structured feedback | `interview:feedback` | No (feedback itself is the human decision record) |
| POST | `/v1/applications/{applicationId}/progression-decision` | Confirm progression (L1→L2, L2→client, etc.) | `application:progress` | **Yes** (final selection step) |
| POST | `/v1/applications/{applicationId}/offers` | Create draft offer | `offer:write` | No |
| POST | `/v1/offers/{offerId}/approve` | Approve offer | `offer:approve` | **Yes** |
| POST | `/v1/offers/{offerId}/send` | Send approved offer | `offer:send` | No (system action, gated by prior approval) |
| POST | `/v1/offers/{offerId}/acceptance` | Record candidate acceptance/decline | `offer:respond` (candidate-scoped token) | No |
| POST | `/v1/offers/{offerId}/green-form` | Issue Green Form link | `green_form:issue` | No |
| GET | `/v1/green-forms/{greenFormId}` | Read Green Form status | `green_form:read` | No |
| POST | `/v1/green-forms/{greenFormId}/submissions` | Candidate submits data/documents | `green_form:submit` (candidate-scoped token) | No |
| POST | `/v1/documents/{documentId}/verify` | Trigger/read verification | `document:verify` | No |
| POST | `/v1/documents/{documentId}/reupload-request` | Request re-upload/clarification | `document:request_reupload` | No |
| POST | `/v1/discrepancies` | Create discrepancy record | `discrepancy:write` | No |
| GET | `/v1/discrepancies/{discrepancyId}` | Read discrepancy | `discrepancy:read` | No |
| POST | `/v1/discrepancies/{discrepancyId}/resolve` | Close/grant exception | `discrepancy:resolve` | **Yes** |
| POST | `/v1/applications/{applicationId}/employee-conversion` | Convert to employee, issue Employee ID | `employee:convert` | **Yes** |
| GET | `/v1/workflow/{subjectType}/{subjectId}/status` | Read current workflow status | `workflow:read` | No |
| GET | `/v1/audit-log` | Query audit log | `audit:read` | No (read-only, restricted to compliance/HR approver roles) |
| GET | `/v1/evaluations/{runId}` | Read AI evaluation run status | `evaluation:read` | No |

## Cross-references

Full contract: [hr-onboarding-api.openapi.yaml](../../openapi/hr-onboarding-api.openapi.yaml). Events emitted alongside these calls: [hr-onboarding-events.asyncapi.yaml](../../asyncapi/hr-onboarding-events.asyncapi.yaml).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
