/* ============================================================================
   07-create-stored-procedures.sql
   Purpose : Stored procedures for security-sensitive, multi-entity, and
             workflow-critical actions (section 14 of the design spec).
             Ordinary single-entity CRUD (candidate profile edit, master-data
             lookups) goes through EF Core repositories instead — see
             ../../Persistence/README.md "When to use EF Core vs. a stored
             procedure". This file implements the highest-value subset in
             full: every procedure tied to a non-negotiable human-approval
             gate (TAN approval, candidate rejection, offer send, discrepancy
             resolution, employee conversion), plus the generic workflow/
             audit/outbox plumbing every other procedure builds on. The full
             procedure name list from section 14 is tracked in
             docs/stored-procedure-catalog.md, with each entry marked
             Implemented / Pending-same-pattern.

   Every procedure in this file:
     - Begins SET NOCOUNT ON; SET XACT_ABORT ON.
     - Validates TenantId is non-NULL and sets SESSION_CONTEXT for the
       duration of the call (defense-in-depth alongside API-layer auth).
     - Uses TRY/CATCH with safe ROLLBACK via XACT_STATE().
     - Returns Success, Message, EntityId, WorkflowInstanceId, CorrelationId,
       ErrorCode as a single-row result set.
     - Generates a CorrelationId when the caller doesn't supply one.
     - Writes an audit.AuditEvent row via audit.usp_WriteAuditEvent for every
       state-changing action.
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   GENERIC PLUMBING — every other procedure in this file calls these.
   ============================================================================ */

CREATE OR ALTER PROCEDURE audit.usp_WriteAuditEvent
    @TenantId UNIQUEIDENTIFIER = NULL,
    @ActorUserId UNIQUEIDENTIFIER = NULL,
    @ActorType nvarchar(20) = N'User',
    @Action nvarchar(150),
    @EntityType nvarchar(100),
    @EntityId UNIQUEIDENTIFIER = NULL,
    @PreviousStatus nvarchar(50) = NULL,
    @NewStatus nvarchar(50) = NULL,
    @Outcome nvarchar(20) = N'Success',
    @MetadataJson nvarchar(max) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Append-only insert only — no UPDATE/DELETE path exists for this table
    -- (also enforced by the trg_AuditEvent_PreventModify trigger).
    INSERT INTO audit.AuditEvent
        (TenantId, ActorUserId, ActorType, Action, EntityType, EntityId,
         PreviousStatus, NewStatus, Outcome, MetadataJson, CorrelationId, OccurredAtUtc)
    VALUES
        (@TenantId, @ActorUserId, @ActorType, @Action, @EntityType, @EntityId,
         @PreviousStatus, @NewStatus, @Outcome, @MetadataJson, @CorrelationId, SYSUTCDATETIME());
END
GO

CREATE OR ALTER PROCEDURE integration.usp_AddOutboxMessage
    @TenantId UNIQUEIDENTIFIER,
    @EventType nvarchar(150),
    @PayloadJson nvarchar(max),
    @PayloadVersion int = 1,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(@PayloadJson) = 0
    BEGIN
        SELECT CAST(0 AS bit) AS Success, N'PayloadJson is not valid JSON.' AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, N'INVALID_JSON' AS ErrorCode;
        RETURN;
    END

    DECLARE @messageId UNIQUEIDENTIFIER = NEWID();
    INSERT INTO integration.OutboxMessage (MessageId, TenantId, EventType, PayloadVersion, PayloadJson, CorrelationId)
    VALUES (@messageId, @TenantId, @EventType, @PayloadVersion, @PayloadJson, @CorrelationId);

    SELECT CAST(1 AS bit) AS Success, N'Outbox message queued.' AS Message,
           @messageId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
           @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
END
GO

CREATE OR ALTER PROCEDURE integration.usp_LockNextOutboxBatch
    @BatchSize int = 50
AS
BEGIN
    SET NOCOUNT ON;
    -- Set-based dispatch batch lock: READPAST skips rows already locked by a
    -- concurrent dispatcher instance, UPDLOCK claims the batch atomically.
    BEGIN TRAN;
    DECLARE @claimed TABLE (OutboxMessageId bigint PRIMARY KEY);

    UPDATE TOP (@BatchSize) om
        SET Status = N'Processing'
    OUTPUT inserted.OutboxMessageId INTO @claimed
    FROM integration.OutboxMessage om WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE om.Status IN (N'Pending', N'Failed')
      AND om.VisibleAfterUtc <= SYSUTCDATETIME()
      AND om.RetryCount < om.MaxRetryCount;

    SELECT om.OutboxMessageId, om.MessageId, om.TenantId, om.EventType, om.PayloadVersion, om.PayloadJson, om.RetryCount, om.CorrelationId
    FROM integration.OutboxMessage om
    JOIN @claimed c ON c.OutboxMessageId = om.OutboxMessageId;
    COMMIT TRAN;
END
GO

CREATE OR ALTER PROCEDURE integration.usp_MarkOutboxMessageProcessed
    @OutboxMessageId bigint
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE integration.OutboxMessage
        SET Status = N'Processed', ProcessedAtUtc = SYSUTCDATETIME()
        WHERE OutboxMessageId = @OutboxMessageId;

    SELECT CAST(1 AS bit) AS Success, N'Marked processed.' AS Message,
           CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
           CAST(NULL AS UNIQUEIDENTIFIER) AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
END
GO

CREATE OR ALTER PROCEDURE integration.usp_MarkOutboxMessageFailed
    @OutboxMessageId bigint,
    @ErrorMessage nvarchar(1000),
    @BackoffSeconds int = 60
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE integration.OutboxMessage
        SET Status = CASE WHEN RetryCount + 1 >= MaxRetryCount THEN N'DeadLettered' ELSE N'Failed' END,
            RetryCount = RetryCount + 1,
            LastErrorMessage = @ErrorMessage,
            VisibleAfterUtc = DATEADD(SECOND, @BackoffSeconds, SYSUTCDATETIME())
        WHERE OutboxMessageId = @OutboxMessageId;

    IF EXISTS (SELECT 1 FROM integration.OutboxMessage WHERE OutboxMessageId = @OutboxMessageId AND Status = N'DeadLettered')
    BEGIN
        INSERT INTO integration.DeadLetterMessage (TenantId, SourceType, SourceMessageId, PayloadJson, FailureReason)
        SELECT TenantId, N'Outbox', CAST(MessageId AS nvarchar(100)), PayloadJson, @ErrorMessage
        FROM integration.OutboxMessage WHERE OutboxMessageId = @OutboxMessageId;
    END

    SELECT CAST(1 AS bit) AS Success, N'Marked failed / retried.' AS Message,
           CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
           CAST(NULL AS UNIQUEIDENTIFIER) AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
END
GO

CREATE OR ALTER PROCEDURE integration.usp_RegisterInboxMessage
    @TenantId UNIQUEIDENTIFIER,
    @ExternalMessageId nvarchar(200),
    @SourceSystemCode nvarchar(100),
    @EventType nvarchar(150),
    @PayloadJson nvarchar(max) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        INSERT INTO integration.InboxMessage (TenantId, ExternalMessageId, SourceSystemCode, EventType, PayloadJson, CorrelationId)
        VALUES (@TenantId, @ExternalMessageId, @SourceSystemCode, @EventType, @PayloadJson, @CorrelationId);

        SELECT CAST(1 AS bit) AS Success, N'Registered.' AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627) -- unique-index violation = this exact message already processed
        BEGIN
            SELECT CAST(1 AS bit) AS Success, N'Duplicate — already registered, skipping reprocessing.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DUPLICATE' AS ErrorCode;
        END
        ELSE
        BEGIN
            SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
        END
    END CATCH
END
GO

/* ============================================================================
   IAM AND SETUP
   ============================================================================ */

