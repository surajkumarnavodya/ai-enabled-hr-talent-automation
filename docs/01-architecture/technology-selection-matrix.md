# Technology Selection Matrix

> Title: Technology Selection Matrix | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security, Platform

## Purpose and scope

Documents the default reference technology for each platform capability, with alternatives, configuration key, and selection criteria. **No technology below is a hard dependency** unless recorded as fixed in an ADR under `docs/adr/`. This avoids vendor lock-in language beyond what's explicitly decided.

## Matrix

### Frontend

- **Purpose:** Recruiter/HR web app and candidate secure portal.
- **Default:** React or Next.js.
- **Alternatives:** Angular, Vue, server-rendered .NET Razor.
- **Configuration key:** `platform.frontend.framework`
- **Security considerations:** CSP headers, XSS/CSRF protection, no PII in client-side storage beyond session needs.
- **Operational considerations:** CDN hosting, cache invalidation strategy.
- **Selection criteria:** Team skill set, SSR/SEO needs (minimal for internal tool), component ecosystem.

### Core HR API

- **Purpose:** Command/query surface, workflow orchestration entry point.
- **Default:** ASP.NET Core (.NET 10+).
- **Alternatives:** Node.js/NestJS, Java/Spring Boot, Python/FastAPI.
- **Configuration key:** `platform.core_api.runtime`
- **Security considerations:** Built-in OIDC middleware, model validation, output encoding.
- **Operational considerations:** Container base image patching cadence, health/readiness probes.
- **Selection criteria:** Team skill set, performance needs, existing enterprise standards.

### Agent service

- **Purpose:** Hosts supervisor + specialist AI skills, tool-calling, guardrails.
- **Default:** Python with LangGraph/LangChain or Microsoft Semantic Kernel.
- **Alternatives:** .NET-native orchestration (Semantic Kernel .NET), custom orchestration.
- **Configuration key:** `platform.agent_service.framework`
- **Security considerations:** Sandboxed tool execution, strict output schema validation, prompt-injection defenses (see [prompt-injection-defense.md](../05-security-governance/prompt-injection-defense.md)).
- **Operational considerations:** Separate scaling/bulkhead from Core API; model provider failover.
- **Selection criteria:** Ecosystem maturity for agent orchestration, observability hooks, team skill set.

### Relational database

- **Purpose:** Transactional system of record.
- **Default:** PostgreSQL or Microsoft SQL Server.
- **Alternatives:** MySQL, other enterprise RDBMS.
- **Configuration key:** `platform.database.engine`
- **Security considerations:** Row-level security (tenant isolation), encryption at rest, least-privilege DB roles.
- **Operational considerations:** Managed-service failover, backup/restore cadence, migration tooling (see [database-migration-strategy.md](../03-data/database-migration-strategy.md)).
- **Selection criteria:** Existing enterprise standard, managed-service availability in target cloud, row-level security support.

### Cache and distributed locks

- **Purpose:** Caching reference data, distributed locking (e.g., dedupe/idempotency), rate-limit counters.
- **Default:** Redis.
- **Alternatives:** Memcached (cache-only, no locking), cloud-native cache services.
- **Configuration key:** `platform.cache.provider`
- **Security considerations:** AUTH/TLS enabled, no PII cached beyond short TTL where unavoidable.
- **Operational considerations:** Eviction policy, persistence mode (AOF/RDB) if used for locks.
- **Selection criteria:** Latency requirements, existing infra.

### Object storage

- **Purpose:** Documents, CVs, offer letters, Green Form uploads.
- **Default:** Azure Blob Storage, AWS S3, or equivalent.
- **Alternatives:** GCS, on-prem S3-compatible storage (MinIO).
- **Configuration key:** `platform.object_storage.provider`
- **Security considerations:** Server-side encryption (customer-managed key option), signed URLs with short TTL, virus scanning on upload (see [secure-file-upload-policy.md](../05-security-governance/secure-file-upload-policy.md)).
- **Operational considerations:** Lifecycle policies for retention/deletion, versioning.
- **Selection criteria:** Cloud provider alignment, compliance certifications.

### Vector retrieval

- **Purpose:** Approved-content retrieval for RAG (policy, JD grounding) — never workflow system of record.
- **Default:** Azure AI Search, pgvector, Qdrant, Pinecone, or Weaviate.
- **Alternatives:** Any ANN-capable store meeting metadata-filtering requirements.
- **Configuration key:** `rag.vector_store.provider`
- **Security considerations:** Metadata ACL filtering before retrieval, tenant-scoped indices, no raw PII embedded by default (see [rag-architecture.md](../06-ai-agents-rag/rag-architecture.md)).
- **Operational considerations:** Re-embedding on model/version change, index rebuild strategy.
- **Selection criteria:** Hybrid search support, metadata filtering, existing DB co-location (pgvector) vs. dedicated service trade-off.

### Identity

- **Purpose:** Authentication and token issuance.
- **Default:** Entra ID / OAuth 2.1 / OpenID Connect-compatible provider.
- **Alternatives:** Okta, Auth0, Keycloak.
- **Configuration key:** `platform.identity.provider`
- **Security considerations:** Short-lived tokens, MFA enforcement, conditional access policies.
- **Operational considerations:** SSO integration with existing enterprise IdP.
- **Selection criteria:** Existing enterprise IdP, OIDC compliance.

### API gateway

