# Identity and Access Control

> Title: Identity and Access Control | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Security Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Security, Architecture, HR

## Purpose and scope

Defines RBAC and ABAC controls implementing the roles in [personas-and-roles.md](../00-product/personas-and-roles.md) and the scopes in [hr-onboarding-api.openapi.yaml](../../openapi/hr-onboarding-api.openapi.yaml).

## RBAC model

Roles carry a fixed set of scopes (see the OpenAPI `securitySchemes.oauth2.flows.authorizationCode.scopes` list). Role-to-scope mapping is configuration, not code — see `config/tenants/sample-tenant.yaml`.

## ABAC model

Every request additionally carries attribute context evaluated against the resource: `tenant_id`, `department`, `location`, `business_unit`, `grade`. A `recruiter` role, for example, is further scoped to the departments/locations they are assigned (`user_role_assignment.scope` in [sample-relational-schema.sql](../03-data/sample-relational-schema.sql)).

## Access matrix (role × sensitive action)

| Role | TAN approve | Shortlist approve | Offer approve | Discrepancy resolve | Employee convert | Audit read |
|---|---|---|---|---|---|---|
| `recruiter` | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `hiring_manager` | ✗ | Configurable (co-approve) | ✗ | ✗ | ✗ | ✗ |
| `hr_approver` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `interviewer` | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `hr_ops` | ✗ | ✗ | ✗ | ✗ (request re-upload only) | ✗ | ✗ |
| `compliance_reviewer` | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| `platform_admin` | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| `agent_service_principal` | ✗ (may propose only) | ✗ (may propose only) | ✗ (may draft only) | ✗ | ✗ | ✗ |

## Authentication requirements

- OAuth 2.1 / OIDC via the configured identity provider ([technology-selection-matrix.md](../01-architecture/technology-selection-matrix.md)).
- MFA required for `hr_approver`, `platform_admin`, and `compliance_reviewer` roles — [TENANT_CONFIGURATION_REQUIRED] enforcement point (IdP conditional access policy).
- Candidate-facing flows (offer acceptance, Green Form) use short-lived, single-purpose tokens scoped to one resource, not a full account session.
- Service-to-service and agent calls use service principals / managed identities, never shared static API keys.

## Session and token handling

Access tokens are short-lived (default 15 minutes — [TENANT_CONFIGURATION_REQUIRED]); refresh tokens rotate on use. Tokens are never logged (see [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
