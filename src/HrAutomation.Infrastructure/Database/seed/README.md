# seed/

Synthetic demo data only — **never real candidate, employee, client, or compensation
data**, per root `CLAUDE.md` and `.claude/rules/testing.md`.

- `sample-demo-data.sql` — a small, coherent demo dataset (two tenants, a handful of
  users/roles, one TAN through to one converted employee) used for local development
  and manual UI testing. Depends on `../scripts/10-seed-reference-data.sql` having run
  first (reference/master data) and all table-creation scripts having run.
- Reference/master data (statuses, document types, skill catalog, numbering rules, etc.)
  lives in `../scripts/10-seed-reference-data.sql`, not here — that data is
  environment-independent baseline configuration, not "demo" data, and ships to every
  environment including production.
- Re-running files in this folder must be safe (idempotent `MERGE`/existence checks) —
  never blind `INSERT` that would duplicate rows on a second run.
