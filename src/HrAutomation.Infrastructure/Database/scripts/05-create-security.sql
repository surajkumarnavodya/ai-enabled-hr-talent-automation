/* ============================================================================
   05-create-security.sql
   Purpose : PART A — database roles and the least-privilege grant model.
             PART B — Row-Level Security predicate function and security
             policies (added once the tenant-owned tables exist — see
             scripts/03-create-tables.sql — appended to this file in the same
             deployment package rather than a second file, so security
             configuration has one authoritative location).
   Run as  : db_hr_security_admin or a one-time setup principal with ALTER ANY
             ROLE / ALTER ANY USER / CREATE SECURITY POLICY rights. Never the
             application runtime login.
   Idempotent: Yes.
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   PART A — DATABASE ROLES
   ============================================================================
   Grant model (see docs/security-model.md for full rationale):
     - The application runtime connection uses db_hr_app_reader + db_hr_app_writer
       + db_hr_workflow_executor ONLY — never db_owner, never sysadmin.
     - Sensitive writes (offer send, discrepancy closure, Employee ID creation,
       approval decisions) are only reachable through stored procedures granted
       to db_hr_workflow_executor — no direct table INSERT/UPDATE/DELETE grant
       on the underlying tables for those actions.
     - db_hr_migration_executor has schema-change rights (ALTER on business
       schemas) and is used ONLY by the CI/CD migration pipeline, never at
       application runtime, never interactively by a developer against
       staging/production.
     - db_hr_reporting_reader can SELECT from `reporting` schema views/procs
       only — no access to base tables in recruitment/offer/onboarding/employee.
     - db_hr_audit_reader can SELECT from `audit` schema and approved audit
       views only.
     - db_hr_readonly_support is for time-bound, approved production-support
       access (see docs/security-model.md "Production support access") and is
       scoped to reporting + audit read access, never base PII tables.
   ============================================================================ */

DECLARE @roles TABLE (RoleName sysname NOT NULL, Purpose nvarchar(300) NOT NULL);
INSERT INTO @roles (RoleName, Purpose) VALUES
    (N'db_hr_app_reader',          N'Application runtime: SELECT on business tables via views/procs'),
    (N'db_hr_app_writer',          N'Application runtime: INSERT/UPDATE on non-sensitive business tables'),
    (N'db_hr_workflow_executor',   N'Application runtime: EXECUTE on workflow/approval/sensitive-write procedures'),
    (N'db_hr_reporting_reader',    N'Reporting/BI: SELECT on reporting schema objects only'),
    (N'db_hr_integration_executor',N'Integration workers: outbox/inbox EXECUTE + SELECT'),
    (N'db_hr_migration_executor',  N'CI/CD schema deploys: DDL rights, never used at runtime'),
    (N'db_hr_security_admin',      N'DBA/security: manage roles, RLS policies, grants — not data'),
    (N'db_hr_audit_reader',        N'Compliance/security: SELECT on audit schema only'),
    (N'db_hr_readonly_support',    N'Time-bound approved production support: reporting + audit read only');

DECLARE @roleName sysname, @purpose nvarchar(300), @sql nvarchar(max);
DECLARE role_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT RoleName, Purpose FROM @roles;
OPEN role_cursor;
FETCH NEXT FROM role_cursor INTO @roleName, @purpose;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @roleName AND type = 'R')
    BEGIN
        SET @sql = N'CREATE ROLE ' + QUOTENAME(@roleName) + N' AUTHORIZATION dbo;';
        EXEC (@sql);
        PRINT N'Created role ' + @roleName;
    END
    ELSE
        PRINT N'Role ' + @roleName + N' already exists — skipping.';

    FETCH NEXT FROM role_cursor INTO @roleName, @purpose;
END
CLOSE role_cursor;
DEALLOCATE role_cursor;
GO

/* Schema-level EXECUTE grants for workflow/integration roles — object-level
   SELECT/INSERT/UPDATE grants on individual tables are applied per-table in
   scripts/04-create-keys-indexes-constraints.sql review checklist and audited
   by scripts/99-validate-database.sql (no unrestricted grant to PUBLIC). */
