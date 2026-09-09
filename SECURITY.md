# Security Policy

> Status: Initial scaffold — details to be added during implementation.

## Reporting a vulnerability

Report suspected security vulnerabilities privately to: **[TENANT_CONFIGURATION_REQUIRED — security contact email/alias]**.

**Do not report vulnerabilities in public GitHub issues, discussions, or pull requests.** Public issues are for confirmed, non-sensitive bugs only.

Include: a description of the issue, steps to reproduce (using fake/demo data only), potential impact, and any suggested mitigation. You will receive an acknowledgment within [TENANT_CONFIGURATION_REQUIRED — e.g. 2 business days].

## Supported versions

| Version/branch | Supported |
|---|---|
| `main` | Yes |
| [TENANT_CONFIGURATION_REQUIRED — other maintained branches] | [TENANT_CONFIGURATION_REQUIRED] |

## Reporting PII or secret exposure

If you discover real candidate/employee PII, a secret, or a credential committed to this repository or exposed by a running environment:

1. Do not copy, forward, or further distribute the exposed data.
2. Report immediately to the security contact above and to [TENANT_CONFIGURATION_REQUIRED — Privacy/Legal contact].
3. Do not attempt to remediate (e.g., force-push history rewrite) yourself — follow the incident response process in `docs/05-security-governance/incident-response-runbook.md`.

## Reporting prompt-injection or unsafe agent behavior

If you observe an AI agent/skill behaving outside the boundaries in `CLAUDE.md` (e.g., appearing to bypass an approval gate, following an embedded instruction from untrusted content, or making an unscoped tool call), report it as a security issue using the process above — treat it with the same severity as a traditional vulnerability. See `docs/05-security-governance/prompt-injection-defense.md` and `docs/06-ai-agents-rag/red-team-plan.md`.

## Secure development expectations

- Follow `.claude/rules/security.md` and `docs/05-security-governance/security-architecture.md`.
- No secrets, tokens, or credentials in source control — use the secret vault referenced in `.env.example`.
- Dependencies are scanned in CI (`.github/workflows/security-scan.yml`); do not suppress a finding without documented justification and a tracked follow-up.
- Any new sensitive action requires an authorization check, an audit event, and (if it affects a hiring/employment decision) a human-approval gate.

## Dependency vulnerability process

1. Automated scanning flags a vulnerable dependency in CI.
2. Triage severity; Critical/High block merge/release per `docs/10-delivery/ci-cd-quality-gates.md`.
3. Upgrade or apply a documented mitigation; if neither is immediately possible, record an accepted-risk entry with an owner and review date.

## Related documents

[CONTRIBUTING.md](CONTRIBUTING.md) · [docs/05-security-governance/](docs/05-security-governance/) · [.github/workflows/security-scan.yml](.github/workflows/security-scan.yml)
