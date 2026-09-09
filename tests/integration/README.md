# tests/integration/

**Purpose:** Tests exercising a service against a real (containerized) dependency — database, cache, or another internal service — verifying they work together correctly.

**What belongs here:** Tests using `docker-compose.yml` dependencies or equivalent, with synthetic seed data.

**What must not be stored here:** Tests requiring live third-party/external systems (→ `tests/contract/` for contract verification, or mocked adapters), real candidate/employee data.

**Owner:** Each layer's engineering team.

**Status:** Initial scaffold — details to be added during implementation.
