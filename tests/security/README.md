# tests/security/

**Purpose:** Authorization, tenant-isolation, and other security-specific tests per `docs/05-security-governance/security-test-plan.md` — e.g., a cross-tenant read attempt must return `404`, not partial data.

**What belongs here:** RBAC/ABAC enforcement tests, tenant-isolation tests, and any automated check derived from `docs/05-security-governance/threat-model.md`.

**What must not be stored here:** Real vulnerability details or exploit code targeting production systems — coordinate through `SECURITY.md` instead. No real candidate/employee data.

**Owner:** Security, jointly with engineering.

**Status:** Initial scaffold — details to be added during implementation.
