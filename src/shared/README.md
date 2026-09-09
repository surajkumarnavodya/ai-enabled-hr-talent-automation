# src/shared/

**Purpose:** Cross-cutting contracts, DTOs, and configuration models used by more than one layer (frontend, backend, agents, integration adapters), to avoid divergent duplicate definitions.

**What belongs here:** Generated or hand-written types matching `openapi/`/`asyncapi/` contracts and `config/schemas/`, shared constants (e.g., workflow state names), and shared validation logic.

**What must not be stored here:** Layer-specific business logic, UI components, or anything that would create a dependency from `shared` back to `frontend`/`backend`/`agents` (dependency direction is one-way, into `shared`).

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Backend/Platform Engineering], changes reviewed by any team consuming the changed contract.

**Related documents:** [PROJECT_STRUCTURE.md](../../PROJECT_STRUCTURE.md) (dependency direction)

**Status:** Initial scaffold — details to be added during implementation.
