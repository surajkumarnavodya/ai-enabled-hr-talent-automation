---
description: Create a new Architecture Decision Record
---

Create a new ADR under `docs/adr/` following the existing pattern (see `docs/adr/ADR-001-transactional-system-of-record.md` for the format):

1. Determine the next sequential ADR number.
2. Use filename pattern `ADR-{NNN}-{kebab-case-title}.md`.
3. Include: document-control header, Context, Decision, Alternatives considered (at least 2, with rejection rationale), Consequences (positive and negative), Status, Change control table.
4. Cross-link from any `/docs` page whose guidance the new ADR affects, and update `GENERATED_FILES.md`.
5. If the ADR supersedes a prior ADR, mark the prior one's Status as "Superseded by ADR-{NNN}" rather than deleting it.

Ask the user for the decision topic and context if not already provided in the conversation.
