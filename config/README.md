# config/ — Configuration as Code

**Purpose:** Versioned, non-secret configuration implementing the platform's configuration-first principle: workflow stages, approval matrices, SLAs, matching weights, RAG parameters, model routing, retention policy, notification templates, and feature flags.

**What belongs here:** JSON Schemas (`schemas/`), safe default values (`defaults/`), environment overrides (`environments/`), tenant overrides (`tenants/`), and feature flag definitions (`feature-flags/`) — all version-controlled, all validated against their schema.

**What must not be stored here:** Any credential, API key, connection string, or secret value. Secret-requiring settings reference a vault key (see `.env.example`), never a literal.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Platform Engineering], changes co-reviewed by the relevant domain owner (HR for workflow/approval config, Security for security defaults, AI Governance for RAG/model-routing config).

**Main dependencies:** `docs/` (each schema is specified in the corresponding doc), `scripts/validate-config.sh` / `.ps1`, `.claude/rules/data.md`.

**Subfolders:** [schemas/](schemas/) · [defaults/](defaults/) · [environments/](environments/) · [tenants/](tenants/) · [feature-flags/](feature-flags/)

**Status:** Initial scaffold — schemas and defaults populated; feature-flags/ newly added.
