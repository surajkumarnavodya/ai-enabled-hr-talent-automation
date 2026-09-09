# infra/terraform/

**Purpose:** Terraform modules provisioning cloud infrastructure (per the configurable default in `docs/01-architecture/technology-selection-matrix.md`): database, object storage, vector store, message bus, identity, API gateway, Kubernetes cluster.

**What belongs here:** Reusable modules and per-environment root configurations (backend config pointing at remote state, never local state).

**What must not be stored here:** `*.tfstate`, `*.tfvars` with real values, or cloud provider credentials — all excluded via `.gitignore`.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps/SRE]

**Status:** Initial scaffold — no modules defined yet.
