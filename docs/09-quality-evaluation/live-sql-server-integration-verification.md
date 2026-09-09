# Live SQL Server Integration Verification

> Title: Live SQL Server Integration Verification | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Engineering] | Status: Verified this pass (2026-09-08) | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Engineering, QA

## Purpose and scope

A manual, repeatable procedure to prove — not assume — that `HrAutomation.Web` is actually writing to and reading from `HrAutomationDb` through `HrAutomation.Api`, rather than MSW mock handlers. Covers the vertical slice that is real today: TAN creation/approval and CV upload/candidate list. See [PROJECT_STATUS.md](../../PROJECT_STATUS.md) for what else is (and isn't) connected.

**No real credentials or server details appear in this document** — every value below is a local-dev placeholder or a fake/demo identifier already committed to the seed scripts.

## Prerequisites

- .NET 8 SDK, Node.js 20+.
- SQL Server LocalDB (or a full SQL Server instance) with `HrAutomationDb` deployed — run `src/HrAutomation.Infrastructure/Database/scripts/00-*.sql` through `09-*.sql` in order, then `src/HrAutomation.Infrastructure/Database/seed/01-*.sql` through `09-*.sql` for demo/reference data.
- A connection string configured via `dotnet user-secrets` (see below) — never a literal password in a committed file.

## Configure the connection (non-secret placeholders only)

From `src/HrAutomation.Api`:

```bash
dotnet user-secrets set "ConnectionStrings:HrAutomationDb" "Server=(localdb)\MSSQLLocalDB;Database=HrAutomationDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
```

For a non-LocalDB SQL Server instance, replace the `Server=`/auth portion only — never commit the result.

## Start the API and confirm health/Swagger

```bash
dotnet run --project src/HrAutomation.Api/HrAutomation.Api.csproj
# Default profile listens on http://localhost:5219 (see Properties/launchSettings.json)
```

- `GET http://localhost:5219/health` → `{"status":"Healthy","checks":[{"name":"database","status":"Healthy"}]}`. If `"Unhealthy"`, the connection string is wrong or the database isn't reachable — the response deliberately never says why (see `DatabaseHealthCheck`).
- `http://localhost:5219/swagger` → the OpenAPI UI, Development-only.

## Start the React UI in real-API mode

From `src/HrAutomation.Web`:

```bash
npm install
cp .env.example .env.local   # if not already present
# Ensure: VITE_AUTH_MODE=devToken, VITE_ENABLE_MSW=false, VITE_API_PROXY_TARGET=http://localhost:5219
npm run dev
```

Open `http://localhost:5173`. The dev-only status strip at the top of the authenticated app shell shows **API: reachable**, **MSW: disabled (real API)**, **Auth: authenticated** once logged in — if any of those is red/wrong, stop here and fix it before testing a workflow.

## Verify MSW is actually disabled

- `appConfig.mswEnabled` is `false` whenever `VITE_ENABLE_MSW` is unset or `false` (the default), and is forced `false` in `VITE_APP_ENV=prod` regardless of the flag — see `src/app/config/env.ts`/`appConfig.ts` and `tests/unit/env.test.ts`.
- Open the browser's Network tab: real requests should show `http://localhost:5173/api/v1/...` proxied through to `localhost:5219` (no `msw` marker on the response, no service worker log lines in the console).
- The login page's copy explicitly says "Development sign-in against the real API" when `VITE_AUTH_MODE=devToken` — if it instead says "This mode never calls a real identity provider or a real API," you're in `mock` mode and nothing you do will reach SQL Server.

## Create a TAN from `/tans/new` and verify persistence

1. Sign in (any role — `RECRUITER` can create TANs).
2. Navigate to **TANs → New TAN**, fill in Title/Location/Grade/Budget/skills/Description, submit.
3. On success the app navigates to `/tans/{tan_id}` using the **server-generated GUID** — never a locally-invented id — and re-fetches `GET /api/v1/tans/{tan_id}` to render the detail page. Note the TAN number shown (e.g. `TAN-00024`) and the `tan_id` from the URL.
4. Confirm the same record via a second, independent read — `GET http://localhost:5219/api/v1/tans/{tan_id}` with a valid bearer token (see `POST /api/v1/dev/token` in Swagger for a Development-only token).
5. Confirm directly in SQL Server, bypassing the API entirely:

```sql
-- Run against HrAutomationDb. Session context is required for row-level security.
EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId; -- the tenant_id from your token
SELECT jr.JobRequisitionId, tan.TanNumber, jr.Title, jr.RequisitionStatusCode, jr.CreatedAtUtc
FROM recruitment.JobRequisition jr
JOIN recruitment.TalentAcquisitionNumber tan ON tan.TalentAcquisitionNumberId = jr.TalentAcquisitionNumberId
WHERE jr.JobRequisitionId = @TanId; -- the tan_id from the UI's URL
```

If the row shows the same title/TAN number the UI displayed, persistence is proven — not assumed.

## Verify TAN approval

1. Sign in as `HR_ADMIN` (or reuse a session with that role).
2. Open the TAN's detail page, click **Approve TAN**, confirm in the dialog.
3. The status badge updates to `Approved` only after the API call returns `action_status: "completed"` — never before (see `TanDetailPage`/`useApproveTan`).
4. Re-run the SQL query above — `RequisitionStatusCode` should now read `Approved`, and `workflow.ApprovalRequest`/`ApprovalStep`/`ApprovalDecision` rows should exist for that `JobRequisitionId`:

```sql
SELECT ar.ApprovalRequestId, ar.Status, ast.StepOrder, ast.Status AS StepStatus, ad.Decision, ad.DecidedAtUtc
FROM workflow.ApprovalRequest ar
JOIN workflow.ApprovalStep ast ON ast.ApprovalRequestId = ar.ApprovalRequestId
LEFT JOIN workflow.ApprovalDecision ad ON ad.ApprovalStepId = ast.ApprovalStepId
WHERE ar.EntityType = N'recruitment.JobRequisition' AND ar.EntityId = @TanId;
```

5. Check the audit trail:

```sql
SELECT TOP 10 Action, EntityType, EntityId, PreviousStatus, NewStatus, OccurredAtUtc
FROM audit.AuditEvent
WHERE EntityId = @TanId OR EntityType = N'recruitment.JobRequisition'
ORDER BY OccurredAtUtc DESC;
```

You should see at least two rows: one written by the orchestrator (`action = approve_tan`) and one written by the stored procedure itself (`action = JobRequisition.Approve`) — both are expected, see `WorkflowOrchestrator`'s class comment on why there are two audit granularities.

## Verify master-data dropdowns

None exist yet — Location/Grade on the TAN form are free-text inputs, not dropdowns backed by a master-data endpoint (see DECISIONS_REQUIRED.md DEC-004). Do not expect a dropdown here until that decision is resolved and an endpoint is built.

## Verify CV upload

1. Go to **CV Bank → Upload CVs**, select a PDF/DOCX (fake/demo content only — never a real CV).
2. Each file is uploaded as its own real `POST /api/v1/candidates/cvs` call (the endpoint accepts one file per request); the result panel shows the server's actual response per file, with a link to the created candidate on success.
3. Confirm in SQL Server:

```sql
SELECT c.CandidateId, c.FirstName, c.LastName, cv.CandidateCvId, v.FileName, v.MalwareScanStatus, p.ParseStatus
FROM recruitment.Candidate c
JOIN recruitment.CandidateCv cv ON cv.CandidateId = c.CandidateId
JOIN recruitment.CandidateCvVersion v ON v.CandidateCvId = cv.CandidateCvId
JOIN recruitment.CvParsingResult p ON p.CandidateCvVersionId = v.CandidateCvVersionId
WHERE c.CandidateId = @CandidateId;
```

## Cleaning up test/demo data safely

Every row created by this procedure is fake/demo data in the seeded demo tenant (`5B7EA628-5EE4-4680-865D-71CABB8463D7`). Delete it in FK-dependency order (children before parents) rather than leaving it to accumulate — repeated manual/automated test runs against a shared LocalDB instance **will** leave stray rows otherwise (observed directly during this pass — see DECISIONS_REQUIRED.md DEC-007). There is no automated cleanup script yet; delete by hand via `sqlcmd`/SSMS, always starting from `workflow.ApprovalDecision`/`ApprovalStep`/`ApprovalRequest`, then `recruitment.JobRequisitionStatusHistory`/`JobDescriptionVersion`/`JobDescription`/`JobOpening`/`JobRequisition`/`TalentAcquisitionNumber` (or the equivalent chain for a candidate: `CvExtractionField`→`CvParsingResult`→`CandidateCvVersion`→`CandidateCv`→`CandidateStatusHistory`→`CandidateContact`→`Candidate`). Never delete a row you didn't create — check `CreatedAtUtc`/the title or name you used first.

## Related documents

[PROJECT_STATUS.md](../../PROJECT_STATUS.md) · [DECISIONS_REQUIRED.md](../../DECISIONS_REQUIRED.md) · [ADR-006](../adr/ADR-006-database-first-stored-procedure-workflow.md) · [docs/04-api/frontend-api-integration.md](../04-api/frontend-api-integration.md)

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-08 | Real-integration verification pass | Initial creation, based on an actual run of every step above |
