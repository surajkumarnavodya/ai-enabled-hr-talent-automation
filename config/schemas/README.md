# config/schemas/

**Purpose:** JSON Schema definitions that every file under `config/defaults/`, `config/environments/`, and `config/tenants/` must validate against.

**What belongs here:** `.schema.json` files only, each with a stable `$id`.

**What must not be stored here:** Actual configuration values (→ `config/defaults/`), secrets.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Platform Engineering]

**Contents:** [platform-config.schema.json](platform-config.schema.json) · [tenant-config.schema.json](tenant-config.schema.json) · [workflow-config.schema.json](workflow-config.schema.json) · [approval-matrix.schema.json](approval-matrix.schema.json) · [rag-config.schema.json](rag-config.schema.json) · [model-routing.schema.json](model-routing.schema.json) · [retention-policy.schema.json](retention-policy.schema.json) · [notification-template.schema.json](notification-template.schema.json)

**Status:** Populated.
