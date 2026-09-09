# 03-data/

**Purpose:** Data architecture, entity-relationship model, data dictionary, classification/retention rules, and the baseline SQL schema.

**What belongs here:** Data domain diagrams, entity definitions, retention/classification policy, and the sample DDL (explicitly a technical baseline requiring DBA/security review).

**What must not be stored here:** Real data of any kind, actual migration scripts for a live database (those belong with the backend implementation once it exists), secrets/connection strings.

**Owner:** [TENANT_CONFIGURATION_REQUIRED — Data Architecture / DBA]

**Main dependencies:** `docs/05-security-governance/privacy-and-pii-handling.md`, `config/schemas/retention-policy.schema.json`, the backend persistence layer once implemented.

**Contents:** [data-architecture.md](data-architecture.md) · [er-diagram.md](er-diagram.md) · [data-dictionary.md](data-dictionary.md) · [data-classification-and-retention.md](data-classification-and-retention.md) · [data-quality-rules.md](data-quality-rules.md) · [audit-log-specification.md](audit-log-specification.md) · [database-migration-strategy.md](database-migration-strategy.md) · [master-data-management.md](master-data-management.md) · [sample-relational-schema.sql](sample-relational-schema.sql)

**Status:** Initial scaffold — details to be added during implementation.
