# Security Test Plan

> Title: Security Test Plan | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Security Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Security, QA

## Purpose and scope

Defines the security testing tiers applied before release, integrated into [test-strategy.md](../09-quality-evaluation/test-strategy.md) and [ci-cd-quality-gates.md](../10-delivery/ci-cd-quality-gates.md).

## Test tiers

| Tier | Scope | Tooling category | Cadence |
|---|---|---|---|
| Static analysis (SAST) | Source code | [TENANT_CONFIGURATION_REQUIRED — e.g. Semgrep, SonarQube] | Every PR |
| Dependency/SCA scanning | Third-party packages | [TENANT_CONFIGURATION_REQUIRED — e.g. Dependabot, Snyk, Trivy] | Every PR + daily |
| Secret scanning | Repo history and diffs | [TENANT_CONFIGURATION_REQUIRED — e.g. gitleaks, TruffleHog] | Every PR |
| Container image scanning | Built images | [TENANT_CONFIGURATION_REQUIRED — e.g. Trivy, Grype] | Every build |
| DAST | Running API in staging | [TENANT_CONFIGURATION_REQUIRED — e.g. OWASP ZAP] | Per release |
| Authorization/tenant-isolation tests | RBAC/ABAC and RLS enforcement | Custom integration test suite | Every PR touching auth/data-access code |
| Prompt-injection / AI red-team | Agent skills, RAG | See [red-team-plan.md](../06-ai-agents-rag/red-team-plan.md) | Every prompt/model version change + quarterly |
| Penetration testing | Full platform | [TENANT_CONFIGURATION_REQUIRED — external vendor] | Annually or before major release |

## OWASP-aligned checks (illustrative, non-exhaustive)

Injection, broken authentication, sensitive data exposure, XXE, broken access control, security misconfiguration, XSS, insecure deserialization, vulnerable components, insufficient logging/monitoring — mapped to specific test cases in [security-test-plan.md](security-test-plan.md) execution tooling (tracked outside this doc in the test-management system).

## Cross-tenant isolation test requirement

Every release must include an automated test that attempts to read/write another tenant's data using a valid token for a different tenant and asserts a `404`/`403`, not partial data leakage.

## Acceptance criteria for release

No open Critical/High findings from SAST/SCA/container scanning; DAST findings triaged; AI red-team suite passing at the configured threshold ([ai-evaluation-scorecard.md](../09-quality-evaluation/ai-evaluation-scorecard.md)).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
