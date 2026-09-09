# config/feature-flags/

**Purpose:** Feature flag definitions beyond the baseline set already in `config/schemas/platform-config.schema.json` (`featureFlags` block) and `config/defaults/platform.default.yaml` — this folder is for flags that need richer targeting (percentage rollout, tenant allow-list, environment gating) than a flat boolean.

**What belongs here:** Flag definition files describing name, description, default state, allowed override scope (tenant/environment/user-role), and owner. If the organization adopts an external flag service instead, this folder documents the flag catalog while `FEATURE_FLAGS_SOURCE` (see `.env.example`) points at the live service.

**What must not be stored here:** Secrets, or flags that gate a non-negotiable rule from `CLAUDE.md` (e.g., `autonomousApprovals` must remain hardcoded `false` at the schema level, never a togglable flag here).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Product + Platform Engineering]

**Related documents:** [config/schemas/platform-config.schema.json](../schemas/platform-config.schema.json) · [config/defaults/platform.default.yaml](../defaults/platform.default.yaml) · [.env.example](../../.env.example) (`FEATURE_FLAGS_SOURCE`)

**Status:** Initial scaffold — no flag definitions yet beyond the baseline set in `config/defaults/platform.default.yaml`.
