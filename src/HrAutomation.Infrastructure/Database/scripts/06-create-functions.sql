/* ============================================================================
   06-create-functions.sql
   Purpose : The remaining functions from section 13 of the design spec.
             security.fn_tenant_access_predicate, security.fn_has_permission,
             dbo.fn_normalize_email, and dbo.fn_normalize_phone are created
             earlier (02-create-types.sql and 05-create-security.sql) because
             tables/policies depend on them at creation time — see the note in
             02-create-types.sql. This file holds the rest.
   Idempotent: Yes (CREATE OR ALTER).
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* dbo.fn_get_current_utc — thin wrapper kept ONLY because a handful of
   generated-column/check-constraint contexts cannot call SYSUTCDATETIME()
   directly in some SQL Server versions' DEFAULT expressions the same way a
   function reference reads in code review; every ordinary column default in
   this design calls SYSUTCDATETIME() directly (see 02-create-types.sql
   conventions) — this function exists only for T-SQL callers (procedures,
   views) that want a single documented "current time" symbol to search for.
   Preferred approach: call SYSUTCDATETIME() directly; this function is a
   thin pass-through, not a caching or timezone-conversion layer. */
CREATE OR ALTER FUNCTION dbo.fn_get_current_utc()
RETURNS datetime2(7)
WITH SCHEMABINDING
AS
BEGIN
    RETURN SYSUTCDATETIME();
END
GO

/* workflow.fn_is_valid_transition — checks whether a FromState -> ToState
   transition is configured for a given workflow definition. Inline TVF for
   index-seek-friendly use in stored procedures (avoids a scalar-UDF-in-
   predicate performance trap per section 13's guidance). */
IF OBJECT_ID(N'workflow.fn_is_valid_transition', N'IF') IS NOT NULL
    DROP FUNCTION workflow.fn_is_valid_transition;
GO
CREATE FUNCTION workflow.fn_is_valid_transition
(
    @WorkflowDefinitionId UNIQUEIDENTIFIER,
    @FromStateId UNIQUEIDENTIFIER,
    @ToStateId UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
    SELECT 1 AS is_valid, wtd.WorkflowTransitionDefinitionId, wtd.RequiresApproval, wtd.RequiredPermissionKey
    FROM ref.WorkflowTransitionDefinition wtd
    WHERE wtd.WorkflowDefinitionId = @WorkflowDefinitionId
      AND wtd.FromStateId = @FromStateId
      AND wtd.ToStateId = @ToStateId
      AND wtd.IsActive = 1
      AND wtd.IsDeleted = 0;
GO

/* employee.fn_preview_employee_id — NON-RESERVING preview only. Building the
   preview string mirrors ref.NumberingRule.NumberFormat but reads
   CurrentSequence + 1 WITHOUT locking or incrementing it — the actual
   reservation happens inside employee.usp_GenerateEmployeeId under
   UPDLOCK/HOLDLOCK. Calling this function twice for the same tenant can
   legitimately return the same preview value; callers must never treat the
   preview as an issued ID. */
IF OBJECT_ID(N'employee.fn_preview_employee_id', N'FN') IS NOT NULL
    DROP FUNCTION employee.fn_preview_employee_id;
GO
CREATE FUNCTION employee.fn_preview_employee_id(@TenantId UNIQUEIDENTIFIER)
RETURNS nvarchar(200)
AS
BEGIN
    DECLARE @preview nvarchar(200);
    DECLARE @prefix nvarchar(20), @suffix nvarchar(20), @padding int, @nextSeq bigint;

    SELECT TOP (1)
        @prefix = Prefix,
        @suffix = Suffix,
        @padding = PaddingWidth,
        @nextSeq = CurrentSequence + 1
    FROM ref.NumberingRule
    WHERE TenantId = @TenantId AND EntityType = N'EmployeeId' AND IsActive = 1 AND IsDeleted = 0;

    IF @nextSeq IS NULL
        RETURN NULL; -- no numbering rule configured for this tenant — caller must handle

    SET @preview = ISNULL(@prefix, N'') + RIGHT(REPLICATE('0', @padding) + CAST(@nextSeq AS nvarchar(20)), @padding) + ISNULL(@suffix, N'');
    RETURN @preview;
END
GO

/* reporting.fn_redact_sensitive_value — used by restricted reporting views
   to mask email/phone/identity/document references for audiences that
   should see "something was there" but not the value itself. */
IF OBJECT_ID(N'reporting.fn_redact_sensitive_value', N'FN') IS NOT NULL
    DROP FUNCTION reporting.fn_redact_sensitive_value;
GO
CREATE FUNCTION reporting.fn_redact_sensitive_value(@Value nvarchar(500), @Kind nvarchar(20))
RETURNS nvarchar(500)
AS
BEGIN
    IF @Value IS NULL OR LEN(@Value) = 0
        RETURN NULL;

    DECLARE @result nvarchar(500);

    IF @Kind = N'Email' AND CHARINDEX(N'@', @Value) > 1
        SET @result = LEFT(@Value, 1) + N'***@' + SUBSTRING(@Value, CHARINDEX(N'@', @Value) + 1, 500);
    ELSE IF @Kind = N'Phone' AND LEN(@Value) >= 4
        SET @result = REPLICATE(N'*', LEN(@Value) - 4) + RIGHT(@Value, 4);
    ELSE
        SET @result = N'***REDACTED***';

    RETURN @result;
END
GO

PRINT N'06-create-functions.sql complete.';
