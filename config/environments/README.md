# config/environments/

**Purpose:** Environment-specific overrides (dev, test, staging, prod) merged on top of `config/defaults/`.

**What belongs here:** One YAML per environment containing only the keys that differ from the default.

**What must not be stored here:** Secrets or production credentials — only non-secret behavioral overrides (sampling rates, retry counts, log level). Reference secrets via the vault, per `.env.example`.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps]

**Contents:** [dev.yaml](dev.yaml) · [test.yaml](test.yaml) · [staging.yaml](staging.yaml) · [prod.yaml](prod.yaml)

**Status:** Populated.
