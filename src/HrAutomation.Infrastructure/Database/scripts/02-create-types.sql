/* ============================================================================
   02-create-types.sql
   Purpose : Solution-wide conventions (documented below) and the small set of
             reusable user-defined table types used as stored-procedure
             parameters for set-based batch operations.
   Idempotent: Yes.
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ----------------------------------------------------------------------------
   CONVENTIONS (enforced by review + 99-validate-database.sql, not by the engine)
   ----------------------------------------------------------------------------
   Identity          : UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() for
                        business entities (clustering-friendly, non-guessable
                        ordering). bigint IDENTITY is reserved for high-volume
                        append-only tables (audit.*, integration.OutboxMessage,
                        integration.InboxMessage, ai.AiToolCall) where sequential
                        insert order and index density matter more than opacity.
   Tenant scope       : TenantId UNIQUEIDENTIFIER NOT NULL on every tenant-owned
                        table, FK to org.Tenant(TenantId), first column after Id.
   Timestamps         : datetime2(7) in UTC. Column suffix *AtUtc. Date-only
                        values use `date` (e.g., EffectiveFromUtc uses datetime2
                        only when a time component is meaningful — otherwise a
                        plain `date` column is used and named without the Utc
                        suffix, e.g., HolidayDate).
   Money              : decimal(19,4) + a paired char(3) ISO-4217-style currency
                        code column, never a bare float/money column.
   Flags              : bit, named Is<Adjective> or Has<Noun>.
   Concurrency        : rowversion column named RowVersion on every mutable
                        business table.
   Audit columns      : CreatedAtUtc datetime2(7) NOT NULL, CreatedByUserId
                        UNIQUEIDENTIFIER NULL (NULL = system/migration),
                        UpdatedAtUtc datetime2(7) NULL, UpdatedByUserId
                        UNIQUEIDENTIFIER NULL, IsDeleted bit NOT NULL DEFAULT 0,
                        DeletedAtUtc datetime2(7) NULL, DeletedByUserId
                        UNIQUEIDENTIFIER NULL.
   Text               : nvarchar(<n>) with an explicit, reviewed length. nvarchar(max)
                        only for approved long-form/JSON fields, each documented in
                        docs/data-dictionary.md with its reason.
   JSON columns       : nvarchar(max) + `CHECK (ISJSON(<column>) = 1)`.
   Status columns     : Where a status set is configuration-driven (ref.* tables),
                        store the code as nvarchar + FK to the ref table, not a
                        hardcoded CHECK list. Where a status set is small, closed,
                        and part of the domain model itself (e.g., IsDeleted-style
                        booleans, WorkflowTask.Priority), a CHECK constraint on a
                        fixed list is acceptable and documented at the column.
   ---------------------------------------------------------------------------- */

/* Reusable table types for set-based, multi-row stored-procedure parameters —
   avoids comma-split parsing and keeps batch operations set-based (no cursors
   in application-facing procedures). */

IF TYPE_ID(N'dbo.GuidList') IS NULL
    CREATE TYPE dbo.GuidList AS TABLE
    (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );
GO

IF TYPE_ID(N'dbo.CodeList') IS NULL
    CREATE TYPE dbo.CodeList AS TABLE
    (
        Code nvarchar(100) NOT NULL PRIMARY KEY
    );
GO

IF TYPE_ID(N'recruitment.SkillAssignmentList') IS NULL
    CREATE TYPE recruitment.SkillAssignmentList AS TABLE
    (
        SkillId          UNIQUEIDENTIFIER NOT NULL,
        ProficiencyLevel nvarchar(30)     NULL,
        YearsExperience  decimal(4,1)     NULL,
        PRIMARY KEY (SkillId)
    );
GO

/* ----------------------------------------------------------------------------
   BOOTSTRAP FUNCTIONS — created here, not in 06-create-functions.sql, because
   iam.User (03-create-tables.sql) uses dbo.fn_normalize_email in a persisted
   computed column and therefore needs it to exist before any table is created.
   The rest of the function catalog (section 13 of the design spec) lives in
   06-create-functions.sql — see docs/function-catalog.md for the full list and
   this note repeated there so the split isn't a surprise during review.
   ---------------------------------------------------------------------------- */

CREATE OR ALTER FUNCTION dbo.fn_normalize_email (@Email nvarchar(320))
RETURNS nvarchar(320)
WITH SCHEMABINDING
AS
BEGIN
    -- Lowercases and trims for uniqueness/search purposes only; the original
    -- Email column always retains the user-supplied casing/value.
    RETURN LOWER(LTRIM(RTRIM(@Email)));
END
GO

CREATE OR ALTER FUNCTION dbo.fn_normalize_phone (@Phone nvarchar(30))
RETURNS nvarchar(30)
WITH SCHEMABINDING
AS
BEGIN
    -- Strips everything except digits and a leading '+' for duplicate-detection
    -- and search purposes only; the original phone value is stored unchanged.
    DECLARE @result nvarchar(30) = N'';
    DECLARE @i int = 1;
    DECLARE @len int = LEN(ISNULL(@Phone, N''));
    DECLARE @ch nchar(1);
    WHILE @i <= @len
    BEGIN
        SET @ch = SUBSTRING(@Phone, @i, 1);
        IF @ch LIKE '[0-9]' OR (@ch = '+' AND @i = 1)
            SET @result = @result + @ch;
        SET @i += 1;
    END
    RETURN NULLIF(@result, N'');
END
GO

PRINT N'02-create-types.sql complete.';
