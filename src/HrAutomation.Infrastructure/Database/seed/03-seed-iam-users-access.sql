/* ============================================================================
   03-seed-iam-users-access.sql
   Purpose : Seed the 17 synthetic demo users, their external-IdP mapping,
             tenant access, minimal profile, department/location scope, role
             assignment, and reporting-manager mapping.
   Depends on: 01-seed-tenant-organization.sql, 02-seed-iam-roles-permissions.sql.
   Idempotent: Yes.

   SCHEMA NOTE: iam.[User] has no UserName column — Email is the natural
   business key throughout this package (see Database/docs/data-dictionary.md).
   Every user is created via iam.usp_CreateUser, the existing approved
   procedure, which also creates the iam.UserAuthenticationProvider row in
   the same transaction — never a raw INSERT into iam.[User] here.

   BOOTSTRAP NOTE: demo.hr.admin is this package's designated "seed actor"
   for scripts 04 onward (see each script's config block). It cannot resolve
   itself as its own creator, so it is created first in this script with
   @CreatedByUserId = NULL; every other user created afterward in this
   script uses demo.hr.admin's newly-created UserId as @CreatedByUserId.

   No password, MFA secret, session token, or access token is ever seeded —
   authentication is entirely external-IdP (ProviderName = 'DEMO_OIDC'),
   consistent with iam.UserAuthenticationProvider's design (identity-provider
   subject id + metadata only).
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @TenantCode nvarchar(50) = N'DEMO-HR';
DECLARE @TenantId UNIQUEIDENTIFIER;
DECLARE @ActorUserId UNIQUEIDENTIFIER;
DECLARE @CorrelationId UNIQUEIDENTIFIER = NEWID();
DECLARE @ExecutionUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ProviderName nvarchar(50) = N'DEMO_OIDC';

SELECT @TenantId = TenantId FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0;
IF @TenantId IS NULL
    THROW 50001, 'Seed execution failed: tenant was not found. Run 01-seed-tenant-organization.sql first.', 1;

-- Plain (non-read-only) context — see 01-seed-tenant-organization.sql header
-- note on why iam.usp_SetSessionSecurityContext (read-only) is not used here.
EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

BEGIN TRY
    BEGIN TRAN;

    -- --- Bootstrap: demo.hr.admin first, self-created (@CreatedByUserId = NULL on first run) ---
    IF NOT EXISTS (SELECT 1 FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.hr.admin@example.test' AND IsDeleted = 0)
        EXEC iam.usp_CreateUser
            @TenantId = @TenantId, @Email = N'demo.hr.admin@example.test', @DisplayName = N'Demo HR Administrator',
            @ProviderName = @ProviderName, @ProviderSubjectId = N'demo-oidc|demo.hr.admin', @CreatedByUserId = NULL, @CorrelationId = @CorrelationId;

    SELECT @ActorUserId = UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.hr.admin@example.test' AND IsDeleted = 0;
    IF @ActorUserId IS NULL
        THROW 50002, 'Seed execution failed: seed administrator user (demo.hr.admin@example.test) was not found after creation attempt.', 1;

    -- --- Remaining 16 users, created by the seed actor -----------------------
    DECLARE @Users TABLE (
        Email nvarchar(320), DisplayName nvarchar(400), RoleName nvarchar(200),
        ProviderSubjectId nvarchar(400), DepartmentCode nvarchar(100) NULL, LocationCode nvarchar(100) NULL,
        JobTitle nvarchar(300) NULL, IsServiceAccount bit
    );
    INSERT INTO @Users (Email, DisplayName, RoleName, ProviderSubjectId, DepartmentCode, LocationCode, JobTitle, IsServiceAccount) VALUES
    (N'demo.platform.admin@example.test', N'Demo Platform Administrator', N'PLATFORM_ADMIN', N'demo-oidc|demo.platform.admin', NULL, NULL, N'Platform Administrator', 0),
    (N'demo.tenant.admin@example.test', N'Demo Tenant Administrator', N'TENANT_ADMIN', N'demo-oidc|demo.tenant.admin', N'DEMO-HR-DEPT', N'DEMO-MUM', N'Tenant Administrator', 0),
    (N'demo.recruiter@example.test', N'Demo Recruiter', N'RECRUITER', N'demo-oidc|demo.recruiter', N'DEMO-HR-DEPT', N'DEMO-MUM', N'Recruiter', 0),
    (N'demo.ta.manager@example.test', N'Demo Talent Acquisition Manager', N'TALENT_ACQUISITION_MANAGER', N'demo-oidc|demo.ta.manager', N'DEMO-HR-DEPT', N'DEMO-MUM', N'Talent Acquisition Manager', 0),
    (N'demo.hiring.manager@example.test', N'Demo Hiring Manager', N'HIRING_MANAGER', N'demo-oidc|demo.hiring.manager', N'DEMO-ENG-DEPT', N'DEMO-PUN', N'Engineering Manager', 0),
    (N'demo.interviewer.1@example.test', N'Demo Technical Interviewer', N'INTERVIEWER', N'demo-oidc|demo.interviewer.1', N'DEMO-ENG-DEPT', N'DEMO-PUN', N'Technical Lead', 0),
    (N'demo.interviewer.2@example.test', N'Demo Managerial Interviewer', N'INTERVIEWER', N'demo-oidc|demo.interviewer.2', N'DEMO-ENG-DEPT', N'DEMO-PUN', N'Engineering Manager', 0),
    (N'demo.client.interviewer@example.test', N'Demo Client Interviewer', N'CLIENT_INTERVIEWER', N'demo-oidc|demo.client.interviewer', NULL, N'DEMO-REM', N'Client Interviewer (External Scope)', 0),
    (N'demo.offer.approver@example.test', N'Demo Offer Approver', N'OFFER_APPROVER', N'demo-oidc|demo.offer.approver', N'DEMO-HR-DEPT', N'DEMO-MUM', N'HR Manager', 0),
    (N'demo.document.verifier@example.test', N'Demo Document Verifier', N'DOCUMENT_VERIFIER', N'demo-oidc|demo.document.verifier', N'DEMO-HR-DEPT', N'DEMO-MUM', N'HR Executive', 0),
    (N'demo.onboarding.admin@example.test', N'Demo Onboarding Administrator', N'EMPLOYEE_ONBOARDING_ADMIN', N'demo-oidc|demo.onboarding.admin', N'DEMO-HR-DEPT', N'DEMO-MUM', N'HR Executive', 0),
    (N'demo.auditor@example.test', N'Demo Auditor', N'AUDITOR', N'demo-oidc|demo.auditor', NULL, NULL, N'Auditor', 0),
    (N'demo.reporting.user@example.test', N'Demo Reporting User', N'REPORTING_USER', N'demo-oidc|demo.reporting.user', NULL, NULL, N'Reporting Analyst', 0),
    (N'demo.support.readonly@example.test', N'Demo Support Reader', N'SUPPORT_READONLY', N'demo-oidc|demo.support.readonly', NULL, NULL, N'Support Engineer (Read-Only)', 0),
    (N'demo.ai.reviewer@example.test', N'Demo AI Reviewer', N'AI_REVIEWER', N'demo-oidc|demo.ai.reviewer', N'DEMO-HR-DEPT', NULL, N'AI Recommendation Reviewer', 0),
    (N'svc.demo.integration@example.test', N'Demo Integration Service', N'INTEGRATION_SERVICE', N'demo-oidc|svc.demo.integration', NULL, NULL, N'Integration Service Account', 1);

    -- Also process demo.hr.admin's own profile/role/access below, so every
    -- user (including the bootstrap actor) ends up fully provisioned.
    INSERT INTO @Users (Email, DisplayName, RoleName, ProviderSubjectId, DepartmentCode, LocationCode, JobTitle, IsServiceAccount)
    VALUES (N'demo.hr.admin@example.test', N'Demo HR Administrator', N'HR_ADMIN', N'demo-oidc|demo.hr.admin', N'DEMO-HR-DEPT', N'DEMO-MUM', N'HR Administrator', 0);

    DECLARE user_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT Email, DisplayName, RoleName, ProviderSubjectId, DepartmentCode, LocationCode, JobTitle, IsServiceAccount FROM @Users;

    DECLARE @Email nvarchar(320), @DisplayName nvarchar(400), @RoleName nvarchar(200), @ProviderSubjectId nvarchar(400),
            @DepartmentCode nvarchar(100), @LocationCode nvarchar(100), @JobTitle nvarchar(300), @IsServiceAccount bit;

    OPEN user_cursor;
    FETCH NEXT FROM user_cursor INTO @Email, @DisplayName, @RoleName, @ProviderSubjectId, @DepartmentCode, @LocationCode, @JobTitle, @IsServiceAccount;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @UserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = @Email AND IsDeleted = 0);

        IF @UserId IS NULL
        BEGIN
            EXEC iam.usp_CreateUser
                @TenantId = @TenantId, @Email = @Email, @DisplayName = @DisplayName,
                @ProviderName = @ProviderName, @ProviderSubjectId = @ProviderSubjectId,
                @CreatedByUserId = @ActorUserId, @CorrelationId = @CorrelationId;

            SELECT @UserId = UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = @Email AND IsDeleted = 0;
        END

        IF @UserId IS NULL
            THROW 50003, N'Seed execution failed: user was not found/created for the expected email.', 1;

        IF @IsServiceAccount = 1
            UPDATE iam.[User] SET IsSystemServiceAccount = 1 WHERE UserId = @UserId AND IsSystemServiceAccount = 0;

        -- Tenant access
        IF NOT EXISTS (SELECT 1 FROM iam.UserTenantAccess WHERE UserId = @UserId AND TenantId = @TenantId AND IsDeleted = 0)
            INSERT INTO iam.UserTenantAccess (UserId, TenantId, IsActive, CreatedAtUtc, CreatedByUserId)
            VALUES (@UserId, @TenantId, 1, @ExecutionUtc, @ActorUserId);

        -- Profile (first/last name split from DisplayName's last space; job title)
        IF NOT EXISTS (SELECT 1 FROM iam.UserProfile WHERE UserId = @UserId AND IsDeleted = 0)
            INSERT INTO iam.UserProfile (TenantId, UserId, FirstName, LastName, JobTitle, CreatedAtUtc, CreatedByUserId)
            VALUES (
                @TenantId, @UserId,
                LEFT(@DisplayName, CASE WHEN CHARINDEX(N' ', @DisplayName) = 0 THEN LEN(@DisplayName) ELSE LEN(@DisplayName) - CHARINDEX(N' ', REVERSE(@DisplayName)) END),
                CASE WHEN CHARINDEX(N' ', REVERSE(@DisplayName)) = 0 THEN N'' ELSE RIGHT(@DisplayName, CHARINDEX(N' ', REVERSE(@DisplayName)) - 1) END,
                @JobTitle, @ExecutionUtc, @ActorUserId
            );

        IF @DepartmentCode IS NOT NULL
        BEGIN
            DECLARE @DeptId UNIQUEIDENTIFIER = (SELECT DepartmentId FROM org.Department WHERE TenantId = @TenantId AND DepartmentCode = @DepartmentCode AND IsDeleted = 0);
            IF @DeptId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM iam.UserDepartmentAccess WHERE UserId = @UserId AND DepartmentId = @DeptId AND IsDeleted = 0)
                INSERT INTO iam.UserDepartmentAccess (TenantId, UserId, DepartmentId, IsActive, CreatedAtUtc, CreatedByUserId)
                VALUES (@TenantId, @UserId, @DeptId, 1, @ExecutionUtc, @ActorUserId);

            IF @DeptId IS NOT NULL
                UPDATE iam.UserProfile SET DepartmentId = @DeptId WHERE UserId = @UserId AND DepartmentId IS NULL;
        END

        IF @LocationCode IS NOT NULL
        BEGIN
            DECLARE @LocId UNIQUEIDENTIFIER = (SELECT LocationId FROM org.Location WHERE TenantId = @TenantId AND LocationCode = @LocationCode AND IsDeleted = 0);
            IF @LocId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM iam.UserLocationAccess WHERE UserId = @UserId AND LocationId = @LocId AND IsDeleted = 0)
                INSERT INTO iam.UserLocationAccess (TenantId, UserId, LocationId, IsActive, CreatedAtUtc, CreatedByUserId)
                VALUES (@TenantId, @UserId, @LocId, 1, @ExecutionUtc, @ActorUserId);

            IF @LocId IS NOT NULL
                UPDATE iam.UserProfile SET LocationId = @LocId WHERE UserId = @UserId AND LocationId IS NULL;
        END

        -- Role assignment (minimum single role per spec's table)
        DECLARE @RoleId UNIQUEIDENTIFIER = (SELECT RoleId FROM iam.Role WHERE TenantId IS NULL AND RoleName = @RoleName AND IsDeleted = 0);
        IF @RoleId IS NULL
            THROW 50004, N'Seed execution failed: expected role was not found. Run 02-seed-iam-roles-permissions.sql first.', 1;

        IF NOT EXISTS (SELECT 1 FROM iam.UserRole WHERE UserId = @UserId AND RoleId = @RoleId AND RevokedAtUtc IS NULL AND IsDeleted = 0)
            EXEC iam.usp_AssignUserRole @TenantId = @TenantId, @UserId = @UserId, @RoleId = @RoleId, @AssignedByUserId = @ActorUserId, @CorrelationId = @CorrelationId;

        FETCH NEXT FROM user_cursor INTO @Email, @DisplayName, @RoleName, @ProviderSubjectId, @DepartmentCode, @LocationCode, @JobTitle, @IsServiceAccount;
    END
    CLOSE user_cursor;
    DEALLOCATE user_cursor;

    -- ========================================================================
    -- Reporting-manager mapping (section 7)
    -- ========================================================================
    DECLARE @ReportingMap TABLE (SubordinateEmail nvarchar(320), ManagerEmail nvarchar(320));
    INSERT INTO @ReportingMap (SubordinateEmail, ManagerEmail) VALUES
    (N'demo.recruiter@example.test', N'demo.hr.admin@example.test'),
    (N'demo.ta.manager@example.test', N'demo.hr.admin@example.test'),
    (N'demo.hiring.manager@example.test', N'demo.tenant.admin@example.test'),
    (N'demo.onboarding.admin@example.test', N'demo.hr.admin@example.test'),
    (N'demo.document.verifier@example.test', N'demo.hr.admin@example.test');

    INSERT INTO org.ReportingManagerMapping (TenantId, UserId, ManagerUserId, EffectiveFromUtc, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, u.UserId, m.UserId, @ExecutionUtc, @ExecutionUtc, @ActorUserId
    FROM @ReportingMap rm
    JOIN iam.[User] u ON u.TenantId = @TenantId AND u.Email = rm.SubordinateEmail AND u.IsDeleted = 0
    JOIN iam.[User] m ON m.TenantId = @TenantId AND m.Email = rm.ManagerEmail AND m.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM org.ReportingManagerMapping x
        WHERE x.UserId = u.UserId AND x.EffectiveToUtc IS NULL AND x.IsDeleted = 0
    );

    -- Also give demo.hiring.manager visibility of the demo TAN's hiring-manager
    -- assignment scope up front (recruitment.JobRequisitionHiringManager is
    -- seeded per-TAN in 09; this reporting mapping is org-structure only).

    COMMIT TRAN;
    PRINT N'03-seed-iam-users-access.sql complete. Seed actor UserId = ' + CAST(@ActorUserId AS nvarchar(50));
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
