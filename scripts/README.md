# scripts/ — Developer-Experience Scripts

**Purpose:** Bootstrap and validation scripts for local development, referenced from `Makefile` and `CLAUDE.md`'s Validation Commands section.

**What belongs here:** Idempotent, safe-by-default scripts (no destructive operation without an explicit confirmation flag).

**What must not be stored here:** Embedded secrets — read from environment variables per `.env.example`. Infrastructure lifecycle scripts (cluster bootstrap, DR drills) belong in `infra/scripts/` instead.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps]

**Contents:**

| Script | Purpose |
|---|---|
| [bootstrap.sh](bootstrap.sh) / [bootstrap.ps1](bootstrap.ps1) | Copy `.env.example` → `.env`, check toolchain, restore the .NET solution, start local Docker dependencies |
| [validate-config.sh](validate-config.sh) / [validate-config.ps1](validate-config.ps1) | Validate `config/*.yaml` against `config/schemas/*.json` (best-effort; requires `python3` + `pyyaml`/`jsonschema`) |

**Related documents:** [Makefile](../Makefile) · [CLAUDE.md](../CLAUDE.md) (Validation Commands) · [docs/10-delivery/ci-cd-quality-gates.md](../docs/10-delivery/ci-cd-quality-gates.md)

**Status:** Populated with bootstrap and config-validation scripts.
