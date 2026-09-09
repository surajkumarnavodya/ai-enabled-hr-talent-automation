# infra/scripts/

**Purpose:** Operational scripts specific to infrastructure lifecycle (cluster bootstrap, database backup/restore drills, DR failover rehearsal) — distinct from the developer-facing scripts in the repo-root `scripts/` folder.

**What belongs here:** Idempotent, safe-by-default operational scripts with clear documentation of what they do before they do it.

**What must not be stored here:** Embedded credentials; scripts that perform an irreversible action without an explicit confirmation flag.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps/SRE]

**Status:** Initial scaffold — no scripts defined yet.
