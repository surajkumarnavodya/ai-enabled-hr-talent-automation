# tests/rag/

**Purpose:** RAG-specific tests: retrieval grounding, citation validity, metadata ACL filtering enforcement, and no-answer fallback behavior, per `docs/06-ai-agents-rag/rag-architecture.md` and `docs/06-ai-agents-rag/retrieval-and-grounding-policy.md`.

**What belongs here:** Tests asserting retrieval never returns content outside the caller's tenant/access policy, and that answers cite only actually-retrieved chunks.

**What must not be stored here:** Real policy documents containing confidential business terms not meant for a test fixture; real candidate data.

**Owner:** Data/AI Engineering.

**Status:** Initial scaffold — details to be added during implementation.
