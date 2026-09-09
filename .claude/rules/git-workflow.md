# Rule: Git Workflow

- Never commit secrets, tokens, credentials, or real candidate/employee data — check staged changes before committing, not just the diff you intended.
- Branch naming: `feature/<short-description>`, `fix/<short-description>`, `docs/<short-description>`, `chore/<short-description>`, `security/<short-description>`.
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `security:` — one logical change per commit, not a batch of unrelated edits.
- Prefer several small, focused commits over one large one; each should build and pass tests where practical.
- A pull request that changes behavior updates documentation, contracts (OpenAPI/AsyncAPI), and tests in the same PR — never as a promised follow-up.
- Never rewrite shared/published Git history: no `git push --force` to `main` or other shared branches, no interactive rebase of commits others have already pulled.
- Never skip a required CI/CD check to merge faster; if a check is broken, fix it or get an explicit, documented exception.
- Changes to `CLAUDE.md` or `.claude/rules/` go through the same PR review as any other change — no direct edits.
- Follow the pull request checklist in `.github/pull_request_template.md` before requesting review.
