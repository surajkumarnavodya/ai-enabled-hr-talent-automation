/* ============================================================================
   01-create-schemas.sql
   Purpose : Create every schema used to separate ownership/responsibility.
   Run against: $(DatabaseName) (default HrAutomationDb) — connect to the target
                database before running (sqlcmd -d $(DatabaseName) or USE below).
   Idempotent: Yes.
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @schemas TABLE (SchemaName sysname NOT NULL, Purpose nvarchar(200) NOT NULL);
INSERT INTO @schemas (SchemaName, Purpose) VALUES
    (N'ref',         N'Reference/master/configuration data — versioned, tenant-overridable'),
    (N'iam',         N'Identity, users, roles, permissions, authN/authZ mappings'),
    (N'org',         N'Tenant, organization, department, business unit, client, location, grade'),
    (N'recruitment', N'CV Bank, candidates, TAN, job descriptions, applications, matching, interviews'),
    (N'offer',       N'Offer details, approvals, templates, acceptance'),
    (N'onboarding',  N'Green Form, employment/education history, documents, verification, discrepancies'),
    (N'employee',    N'Employee master, Employee ID, candidate-to-employee conversion'),
    (N'workflow',    N'Workflow instances, states, tasks, transitions, approvals, SLA/escalation'),
    (N'integration', N'Outbox, inbox/idempotency, external mappings, integration logs'),
    (N'ai',          N'AI model/prompt/skill/evaluation metadata and RAG corpus/embedding metadata'),
    (N'audit',       N'Immutable audit events and security events — append-only'),
    (N'security',    N'RLS predicate functions, security policies, restricted-access support'),
    (N'reporting',   N'Secure, tenant-aware reporting views and stored procedures'),
    (N'maintenance', N'Maintenance jobs, purge/archive procedures, health/metadata views');

DECLARE @schemaName sysname, @purpose nvarchar(200), @sql nvarchar(max);
DECLARE schema_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SchemaName, Purpose FROM @schemas;

OPEN schema_cursor;
FETCH NEXT FROM schema_cursor INTO @schemaName, @purpose;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @schemaName)
    BEGIN
        SET @sql = N'CREATE SCHEMA ' + QUOTENAME(@schemaName) + N' AUTHORIZATION dbo;';
        EXEC (@sql);
        PRINT N'Created schema ' + @schemaName;
    END
    ELSE
        PRINT N'Schema ' + @schemaName + N' already exists — skipping.';

    FETCH NEXT FROM schema_cursor INTO @schemaName, @purpose;
END
CLOSE schema_cursor;
DEALLOCATE schema_cursor;
GO

/* dbo is intentionally used for shared/system objects only — extended properties
   document its restricted purpose for anyone browsing the catalog. */
IF NOT EXISTS (
    SELECT 1 FROM sys.extended_properties
    WHERE class = 3 AND major_id = SCHEMA_ID(N'dbo') AND name = N'Purpose'
)
BEGIN
    EXEC sys.sp_addextendedproperty
        @name = N'Purpose',
        @value = N'Limited shared/system objects only — business objects belong in a named schema.',
        @level0type = N'SCHEMA', @level0name = N'dbo';
END
GO

PRINT N'01-create-schemas.sql complete.';
