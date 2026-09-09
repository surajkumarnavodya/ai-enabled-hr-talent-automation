# config/tenants/

**Purpose:** Per-tenant configuration overrides — branding, roles, departments, job grades, numbering formats, escalation chains.

**What belongs here:** One YAML per tenant, validating against `config/schemas/tenant-config.schema.json`, using fake/demo data for any example tenant.

**What must not be stored here:** Real tenant/organization data beyond what's needed for non-secret configuration; no credentials.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Platform Engineering], values co-owned by each tenant's HR/Product contact.

**Contents:** [sample-tenant.yaml](sample-tenant.yaml) (worked example, fake/demo data)

**Status:** Populated with one example; add real tenant files as tenants onboard.