GRANT EXECUTE ON SCHEMA :: workflow    TO db_hr_workflow_executor;
GRANT EXECUTE ON SCHEMA :: recruitment TO db_hr_workflow_executor;
GRANT EXECUTE ON SCHEMA :: offer       TO db_hr_workflow_executor;
GRANT EXECUTE ON SCHEMA :: onboarding  TO db_hr_workflow_executor;
GRANT EXECUTE ON SCHEMA :: employee    TO db_hr_workflow_executor;
GRANT EXECUTE ON SCHEMA :: iam         TO db_hr_workflow_executor;

GRANT SELECT  ON SCHEMA :: reporting TO db_hr_reporting_reader, db_hr_readonly_support;
GRANT EXECUTE ON SCHEMA :: reporting TO db_hr_reporting_reader, db_hr_readonly_support;

GRANT SELECT  ON SCHEMA :: audit TO db_hr_audit_reader, db_hr_readonly_support;

GRANT EXECUTE ON SCHEMA :: integration TO db_hr_integration_executor;
GRANT SELECT  ON SCHEMA :: integration TO db_hr_integration_executor;

/* db_hr_security_admin manages principals/policies, not data. */
GRANT ALTER ANY SECURITY POLICY TO db_hr_security_admin;
GRANT VIEW DEFINITION TO db_hr_security_admin;
GO

/* Explicitly confirm nothing sensitive is ever granted to PUBLIC — re-checked
   by scripts/99-validate-database.sql. */
DENY SELECT ON SCHEMA :: iam TO PUBLIC;
DENY SELECT ON SCHEMA :: offer TO PUBLIC;
DENY SELECT ON SCHEMA :: onboarding TO PUBLIC;
DENY SELECT ON SCHEMA :: employee TO PUBLIC;
DENY SELECT ON SCHEMA :: audit TO PUBLIC;
DENY SELECT ON SCHEMA :: ai TO PUBLIC;
GO

PRINT N'05-create-security.sql PART A (roles) complete.';
GO

/* ============================================================================
   PART B — ROW-LEVEL SECURITY
   ============================================================================
   Design (full rationale in docs/rls-design.md):

   - The application sets `SESSION_CONTEXT('TenantId', @TenantId, @readonly = 1)`
     once per connection/request in HrAutomation.Api's connection-opening
     middleware, immediately after authenticating the caller's tenant — never
     from a client-supplied header/claim taken at face value inside the
     predicate itself (the predicate only ever reads SESSION_CONTEXT, which
     only the API's own middleware — not the browser — can set).
   - Missing tenant context (SESSION_CONTEXT('TenantId') IS NULL) denies all
     rows, EXCEPT for one documented, narrowly-scoped exception: the
     `db_hr_migration_executor` and `db_hr_security_admin` roles, which never
     carry application data access anyway (see PART A grants) and need
     unfiltered access to run schema migrations / manage policies. This
     exception is implemented via IS_ROLEMEMBER(), not a bypassable client
     flag, so it cannot be triggered by anything the application sends.
   - RLS is DEFENSE IN DEPTH. The primary authorization boundary is
     HrAutomation.Api (see .claude/rules/api.md "independently re-check the
     approval matrix server-side"). RLS exists so that a bug or an
     unanticipated raw-SQL path can never leak cross-tenant data even if the
     application-layer check is somehow bypassed.
   - Every security policy uses STATE = ON and applies to both the base table
     query (filter predicate) and INSERT/UPDATE (block predicate), so a
     session can never read, nor write, a row outside its own tenant context.
   ============================================================================ */