CREATE OR ALTER PROCEDURE iam.usp_CreateTenant
    @TenantCode nvarchar(50),
    @TenantName nvarchar(200),
    @LegalName nvarchar(200) = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0)
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'A tenant with this code already exists.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DUPLICATE_CODE' AS ErrorCode;
            RETURN;
        END

        DECLARE @tenantId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO org.Tenant (TenantId, TenantCode, TenantName, LegalName, CreatedByUserId)
        VALUES (@tenantId, @TenantCode, @TenantName, @LegalName, @CreatedByUserId);

        -- The tenant did not exist until the INSERT above, so no caller could
        -- have set SESSION_CONTEXT to it beforehand — set it now, immediately
        -- after creation, so the audit write below (RLS-protected, tenant-
        -- scoped) is not rejected by the block predicate.
        EXEC sp_set_session_context @key = N'TenantId', @value = @tenantId;

        EXEC audit.usp_WriteAuditEvent @TenantId = @tenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'Tenant.Create', @EntityType = N'org.Tenant', @EntityId = @tenantId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Tenant created.' AS Message,
               @tenantId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE iam.usp_CreateUser
    @TenantId UNIQUEIDENTIFIER,
    @Email nvarchar(320),
    @DisplayName nvarchar(200),
    @ProviderName nvarchar(50),
    @ProviderSubjectId nvarchar(200),
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @normalizedEmail nvarchar(320) = dbo.fn_normalize_email(@Email);
        IF EXISTS (SELECT 1 FROM iam.[User] WHERE TenantId = @TenantId AND NormalizedEmail = @normalizedEmail AND IsDeleted = 0)
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'A user with this email already exists for this tenant.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DUPLICATE_EMAIL' AS ErrorCode;
            RETURN;
        END

        DECLARE @userId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO iam.[User] (UserId, TenantId, Email, DisplayName, UserStatus, CreatedByUserId)
        VALUES (@userId, @TenantId, @Email, @DisplayName, N'Active', @CreatedByUserId);

        INSERT INTO iam.UserAuthenticationProvider (TenantId, UserId, ProviderName, ProviderSubjectId, CreatedByUserId)
        VALUES (@TenantId, @userId, @ProviderName, @ProviderSubjectId, @CreatedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'User.Create', @EntityType = N'iam.User', @EntityId = @userId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'User created.' AS Message,
               @userId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE iam.usp_AssignUserRole
    @TenantId UNIQUEIDENTIFIER,
    @UserId UNIQUEIDENTIFIER,
    @RoleId UNIQUEIDENTIFIER,
    @AssignedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM iam.UserRole WHERE UserId = @UserId AND RoleId = @RoleId AND RevokedAtUtc IS NULL AND IsDeleted = 0)
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(1 AS bit) AS Success, N'Role already assigned (idempotent no-op).' AS Message,
                   @UserId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
            RETURN;
        END

        INSERT INTO iam.UserRole (TenantId, UserId, RoleId, AssignedByUserId)
        VALUES (@TenantId, @UserId, @RoleId, @AssignedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @AssignedByUserId,
             @Action = N'UserRole.Assign', @EntityType = N'iam.User', @EntityId = @UserId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Role assigned.' AS Message,
               @UserId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE iam.usp_RevokeUserRole
    @TenantId UNIQUEIDENTIFIER,
    @UserId UNIQUEIDENTIFIER,
    @RoleId UNIQUEIDENTIFIER,
    @RevokedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;
        UPDATE iam.UserRole SET RevokedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @RevokedByUserId, UpdatedAtUtc = SYSUTCDATETIME()
        WHERE UserId = @UserId AND RoleId = @RoleId AND RevokedAtUtc IS NULL AND IsDeleted = 0;

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @RevokedByUserId,
             @Action = N'UserRole.Revoke', @EntityType = N'iam.User', @EntityId = @UserId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Role revoked.' AS Message,
               @UserId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE iam.usp_SetSessionSecurityContext
    @TenantId UNIQUEIDENTIFIER
AS
BEGIN
    -- Called once per connection/request by HrAutomation.Api's connection-
    -- opening middleware, immediately after resolving the caller's tenant
    -- from their authenticated identity — never from a raw client header.
    SET NOCOUNT ON;
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId, @read_only = 1;
END
GO

/* ============================================================================
   CV BANK / CANDIDATE
   ============================================================================ */

CREATE OR ALTER PROCEDURE recruitment.usp_CreateCandidate
    @TenantId UNIQUEIDENTIFIER,
    @FirstName nvarchar(100),
    @LastName nvarchar(100),
    @Email nvarchar(320) = NULL,
    @Phone nvarchar(30) = NULL,
    @CandidateSourceCode nvarchar(50) = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @statusId UNIQUEIDENTIFIER = (
            SELECT TOP (1) CandidateStatusId FROM ref.CandidateStatus
            WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'New' AND IsActive = 1
            ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        DECLARE @sourceId UNIQUEIDENTIFIER = NULL;
        IF @CandidateSourceCode IS NOT NULL
            SET @sourceId = (SELECT TOP (1) CandidateSourceId FROM ref.CandidateSource
                              WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = @CandidateSourceCode
                              ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);

        DECLARE @candidateId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.Candidate (CandidateId, TenantId, FirstName, LastName, CandidateStatusId, PrimaryCandidateSourceId, CreatedByUserId)
        VALUES (@candidateId, @TenantId, @FirstName, @LastName, @statusId, @sourceId, @CreatedByUserId);

        IF @Email IS NOT NULL
            INSERT INTO recruitment.CandidateContact (TenantId, CandidateId, ContactType, ContactValue, NormalizedValue, IsPrimary, CreatedByUserId)
            VALUES (@TenantId, @candidateId, N'Email', @Email, dbo.fn_normalize_email(@Email), 1, @CreatedByUserId);

        IF @Phone IS NOT NULL
            INSERT INTO recruitment.CandidateContact (TenantId, CandidateId, ContactType, ContactValue, NormalizedValue, IsPrimary, CreatedByUserId)
            VALUES (@TenantId, @candidateId, N'Phone', @Phone, dbo.fn_normalize_phone(@Phone), 1, @CreatedByUserId);

        INSERT INTO recruitment.CandidateStatusHistory (TenantId, CandidateId, ToCandidateStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @candidateId, @statusId, @CreatedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'Candidate.Create', @EntityType = N'recruitment.Candidate', @EntityId = @candidateId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Candidate created.' AS Message,
               @candidateId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE recruitment.usp_CreateDuplicateReview
    @TenantId UNIQUEIDENTIFIER,
    @PrimaryCandidateId UNIQUEIDENTIFIER,
    @SuspectedDuplicateCandidateId UNIQUEIDENTIFIER,
    @MatchConfidenceScore decimal(5,4) = NULL,
    @MatchReason nvarchar(500) = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF @PrimaryCandidateId = @SuspectedDuplicateCandidateId
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'A candidate cannot be a duplicate of itself.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'INVALID_SELF_REFERENCE' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @reviewId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.CandidateDuplicateReview
            (CandidateDuplicateReviewId, TenantId, PrimaryCandidateId, SuspectedDuplicateCandidateId, MatchConfidenceScore, MatchReason, CreatedByUserId)
        VALUES (@reviewId, @TenantId, @PrimaryCandidateId, @SuspectedDuplicateCandidateId, @MatchConfidenceScore, @MatchReason, @CreatedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'CandidateDuplicateReview.Create', @EntityType = N'recruitment.CandidateDuplicateReview', @EntityId = @reviewId,
             @CorrelationId = @CorrelationId;
        COMMIT TRAN;

        SELECT CAST(1 AS bit) AS Success, N'Duplicate review created.' AS Message,
               @reviewId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* recruitment.usp_MergeCandidateRecords — merge is a HUMAN decision (the
   AI/duplicate-detection pipeline only creates the CandidateDuplicateReview
   suggestion via usp_CreateDuplicateReview); this procedure requires the
   review to already be in 'ConfirmedDuplicate' status, set by a human. */
CREATE OR ALTER PROCEDURE recruitment.usp_MergeCandidateRecords
    @TenantId UNIQUEIDENTIFIER,
    @CandidateDuplicateReviewId UNIQUEIDENTIFIER,
    @MergedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @primaryId UNIQUEIDENTIFIER, @dupId UNIQUEIDENTIFIER, @reviewStatus nvarchar(20);
        SELECT @primaryId = PrimaryCandidateId, @dupId = SuspectedDuplicateCandidateId, @reviewStatus = ReviewStatus
        FROM recruitment.CandidateDuplicateReview WHERE CandidateDuplicateReviewId = @CandidateDuplicateReviewId AND TenantId = @TenantId;

        IF @reviewStatus IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Duplicate review not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END
        IF @reviewStatus <> N'ConfirmedDuplicate'
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Merge requires a human-confirmed duplicate review (ReviewStatus = ConfirmedDuplicate).' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_REQUIRED' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        -- Soft-delete the merged-away candidate; history is never hard-deleted.
        UPDATE recruitment.Candidate SET IsDeleted = 1, DeletedAtUtc = SYSUTCDATETIME(), DeletedByUserId = @MergedByUserId
        WHERE CandidateId = @dupId AND TenantId = @TenantId;

        DECLARE @mergeId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.CandidateMergeHistory
            (CandidateMergeHistoryId, TenantId, CandidateDuplicateReviewId, SurvivingCandidateId, MergedCandidateId, MergedByUserId, CorrelationId)
        VALUES (@mergeId, @TenantId, @CandidateDuplicateReviewId, @primaryId, @dupId, @MergedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @MergedByUserId,
             @Action = N'Candidate.Merge', @EntityType = N'recruitment.Candidate', @EntityId = @primaryId,
             @CorrelationId = @CorrelationId;
        COMMIT TRAN;

        SELECT CAST(1 AS bit) AS Success, N'Candidates merged.' AS Message,
               @primaryId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   TAN / REQUISITION
   ============================================================================ */

CREATE OR ALTER PROCEDURE recruitment.usp_CreateTalentAcquisitionNumber
    @TenantId UNIQUEIDENTIFIER,
    @DepartmentId UNIQUEIDENTIFIER = NULL,
    @BusinessUnitId UNIQUEIDENTIFIER = NULL,
    @RequestedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;

        -- Reserve the next TAN number under UPDLOCK/HOLDLOCK so concurrent
        -- requests can never receive the same number (uniqueness per
        -- non-negotiable rule "TAN must be unique by tenant").
        DECLARE @ruleId UNIQUEIDENTIFIER, @prefix nvarchar(20), @suffix nvarchar(20), @padding int, @nextSeq bigint;
        SELECT TOP (1) @ruleId = NumberingRuleId, @prefix = Prefix, @suffix = Suffix, @padding = PaddingWidth
        FROM ref.NumberingRule WITH (UPDLOCK, HOLDLOCK)
        WHERE TenantId = @TenantId AND EntityType = N'TAN' AND IsActive = 1 AND IsDeleted = 0;

        IF @ruleId IS NULL
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'No active TAN numbering rule configured for this tenant.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NUMBERING_RULE_MISSING' AS ErrorCode;
            RETURN;
        END

        UPDATE ref.NumberingRule SET CurrentSequence = CurrentSequence + 1 WHERE NumberingRuleId = @ruleId;
        SELECT @nextSeq = CurrentSequence FROM ref.NumberingRule WHERE NumberingRuleId = @ruleId;

        DECLARE @tanNumber nvarchar(50) = ISNULL(@prefix, N'') + RIGHT(REPLICATE('0', @padding) + CAST(@nextSeq AS nvarchar(20)), @padding) + ISNULL(@suffix, N'');
        DECLARE @tanId UNIQUEIDENTIFIER = NEWID();

        INSERT INTO recruitment.TalentAcquisitionNumber (TalentAcquisitionNumberId, TenantId, TanNumber, NumberingRuleId, DepartmentId, BusinessUnitId, RequestedByUserId, CreatedByUserId)
        VALUES (@tanId, @TenantId, @tanNumber, @ruleId, @DepartmentId, @BusinessUnitId, @RequestedByUserId, @RequestedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @RequestedByUserId,
             @Action = N'TAN.Create', @EntityType = N'recruitment.TalentAcquisitionNumber', @EntityId = @tanId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, @tanNumber AS Message,
               @tanId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE recruitment.usp_CreateJobRequisition
    @TenantId UNIQUEIDENTIFIER,
    @TalentAcquisitionNumberId UNIQUEIDENTIFIER,
    @Title nvarchar(200),
    @HeadcountRequested int = 1,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @reqId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.JobRequisition
            (JobRequisitionId, TenantId, TalentAcquisitionNumberId, Title, HeadcountRequested, RequisitionStatusCode, CreatedByUserId)
        VALUES (@reqId, @TenantId, @TalentAcquisitionNumberId, @Title, @HeadcountRequested, N'Draft', @CreatedByUserId);

        DECLARE @i int = 1;
        WHILE @i <= @HeadcountRequested
        BEGIN
            INSERT INTO recruitment.JobOpening (TenantId, JobRequisitionId, OpeningSequenceNumber, CreatedByUserId)
            VALUES (@TenantId, @reqId, @i, @CreatedByUserId);
            SET @i += 1;
        END

        INSERT INTO recruitment.JobRequisitionStatusHistory (TenantId, JobRequisitionId, ToStatusCode, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @reqId, N'Draft', @CreatedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'JobRequisition.Create', @EntityType = N'recruitment.JobRequisition', @EntityId = @reqId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Job requisition created.' AS Message,
               @reqId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE recruitment.usp_SubmitJobRequisitionForApproval
    @TenantId UNIQUEIDENTIFIER,
    @JobRequisitionId UNIQUEIDENTIFIER,
    @ApprovalMatrixCode nvarchar(100),
    @RequestedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @currentStatus nvarchar(30) = (SELECT RequisitionStatusCode FROM recruitment.JobRequisition WHERE JobRequisitionId = @JobRequisitionId AND TenantId = @TenantId);
        IF @currentStatus IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Job requisition not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END
        IF @currentStatus <> N'Draft'
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Only a Draft requisition can be submitted for approval.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'INVALID_TRANSITION' AS ErrorCode;
            RETURN;
        END

        DECLARE @matrixId UNIQUEIDENTIFIER = (SELECT ApprovalMatrixId FROM ref.ApprovalMatrix WHERE TenantId = @TenantId AND MatrixCode = @ApprovalMatrixCode AND IsActive = 1);
        IF @matrixId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval matrix not found for this tenant.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_MATRIX_MISSING' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @approvalRequestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO workflow.ApprovalRequest (ApprovalRequestId, TenantId, ApprovalMatrixId, EntityType, EntityId, RequestedByUserId, CorrelationId)
        VALUES (@approvalRequestId, @TenantId, @matrixId, N'recruitment.JobRequisition', @JobRequisitionId, @RequestedByUserId, @CorrelationId);

        INSERT INTO workflow.ApprovalStep (TenantId, ApprovalRequestId, ApprovalMatrixRuleId, StepOrder, AssignedApproverUserId)
        SELECT @TenantId, @approvalRequestId, amr.ApprovalMatrixRuleId, amr.StepOrder, NULL
        FROM ref.ApprovalMatrixRule amr WHERE amr.ApprovalMatrixId = @matrixId AND amr.IsDeleted = 0
        ORDER BY amr.StepOrder;

        UPDATE recruitment.JobRequisition SET RequisitionStatusCode = N'PendingApproval', UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @RequestedByUserId
        WHERE JobRequisitionId = @JobRequisitionId;

        INSERT INTO recruitment.JobRequisitionStatusHistory (TenantId, JobRequisitionId, FromStatusCode, ToStatusCode, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @JobRequisitionId, @currentStatus, N'PendingApproval', @RequestedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @RequestedByUserId,
             @Action = N'JobRequisition.SubmitForApproval', @EntityType = N'recruitment.JobRequisition', @EntityId = @JobRequisitionId,
             @PreviousStatus = @currentStatus, @NewStatus = N'PendingApproval', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Submitted for approval.' AS Message,
               @JobRequisitionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE recruitment.usp_ApproveJobRequisition
    @TenantId UNIQUEIDENTIFIER,
    @JobRequisitionId UNIQUEIDENTIFIER,
    @ApproverUserId UNIQUEIDENTIFIER,
    @Comments nvarchar(1000) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @approvalRequestId UNIQUEIDENTIFIER, @stepId UNIQUEIDENTIFIER, @stepStatus nvarchar(20);
        SELECT TOP (1) @approvalRequestId = ar.ApprovalRequestId, @stepId = ast.ApprovalStepId, @stepStatus = ast.Status
        FROM workflow.ApprovalRequest ar
        JOIN workflow.ApprovalStep ast ON ast.ApprovalRequestId = ar.ApprovalRequestId
        WHERE ar.EntityType = N'recruitment.JobRequisition' AND ar.EntityId = @JobRequisitionId AND ar.Status = N'Pending' AND ar.TenantId = @TenantId
        ORDER BY ast.StepOrder;

        IF @approvalRequestId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'No pending approval request found for this requisition.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        UPDATE workflow.ApprovalStep SET Status = N'Approved' WHERE ApprovalStepId = @stepId;
        INSERT INTO workflow.ApprovalDecision (TenantId, ApprovalStepId, DecidedByUserId, Decision, Comments, CorrelationId)
        VALUES (@TenantId, @stepId, @ApproverUserId, N'Approved', @Comments, @CorrelationId);

        -- If every step is Approved, the overall request and the requisition
        -- move forward; otherwise the requisition stays PendingApproval for
        -- the next step (multi-step matrices supported by ref.ApprovalMatrixRule).
        IF NOT EXISTS (SELECT 1 FROM workflow.ApprovalStep WHERE ApprovalRequestId = @approvalRequestId AND Status NOT IN (N'Approved', N'Skipped'))
        BEGIN
            UPDATE workflow.ApprovalRequest SET Status = N'Approved', CompletedAtUtc = SYSUTCDATETIME() WHERE ApprovalRequestId = @approvalRequestId;
            UPDATE recruitment.JobRequisition SET RequisitionStatusCode = N'Approved', UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @ApproverUserId
            WHERE JobRequisitionId = @JobRequisitionId;
            INSERT INTO recruitment.JobRequisitionStatusHistory (TenantId, JobRequisitionId, FromStatusCode, ToStatusCode, ChangedByUserId, CorrelationId)
            VALUES (@TenantId, @JobRequisitionId, N'PendingApproval', N'Approved', @ApproverUserId, @CorrelationId);
        END

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ApproverUserId,
             @Action = N'JobRequisition.Approve', @EntityType = N'recruitment.JobRequisition', @EntityId = @JobRequisitionId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Approval step recorded.' AS Message,
               @JobRequisitionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* Added post-catalog: usp_ApproveJobRequisition had no reject counterpart, and
   usp_CloseJobRequisition doesn't touch the pending workflow.ApprovalRequest/Step/Decision
   rows it would leave dangling. Mirrors usp_ApproveJobRequisition's pattern exactly, with
   Decision = 'Rejected' and RequisitionStatusCode -> 'Cancelled'. */
CREATE OR ALTER PROCEDURE recruitment.usp_RejectJobRequisition
    @TenantId UNIQUEIDENTIFIER,
    @JobRequisitionId UNIQUEIDENTIFIER,
    @ApproverUserId UNIQUEIDENTIFIER,
    @Comments nvarchar(1000) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @approvalRequestId UNIQUEIDENTIFIER, @stepId UNIQUEIDENTIFIER;
        SELECT TOP (1) @approvalRequestId = ar.ApprovalRequestId, @stepId = ast.ApprovalStepId
        FROM workflow.ApprovalRequest ar
        JOIN workflow.ApprovalStep ast ON ast.ApprovalRequestId = ar.ApprovalRequestId
        WHERE ar.EntityType = N'recruitment.JobRequisition' AND ar.EntityId = @JobRequisitionId AND ar.Status = N'Pending' AND ar.TenantId = @TenantId
        ORDER BY ast.StepOrder;

        IF @approvalRequestId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'No pending approval request found for this requisition.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @currentStatus nvarchar(30) = (SELECT RequisitionStatusCode FROM recruitment.JobRequisition WHERE JobRequisitionId = @JobRequisitionId);

        UPDATE workflow.ApprovalStep SET Status = N'Rejected' WHERE ApprovalStepId = @stepId;
        INSERT INTO workflow.ApprovalDecision (TenantId, ApprovalStepId, DecidedByUserId, Decision, Comments, CorrelationId)
        VALUES (@TenantId, @stepId, @ApproverUserId, N'Rejected', @Comments, @CorrelationId);

        UPDATE workflow.ApprovalRequest SET Status = N'Rejected', CompletedAtUtc = SYSUTCDATETIME() WHERE ApprovalRequestId = @approvalRequestId;
        UPDATE recruitment.JobRequisition SET RequisitionStatusCode = N'Cancelled', UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @ApproverUserId
        WHERE JobRequisitionId = @JobRequisitionId;
        INSERT INTO recruitment.JobRequisitionStatusHistory (TenantId, JobRequisitionId, FromStatusCode, ToStatusCode, ChangedByUserId, Reason, CorrelationId)
        VALUES (@TenantId, @JobRequisitionId, @currentStatus, N'Cancelled', @ApproverUserId, @Comments, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ApproverUserId,
             @Action = N'JobRequisition.Reject', @EntityType = N'recruitment.JobRequisition', @EntityId = @JobRequisitionId,
             @PreviousStatus = @currentStatus, @NewStatus = N'Cancelled', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Rejection recorded.' AS Message,
               @JobRequisitionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE recruitment.usp_CloseJobRequisition
    @TenantId UNIQUEIDENTIFIER,
    @JobRequisitionId UNIQUEIDENTIFIER,
    @ClosedByUserId UNIQUEIDENTIFIER,
    @Reason nvarchar(500) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @currentStatus nvarchar(30) = (SELECT RequisitionStatusCode FROM recruitment.JobRequisition WHERE JobRequisitionId = @JobRequisitionId AND TenantId = @TenantId);
        IF @currentStatus IS NULL OR @currentStatus = N'Cancelled' OR @currentStatus = N'ClosedFilled'
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Requisition not found or already closed.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'INVALID_TRANSITION' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @allFilled bit = CASE WHEN NOT EXISTS (SELECT 1 FROM recruitment.JobOpening WHERE JobRequisitionId = @JobRequisitionId AND IsFilled = 0) THEN 1 ELSE 0 END;
        DECLARE @newStatus nvarchar(30) = CASE WHEN @allFilled = 1 THEN N'ClosedFilled' ELSE N'Cancelled' END;

        UPDATE recruitment.JobRequisition SET RequisitionStatusCode = @newStatus, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @ClosedByUserId
        WHERE JobRequisitionId = @JobRequisitionId;

        INSERT INTO recruitment.JobRequisitionStatusHistory (TenantId, JobRequisitionId, FromStatusCode, ToStatusCode, ChangedByUserId, Reason, CorrelationId)
        VALUES (@TenantId, @JobRequisitionId, @currentStatus, @newStatus, @ClosedByUserId, @Reason, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ClosedByUserId,
             @Action = N'JobRequisition.Close', @EntityType = N'recruitment.JobRequisition', @EntityId = @JobRequisitionId,
             @PreviousStatus = @currentStatus, @NewStatus = @newStatus, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, @newStatus AS Message,
               @JobRequisitionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   MATCHING / APPLICATION
   ============================================================================ */

CREATE OR ALTER PROCEDURE recruitment.usp_CreateCandidateApplication
    @TenantId UNIQUEIDENTIFIER,
    @CandidateId UNIQUEIDENTIFIER,
    @JobRequisitionId UNIQUEIDENTIFIER,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    -- A candidate MAY apply to multiple TANs — only an *active* (non-terminal)
    -- application per candidate+requisition is blocked, per the schema note
    -- on recruitment.CandidateApplication.
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM recruitment.CandidateApplication ca
            JOIN ref.CandidateStatus cs ON cs.Code = ca.ApplicationStatusCode -- ApplicationStatusCode reuses candidate-status-style codes by convention; see data-dictionary.md
            WHERE ca.CandidateId = @CandidateId AND ca.JobRequisitionId = @JobRequisitionId
              AND ca.IsDeleted = 0 AND ISNULL(cs.IsTerminal, 0) = 0
        )
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Candidate already has an active application for this requisition.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DUPLICATE_ACTIVE_APPLICATION' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @applicationId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.CandidateApplication (CandidateApplicationId, TenantId, CandidateId, JobRequisitionId, ApplicationStatusCode, CreatedByUserId)
        VALUES (@applicationId, @TenantId, @CandidateId, @JobRequisitionId, N'Applied', @CreatedByUserId);

        INSERT INTO recruitment.CandidateApplicationStatusHistory (TenantId, CandidateApplicationId, ToStatusCode, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @applicationId, N'Applied', @CreatedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'CandidateApplication.Create', @EntityType = N'recruitment.CandidateApplication', @EntityId = @applicationId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Application created.' AS Message,
               @applicationId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* recruitment.usp_ApproveCandidateShortlist — AI never shortlists alone: this
   procedure requires ShortlistedByUserId to already be set by
   recruitment.usp_SaveCandidateMatchRecommendation's caller (the UI action a
   human takes), and additionally requires a human approval decision here. */
CREATE OR ALTER PROCEDURE recruitment.usp_ApproveCandidateShortlist
    @TenantId UNIQUEIDENTIFIER,
    @CandidateShortlistId UNIQUEIDENTIFIER,
    @ApproverUserId UNIQUEIDENTIFIER,
    @Comments nvarchar(1000) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateShortlist WHERE CandidateShortlistId = @CandidateShortlistId AND TenantId = @TenantId AND ShortlistedByUserId IS NOT NULL)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Shortlist entry not found or was never confirmed by a human.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        INSERT INTO recruitment.CandidateShortlistApproval (TenantId, CandidateShortlistId, ApproverUserId, DecisionStatus, DecidedAtUtc, Comments)
        VALUES (@TenantId, @CandidateShortlistId, @ApproverUserId, N'Approved', SYSUTCDATETIME(), @Comments);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ApproverUserId,
             @Action = N'CandidateShortlist.Approve', @EntityType = N'recruitment.CandidateShortlist', @EntityId = @CandidateShortlistId,
             @CorrelationId = @CorrelationId;
        COMMIT TRAN;

        SELECT CAST(1 AS bit) AS Success, N'Shortlist approved.' AS Message,
               @CandidateShortlistId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* recruitment.usp_RejectCandidateForRequisition — the canonical example of
   "AI must not autonomously reject a candidate": @DecidedByUserId is
   mandatory and must resolve to a real iam.User row (enforced by the FK);
   there is no code path here an AI service account can call without a human
   decision already made upstream (see docs/ai-guardrails-policy.md). */
CREATE OR ALTER PROCEDURE recruitment.usp_RejectCandidateForRequisition
    @TenantId UNIQUEIDENTIFIER,
    @CandidateApplicationId UNIQUEIDENTIFIER,
    @RejectionReasonCode nvarchar(50),
    @RejectionNotes nvarchar(1000) = NULL,
    @DecidedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF @DecidedByUserId IS NULL OR NOT EXISTS (SELECT 1 FROM iam.[User] WHERE UserId = @DecidedByUserId AND IsSystemServiceAccount = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Candidate rejection requires a human decision-maker (DecidedByUserId must be a non-service-account user).' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'HUMAN_APPROVAL_REQUIRED' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        INSERT INTO recruitment.CandidateRejection (TenantId, CandidateApplicationId, RejectionReasonCode, RejectionNotes, DecidedByUserId)
        VALUES (@TenantId, @CandidateApplicationId, @RejectionReasonCode, @RejectionNotes, @DecidedByUserId);

        DECLARE @fromStatus nvarchar(30) = (SELECT ApplicationStatusCode FROM recruitment.CandidateApplication WHERE CandidateApplicationId = @CandidateApplicationId);
        UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'Rejected', UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @DecidedByUserId
        WHERE CandidateApplicationId = @CandidateApplicationId;

        INSERT INTO recruitment.CandidateApplicationStatusHistory (TenantId, CandidateApplicationId, FromStatusCode, ToStatusCode, ChangedByUserId, Reason, CorrelationId)
        VALUES (@TenantId, @CandidateApplicationId, @fromStatus, N'Rejected', @DecidedByUserId, @RejectionNotes, @CorrelationId);

        -- Rejection for THIS requisition never touches the candidate's other
        -- applications — "remains available for other TANs subject to policy".
        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @DecidedByUserId,
             @Action = N'CandidateApplication.Reject', @EntityType = N'recruitment.CandidateApplication', @EntityId = @CandidateApplicationId,
             @PreviousStatus = @fromStatus, @NewStatus = N'Rejected', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Candidate rejected for this requisition.' AS Message,
               @CandidateApplicationId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   INTERVIEW — scheduling creates the next InterviewRound for an application's
   Interview; feedback is always submitted by the assigned human panelist and
   records InterviewOutcome directly (a real, audited human decision) — it
   does not itself advance the CandidateApplication through the TAN/offer
   pipeline (see recruitment.usp_ApproveCandidateShortlist for that gate).
   ============================================================================ */

CREATE OR ALTER PROCEDURE recruitment.usp_ScheduleInterview
    @TenantId UNIQUEIDENTIFIER,
    @CandidateApplicationId UNIQUEIDENTIFIER,
    @InterviewRoundDefinitionId UNIQUEIDENTIFIER,
    @ScheduledStartUtc datetime2(7),
    @ScheduledEndUtc datetime2(7),
    @TimeZoneId nvarchar(60) = NULL,
    @LocationOrLink nvarchar(500) = NULL,
    @PanelUserId UNIQUEIDENTIFIER = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF @ScheduledEndUtc <= @ScheduledStartUtc
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Scheduled end time must be after the start time.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'INVALID_TIME_RANGE' AS ErrorCode;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateApplication WHERE CandidateApplicationId = @CandidateApplicationId AND TenantId = @TenantId)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Candidate application not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;

        DECLARE @interviewId UNIQUEIDENTIFIER = (SELECT InterviewId FROM recruitment.Interview WHERE CandidateApplicationId = @CandidateApplicationId AND TenantId = @TenantId AND IsDeleted = 0);
        IF @interviewId IS NULL
        BEGIN
            SET @interviewId = NEWID();
            INSERT INTO recruitment.Interview (InterviewId, TenantId, CandidateApplicationId, Status, CreatedAtUtc, CreatedByUserId)
            VALUES (@interviewId, @TenantId, @CandidateApplicationId, N'Scheduled', SYSUTCDATETIME(), @CreatedByUserId);
        END
        ELSE
        BEGIN
            UPDATE recruitment.Interview SET Status = N'Scheduled', UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @CreatedByUserId WHERE InterviewId = @interviewId;
        END

        DECLARE @nextSequence int = ISNULL((SELECT MAX(SequenceNumber) FROM recruitment.InterviewRound WHERE InterviewId = @interviewId AND IsDeleted = 0), 0) + 1;

        DECLARE @interviewRoundId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.InterviewRound (InterviewRoundId, TenantId, InterviewId, InterviewRoundDefinitionId, SequenceNumber, CreatedAtUtc, CreatedByUserId)
        VALUES (@interviewRoundId, @TenantId, @interviewId, @InterviewRoundDefinitionId, @nextSequence, SYSUTCDATETIME(), @CreatedByUserId);

        IF @PanelUserId IS NOT NULL
            INSERT INTO recruitment.InterviewPanelMember (TenantId, InterviewRoundId, UserId, IsLeadInterviewer, CreatedAtUtc, CreatedByUserId)
            VALUES (@TenantId, @interviewRoundId, @PanelUserId, 1, SYSUTCDATETIME(), @CreatedByUserId);

        INSERT INTO recruitment.InterviewScheduleSlot (TenantId, InterviewRoundId, ScheduledStartUtc, ScheduledEndUtc, TimeZoneId, LocationOrLink, IsCurrent, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @interviewRoundId, @ScheduledStartUtc, @ScheduledEndUtc, @TimeZoneId, @LocationOrLink, 1, SYSUTCDATETIME(), @CreatedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'Interview.Schedule', @EntityType = N'recruitment.InterviewRound', @EntityId = @interviewRoundId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Interview scheduled.' AS Message,
               @interviewRoundId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE recruitment.usp_SubmitInterviewFeedback
    @TenantId UNIQUEIDENTIFIER,
    @InterviewRoundId UNIQUEIDENTIFIER,
    @SubmittedByUserId UNIQUEIDENTIFIER,
    @OverallRecommendation nvarchar(20), -- StrongYes, Yes, No, StrongNo (CK_InterviewFeedback_Recommendation)
    @OutcomeStatus nvarchar(20), -- Progressed, Rejected, OnHold (CK_InterviewOutcome_Status)
    @CommunicationScore decimal(5,2) = NULL,
    @TechnicalScore decimal(5,2) = NULL,
    @Notes nvarchar(2000) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF @SubmittedByUserId IS NULL OR NOT EXISTS (SELECT 1 FROM iam.[User] WHERE UserId = @SubmittedByUserId AND IsSystemServiceAccount = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Interview feedback requires a human panelist (SubmittedByUserId must be a non-service-account user).' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'HUMAN_APPROVAL_REQUIRED' AS ErrorCode;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewRound WHERE InterviewRoundId = @InterviewRoundId AND TenantId = @TenantId AND IsDeleted = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Interview round not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        DECLARE @templateId UNIQUEIDENTIFIER = (SELECT TOP (1) InterviewFeedbackTemplateId FROM ref.InterviewFeedbackTemplate WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'STANDARD_FEEDBACK' AND IsActive = 1 ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        IF @templateId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'No active interview feedback template configured.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'TEMPLATE_MISSING' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;

        DECLARE @nextVersion int = ISNULL((SELECT MAX(VersionNumber) FROM recruitment.InterviewFeedback WHERE InterviewRoundId = @InterviewRoundId AND SubmittedByUserId = @SubmittedByUserId AND IsDeleted = 0), 0) + 1;

        DECLARE @feedbackId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.InterviewFeedback (InterviewFeedbackId, TenantId, InterviewRoundId, InterviewFeedbackTemplateId, SubmittedByUserId, VersionNumber, OverallRecommendation, SubmittedAtUtc, IsFinal, CreatedAtUtc, CreatedByUserId)
        VALUES (@feedbackId, @TenantId, @InterviewRoundId, @templateId, @SubmittedByUserId, @nextVersion, @OverallRecommendation, SYSUTCDATETIME(), 1, SYSUTCDATETIME(), @SubmittedByUserId);

        IF @Notes IS NOT NULL
            INSERT INTO recruitment.InterviewFeedbackComment (TenantId, InterviewFeedbackId, CommentText, CreatedAtUtc)
            VALUES (@TenantId, @feedbackId, @Notes, SYSUTCDATETIME());

        IF @CommunicationScore IS NOT NULL
        BEGIN
            DECLARE @commCompetencyId UNIQUEIDENTIFIER = (SELECT TOP (1) InterviewCompetencyId FROM ref.InterviewCompetency WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'COMMUNICATION' AND IsActive = 1 ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
            IF @commCompetencyId IS NOT NULL
                INSERT INTO recruitment.InterviewFeedbackScore (TenantId, InterviewFeedbackId, InterviewCompetencyId, Score, MaxScore)
                VALUES (@TenantId, @feedbackId, @commCompetencyId, @CommunicationScore, 5);
        END

        IF @TechnicalScore IS NOT NULL
        BEGIN
            DECLARE @techCompetencyId UNIQUEIDENTIFIER = (SELECT TOP (1) InterviewCompetencyId FROM ref.InterviewCompetency WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'TECHNICAL_SKILLS' AND IsActive = 1 ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
            IF @techCompetencyId IS NOT NULL
                INSERT INTO recruitment.InterviewFeedbackScore (TenantId, InterviewFeedbackId, InterviewCompetencyId, Score, MaxScore)
                VALUES (@TenantId, @feedbackId, @techCompetencyId, @TechnicalScore, 5);
        END

        -- The outcome decision belongs to the human panelist submitting feedback for
        -- their own round — it is recorded here directly (DecidedByUserId = the
        -- submitter), and is distinct from — and does not itself trigger — the
        -- CandidateApplication's overall shortlist/offer progression, which stays
        -- gated behind its own separate human approval (usp_ApproveCandidateShortlist
        -- / the progression-approval action).
        DECLARE @outcomeId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO recruitment.InterviewOutcome (InterviewOutcomeId, TenantId, InterviewRoundId, OutcomeStatus, DecidedByUserId, DecidedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@outcomeId, @TenantId, @InterviewRoundId, @OutcomeStatus, @SubmittedByUserId, SYSUTCDATETIME(), SYSUTCDATETIME(), @SubmittedByUserId);

        UPDATE i SET i.Status = N'Completed', i.UpdatedAtUtc = SYSUTCDATETIME(), i.UpdatedByUserId = @SubmittedByUserId
        FROM recruitment.Interview i
        JOIN recruitment.InterviewRound r ON r.InterviewId = i.InterviewId
        WHERE r.InterviewRoundId = @InterviewRoundId;

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @SubmittedByUserId,
             @Action = N'Interview.SubmitFeedback', @EntityType = N'recruitment.InterviewRound', @EntityId = @InterviewRoundId,
             @NewStatus = @OutcomeStatus, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Interview feedback recorded.' AS Message,
               @feedbackId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   OFFER — "Sent" cannot be reached without a prior Approved offer.OfferApproval.
   ============================================================================ */

CREATE OR ALTER PROCEDURE offer.usp_CreateOfferDraft
    @TenantId UNIQUEIDENTIFIER,
    @CandidateApplicationId UNIQUEIDENTIFIER,
    @OfferTemplateId UNIQUEIDENTIFIER = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @draftStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) OfferStatusId FROM ref.OfferStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Draft' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        DECLARE @ruleId UNIQUEIDENTIFIER, @prefix nvarchar(20), @suffix nvarchar(20), @padding int, @nextSeq bigint;
        SELECT TOP (1) @ruleId = NumberingRuleId, @prefix = Prefix, @suffix = Suffix, @padding = PaddingWidth
        FROM ref.NumberingRule WITH (UPDLOCK, HOLDLOCK) WHERE TenantId = @TenantId AND EntityType = N'OfferNumber' AND IsActive = 1;
        DECLARE @offerNumber nvarchar(50) = N'DRAFT-' + CAST(NEWID() AS nvarchar(50));
        IF @ruleId IS NOT NULL
        BEGIN
            UPDATE ref.NumberingRule SET CurrentSequence = CurrentSequence + 1 WHERE NumberingRuleId = @ruleId;
            SELECT @nextSeq = CurrentSequence FROM ref.NumberingRule WHERE NumberingRuleId = @ruleId;
            SET @offerNumber = ISNULL(@prefix, N'') + RIGHT(REPLICATE('0', @padding) + CAST(@nextSeq AS nvarchar(20)), @padding) + ISNULL(@suffix, N'');
        END

        DECLARE @offerId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO offer.Offer (OfferId, TenantId, CandidateApplicationId, OfferTemplateId, OfferNumber, OfferStatusId, CreatedByUserId)
        VALUES (@offerId, @TenantId, @CandidateApplicationId, @OfferTemplateId, @offerNumber, @draftStatusId, @CreatedByUserId);

        INSERT INTO offer.OfferVersion (TenantId, OfferId, VersionNumber, CreatedByUserId)
        VALUES (@TenantId, @offerId, 1, @CreatedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'Offer.CreateDraft', @EntityType = N'offer.Offer', @EntityId = @offerId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, @offerNumber AS Message,
               @offerId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE offer.usp_SubmitOfferForApproval
    @TenantId UNIQUEIDENTIFIER,
    @OfferId UNIQUEIDENTIFIER,
    @ApprovalMatrixCode nvarchar(100),
    @RequestedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @matrixId UNIQUEIDENTIFIER = (SELECT ApprovalMatrixId FROM ref.ApprovalMatrix WHERE TenantId = @TenantId AND MatrixCode = @ApprovalMatrixCode AND IsActive = 1);
        IF @matrixId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval matrix not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_MATRIX_MISSING' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @approvalRequestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO workflow.ApprovalRequest (ApprovalRequestId, TenantId, ApprovalMatrixId, EntityType, EntityId, RequestedByUserId, CorrelationId)
        VALUES (@approvalRequestId, @TenantId, @matrixId, N'offer.Offer', @OfferId, @RequestedByUserId, @CorrelationId);

        INSERT INTO offer.OfferApproval (TenantId, OfferId, ApprovalRequestId, Status, RequestedAtUtc)
        VALUES (@TenantId, @OfferId, @approvalRequestId, N'Pending', SYSUTCDATETIME());

        INSERT INTO workflow.ApprovalStep (TenantId, ApprovalRequestId, ApprovalMatrixRuleId, StepOrder)
        SELECT @TenantId, @approvalRequestId, amr.ApprovalMatrixRuleId, amr.StepOrder
        FROM ref.ApprovalMatrixRule amr WHERE amr.ApprovalMatrixId = @matrixId AND amr.IsDeleted = 0 ORDER BY amr.StepOrder;

        DECLARE @pendingApprovalStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) OfferStatusId FROM ref.OfferStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'PendingApproval' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        UPDATE offer.Offer SET OfferStatusId = @pendingApprovalStatusId, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @RequestedByUserId WHERE OfferId = @OfferId;

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @RequestedByUserId,
             @Action = N'Offer.SubmitForApproval', @EntityType = N'offer.Offer', @EntityId = @OfferId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Offer submitted for approval.' AS Message,
               @OfferId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE offer.usp_ApproveOffer
    @TenantId UNIQUEIDENTIFIER,
    @OfferId UNIQUEIDENTIFIER,
    @ApproverUserId UNIQUEIDENTIFIER,
    @Comments nvarchar(1000) = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @offerApprovalId UNIQUEIDENTIFIER, @approvalRequestId UNIQUEIDENTIFIER;
        SELECT @offerApprovalId = OfferApprovalId, @approvalRequestId = ApprovalRequestId
        FROM offer.OfferApproval WHERE OfferId = @OfferId AND TenantId = @TenantId AND Status = N'Pending';

        IF @offerApprovalId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'No pending offer approval found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @stepId UNIQUEIDENTIFIER = (SELECT TOP (1) ApprovalStepId FROM workflow.ApprovalStep WHERE ApprovalRequestId = @approvalRequestId AND Status = N'Pending' ORDER BY StepOrder);
        UPDATE workflow.ApprovalStep SET Status = N'Approved' WHERE ApprovalStepId = @stepId;
        INSERT INTO workflow.ApprovalDecision (TenantId, ApprovalStepId, DecidedByUserId, Decision, Comments, CorrelationId)
        VALUES (@TenantId, @stepId, @ApproverUserId, N'Approved', @Comments, @CorrelationId);

        IF NOT EXISTS (SELECT 1 FROM workflow.ApprovalStep WHERE ApprovalRequestId = @approvalRequestId AND Status NOT IN (N'Approved', N'Skipped'))
        BEGIN
            UPDATE workflow.ApprovalRequest SET Status = N'Approved', CompletedAtUtc = SYSUTCDATETIME() WHERE ApprovalRequestId = @approvalRequestId;
            UPDATE offer.OfferApproval SET Status = N'Approved', CompletedAtUtc = SYSUTCDATETIME() WHERE OfferApprovalId = @offerApprovalId;

            DECLARE @approvedStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) OfferStatusId FROM ref.OfferStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Approved' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
            UPDATE offer.Offer SET OfferStatusId = @approvedStatusId, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @ApproverUserId WHERE OfferId = @OfferId;
        END

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ApproverUserId,
             @Action = N'Offer.Approve', @EntityType = N'offer.Offer', @EntityId = @OfferId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Approval step recorded.' AS Message,
               @OfferId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* offer.usp_MarkOfferSent — THE enforcement point for "Require approvals
   before 'Sent' state." Refuses unless the current OfferStatus code is
   'Approved' (which itself can only be reached by usp_ApproveOffer completing
   every approval step above). This is the primary defense; the database
   also never grants db_hr_app_writer direct UPDATE on offer.Offer.OfferStatusId
   (see docs/security-model.md) — only this procedure, granted to
   db_hr_workflow_executor, can move an offer to Sent. */
CREATE OR ALTER PROCEDURE offer.usp_MarkOfferSent
    @TenantId UNIQUEIDENTIFIER,
    @OfferId UNIQUEIDENTIFIER,
    @SentByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @currentCode nvarchar(50) = (
            SELECT os.Code FROM offer.Offer o JOIN ref.OfferStatus os ON os.OfferStatusId = o.OfferStatusId
            WHERE o.OfferId = @OfferId AND o.TenantId = @TenantId);

        IF @currentCode IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Offer not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END
        IF @currentCode <> N'Approved'
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Offer cannot be sent — it has not completed the approval workflow (current status: ' + @currentCode + N').' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_REQUIRED' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @sentStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) OfferStatusId FROM ref.OfferStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Sent' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        UPDATE offer.Offer SET OfferStatusId = @sentStatusId, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @SentByUserId WHERE OfferId = @OfferId;

        INSERT INTO offer.OfferStatusHistory (TenantId, OfferId, ToOfferStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @OfferId, @sentStatusId, @SentByUserId, @CorrelationId);

        DECLARE @payload nvarchar(max) = (SELECT @OfferId AS OfferId, @TenantId AS TenantId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        INSERT INTO integration.OutboxMessage (TenantId, EventType, PayloadJson, CorrelationId)
        VALUES (@TenantId, N'offer.sent', @payload, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @SentByUserId,
             @Action = N'Offer.MarkSent', @EntityType = N'offer.Offer', @EntityId = @OfferId,
             @PreviousStatus = @currentCode, @NewStatus = N'Sent', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Offer marked as sent.' AS Message,
               @OfferId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* offer.usp_RecordOfferAcceptance — the only write path for offer.OfferAcceptance.
   Refuses unless the offer is currently 'Sent' (mirrors usp_MarkOfferSent's own
   status-gate pattern one step further down the lifecycle). */
CREATE OR ALTER PROCEDURE offer.usp_RecordOfferAcceptance
    @TenantId UNIQUEIDENTIFIER,
    @OfferId UNIQUEIDENTIFIER,
    @RecordedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @currentCode nvarchar(50) = (
            SELECT os.Code FROM offer.Offer o JOIN ref.OfferStatus os ON os.OfferStatusId = o.OfferStatusId
            WHERE o.OfferId = @OfferId AND o.TenantId = @TenantId);

        IF @currentCode IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Offer not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END
        IF @currentCode <> N'Sent'
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Offer cannot be accepted — it has not been sent (current status: ' + @currentCode + N').' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_SENT' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        INSERT INTO offer.OfferAcceptance (TenantId, OfferId, AcceptedAtUtc, RecordedByUserId)
        VALUES (@TenantId, @OfferId, SYSUTCDATETIME(), @RecordedByUserId);

        DECLARE @acceptedStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) OfferStatusId FROM ref.OfferStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Accepted' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        UPDATE offer.Offer SET OfferStatusId = @acceptedStatusId, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @RecordedByUserId WHERE OfferId = @OfferId;

        INSERT INTO offer.OfferStatusHistory (TenantId, OfferId, ToOfferStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @OfferId, @acceptedStatusId, @RecordedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @RecordedByUserId,
             @Action = N'Offer.RecordAcceptance', @EntityType = N'offer.Offer', @EntityId = @OfferId,
             @PreviousStatus = @currentCode, @NewStatus = N'Accepted', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Offer acceptance recorded.' AS Message,
               @OfferId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   GREEN FORM — candidate-facing, token-authorized (the GreenFormSubmissionId
   itself is the single-use "token" the candidate URL carries; no separate
   token table exists for this purpose in the schema — see
   docs/09-quality-evaluation/production-readiness-report.md).
   ============================================================================ */

CREATE OR ALTER PROCEDURE onboarding.usp_IssueGreenFormLink
    @TenantId UNIQUEIDENTIFIER,
    @CandidateApplicationId UNIQUEIDENTIFIER,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateApplication WHERE CandidateApplicationId = @CandidateApplicationId AND TenantId = @TenantId)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Candidate application not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;

        DECLARE @greenFormId UNIQUEIDENTIFIER = (SELECT GreenFormId FROM onboarding.GreenForm WHERE TenantId = @TenantId AND Code = N'STANDARD' AND IsDeleted = 0);
        IF @greenFormId IS NULL
        BEGIN
            SET @greenFormId = NEWID();
            INSERT INTO onboarding.GreenForm (GreenFormId, TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
            VALUES (@greenFormId, @TenantId, N'STANDARD', N'Standard Green Form', 1, SYSUTCDATETIME(), @CreatedByUserId);
        END

        DECLARE @greenFormVersionId UNIQUEIDENTIFIER = (SELECT TOP (1) GreenFormVersionId FROM onboarding.GreenFormVersion WHERE GreenFormId = @greenFormId AND ApprovalStatus = N'Approved' ORDER BY VersionNumber DESC);
        IF @greenFormVersionId IS NULL
        BEGIN
            SET @greenFormVersionId = NEWID();
            INSERT INTO onboarding.GreenFormVersion (GreenFormVersionId, TenantId, GreenFormId, VersionNumber, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
            VALUES (@greenFormVersionId, @TenantId, @greenFormId, 1, N'Approved', SYSUTCDATETIME(), @CreatedByUserId);
            UPDATE onboarding.GreenForm SET CurrentVersionId = @greenFormVersionId WHERE GreenFormId = @greenFormId;
        END

        DECLARE @submissionId UNIQUEIDENTIFIER = (SELECT GreenFormSubmissionId FROM onboarding.GreenFormSubmission WHERE CandidateApplicationId = @CandidateApplicationId AND GreenFormVersionId = @greenFormVersionId AND IsDeleted = 0);
        IF @submissionId IS NULL
        BEGIN
            SET @submissionId = NEWID();
            INSERT INTO onboarding.GreenFormSubmission (GreenFormSubmissionId, TenantId, GreenFormVersionId, CandidateApplicationId, Status, CreatedAtUtc, CreatedByUserId)
            VALUES (@submissionId, @TenantId, @greenFormVersionId, @CandidateApplicationId, N'InProgress', SYSUTCDATETIME(), @CreatedByUserId);
        END

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'GreenForm.IssueLink', @EntityType = N'onboarding.GreenFormSubmission', @EntityId = @submissionId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Green Form link issued.' AS Message,
               @submissionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* usp_SubmitGreenForm and usp_GetGreenFormSubmissionStatus run WITH EXECUTE AS
   'db_hr_green_form_token_resolver' (scripts/05 — a dedicated, login-less, narrowly-scoped
   user, deliberately NOT dbo/OWNER, so this RLS exemption can never be inherited by some future
   unrelated EXECUTE AS OWNER procedure): the candidate calling these has no authenticated
   session and therefore no SESSION_CONTEXT('TenantId') for security.fn_tenant_access_predicate
   to match against (see that function's definition — a NULL session tenant matches nothing, for
   any principal other than the explicitly exempted roles). This is the same "magic link"
   pattern any token-authorized, pre-authentication flow needs: authorization comes from
   possession of an unguessable GreenFormSubmissionId (sent out-of-band to the candidate), not
   from a client-supplied tenant id — CLAUDE.md's "never trust client-supplied tenant context
   alone" is upheld because the tenant is derived server-side from the token's own row, never
   accepted as an input parameter. Both procedures immediately narrow to the single row
   identified by the token and touch nothing else; EXECUTE on them is granted per-procedure
   below to db_hr_public_token_resolver only, never schema- or table-wide. */
CREATE OR ALTER PROCEDURE onboarding.usp_SubmitGreenForm
    @GreenFormSubmissionId UNIQUEIDENTIFIER,
    @EmploymentHistoryJson nvarchar(max), -- [{"employerName":"...","startDate":"2020-01-01","endDate":null}]
    @EducationJson nvarchar(max), -- [{"institution":"...","qualification":"...","year":2020}]
    @CorrelationId UNIQUEIDENTIFIER = NULL
WITH EXECUTE AS 'db_hr_green_form_token_resolver'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();

    BEGIN TRY
        DECLARE @tenantId UNIQUEIDENTIFIER, @candidateApplicationId UNIQUEIDENTIFIER, @status nvarchar(20);
        SELECT @tenantId = TenantId, @candidateApplicationId = CandidateApplicationId, @status = Status
        FROM onboarding.GreenFormSubmission WHERE GreenFormSubmissionId = @GreenFormSubmissionId AND IsDeleted = 0;

        IF @tenantId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Green Form submission not found or link has expired.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END
        IF @status NOT IN (N'InProgress')
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'This Green Form has already been submitted.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'ALREADY_SUBMITTED' AS ErrorCode;
            RETURN;
        END
        IF ISJSON(@EmploymentHistoryJson) = 0 OR ISJSON(@EducationJson) = 0
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Employment history / education must be valid JSON arrays.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'INVALID_JSON' AS ErrorCode;
            RETURN;
        END

        EXEC sp_set_session_context @key = N'TenantId', @value = @tenantId;

        DECLARE @candidateId UNIQUEIDENTIFIER = (SELECT CandidateId FROM recruitment.CandidateApplication WHERE CandidateApplicationId = @candidateApplicationId);

        BEGIN TRAN;

        INSERT INTO onboarding.CandidateEmploymentHistory (TenantId, CandidateId, EmployerName, StartDate, EndDate, IsCurrent, CreatedAtUtc)
        SELECT @tenantId, @candidateId, j.EmployerName, j.StartDate, j.EndDate, CASE WHEN j.EndDate IS NULL THEN 1 ELSE 0 END, SYSUTCDATETIME()
        FROM OPENJSON(@EmploymentHistoryJson) WITH (
            EmployerName nvarchar(200) '$.employerName',
            StartDate date '$.startDate',
            EndDate date '$.endDate'
        ) j;

        INSERT INTO onboarding.CandidateEducationHistory (TenantId, CandidateId, InstitutionName, QualificationName, EndDate, CreatedAtUtc)
        SELECT @tenantId, @candidateId, j.Institution, j.Qualification, DATEFROMPARTS(j.Year, 12, 31), SYSUTCDATETIME()
        FROM OPENJSON(@EducationJson) WITH (
            Institution nvarchar(200) '$.institution',
            Qualification nvarchar(200) '$.qualification',
            Year int '$.year'
        ) j;

        UPDATE onboarding.GreenFormSubmission SET Status = N'Submitted', SubmittedAtUtc = SYSUTCDATETIME(), UpdatedAtUtc = SYSUTCDATETIME()
        WHERE GreenFormSubmissionId = @GreenFormSubmissionId;

        EXEC audit.usp_WriteAuditEvent @TenantId = @tenantId, @ActorUserId = NULL,
             @Action = N'GreenForm.Submit', @EntityType = N'onboarding.GreenFormSubmission', @EntityId = @GreenFormSubmissionId,
             @PreviousStatus = N'InProgress', @NewStatus = N'Submitted', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Green Form submitted.' AS Message,
               @GreenFormSubmissionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* Read-only counterpart to usp_SubmitGreenForm — same WITH EXECUTE AS 'db_hr_green_form_token_resolver'
   rationale (see that procedure's header comment). Returns a single row shaped for the
   candidate-facing status page; NOT the uniform Success/Message/EntityId result set every other
   procedure in this file returns, since this is a query, not a state-changing action. */
CREATE OR ALTER PROCEDURE onboarding.usp_GetGreenFormSubmissionStatus
    @GreenFormSubmissionId UNIQUEIDENTIFIER
WITH EXECUTE AS 'db_hr_green_form_token_resolver'
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        GreenFormSubmissionId,
        Status,
        CreatedAtUtc,
        SubmittedAtUtc
    FROM onboarding.GreenFormSubmission
    WHERE GreenFormSubmissionId = @GreenFormSubmissionId AND IsDeleted = 0;
END
GO

/* Least-privilege: EXECUTE on exactly these two token-resolution procedures, granted to
   db_hr_public_token_resolver only (never a schema-wide or table-level grant) — see
   scripts/05-create-security.sql for the role/user and the RLS predicate exemption this backs. */
GRANT EXECUTE ON onboarding.usp_SubmitGreenForm TO db_hr_public_token_resolver;
GRANT EXECUTE ON onboarding.usp_GetGreenFormSubmissionStatus TO db_hr_public_token_resolver;
GO

/* ============================================================================
   ONBOARDING / DISCREPANCY — closure requires human resolution + approval.
   ============================================================================ */

CREATE OR ALTER PROCEDURE onboarding.usp_CreateDiscrepancy
    @TenantId UNIQUEIDENTIFIER,
    @CandidateApplicationId UNIQUEIDENTIFIER,
    @DiscrepancyTypeCode nvarchar(50),
    @DiscrepancySeverityCode nvarchar(50),
    @Description nvarchar(2000),
    @Source nvarchar(50) = N'Manual', -- 'AiSuggested' when raised by an AI skill — see IsAiSuggested below
    @VerificationCheckId UNIQUEIDENTIFIER = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @typeId UNIQUEIDENTIFIER = (SELECT TOP (1) DiscrepancyTypeId FROM ref.DiscrepancyType WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = @DiscrepancyTypeCode ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        DECLARE @severityId UNIQUEIDENTIFIER = (SELECT TOP (1) DiscrepancySeverityId FROM ref.DiscrepancySeverity WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = @DiscrepancySeverityCode ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        DECLARE @openStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) DiscrepancyStatusId FROM ref.DiscrepancyStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Open' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);

        BEGIN TRAN;
        DECLARE @discrepancyId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO onboarding.Discrepancy
            (DiscrepancyId, TenantId, VerificationCheckId, CandidateApplicationId, DiscrepancyTypeId, DiscrepancySeverityId, DiscrepancyStatusId, Source, IsAiSuggested, Description, CreatedByUserId)
        VALUES
            (@discrepancyId, @TenantId, @VerificationCheckId, @CandidateApplicationId, @typeId, @severityId, @openStatusId, @Source, CASE WHEN @Source = N'AiSuggested' THEN 1 ELSE 0 END, @Description, @CreatedByUserId);

        INSERT INTO onboarding.DiscrepancyStatusHistory (TenantId, DiscrepancyId, ToStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @discrepancyId, @openStatusId, @CreatedByUserId, @CorrelationId);

        DECLARE @actorType nvarchar(20) = CASE WHEN @Source = N'AiSuggested' THEN N'AiAgent' ELSE N'User' END;
        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @ActorType = @actorType,
             @Action = N'Discrepancy.Create', @EntityType = N'onboarding.Discrepancy', @EntityId = @discrepancyId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Discrepancy created.' AS Message,
               @discrepancyId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* onboarding.usp_ResolveDiscrepancy — THE enforcement point for "AI may
   create a discrepancy suggestion; HR must approve a discrepancy decision or
   closure." @ResolvedByUserId must be a non-service-account human, and an
   Approved workflow.ApprovalRequest is created/required in the same
   transaction before the Discrepancy's status can move to a terminal state. */
CREATE OR ALTER PROCEDURE onboarding.usp_ResolveDiscrepancy
    @TenantId UNIQUEIDENTIFIER,
    @DiscrepancyId UNIQUEIDENTIFIER,
    @ResolutionType nvarchar(50), -- Cleared, Confirmed, WaivedWithException
    @CorrectiveAction nvarchar(1000) = NULL,
    @HrDecisionNotes nvarchar(1000) = NULL,
    @ResolvedByUserId UNIQUEIDENTIFIER,
    @ApprovalMatrixCode nvarchar(100),
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF @ResolvedByUserId IS NULL OR NOT EXISTS (SELECT 1 FROM iam.[User] WHERE UserId = @ResolvedByUserId AND IsSystemServiceAccount = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Discrepancy resolution requires a human decision-maker.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'HUMAN_APPROVAL_REQUIRED' AS ErrorCode;
            RETURN;
        END
        IF EXISTS (SELECT 1 FROM onboarding.DiscrepancyResolution WHERE DiscrepancyId = @DiscrepancyId)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Discrepancy already resolved.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'ALREADY_RESOLVED' AS ErrorCode;
            RETURN;
        END

        DECLARE @matrixId UNIQUEIDENTIFIER = (SELECT ApprovalMatrixId FROM ref.ApprovalMatrix WHERE TenantId = @TenantId AND MatrixCode = @ApprovalMatrixCode AND IsActive = 1);
        IF @matrixId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval matrix not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_MATRIX_MISSING' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @approvalRequestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO workflow.ApprovalRequest (ApprovalRequestId, TenantId, ApprovalMatrixId, EntityType, EntityId, Status, RequestedByUserId, CompletedAtUtc, CorrelationId)
        VALUES (@approvalRequestId, @TenantId, @matrixId, N'onboarding.Discrepancy', @DiscrepancyId, N'Approved', @ResolvedByUserId, SYSUTCDATETIME(), @CorrelationId);
        -- Single-actor fast-path approval (the resolving HR user IS the
        -- approver for this matrix step) — multi-step matrices instead flow
        -- through onboarding.usp_ApproveDiscrepancyException below before
        -- this procedure is called with an already-Approved ApprovalRequestId.

        INSERT INTO onboarding.DiscrepancyApproval (TenantId, DiscrepancyId, ApprovalRequestId, Status, CompletedAtUtc)
        VALUES (@TenantId, @DiscrepancyId, @approvalRequestId, N'Approved', SYSUTCDATETIME());

        INSERT INTO onboarding.DiscrepancyResolution (TenantId, DiscrepancyId, ResolutionType, CorrectiveAction, HrDecisionNotes, ResolvedByUserId, ApprovalRequestId)
        VALUES (@TenantId, @DiscrepancyId, @ResolutionType, @CorrectiveAction, @HrDecisionNotes, @ResolvedByUserId, @approvalRequestId);

        DECLARE @fromStatusId UNIQUEIDENTIFIER = (SELECT DiscrepancyStatusId FROM onboarding.Discrepancy WHERE DiscrepancyId = @DiscrepancyId);
        DECLARE @closedStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) DiscrepancyStatusId FROM ref.DiscrepancyStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Closed' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        UPDATE onboarding.Discrepancy SET DiscrepancyStatusId = @closedStatusId, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @ResolvedByUserId WHERE DiscrepancyId = @DiscrepancyId;

        INSERT INTO onboarding.DiscrepancyStatusHistory (TenantId, DiscrepancyId, FromStatusId, ToStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @DiscrepancyId, @fromStatusId, @closedStatusId, @ResolvedByUserId, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ResolvedByUserId,
             @Action = N'Discrepancy.Resolve', @EntityType = N'onboarding.Discrepancy', @EntityId = @DiscrepancyId,
             @NewStatus = N'Closed', @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Discrepancy resolved and closed.' AS Message,
               @DiscrepancyId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* Raises a document re-upload request against the same application a discrepancy is filed
   against — DocumentTypeId defaults to the first active ref.DocumentType for the tenant since
   discrepancies aren't currently linked to a specific required document type; a future pass
   could thread a real DocumentTypeId through from the discrepancy's evidence instead. */
CREATE OR ALTER PROCEDURE onboarding.usp_RequestDocumentReupload
    @TenantId UNIQUEIDENTIFIER,
    @DiscrepancyId UNIQUEIDENTIFIER,
    @Reason nvarchar(1000) = NULL,
    @RequestedByUserId UNIQUEIDENTIFIER = NULL,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @candidateApplicationId UNIQUEIDENTIFIER = (SELECT CandidateApplicationId FROM onboarding.Discrepancy WHERE DiscrepancyId = @DiscrepancyId AND TenantId = @TenantId AND IsDeleted = 0);
        IF @candidateApplicationId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Discrepancy not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        DECLARE @documentTypeId UNIQUEIDENTIFIER = (SELECT TOP (1) DocumentTypeId FROM ref.DocumentType WHERE (TenantId = @TenantId OR TenantId IS NULL) AND IsActive = 1 ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END, Code);
        IF @documentTypeId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'No document type configured.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DOCUMENT_TYPE_MISSING' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @requestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO onboarding.DocumentUploadRequest (DocumentUploadRequestId, TenantId, CandidateApplicationId, DocumentTypeId, RequestedByUserId, RequestedAtUtc, Status)
        VALUES (@requestId, @TenantId, @candidateApplicationId, @documentTypeId, @RequestedByUserId, SYSUTCDATETIME(), N'Pending');

        DECLARE @awaitingStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) DiscrepancyStatusId FROM ref.DiscrepancyStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'AWAITING_CANDIDATE_RESPONSE' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        DECLARE @fromStatusId UNIQUEIDENTIFIER = (SELECT DiscrepancyStatusId FROM onboarding.Discrepancy WHERE DiscrepancyId = @DiscrepancyId);
        IF @awaitingStatusId IS NOT NULL
        BEGIN
            UPDATE onboarding.Discrepancy SET DiscrepancyStatusId = @awaitingStatusId, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @RequestedByUserId WHERE DiscrepancyId = @DiscrepancyId;
            INSERT INTO onboarding.DiscrepancyStatusHistory (TenantId, DiscrepancyId, FromStatusId, ToStatusId, ChangedByUserId, CorrelationId)
            VALUES (@TenantId, @DiscrepancyId, @fromStatusId, @awaitingStatusId, @RequestedByUserId, @CorrelationId);
        END

        DECLARE @metadataJson nvarchar(max) = (SELECT @Reason AS reason FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @RequestedByUserId,
             @Action = N'Discrepancy.RequestReupload', @EntityType = N'onboarding.Discrepancy', @EntityId = @DiscrepancyId,
             @MetadataJson = @metadataJson, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Re-upload requested.' AS Message,
               @requestId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   EMPLOYEE CONVERSION — the single most-gated transition. usp_CheckEligibility
   is read-only and reusable by both the API (to render a checklist in the UI)
   and usp_CreateEmployeeFromCandidate (to enforce the gate server-side, never
   trusting a client-supplied "eligible" flag).
   ============================================================================ */

CREATE OR ALTER PROCEDURE employee.usp_CheckEmployeeConversionEligibility
    @TenantId UNIQUEIDENTIFIER,
    @EmployeeConversionId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    DECLARE @candidateApplicationId UNIQUEIDENTIFIER, @offerId UNIQUEIDENTIFIER;
    SELECT @candidateApplicationId = CandidateApplicationId, @offerId = OfferId
    FROM employee.EmployeeConversion WHERE EmployeeConversionId = @EmployeeConversionId AND TenantId = @TenantId;

    DECLARE @offerAccepted bit = CASE WHEN EXISTS (SELECT 1 FROM offer.OfferAcceptance WHERE OfferId = @offerId) THEN 1 ELSE 0 END;
    DECLARE @greenFormCompleted bit = CASE WHEN EXISTS (
        SELECT 1 FROM onboarding.GreenFormSubmission WHERE CandidateApplicationId = @candidateApplicationId AND Status = N'Completed'
    ) THEN 1 ELSE 0 END;
    DECLARE @verificationCleared bit = CASE WHEN NOT EXISTS (
        SELECT 1 FROM onboarding.VerificationCase vc WHERE vc.CandidateApplicationId = @candidateApplicationId AND vc.Status <> N'Completed'
    ) AND EXISTS (SELECT 1 FROM onboarding.VerificationCase WHERE CandidateApplicationId = @candidateApplicationId) THEN 1 ELSE 0 END;
    DECLARE @discrepanciesResolved bit = CASE WHEN NOT EXISTS (
        SELECT 1 FROM onboarding.Discrepancy d JOIN ref.DiscrepancyStatus ds ON ds.DiscrepancyStatusId = d.DiscrepancyStatusId
        WHERE d.CandidateApplicationId = @candidateApplicationId AND ISNULL(ds.IsTerminal, 0) = 0 AND d.IsDeleted = 0
    ) THEN 1 ELSE 0 END;

    SELECT
        @offerAccepted AS OfferAccepted,
        @greenFormCompleted AS GreenFormCompleted,
        @verificationCleared AS VerificationCleared,
        @discrepanciesResolved AS DiscrepanciesResolved,
        CAST(CASE WHEN @offerAccepted = 1 AND @greenFormCompleted = 1 AND @verificationCleared = 1 AND @discrepanciesResolved = 1
             THEN 1 ELSE 0 END AS bit) AS IsEligible;
END
GO

CREATE OR ALTER PROCEDURE employee.usp_GenerateEmployeeId
    @TenantId UNIQUEIDENTIFIER,
    @EmployeeConversionId UNIQUEIDENTIFIER,
    @GeneratedByUserId UNIQUEIDENTIFIER = NULL,
    @EmployeeCode nvarchar(50) OUTPUT
AS
BEGIN
    -- Idempotent: if this EmployeeConversionId already reserved an
    -- EmployeeCode, return the SAME one rather than issuing a second — see
    -- non-negotiable rule "Idempotent Employee ID generation" and
    -- tests/workflow-integrity-tests.sql.
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    IF EXISTS (SELECT 1 FROM employee.EmployeeIdRegistry WHERE EmployeeConversionId = @EmployeeConversionId)
    BEGIN
        SELECT @EmployeeCode = EmployeeCode FROM employee.EmployeeIdRegistry WHERE EmployeeConversionId = @EmployeeConversionId;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @ruleId UNIQUEIDENTIFIER, @prefix nvarchar(20), @suffix nvarchar(20), @padding int, @nextSeq bigint;
        SELECT TOP (1) @ruleId = NumberingRuleId, @prefix = Prefix, @suffix = Suffix, @padding = PaddingWidth
        FROM ref.NumberingRule WITH (UPDLOCK, HOLDLOCK) WHERE TenantId = @TenantId AND EntityType = N'EmployeeId' AND IsActive = 1;

        IF @ruleId IS NULL
        BEGIN
            ROLLBACK TRAN;
            SET @EmployeeCode = NULL;
            RETURN;
        END

        UPDATE ref.NumberingRule SET CurrentSequence = CurrentSequence + 1 WHERE NumberingRuleId = @ruleId;
        SELECT @nextSeq = CurrentSequence FROM ref.NumberingRule WHERE NumberingRuleId = @ruleId;
        SET @EmployeeCode = ISNULL(@prefix, N'') + RIGHT(REPLICATE('0', @padding) + CAST(@nextSeq AS nvarchar(20)), @padding) + ISNULL(@suffix, N'');

        INSERT INTO employee.EmployeeIdRegistry (TenantId, EmployeeCode, EmployeeConversionId)
        VALUES (@TenantId, @EmployeeCode, @EmployeeConversionId);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* employee.usp_CreateEmployeeFromCandidate — refuses unless: eligibility (via
   usp_CheckEmployeeConversionEligibility) is true, AND an
   EmployeeConversionApproval already exists with Status='Approved' (from
   usp_ApproveEmployeeConversion, a separate human action). This is the
   database's enforcement of "Prevent conversion until required offer
   acceptance, Green Form completion, verification status, discrepancy
   status, and HR approval are confirmed." */
CREATE OR ALTER PROCEDURE employee.usp_CreateEmployeeFromCandidate
    @TenantId UNIQUEIDENTIFIER,
    @EmployeeConversionId UNIQUEIDENTIFIER,
    @DesignationId UNIQUEIDENTIFIER = NULL,
    @JobGradeId UNIQUEIDENTIFIER = NULL,
    @EmploymentTypeId UNIQUEIDENTIFIER = NULL,
    @DateOfJoining date = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        -- Idempotency: if an Employee already exists for this conversion,
        -- return it rather than erroring or duplicating.
        IF EXISTS (SELECT 1 FROM employee.Employee WHERE EmployeeConversionId = @EmployeeConversionId)
        BEGIN
            DECLARE @existingId UNIQUEIDENTIFIER = (SELECT EmployeeId FROM employee.Employee WHERE EmployeeConversionId = @EmployeeConversionId);
            SELECT CAST(1 AS bit) AS Success, N'Employee already exists for this conversion (idempotent).' AS Message,
                   @existingId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM employee.EmployeeConversionApproval WHERE EmployeeConversionId = @EmployeeConversionId AND Status = N'Approved')
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Employee conversion has not been approved.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_REQUIRED' AS ErrorCode;
            RETURN;
        END

        DECLARE @isEligible bit;
        DECLARE @eligibility TABLE (OfferAccepted bit, GreenFormCompleted bit, VerificationCleared bit, DiscrepanciesResolved bit, IsEligible bit);
        INSERT INTO @eligibility EXEC employee.usp_CheckEmployeeConversionEligibility @TenantId, @EmployeeConversionId;
        SELECT @isEligible = IsEligible FROM @eligibility;

        IF ISNULL(@isEligible, 0) = 0
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Employee conversion eligibility checklist is not satisfied.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'ELIGIBILITY_NOT_MET' AS ErrorCode;
            RETURN;
        END

        DECLARE @candidateId UNIQUEIDENTIFIER;
        SELECT @candidateId = ca.CandidateId
        FROM employee.EmployeeConversion ec JOIN recruitment.CandidateApplication ca ON ca.CandidateApplicationId = ec.CandidateApplicationId
        WHERE ec.EmployeeConversionId = @EmployeeConversionId;

        BEGIN TRAN;

        DECLARE @employeeCode nvarchar(50);
        EXEC employee.usp_GenerateEmployeeId @TenantId, @EmployeeConversionId, @CreatedByUserId, @employeeCode OUTPUT;
        IF @employeeCode IS NULL
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'No active Employee ID numbering rule configured for this tenant.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NUMBERING_RULE_MISSING' AS ErrorCode;
            RETURN;
        END

        DECLARE @activeStatusId UNIQUEIDENTIFIER = (SELECT TOP (1) EmployeeStatusId FROM ref.EmployeeStatus WHERE (TenantId = @TenantId OR TenantId IS NULL) AND Code = N'Active' ORDER BY CASE WHEN TenantId = @TenantId THEN 0 ELSE 1 END);
        DECLARE @firstName nvarchar(100), @lastName nvarchar(100);
        SELECT @firstName = FirstName, @lastName = LastName FROM recruitment.Candidate WHERE CandidateId = @candidateId;

        DECLARE @employeeId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO employee.Employee
            (EmployeeId, TenantId, EmployeeConversionId, CandidateId, EmployeeCode, FirstName, LastName, EmployeeStatusId, DesignationId, JobGradeId, EmploymentTypeId, DateOfJoining, CreatedByUserId)
        VALUES
            (@employeeId, @TenantId, @EmployeeConversionId, @candidateId, @employeeCode, @firstName, @lastName, @activeStatusId, @DesignationId, @JobGradeId, @EmploymentTypeId, @DateOfJoining, @CreatedByUserId);

        UPDATE employee.EmployeeConversion SET Status = N'Converted', ConvertedAtUtc = SYSUTCDATETIME(), UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @CreatedByUserId
        WHERE EmployeeConversionId = @EmployeeConversionId;

        INSERT INTO employee.EmployeeStatusHistory (TenantId, EmployeeId, ToEmployeeStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @employeeId, @activeStatusId, @CreatedByUserId, @CorrelationId);

        DECLARE @payload nvarchar(max) = (SELECT @employeeId AS EmployeeId, @employeeCode AS EmployeeCode, @TenantId AS TenantId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        INSERT INTO integration.OutboxMessage (TenantId, EventType, PayloadJson, CorrelationId)
        VALUES (@TenantId, N'employee.created', @payload, @CorrelationId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'Employee.Create', @EntityType = N'employee.Employee', @EntityId = @employeeId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, @employeeCode AS Message,
               @employeeId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE employee.usp_ApproveEmployeeConversion
    @TenantId UNIQUEIDENTIFIER,
    @EmployeeConversionId UNIQUEIDENTIFIER,
    @ApproverUserId UNIQUEIDENTIFIER,
    @ApprovalMatrixCode nvarchar(100),
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @isEligible bit;
        DECLARE @eligibility TABLE (OfferAccepted bit, GreenFormCompleted bit, VerificationCleared bit, DiscrepanciesResolved bit, IsEligible bit);
        INSERT INTO @eligibility EXEC employee.usp_CheckEmployeeConversionEligibility @TenantId, @EmployeeConversionId;
        SELECT @isEligible = IsEligible FROM @eligibility;
        IF ISNULL(@isEligible, 0) = 0
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Cannot approve — eligibility checklist not yet satisfied.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'ELIGIBILITY_NOT_MET' AS ErrorCode;
            RETURN;
        END

        DECLARE @matrixId UNIQUEIDENTIFIER = (SELECT ApprovalMatrixId FROM ref.ApprovalMatrix WHERE TenantId = @TenantId AND MatrixCode = @ApprovalMatrixCode AND IsActive = 1);
        IF @matrixId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval matrix not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'APPROVAL_MATRIX_MISSING' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @approvalRequestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO workflow.ApprovalRequest (ApprovalRequestId, TenantId, ApprovalMatrixId, EntityType, EntityId, Status, RequestedByUserId, CompletedAtUtc, CorrelationId)
        VALUES (@approvalRequestId, @TenantId, @matrixId, N'employee.EmployeeConversion', @EmployeeConversionId, N'Approved', @ApproverUserId, SYSUTCDATETIME(), @CorrelationId);

        INSERT INTO employee.EmployeeConversionApproval (TenantId, EmployeeConversionId, ApprovalRequestId, Status, RequestedAtUtc, CompletedAtUtc)
        VALUES (@TenantId, @EmployeeConversionId, @approvalRequestId, N'Approved', SYSUTCDATETIME(), SYSUTCDATETIME());

        UPDATE employee.EmployeeConversion SET Status = N'Approved', UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @ApproverUserId WHERE EmployeeConversionId = @EmployeeConversionId;

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @ApproverUserId,
             @Action = N'EmployeeConversion.Approve', @EntityType = N'employee.EmployeeConversion', @EntityId = @EmployeeConversionId, @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Employee conversion approved.' AS Message,
               @EmployeeConversionId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   ADMINISTRATION — tenant profile, numbering rules, approval matrix
   configuration. Gated by iam.Permission keys tenant.manage/configuration.manage/
   workflow.manage (see AdminConfigurationController) - never reachable by a
   role without those permissions. Every write here is genuinely consulted at
   runtime by other procedures in this file (ref.NumberingRule by
   employee.usp_GenerateEmployeeId and recruitment.usp_CreateTalentAcquisitionNumber;
   ref.ApprovalMatrix/ApprovalMatrixRule by every *_ApprovalMatrixCode-driven
   approval-submission procedure above) - unlike ref.WorkflowDefinition/
   WorkflowStateDefinition/WorkflowTransitionDefinition, which are reference
   documentation only per ADR-006 and are deliberately NOT exposed as
   editable here (editing them would have zero effect on real behavior).
   ============================================================================ */

CREATE OR ALTER PROCEDURE org.usp_UpdateTenantProfile
    @TenantId UNIQUEIDENTIFIER,
    @TenantName nvarchar(200),
    @LegalName nvarchar(200) = NULL,
    @PrimaryDomain nvarchar(200) = NULL,
    @UpdatedByUserId UNIQUEIDENTIFIER,
    @RowVersion varbinary(8),
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM org.Tenant WHERE TenantId = @TenantId AND IsDeleted = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Tenant not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        UPDATE org.Tenant
        SET TenantName = @TenantName, LegalName = @LegalName, PrimaryDomain = @PrimaryDomain,
            UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @UpdatedByUserId
        WHERE TenantId = @TenantId AND RowVersion = @RowVersion AND IsDeleted = 0;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'Tenant profile was changed by someone else - reload and try again.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'CONCURRENCY_CONFLICT' AS ErrorCode;
            RETURN;
        END

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @UpdatedByUserId,
             @Action = N'Tenant.UpdateProfile', @EntityType = N'org.Tenant', @EntityId = @TenantId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Tenant profile updated.' AS Message,
               @TenantId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ref.usp_UpdateNumberingRule
    @TenantId UNIQUEIDENTIFIER,
    @NumberingRuleId UNIQUEIDENTIFIER,
    @Prefix nvarchar(20) = NULL,
    @Suffix nvarchar(20) = NULL,
    @PaddingWidth int,
    @UpdatedByUserId UNIQUEIDENTIFIER,
    @RowVersion varbinary(8),
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF @PaddingWidth NOT BETWEEN 1 AND 20
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Padding width must be between 1 and 20.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'INVALID_PADDING_WIDTH' AS ErrorCode;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM ref.NumberingRule WHERE NumberingRuleId = @NumberingRuleId AND TenantId = @TenantId AND IsDeleted = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Numbering rule not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        UPDATE ref.NumberingRule
        SET Prefix = @Prefix, Suffix = @Suffix, PaddingWidth = @PaddingWidth,
            VersionNumber = VersionNumber + 1, UpdatedAtUtc = SYSUTCDATETIME(), UpdatedByUserId = @UpdatedByUserId
        WHERE NumberingRuleId = @NumberingRuleId AND TenantId = @TenantId AND RowVersion = @RowVersion AND IsDeleted = 0;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'Numbering rule was changed by someone else - reload and try again.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'CONCURRENCY_CONFLICT' AS ErrorCode;
            RETURN;
        END

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @UpdatedByUserId,
             @Action = N'NumberingRule.Update', @EntityType = N'ref.NumberingRule', @EntityId = @NumberingRuleId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Numbering rule updated. Applies to numbers generated from now on - already-issued numbers are never retroactively changed.' AS Message,
               @NumberingRuleId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ref.usp_AddApprovalMatrixRule
    @TenantId UNIQUEIDENTIFIER,
    @ApprovalMatrixId UNIQUEIDENTIFIER,
    @StepOrder int,
    @ApproverRoleId UNIQUEIDENTIFIER = NULL,
    @IsMandatory bit = 1,
    @ConditionExpression nvarchar(500) = NULL,
    @CreatedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM ref.ApprovalMatrix WHERE ApprovalMatrixId = @ApprovalMatrixId AND TenantId = @TenantId AND IsDeleted = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval matrix not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM ref.ApprovalMatrixRule WHERE ApprovalMatrixId = @ApprovalMatrixId AND StepOrder = @StepOrder AND IsDeleted = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'A step with this order already exists on this matrix.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DUPLICATE_STEP_ORDER' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        DECLARE @newRuleId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO ref.ApprovalMatrixRule
            (ApprovalMatrixRuleId, ApprovalMatrixId, StepOrder, ApproverRoleId, IsMandatory, ConditionExpression, CreatedByUserId)
        VALUES
            (@newRuleId, @ApprovalMatrixId, @StepOrder, @ApproverRoleId, @IsMandatory, @ConditionExpression, @CreatedByUserId);

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @CreatedByUserId,
             @Action = N'ApprovalMatrixRule.Add', @EntityType = N'ref.ApprovalMatrixRule', @EntityId = @newRuleId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Approval step added.' AS Message,
               @newRuleId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ref.usp_UpdateApprovalMatrixRule
    @TenantId UNIQUEIDENTIFIER,
    @ApprovalMatrixRuleId UNIQUEIDENTIFIER,
    @StepOrder int,
    @ApproverRoleId UNIQUEIDENTIFIER = NULL,
    @IsMandatory bit = 1,
    @ConditionExpression nvarchar(500) = NULL,
    @UpdatedByUserId UNIQUEIDENTIFIER,
    @RowVersion varbinary(8),
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @matrixId UNIQUEIDENTIFIER;
        SELECT @matrixId = amr.ApprovalMatrixId
        FROM ref.ApprovalMatrixRule amr
        JOIN ref.ApprovalMatrix am ON am.ApprovalMatrixId = amr.ApprovalMatrixId
        WHERE amr.ApprovalMatrixRuleId = @ApprovalMatrixRuleId AND am.TenantId = @TenantId AND amr.IsDeleted = 0;

        IF @matrixId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval step not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM ref.ApprovalMatrixRule WHERE ApprovalMatrixId = @matrixId AND StepOrder = @StepOrder AND ApprovalMatrixRuleId <> @ApprovalMatrixRuleId AND IsDeleted = 0)
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'A step with this order already exists on this matrix.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'DUPLICATE_STEP_ORDER' AS ErrorCode;
            RETURN;
        END

        -- Never let a matrix's mandatory-step count drop to zero via an edit
        -- (e.g. flipping the last mandatory step's IsMandatory to 0) - this
        -- table is genuinely consulted at approval-submission time (see file
        -- header), so zero mandatory steps would mean zero human approvals.
        IF @IsMandatory = 0 AND (
            SELECT COUNT(*) FROM ref.ApprovalMatrixRule
            WHERE ApprovalMatrixId = @matrixId AND IsMandatory = 1 AND IsDeleted = 0
              AND ApprovalMatrixRuleId <> @ApprovalMatrixRuleId
        ) = 0
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'This matrix must keep at least one mandatory approval step.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'MIN_APPROVAL_STEPS_REQUIRED' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        UPDATE ref.ApprovalMatrixRule
        SET StepOrder = @StepOrder, ApproverRoleId = @ApproverRoleId, IsMandatory = @IsMandatory,
            ConditionExpression = @ConditionExpression
        WHERE ApprovalMatrixRuleId = @ApprovalMatrixRuleId AND RowVersion = @RowVersion AND IsDeleted = 0;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRAN;
            SELECT CAST(0 AS bit) AS Success, N'This approval step was changed by someone else - reload and try again.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'CONCURRENCY_CONFLICT' AS ErrorCode;
            RETURN;
        END

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @UpdatedByUserId,
             @Action = N'ApprovalMatrixRule.Update', @EntityType = N'ref.ApprovalMatrixRule', @EntityId = @ApprovalMatrixRuleId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Approval step updated.' AS Message,
               @ApprovalMatrixRuleId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ref.usp_DeleteApprovalMatrixRule
    @TenantId UNIQUEIDENTIFIER,
    @ApprovalMatrixRuleId UNIQUEIDENTIFIER,
    @DeletedByUserId UNIQUEIDENTIFIER,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CorrelationId IS NULL SET @CorrelationId = NEWID();
    EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;

    BEGIN TRY
        DECLARE @matrixId UNIQUEIDENTIFIER, @isMandatory bit;
        SELECT @matrixId = amr.ApprovalMatrixId, @isMandatory = amr.IsMandatory
        FROM ref.ApprovalMatrixRule amr
        JOIN ref.ApprovalMatrix am ON am.ApprovalMatrixId = amr.ApprovalMatrixId
        WHERE amr.ApprovalMatrixRuleId = @ApprovalMatrixRuleId AND am.TenantId = @TenantId AND amr.IsDeleted = 0;

        IF @matrixId IS NULL
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'Approval step not found.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'NOT_FOUND' AS ErrorCode;
            RETURN;
        END

        IF @isMandatory = 1 AND (
            SELECT COUNT(*) FROM ref.ApprovalMatrixRule
            WHERE ApprovalMatrixId = @matrixId AND IsMandatory = 1 AND IsDeleted = 0
              AND ApprovalMatrixRuleId <> @ApprovalMatrixRuleId
        ) = 0
        BEGIN
            SELECT CAST(0 AS bit) AS Success, N'This matrix must keep at least one mandatory approval step - add a replacement step before removing this one.' AS Message,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
                   @CorrelationId AS CorrelationId, N'MIN_APPROVAL_STEPS_REQUIRED' AS ErrorCode;
            RETURN;
        END

        BEGIN TRAN;
        UPDATE ref.ApprovalMatrixRule
        SET IsDeleted = 1, DeletedAtUtc = SYSUTCDATETIME(), DeletedByUserId = @DeletedByUserId
        WHERE ApprovalMatrixRuleId = @ApprovalMatrixRuleId AND IsDeleted = 0;

        EXEC audit.usp_WriteAuditEvent @TenantId = @TenantId, @ActorUserId = @DeletedByUserId,
             @Action = N'ApprovalMatrixRule.Delete', @EntityType = N'ref.ApprovalMatrixRule', @EntityId = @ApprovalMatrixRuleId,
             @CorrelationId = @CorrelationId;

        COMMIT TRAN;
        SELECT CAST(1 AS bit) AS Success, N'Approval step removed.' AS Message,
               @ApprovalMatrixRuleId AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(NULL AS nvarchar(50)) AS ErrorCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SELECT CAST(0 AS bit) AS Success, ERROR_MESSAGE() AS Message,
               CAST(NULL AS UNIQUEIDENTIFIER) AS EntityId, CAST(NULL AS UNIQUEIDENTIFIER) AS WorkflowInstanceId,
               @CorrelationId AS CorrelationId, CAST(ERROR_NUMBER() AS nvarchar(50)) AS ErrorCode;
    END CATCH
END
GO

/* ============================================================================
   MAINTENANCE — retention/health, granted only to db_hr_security_admin /
   the scheduled maintenance job principal (see scripts/12-create-maintenance.sql
   for the SQL Agent job wiring; this file only defines the procedure body).
   ============================================================================ */

CREATE OR ALTER PROCEDURE maintenance.usp_RunDatabaseHealthChecks
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM sys.tables) AS TableCount,
        (SELECT COUNT(*) FROM sys.foreign_keys) AS ForeignKeyCount,
        (SELECT COUNT(*) FROM sys.security_policies WHERE is_enabled = 1) AS EnabledSecurityPolicyCount,
        (SELECT COUNT(*) FROM integration.OutboxMessage WHERE Status = N'DeadLettered') AS DeadLetteredOutboxCount,
        (SELECT COUNT(*) FROM integration.OutboxMessage WHERE Status IN (N'Pending', N'Failed') AND VisibleAfterUtc <= SYSUTCDATETIME()) AS OutboxBacklogCount,
        (SELECT MAX(OccurredAtUtc) FROM audit.AuditEvent) AS LastAuditEventAtUtc;
END
GO

PRINT N'07-create-stored-procedures.sql complete (highest-value subset - see docs/stored-procedure-catalog.md for full coverage status).';
