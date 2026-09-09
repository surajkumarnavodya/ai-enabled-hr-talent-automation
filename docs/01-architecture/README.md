# 01-architecture/

**Purpose:** Target-state solution, component, and deployment architecture, non-functional requirements, resilience/DR strategy, and the technology selection matrix.

**What belongs here:** Architecture diagrams (Mermaid), NFR targets, resilience patterns, and the default-technology-per-capability matrix. Fixed technology decisions belong in `docs/adr/`, not here.

**What must not be stored here:** Business/workflow rules (→ `docs/02-business-workflows/`), data schema detail (→ `docs/03-data/`), vendor credentials or endpoints.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Principal/Chief Architect]

**Main dependencies:** `docs/adr/` (decisions), `infra/` (implementation of deployment architecture), `docs/05-security-governance/security-architecture.md`.

**Contents:** [solution-architecture.md](solution-architecture.md) · [component-architecture.md](component-architecture.md) · [deployment-architecture.md](deployment-architecture.md) · [integration-architecture.md](integration-architecture.md) · [non-functional-requirements.md](non-functional-requirements.md) · [resilience-and-disaster-recovery.md](resilience-and-disaster-recovery.md) · [technology-selection-matrix.md](technology-selection-matrix.md) · [frontend-architecture.md](frontend-architecture.md)

**Status:** Initial scaffold — details to be added during implementation.
