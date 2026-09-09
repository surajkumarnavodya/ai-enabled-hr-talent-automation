# Scope, Assumptions, and Open Questions Register

> Title: Scope, Assumptions, and Open Questions | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft (living document) | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, Architecture, Security, Legal, HR

## Purpose and scope

Single register of what is explicitly in/out of scope, all assumptions made while authoring this documentation package, and all open questions requiring a decision before or during implementation. Update this file whenever a decision is made — do not let decisions live only in chat/meeting notes.

## In scope

- CV Bank ingestion, TAN lifecycle, AI-assisted matching, interview lifecycle (L1/L2/client), offer lifecycle, Green Form, document verification and discrepancy handling, employee conversion, downstream integration triggers.
- Configuration schema and defaults for all of the above.
- Security, privacy, fairness, and AI-governance controls for the workflow.

## Out of scope (this phase)

- Application source code and infrastructure provisioning.
- Final selection of cloud provider, database engine, vector store, and messaging bus (tracked as ADRs when decided).
- Compensation-band determination logic and content (policy input only).
- Legal text of offer letters/employment contracts.
- Any autonomous AI decision-making on hiring/employment outcomes.

## Assumptions

| ID | Assumption | Impact if wrong |
|---|---|---|
| A-01 | Each tenant maps to one legal entity with its own workflow/approval configuration | Tenant isolation model would need multi-entity-per-tenant support |
| A-02 | A relational database is available as system of record (Postgres or SQL Server) | Data architecture and sample schema would need re-targeting |
| A-03 | Candidates interact via a secure external link (Green Form), not a full portal login | Identity model for candidates would need to expand |
| A-04 | Background verification is performed by a third party via MCP adapter, not built in-house | MCP tool catalog and adapter contract would change |
| A-05 | Offer letter e-signature is via a configurable third-party vendor | Document/e-sign data model would need vendor-specific fields |

## Decisions pending ([TENANT_CONFIGURATION_REQUIRED] / [LEGAL_REVIEW_REQUIRED])

| ID | Question | Owner | Needed by |
|---|---|---|---|
| Q-01 | Final relational DB engine (PostgreSQL vs. SQL Server) per environment | Architecture | Before schema finalization |
| Q-02 | Vector store choice per tenant (pgvector / Azure AI Search / Qdrant / Pinecone / Weaviate) | Architecture | Before RAG implementation |
| Q-03 | Data residency and cross-border transfer rules | Legal | Before go-live |
| Q-04 | Candidate data retention periods post-rejection and post-employment | Legal/HR | Before retention config finalization |
| Q-05 | Background verification vendor(s) and scope of checks | HR/Legal | Before BGV MCP adapter build |
| Q-06 | E-signature vendor | HR/Procurement | Before offer-service build |
| Q-07 | Compensation-band/grade policy source of truth | HR | Before offer-generation logic |
| Q-08 | Definition of "protected characteristics" per jurisdiction | Legal | Before fairness-governance finalization |
| Q-09 | SLA targets per workflow stage per tenant | HR Operations | Before SLA config finalization |
| Q-10 | Legal basis and process for candidate right-to-erasure requests | Legal | Before privacy-handling finalization |

## Risks

See [docs/05-security-governance/threat-model.md](../05-security-governance/threat-model.md) and [docs/10-delivery/backlog-epics-and-user-stories.md](../10-delivery/backlog-epics-and-user-stories.md) for risk registers scoped to security and delivery respectively.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
