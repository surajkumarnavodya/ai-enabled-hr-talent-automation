# infra/kubernetes/

**Purpose:** Kubernetes manifests/Helm charts for deploying the platform per `docs/01-architecture/deployment-architecture.md` (namespace-per-bounded-context topology, network policies, autoscaling).

**What belongs here:** Manifests/charts, kustomize overlays per environment, network policy definitions.

**What must not be stored here:** Secrets (use a Secret-store CSI driver or sealed-secrets referencing the vault, never plaintext manifests), `kubeconfig` files.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps/SRE]

**Status:** Initial scaffold — no manifests defined yet.
