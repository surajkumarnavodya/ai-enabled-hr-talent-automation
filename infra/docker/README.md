# infra/docker/

**Purpose:** Dockerfiles and container-runtime configuration used by both local development (`docker-compose.yml` at repo root) and CI/CD image builds.

**What belongs here:** Dockerfiles per service (once `src/backend/`, `src/frontend/`, `src/agents/` are runnable), and shared container configuration such as the local OpenTelemetry Collector config.

**What must not be stored here:** Base images with embedded secrets, production credentials, or `.env` files.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — DevOps]

**Contents:** [otel-collector-config.yaml](otel-collector-config.yaml) — local-dev OTel Collector config referenced by the root `docker-compose.yml`.

**Status:** Initial scaffold — service Dockerfiles not yet added.
