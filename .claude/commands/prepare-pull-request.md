---
description: Prepare the current branch for a pull request
---

## Command name

`/prepare-pull-request`

## Intent

Get a branch into a reviewable, mergeable state: correct branch name, clean commit history, updated contracts/docs/tests, and a filled-out PR description — without requiring the human to remember every checklist item from `CONTRIBUTING.md`.

## Required inputs

- The branch's intended change summary (if not already obvious from the diff).
- Confirmation of the target base branch (default `main`).

## Preconditions

- The change is functionally complete for this PR's scope (not a mid-refactor snapshot).
- No uncommitted local-only files (`.env`, `CLAUDE.local.md`, `.claude/settings.local.json`) are staged.

## Steps Claude should perform

1. Run `git status` and `git diff` to review everything about to be included.
2. Verify the branch name follows the convention in `.claude/rules/git-workflow.md`; flag (don't silently rename) if it doesn't.
3. Check whether the diff touches: API/event shapes (→ `openapi/`/`asyncapi/` must be updated), workflow state transitions (→ tests required), configurable values (→ `config/schemas/` + `config/defaults/` updated), or an architectural decision (→ ADR needed).
4. Verify no secrets, tokens, or real candidate/employee data appear in the diff.
5. Run the available build/test/validation commands from `CLAUDE.md` "Validation Commands" and report results — do not fabricate a pass if a command is still a placeholder.
6. Draft a PR description following `.github/pull_request_template.md`, with the checklist honestly reflecting what was and wasn't done.
7. List any human approvals required (Security, AI Governance, HR) per the nature of the change.

## Files expected to change

None by default — this command reviews and reports. It may propose edits to documentation/tests it finds missing, but should ask before making non-trivial code changes outside the PR's stated scope.

## Validation checklist

- [ ] Branch name matches convention.
- [ ] No secrets/PII/real candidate data in the diff.
- [ ] Contracts, config schemas, docs, and tests updated where the diff requires it.
- [ ] Build and available tests pass.
- [ ] PR description drafted with an honest checklist.

## Output format

A short report: branch readiness (ready / not ready + why), the drafted PR title and description, and a bullet list of any follow-up items the human should address before opening the PR.

## Human approvals required

None to run this command itself. The command's output may identify approvals needed for the underlying change (e.g., Security sign-off) — surface these, don't seek them yourself.

## Failure/rollback considerations

If validation commands fail, report the failure clearly and do not proceed to draft a "ready" PR description. If the diff includes something that looks like a secret or real PII, stop immediately and flag it rather than continuing preparation.
