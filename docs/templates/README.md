# templates/ — Reusable Document Templates

**Purpose:** Starting points for new documents so every doc in `docs/` carries the same document-control block and structure.

**What belongs here:** Empty/skeleton templates only — no filled-in project content.

**What must not be stored here:** Actual project documentation (copy a template out into the relevant `docs/NN-topic/` folder and fill it in there).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Architecture]

**Templates available:**

| Template | Use for |
|---|---|
| [document-template.md](document-template.md) | Any general-purpose document not covered by a more specific template below |
| [architecture-document-template.md](architecture-document-template.md) | New architecture documents under `docs/01-architecture/` |
| [api-design-template.md](api-design-template.md) | Designing a new API surface before writing OpenAPI/AsyncAPI |
| [threat-model-template.md](threat-model-template.md) | New or component-specific threat models |
| [workflow-template.md](workflow-template.md) | New business workflow documentation under `docs/02-business-workflows/` |
| [adr-template.md](adr-template.md) | Mirrors `docs/adr/ADR-000-template.md` — use that file directly when creating a real ADR |

**Status:** Initial scaffold — details to be added during implementation.