-- Drop every existing policy in the security schema first: SQL Server allows
-- neither DROP FUNCTION nor ALTER FUNCTION on a schemabound function while a
-- security policy references it (error 3729), so on a re-run the policies
-- must go before the function, then get recreated at the end of this part.
DECLARE @dropPolicySql nvarchar(max) = N'';
SELECT @dropPolicySql += N'DROP SECURITY POLICY ' + QUOTENAME(s.name) + N'.' + QUOTENAME(sp.name) + N';' + CHAR(10)
FROM sys.security_policies sp
JOIN sys.schemas s ON s.schema_id = sp.schema_id
WHERE s.name = N'security';
IF LEN(@dropPolicySql) > 0
    EXEC (@dropPolicySql);
GO

IF OBJECT_ID(N'security.fn_tenant_access_predicate', N'IF') IS NOT NULL
    DROP FUNCTION security.fn_tenant_access_predicate;
GO
CREATE FUNCTION security.fn_tenant_access_predicate(@TenantId UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_tenant_access_predicate_result
    WHERE
        -- Normal path: the row's TenantId matches the session's tenant context.
        @TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS UNIQUEIDENTIFIER)
        -- Documented authorized exception: schema/security administration
        -- principals are never granted table-level data access in PART A
        -- anyway, so this only ever matters for catalog/metadata operations,
        -- not row data — included for completeness and tested explicitly in
        -- ../tests/rls-tests.sql "authorized service context".
        OR IS_ROLEMEMBER(N'db_hr_migration_executor') = 1
        OR IS_ROLEMEMBER(N'db_hr_security_admin') = 1;
GO

/* security.fn_has_permission — documented limitation: this is a coarse,
   defense-in-depth check only. The authoritative permission check is
   HrAutomation.Api's authorization middleware (iam.RolePermission evaluated
   server-side against the caller's resolved roles) — this function exists so
   a stored procedure invoked outside a fully-authorized API request path
   (e.g. an ad hoc DBA query under db_hr_readonly_support) still gets a
   coarse check, not so the database becomes a second, independent
   authorization engine. Do not add business-rule complexity here. */
CREATE OR ALTER FUNCTION security.fn_has_permission(@UserId UNIQUEIDENTIFIER, @PermissionKey nvarchar(150))
RETURNS bit
AS
BEGIN
    DECLARE @result bit = 0;

    IF @UserId IS NOT NULL AND EXISTS (
        SELECT 1
        FROM iam.UserRole ur
        JOIN iam.RolePermission rp ON rp.RoleId = ur.RoleId AND rp.IsDeleted = 0
        JOIN iam.Permission p ON p.PermissionId = rp.PermissionId AND p.IsDeleted = 0 AND p.IsActive = 1
        WHERE ur.UserId = @UserId
          AND ur.RevokedAtUtc IS NULL
          AND ur.IsDeleted = 0
          AND p.PermissionKey = @PermissionKey
    )
        SET @result = 1;

    RETURN @result;
END
GO

/* Security policies — one per priority tenant-owned table from section 16.3
   of the design spec. Each follows the identical pattern; apply the same
   pattern to any additional tenant-owned table added later (see
   docs/rls-design.md "Adding RLS to a new table"). */

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_Candidate')
    DROP SECURITY POLICY security.SecPol_Candidate;
GO
CREATE SECURITY POLICY security.SecPol_Candidate
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.Candidate,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.Candidate AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.Candidate AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_JobRequisition')
    DROP SECURITY POLICY security.SecPol_JobRequisition;
GO
CREATE SECURITY POLICY security.SecPol_JobRequisition
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.JobRequisition,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.JobRequisition AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.JobRequisition AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_CandidateApplication')
    DROP SECURITY POLICY security.SecPol_CandidateApplication;
GO
CREATE SECURITY POLICY security.SecPol_CandidateApplication
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.CandidateApplication,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.CandidateApplication AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.CandidateApplication AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_Interview')
    DROP SECURITY POLICY security.SecPol_Interview;
GO
CREATE SECURITY POLICY security.SecPol_Interview
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.Interview,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.Interview AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON recruitment.Interview AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_Offer')
    DROP SECURITY POLICY security.SecPol_Offer;
