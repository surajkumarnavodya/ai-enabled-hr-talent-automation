# RAG Ingestion and Chunking

> Title: RAG Ingestion and Chunking | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, AI Governance

## Purpose and scope

Defines ingestion sourcing rules and chunking strategy for the RAG store described in [rag-architecture.md](rag-architecture.md).

## Ingestion sourcing rules

- Only documents explicitly submitted through an approved ingestion workflow (not arbitrary uploads) are eligible for indexing — source allow-listing reduces RAG-poisoning risk (see [threat-model.md](../05-security-governance/threat-model.md)).
- Every ingested document is versioned; superseding a document creates a new version rather than mutating the old one in place, preserving historical answer traceability.
- Raw candidate identity documents and confidential interview feedback are **excluded by default** from ingestion — see [ADR-003](../adr/ADR-003-rag-and-vector-store-boundary.md).

## Chunking strategy

- **Starting configuration:** 400–800 token chunks with 10–15% overlap, using semantic/hierarchical chunking (respecting document headings/sections rather than fixed character counts) — then tune based on measurable evaluation results (see [ai-evaluation-strategy.md](ai-evaluation-strategy.md)).
- Chunk boundaries prefer natural section/heading breaks over mid-sentence splits.
- Each chunk retains a `heading_path` (e.g., "Leave Policy > Parental Leave > Eligibility") for citation clarity.

## Required chunk metadata

| Field | Purpose |
|---|---|
| `tenant_id` | ACL filtering |
| `document_type` | e.g., `policy`, `process`, `jd_reference` |
| `version` | Traceability to source revision |
| `effective_date` / `expiry_date` | Excludes stale/not-yet-effective content from retrieval |
| `access_policy` | Role/classification-based filtering |
| `classification` | Internal/Confidential/Restricted (see [data-classification-and-retention.md](../03-data/data-classification-and-retention.md)) |
| `source` | Origin system/document ID |
| `heading_path` | Section context |
| `page_or_clause_ref` | Citation precision |
| `embedding_version` | Enables re-embedding on model upgrade without ambiguity |
| `content_hash` | Detects unintended drift/tampering between ingestion and retrieval |

## Re-embedding and versioning

Changing the embedding model requires re-embedding all active chunks under a new `embedding_version`; both versions may coexist during a transition window, with retrieval pinned to a single active version per query to avoid mixed-similarity-space results.

## Configurable items

Chunk size/overlap, allowed source types, and metadata schema extensions are configurable via `config/schemas/rag-config.schema.json` and `config/defaults/rag.default.yaml`.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
