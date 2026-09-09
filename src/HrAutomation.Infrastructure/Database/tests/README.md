# tests/

T-SQL validation and behavioral test scripts. These are **database-level tests**
(tier: "database", "security", per
[docs/09-quality-evaluation/test-strategy.md](../../../../docs/09-quality-evaluation/test-strategy.md))
— they complement, and do not replace, the integration/contract tests in
`tests/HrAutomation.Tests/` at the repository root.

Run against a disposable database (LocalDB instance or a CI ephemeral container), never
against staging/production data.

| Script | Verifies |
|---|---|
| `database-smoke-tests.sql` | Every required schema/table/proc/view/function/index/RLS policy from the design exists (calls `../scripts/99-validate-database.sql` checks and asserts on the results) |
| `rls-tests.sql` | Tenant A cannot see Tenant B's rows; missing tenant context denies access; authorized service context works as documented |
| `workflow-integrity-tests.sql` | Illegal workflow transitions rejected; offer cannot reach Sent without approval; discrepancy cannot close without approval; Employee ID generation is idempotent |
| `security-tests.sql` | No plaintext credential columns; no unrestricted `PUBLIC` grants on sensitive schemas; audit tables reject `UPDATE`/`DELETE` |
| `performance-baseline-tests.sql` | Representative query shapes (tenant + status lookups, pipeline dashboards) return via an index seek, not a scan, at expected row-count scale |

Each script uses `tSQLt`-style conventions (`EXEC tSQLt.NewTestClass`, assert helpers) if
`tSQLt` is installed in the target database; otherwise each script degrades to a
plain batch that raises `THROW` with a descriptive message on the first failed
assertion and prints `PASS`/`FAIL` per check — see the header comment in each script for
the exact convention used, so these can run in a CI job without a `tSQLt` dependency
being mandatory for a first deployment.
