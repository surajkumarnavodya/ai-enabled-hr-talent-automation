# infra/ — Infrastructure as Code

**Purpose:** Container definitions, Kubernetes manifests, Terraform modules, and operational scripts for provisioning and running the platform, implementing `docs/01-architecture/deployment-architecture.md`.

**What belongs here:** Dockerfiles/compose fragments (`docker/`), Kubernetes manifests/Helm charts (`kubernetes/`), Terraform modules (`terraform/`), and operational scripts (`scripts/`).

**What must not be stored here:** Terraform state files, `.tfvars` with real values, cloud credentials, or any production secret — see `.gitignore` for enforced exclusions.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps/SRE]

**Main dependencies:** `docs/01-architecture/deployment-architecture.md`, `docs/01-architecture/resilience-and-disaster-recovery.md`, `.github/workflows/`, `docker-compose.yml` (root, local dev only).

**Subfolders:** [docker/](docker/) · [kubernetes/](kubernetes/) · [terraform/](terraform/) · [scripts/](scripts/)

**Status:** Initial scaffold — no infrastructure defined yet.
