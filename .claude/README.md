# .claude/ — Claude Code Project Configuration

> Status: Initial scaffold — details to be added during implementation.

## Purpose

This directory holds the shared, version-controlled Claude Code configuration for this repository: the conventions and commands every contributor's Claude Code session should follow.

## Committed vs. local-only

| Committed (shared, reviewed via PR) | Local-only (never committed) |
|---|---|
| `.claude/settings.json` | `.claude/settings.local.json` |
| `.claude/rules/*.md` | `CLAUDE.local.md` (repo root) |
| `.claude/commands/*.md` | |
| `.claude/skills/` | |
| `/CLAUDE.md` (repo root) | |

Local-only files are for individual machine/user overrides (e.g., personal permission grants) and are excluded in `.gitignore`. Never put project-wide instructions there — they won't be seen by teammates or CI.

## CLAUDE.md vs. rules vs. commands vs. skills

- **`/CLAUDE.md`** (repo root): the always-loaded, concise entry point — project purpose, repository map, non-negotiable rules, and pointers to deeper docs. Kept short (120-180 lines) by design.
- **`.claude/rules/*.md`**: always-loaded, topic-specific conventions (architecture, security, api, data, ai-agents, testing, documentation, git-workflow) that expand on `CLAUDE.md` without duplicating it.
- **`.claude/commands/*.md`**: specifications for discrete, repeatable tasks (e.g., `/add-api-endpoint`) — intent, inputs, steps, validation checklist, and required approvals. Not shell scripts.
- **`.claude/skills/`**: reserved for packaged, reusable instruction sets for more complex, multi-step tasks. Empty until a concrete need arises — see `.claude/skills/README.md`.

## Requirements for changes to this directory

- Keep instructions concise, current, and non-duplicative of `/docs`.
- Every change goes through a pull request and code review, same as application code — see `.claude/rules/git-workflow.md`.
- Do not add settings that grant broad tool permissions or that could exfiltrate secrets; keep `.claude/settings.json` conservative.

## Owner

[TENANT_CONFIGURATION_REQUIRED — Architecture]

## Related documents

[CLAUDE.md](../CLAUDE.md) · [CONTRIBUTING.md](../CONTRIBUTING.md)
