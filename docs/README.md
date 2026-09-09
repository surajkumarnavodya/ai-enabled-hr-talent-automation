# docs/ — Documentation and Architecture Decisions

> Status: Populated — most subfolders already contain approved content from the initial documentation pass; this README is a navigation index.

## Purpose

Home for all approved product, architecture, workflow, data, security, AI/RAG, MCP, operations, quality, and delivery documentation, plus the ADR log.

## What belongs here

Markdown documentation with a document-control block (title, version, owner, status, last-reviewed, next-review, reviewers), diagrams (Mermaid), and cross-links to related docs, config, and contracts.

## What must not be stored here

- Real candidate/employee data or screenshots containing it.
- Secrets, credentials, or production endpoints.
- Source code (belongs in `src/`) or executable configuration (belongs in `config/`).

## Subfolders

| Folder | Contents |
|---|---|
| [00-product/](00-product/) | PRD, personas/roles, scope & open questions |
| [01-architecture/](01-architecture/) | Solution/component/deployment architecture, NFRs, resilience, tech selection |
| [02-business-workflows/](02-business-workflows/) | End-to-end workflow, state machine, approval matrix, SLAs, notifications, exceptions |
| [03-data/](03-data/) | Data architecture, ER diagram, data dictionary, retention, sample schema |
| [04-api/](04-api/) | API standards, endpoint catalog, error handling, versioning, webhook security |
| [05-security-governance/](05-security-governance/) | Security architecture, threat model, AI guardrails, privacy, fairness |
| [06-ai-agents-rag/](06-ai-agents-rag/) | Agent architecture, RAG, prompt management, evaluation, red-teaming |
| [07-mcp-integrations/](07-mcp-integrations/) | MCP architecture, security/authorization, tool governance |
| [08-operations-observability/](08-operations-observability/) | Observability, logging/redaction, SLOs, dashboards, runbooks, cost |
| [09-quality-evaluation/](09-quality-evaluation/) | Test strategy, acceptance criteria, test cases, AI evaluation scorecard |
| [10-delivery/](10-delivery/) | Backlog, DoR/DoD, release plan, environment strategy, CI/CD gates |
| [adr/](adr/) | Architecture Decision Records |
| [templates/](templates/) | Reusable document templates |

## Owner

[TENANT_CONFIGURATION_REQUIRED — Architecture], with each subfolder's domain owner contributing.

## Related documents

[GENERATED_FILES.md](../GENERATED_FILES.md) (full file-by-file index) · [CLAUDE.md](../CLAUDE.md) · [PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md)