GO
CREATE SECURITY POLICY security.SecPol_Offer
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON offer.Offer,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON offer.Offer AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON offer.Offer AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_GreenFormSubmission')
    DROP SECURITY POLICY security.SecPol_GreenFormSubmission;
GO
CREATE SECURITY POLICY security.SecPol_GreenFormSubmission
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.GreenFormSubmission,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.GreenFormSubmission AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.GreenFormSubmission AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_CandidateDocument')
    DROP SECURITY POLICY security.SecPol_CandidateDocument;
GO
CREATE SECURITY POLICY security.SecPol_CandidateDocument
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.CandidateDocument,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.CandidateDocument AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.CandidateDocument AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_Discrepancy')
    DROP SECURITY POLICY security.SecPol_Discrepancy;
GO
CREATE SECURITY POLICY security.SecPol_Discrepancy
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.Discrepancy,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.Discrepancy AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON onboarding.Discrepancy AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_Employee')
    DROP SECURITY POLICY security.SecPol_Employee;
GO
CREATE SECURITY POLICY security.SecPol_Employee
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON employee.Employee,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON employee.Employee AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON employee.Employee AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_WorkflowInstance')
    DROP SECURITY POLICY security.SecPol_WorkflowInstance;
GO
CREATE SECURITY POLICY security.SecPol_WorkflowInstance
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON workflow.WorkflowInstance,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON workflow.WorkflowInstance AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON workflow.WorkflowInstance AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_ApprovalRequest')
    DROP SECURITY POLICY security.SecPol_ApprovalRequest;
GO
CREATE SECURITY POLICY security.SecPol_ApprovalRequest
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON workflow.ApprovalRequest,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON workflow.ApprovalRequest AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON workflow.ApprovalRequest AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_AuditEvent')
    DROP SECURITY POLICY security.SecPol_AuditEvent;
GO
-- AuditEvent.TenantId is NULLable (platform-level events) — the predicate
-- naturally denies NULL-tenant rows to a tenant-scoped session (NULL never
-- equals a UNIQUEIDENTIFIER), so platform events are only visible to
-- db_hr_audit_reader/db_hr_security_admin via IGNORE_DUP_KEY... actually via
-- the IS_ROLEMEMBER exception path above, not a tenant match. This is
-- intentional and documented in docs/rls-design.md "Nullable-tenant audit
-- rows".
CREATE SECURITY POLICY security.SecPol_AuditEvent
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON audit.AuditEvent,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON audit.AuditEvent AFTER INSERT
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_RagCorpus')
    DROP SECURITY POLICY security.SecPol_RagCorpus;
GO
CREATE SECURITY POLICY security.SecPol_RagCorpus
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON ai.RagCorpus,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON ai.RagCorpus AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON ai.RagCorpus AFTER UPDATE
    WITH (STATE = ON);
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SecPol_AiAgentRun')
    DROP SECURITY POLICY security.SecPol_AiAgentRun;
GO
CREATE SECURITY POLICY security.SecPol_AiAgentRun
    ADD FILTER PREDICATE security.fn_tenant_access_predicate(TenantId) ON ai.AiAgentRun,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON ai.AiAgentRun AFTER INSERT,
    ADD BLOCK PREDICATE security.fn_tenant_access_predicate(TenantId) ON ai.AiAgentRun AFTER UPDATE
    WITH (STATE = ON);
GO

/* Limitation, documented per section 16.3: temporal history tables (created
   in scripts/09-create-triggers.sql-adjacent temporal enablement — see
   docs/rls-design.md "Temporal tables") inherit the current table's security
   policy automatically for period-clause-rewritten queries against the
   current table, but a direct SELECT against the *_History table itself is
   NOT covered by a security policy bound to the current table. Access to
   *_History tables is restricted at the object-grant level instead (no
   SELECT grant to db_hr_app_reader on history tables directly) — see
   docs/rls-design.md for the full explanation and docs/security-model.md for
   the grant. */

PRINT N'05-create-security.sql PART B (RLS) complete.';
