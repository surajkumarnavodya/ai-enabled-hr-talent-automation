# Retrieval and Grounding Policy

> Title: Retrieval and Grounding Policy | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: AI Governance, Security

## Purpose and scope

Defines how retrieval is executed and how grounding/citation is enforced, building on [rag-architecture.md](rag-architecture.md).

## Retrieval pipeline

1. **Metadata ACL filtering** — applied first, before any similarity computation: tenant, classification, access policy, effective/expiry date.
2. **Hybrid search** — combines vector similarity with keyword/BM25 search to catch exact-term policy references (e.g., clause numbers) that pure embeddings may miss.
3. **Reranking** — a secondary, more precise relevance pass over the top-N hybrid results.
4. **Minimum sufficient context selection** — select the smallest set of chunks that answers the question, avoiding over-stuffing the prompt with irrelevant context (cost and accuracy benefit).
5. **Citation attachment** — every claim in the final answer must map to a specific chunk (`document_id` + `heading_path` + `page_or_clause_ref`).
6. **No-answer fallback** — if retrieval relevance is below the configured threshold (default 0.65 — see [ai-guardrails-policy.md](../05-security-governance/ai-guardrails-policy.md)), the system responds that it cannot find a grounded answer and suggests contacting HR directly, rather than guessing.

## Grounding enforcement

The model is instructed (see [hr-orchestrator-system-prompt.md](../../prompts/system/hr-orchestrator-system-prompt.md)) to answer **only** from retrieved chunks for policy questions; general parametric knowledge is not used for policy-specific claims. Output validation checks that every citation reference in the answer corresponds to an actually-retrieved chunk ID (prevents fabricated citations).

## Handling conflicting sources

If multiple retrieved chunks conflict (e.g., an outdated and a current policy version both indexed during a transition), the chunk with the latest `effective_date` not yet superseded takes precedence; the answer notes if a recent policy change may affect the response.

## Configurable items

Relevance threshold, hybrid search weighting, reranking model choice, and max context tokens are configurable via `config/schemas/rag-config.schema.json`.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
