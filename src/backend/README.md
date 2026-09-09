# src/backend/

**Purpose:** Core API, workflow engine, business rules, authorization, and integration orchestration — the deterministic system of record for every workflow state and approval decision.

**What belongs here:** API controllers, the workflow state machine, approval-matrix enforcement, domain entities, and persistence code. See "Current state" note in `src/README.md`: today this logic lives in the existing `src/HrAutomation.Domain`, `.Application`, `.Infrastructure`, and `.Api` projects.

**What must not be stored here:** Frontend UI code, AI/agent orchestration logic (→ `src/agents/`), real candidate/employee data in tests or fixtures.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Backend/Platform Engineering]

**Main dependencies:** `openapi/`, `asyncapi/`, `config/`, `docs/02-business-workflows/`, `docs/03-data/`.

**Related documents:** [PROJECT_STRUCTURE.md](../../PROJECT_STRUCTURE.md) · [.claude/rules/architecture.md](../../.claude/rules/architecture.md) · [.claude/rules/data.md](../../.claude/rules/data.md)

**Status:** Initial scaffold placeholder — the working backend implementation currently lives under `src/HrAutomation.*`.
