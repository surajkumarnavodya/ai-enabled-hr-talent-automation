# config/defaults/

**Purpose:** Safe, conservative default values for every configuration schema — the baseline every environment/tenant inherits from unless it explicitly overrides.

**What belongs here:** One `*.default.yaml` file per schema in `config/schemas/`, validating against it.

**What must not be stored here:** Tenant-specific or environment-specific values (→ `config/tenants/`, `config/environments/`), secrets.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Platform Engineering]

**Contents:** [platform.default.yaml](platform.default.yaml) · [workflow.default.yaml](workflow.default.yaml) · [rag.default.yaml](rag.default.yaml) · [model-routing.default.yaml](model-routing.default.yaml) · [security.default.yaml](security.default.yaml) · [observability.default.yaml](observability.default.yaml)

**Status:** Populated.
