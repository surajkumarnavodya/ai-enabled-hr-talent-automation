# src/ — Application Code

**Purpose:** All application source code: frontend, backend, agents, shared contracts, and integration adapters.

**What belongs here:** Buildable source code and its immediate unit tests co-located per language convention (broader test tiers live in `tests/`).

**What must not be stored here:** Documentation (→ `docs/`), configuration values (→ `config/`), infrastructure definitions (→ `infra/`), real candidate/employee data.

**Owner:** Engineering, with per-subfolder ownership below.

**Current state:** The `HrAutomation.*` .NET projects (`HrAutomation.Domain`, `HrAutomation.Application`, `HrAutomation.Infrastructure`, `HrAutomation.Agents`, `HrAutomation.Rag`, `HrAutomation.Mcp`, `HrAutomation.Api`, built via `HrAutomation.slnx`) are the backend implementation, and **`HrAutomation.Web`** is the real React/TypeScript presentation layer (see [HrAutomation.Web/README.md](HrAutomation.Web/README.md)) — it supersedes the `frontend/` placeholder below as the actual frontend location. The `backend/`, `agents/`, `shared/`, and `integration-adapters/` subfolders still describe a target logical layout referenced throughout `docs/` and `CLAUDE.md` for the .NET side; reconciling them with the existing `HrAutomation.*` project layout remains a deliberate, separate decision — not something to do incidentally while adding a feature.

**Subfolders:** [frontend/](frontend/) · [backend/](backend/) · [agents/](agents/) · [shared/](shared/) · [integration-adapters/](integration-adapters/)

**Status:** Initial scaffold — new subfolders added alongside the existing, working `.NET` solution.
