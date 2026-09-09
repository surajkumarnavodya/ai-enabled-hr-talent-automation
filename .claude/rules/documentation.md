# Rule: Documentation

- Read the root [CLAUDE.md](../../CLAUDE.md) first, then only the task-relevant detailed docs under `/docs` (progressive disclosure) — don't read the entire doc tree for a small change.
- When behavior changes, update together in the same change: OpenAPI/AsyncAPI contracts, data schema/migrations, ADRs (new or superseded), tests, and the relevant `/docs` pages. A change that touches code but not docs/tests is incomplete.
- Every significant document carries a document-control block (title, version, owner, status, last-reviewed, next-review, reviewers) and a change-control table — preserve this format when editing existing docs and include it in any new doc.
- Use `[LEGAL_REVIEW_REQUIRED]` for anything resembling a legal/compliance claim and `[TENANT_CONFIGURATION_REQUIRED]` for anything organization-specific — never invent a legal requirement or company policy.
- All examples in documentation use fake/demo data only.
- Cross-link related documents rather than duplicating content; if the same fact needs to live in two places, link one to the other instead of copying.
- Update [GENERATED_FILES.md](../../GENERATED_FILES.md) when adding, removing, or renaming a file in this repository.
