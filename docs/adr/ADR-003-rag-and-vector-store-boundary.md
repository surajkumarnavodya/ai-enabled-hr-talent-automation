# ADR-003: RAG and Vector Store Boundary

> Title: ADR-003 | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Architecture] | Status: Accepted | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, Security, AI Governance

## Context

The platform uses retrieval-augmented generation (RAG) to ground AI answers about policy, JD interpretation, and process questions. There is a risk of the vector store becoming a de-facto second source of truth (e.g., if workflow status or offer content were ever indexed and queried instead of the relational database), which would break auditability and consistency guarantees.

## Decision

The vector store holds **only approved retrieval content** — policy documents, JD reference material, process documentation, and similar knowledge artifacts explicitly ingested for RAG. It **never** stores or is queried for: workflow status, offer details, approval history, or employee records. Those remain exclusively in the relational system of record ([ADR-001](ADR-001-transactional-system-of-record.md)). Raw candidate identity documents and confidential interview feedback are never indexed by default (see [rag-architecture.md](../06-ai-agents-rag/rag-architecture.md) and [rag-ingestion-and-chunking.md](../06-ai-agents-rag/rag-ingestion-and-chunking.md)). Every retrieval is filtered by metadata ACL (tenant, classification, access policy) **before** similarity search, and answers must cite retrieved sources or return a "no-answer" fallback.

## Alternatives considered

1. **Index workflow/offer data for conversational query ("ask the AI what's the status of TAN-123")** — rejected: would create a stale/inconsistent second source of truth; status queries must hit the relational API directly.
2. **Single shared vector index across tenants with app-layer filtering only** — rejected: insufficient isolation guarantee; metadata ACL filtering must occur at the query layer with tenant-scoped indices or namespaces as defense in depth.
3. **No RAG at all (rely solely on model parametric knowledge for policy questions)** — rejected: unacceptable hallucination risk for policy-sensitive answers.

## Consequences

- Positive: clear boundary keeps the relational DB authoritative; RAG failures degrade gracefully (no-answer) without corrupting workflow data; vector store is fully rebuildable from source documents, simplifying DR ([resilience-and-disaster-recovery.md](../01-architecture/resilience-and-disaster-recovery.md)).
- Negative: status-like questions cannot be answered purely conversationally from the vector store; must be routed to a structured API call instead.

## Status

Accepted.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