- **Purpose:** Ingress, auth enforcement, rate limiting, routing.
- **Default:** Azure API Management, Kong, NGINX, or equivalent.
- **Alternatives:** AWS API Gateway, Apigee.
- **Configuration key:** `platform.api_gateway.provider`
- **Security considerations:** WAF integration, TLS termination, request size limits.
- **Operational considerations:** Rate-limit and quota configuration per tenant.
- **Selection criteria:** Cloud alignment, plugin ecosystem (auth, rate limiting).

### Messaging

- **Purpose:** Async event delivery for workflow-to-downstream propagation.
- **Default:** Azure Service Bus, RabbitMQ, Kafka, or equivalent.
- **Alternatives:** AWS SQS/SNS, Google Pub/Sub.
- **Configuration key:** `platform.messaging.provider`
- **Security considerations:** Encrypted transport, per-topic access control.
- **Operational considerations:** DLQ configuration, consumer-group scaling.
- **Selection criteria:** Ordering guarantees needed, throughput, existing infra.

### Observability

- **Purpose:** Traces, metrics, structured logs, dashboards, alerting.
- **Default:** OpenTelemetry + centralized logging/metrics/tracing backend and dashboard/alerting platform.
- **Alternatives:** Datadog, New Relic, Azure Monitor, Grafana/Prometheus/Loki/Tempo stack.
- **Configuration key:** `platform.observability.backend`
- **Security considerations:** Redaction before export (see [logging-and-redaction-standard.md](../08-operations-observability/logging-and-redaction-standard.md)).
- **Operational considerations:** Sampling rates, retention, cost.
- **Selection criteria:** Existing enterprise standard, OTel-native support.

### Deployment

- **Purpose:** Container orchestration.
- **Default:** Docker and Kubernetes, cloud provider configurable.
- **Alternatives:** Serverless containers (ACA, Cloud Run, Fargate) for lower-scale components.
- **Configuration key:** `platform.deployment.orchestrator`
- **Security considerations:** Network policies, pod security standards, image scanning.
- **Operational considerations:** Autoscaling, rolling/blue-green/canary deploys.
- **Selection criteria:** Team ops maturity, scale needs.

### Infrastructure as Code

- **Purpose:** Reproducible environment provisioning.
- **Default:** Terraform, Bicep, Pulumi, or equivalent.
- **Alternatives:** CloudFormation, Ansible (config management, complementary).
- **Configuration key:** `platform.iac.tool`
- **Security considerations:** State file encryption, least-privilege provisioning credentials.
- **Operational considerations:** Module reuse across environments, drift detection.
- **Selection criteria:** Cloud alignment, team skill set.

### CI/CD

- **Purpose:** Build, test, security scan, deploy pipeline.
- **Default:** GitHub Actions, Azure DevOps, GitLab CI, or equivalent.
- **Alternatives:** Jenkins, CircleCI.
- **Configuration key:** `platform.cicd.provider`
- **Security considerations:** Signed artifacts, secret-scanning, mandatory quality gates (see [ci-cd-quality-gates.md](../10-delivery/ci-cd-quality-gates.md)).
- **Operational considerations:** Pipeline-as-code, environment promotion approvals.
- **Selection criteria:** Existing enterprise standard, integration with chosen source control.

### E-signature

- **Purpose:** Offer letter execution.
- **Default:** Configurable vendor adapter (e.g., DocuSign, Adobe Sign — vendor TBD).
- **Alternatives:** Any vendor supporting webhook callbacks and audit trail export.
- **Configuration key:** `integrations.esignature.vendor`
- **Security considerations:** Webhook signature verification (see [webhook-security.md](../04-api/webhook-security.md)).
- **Operational considerations:** Template versioning, callback retry handling.
- **Selection criteria:** Legal enforceability in target jurisdictions [LEGAL_REVIEW_REQUIRED], procurement preference.

### Calendar and email

- **Purpose:** Interview scheduling, notifications.
- **Default:** Configurable Microsoft 365, Google Workspace, or SMTP adapter.
- **Alternatives:** Any calendar/email API with OAuth support.
- **Configuration key:** `integrations.calendar_email.provider`
- **Security considerations:** OAuth scopes limited to calendar/mail-send only.
- **Operational considerations:** Rate limits per provider.
- **Selection criteria:** Existing enterprise productivity suite.

### MCP

- **Purpose:** Isolated, authenticated access to approved external tools/systems for agents.
- **Default:** One MCP server per external system domain (calendar, email, HRMS, e-signature, document management, background verification, payroll, IT provisioning).
- **Alternatives:** N/A — pattern is fixed per [ADR-004](../adr/ADR-004-mcp-security-model.md); vendor behind each server is configurable.
- **Configuration key:** `mcp.servers.*`
- **Security considerations:** OAuth 2.1, short-lived credentials, tool-level scopes — see [mcp-security-and-authorization.md](../07-mcp-integrations/mcp-security-and-authorization.md).
- **Operational considerations:** Independent scaling/versioning per server.
- **Selection criteria:** N/A (architectural pattern, not a vendor choice).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
| 1.1 | 2026-09-09 | Platform upgrade — Phase 2 (Claude Code) | Updated stated backend default from ASP.NET Core (.NET 8+) to (.NET 10+); see [platform-upgrade-gap-analysis.md](../09-quality-evaluation/platform-upgrade-gap-analysis.md) |
