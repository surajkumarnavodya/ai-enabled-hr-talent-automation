# tests/unit/

**Purpose:** Fast, isolated tests of individual functions/classes and domain invariants (e.g., an illegal workflow transition is rejected at the domain-entity level).

**What belongs here:** Unit tests with no external dependencies (no real DB, network, or file system).

**What must not be stored here:** Integration-style tests requiring a real database/service (→ `tests/integration/`), real candidate/employee data.

**Owner:** Each layer's engineering team.

**Status:** Initial scaffold — details to be added during implementation.
