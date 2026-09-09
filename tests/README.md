# tests/ — Test Suites

**Purpose:** All test tiers defined in `docs/09-quality-evaluation/test-strategy.md`: unit, integration, contract, e2e, security, performance, RAG, and agent tests.

**What belongs here:** Test code and synthetic fixtures only.

**What must not be stored here:** Real candidate/employee data of any kind — every fixture must be fake/demo or synthetically generated.

**Owner:** Each layer's engineering team, jointly with QA.

**Current state:** `tests/HrAutomation.Tests` is the existing, already-passing .NET test project (unit + integration style tests for the current backend). The subfolders below (`unit/`, `integration/`, `contract/`, `e2e/`, `security/`, `performance/`, `rag/`, `agents/`) describe the target test-tier layout referenced in `docs/09-quality-evaluation/test-strategy.md` and will house tests as `src/frontend/`, `src/agents/`, and cross-cutting test tiers come online.

**Subfolders:** [unit/](unit/) · [integration/](integration/) · [contract/](contract/) · [e2e/](e2e/) · [security/](security/) · [performance/](performance/) · [rag/](rag/) · [agents/](agents/)

**Status:** Initial scaffold — new subfolders added alongside the existing, passing test project.
