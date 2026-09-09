/* ============================================================================
   01-seed-tenant-organization.sql
   Purpose : Seed the DEMO-HR tenant and its organization/business-unit/
             department/location/work-mode/employment-type/job-grade/
             designation/cost-center master data.
   Depends on: 00-01-through-09 schema deployment scripts (Database/scripts/).
   Idempotent: Yes — every insert is guarded by a business-key existence check.

   SCHEMA NOTE (read before editing): org.Tenant has no TenantType, Status
   enum, or IsDemoData column — only TenantCode, TenantName, LegalName,
   PrimaryDomain, IsActive (see ../docs/data-dictionary.md). This package
   marks demo data by TenantCode/business-key prefix (DEMO-/SAMPLE-) instead,
   per the fallback convention requested when no schema column exists.

   BOOTSTRAP EXCEPTION: unlike every other script in this package, this one
   cannot resolve an @ActorUserId — no iam.User row can exist before a tenant
   does. CreatedByUserId is intentionally NULL here, which is this schema's
   documented convention for "system/migration" (see Database/scripts/
   02-create-types.sql conventions block). Script 02 onward resolves and uses
   a real actor user.
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @TenantCode nvarchar(50) = N'DEMO-HR';
DECLARE @TenantId UNIQUEIDENTIFIER;
DECLARE @CorrelationId UNIQUEIDENTIFIER = NEWID();
DECLARE @ExecutionUtc datetime2(7) = SYSUTCDATETIME();

BEGIN TRY
    BEGIN TRAN;

    -- --- Tenant (idempotent: create only if it doesn't already exist) -----
    SELECT @TenantId = TenantId FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0;

    IF @TenantId IS NULL
    BEGIN
        EXEC iam.usp_CreateTenant
            @TenantCode = @TenantCode,
            @TenantName = N'Demo HR Automation Organization',
            @LegalName = N'Demo HR Automation Organization (Synthetic Demo Tenant)',
            @CreatedByUserId = NULL,
            @CorrelationId = @CorrelationId;

        SELECT @TenantId = TenantId FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0;

        IF @TenantId IS NULL
            THROW 50001, 'Seed execution failed: tenant creation did not produce a TenantId.', 1;

        PRINT N'Created tenant ' + @TenantCode;
    END
    ELSE
    BEGIN
        PRINT N'Tenant ' + @TenantCode + N' already exists — skipping create.';
    END

    -- Every subsequent statement in this script is tenant-scoped; org.* has
    -- no RLS policy (see docs/rls-design.md priority list), but session
    -- context is still established here for defense-in-depth consistency
    -- with every other script in this package.
    -- Plain (non-read-only) context: iam.usp_SetSessionSecurityContext marks
    -- the key read-only, which then conflicts with the plain
    -- sp_set_session_context calls already inside iam.usp_CreateTenant/
    -- usp_CreateUser/etc. — every business procedure in this schema sets its
    -- own TenantId context internally, so seed scripts use the same plain
    -- form for consistency, matching the spec's own config-block template.
    EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
    EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

    -- --- Organization -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM org.Organization WHERE TenantId = @TenantId AND OrganizationCode = N'DEMO-HR-ORG' AND IsDeleted = 0)
        INSERT INTO org.Organization (TenantId, OrganizationCode, OrganizationName, IsActive, CreatedAtUtc)
        VALUES (@TenantId, N'DEMO-HR-ORG', N'Demo HR Automation Organization', 1, @ExecutionUtc);

    DECLARE @OrgId UNIQUEIDENTIFIER = (SELECT OrganizationId FROM org.Organization WHERE TenantId = @TenantId AND OrganizationCode = N'DEMO-HR-ORG');

    -- --- Business units -------------------------------------------------------
    DECLARE @BusinessUnits TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @BusinessUnits (Code, Name) VALUES
        (N'DEMO-TECH', N'Technology Services'),
        (N'DEMO-OPS', N'Operations'),
        (N'DEMO-HR-BU', N'Human Resources');

    INSERT INTO org.BusinessUnit (TenantId, OrganizationId, BusinessUnitCode, BusinessUnitName, IsActive, CreatedAtUtc)
    SELECT @TenantId, @OrgId, bu.Code, bu.Name, 1, @ExecutionUtc
    FROM @BusinessUnits bu
    WHERE NOT EXISTS (
        SELECT 1 FROM org.BusinessUnit x
        WHERE x.TenantId = @TenantId AND x.BusinessUnitCode = bu.Code AND x.IsDeleted = 0
    );

    -- --- Departments (mapped to the closest matching business unit) -------
    DECLARE @Departments TABLE (Code nvarchar(100), Name nvarchar(400), BusinessUnitCode nvarchar(100));
    INSERT INTO @Departments (Code, Name, BusinessUnitCode) VALUES
        (N'DEMO-HR-DEPT', N'Human Resources', N'DEMO-HR-BU'),
        (N'DEMO-ENG-DEPT', N'Engineering', N'DEMO-TECH'),
        (N'DEMO-OPS-DEPT', N'Operations', N'DEMO-OPS'),
        (N'DEMO-FIN-DEPT', N'Finance', N'DEMO-OPS');

    INSERT INTO org.Department (TenantId, BusinessUnitId, DepartmentCode, DepartmentName, IsActive, CreatedAtUtc)
    SELECT @TenantId, bu.BusinessUnitId, d.Code, d.Name, 1, @ExecutionUtc
    FROM @Departments d
    JOIN org.BusinessUnit bu ON bu.TenantId = @TenantId AND bu.BusinessUnitCode = d.BusinessUnitCode AND bu.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM org.Department x
        WHERE x.TenantId = @TenantId AND x.DepartmentCode = d.Code AND x.IsDeleted = 0
    );

    -- --- Locations ------------------------------------------------------------
    DECLARE @Locations TABLE (Code nvarchar(100), Name nvarchar(400), City nvarchar(200), CountryCode char(2));
    INSERT INTO @Locations (Code, Name, City, CountryCode) VALUES
        (N'DEMO-MUM', N'Mumbai Demo Office', N'Mumbai', N'IN'),
        (N'DEMO-PUN', N'Pune Demo Office', N'Pune', N'IN'),
        (N'DEMO-REM', N'Remote / Hybrid', NULL, NULL);

    INSERT INTO org.Location (TenantId, LocationCode, LocationName, City, CountryCode, IsActive, CreatedAtUtc)
    SELECT @TenantId, l.Code, l.Name, l.City, l.CountryCode, 1, @ExecutionUtc
    FROM @Locations l
    WHERE NOT EXISTS (
        SELECT 1 FROM org.Location x
        WHERE x.TenantId = @TenantId AND x.LocationCode = l.Code AND x.IsDeleted = 0
    );

    -- --- Work modes (global reference — see 02-seed-... note: org.WorkMode
    -- supports TenantId NULL = system baseline; seeded as tenant-scoped
    -- overrides here so this tenant's demo data is fully self-contained and
    -- removable without touching a shared global row). -----------------------
    DECLARE @WorkModes TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @WorkModes (Code, Name) VALUES
        (N'ON_SITE', N'On-site'), (N'HYBRID', N'Hybrid'), (N'REMOTE', N'Remote');

    INSERT INTO org.WorkMode (TenantId, Code, Name, IsActive, CreatedAtUtc)
    SELECT @TenantId, w.Code, w.Name, 1, @ExecutionUtc
    FROM @WorkModes w
    WHERE NOT EXISTS (
        SELECT 1 FROM org.WorkMode x
        WHERE x.TenantId = @TenantId AND x.Code = w.Code AND x.IsDeleted = 0
    );

    -- --- Employment types (ref schema) -----------------------------------
    DECLARE @EmploymentTypes TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @EmploymentTypes (Code, Name) VALUES
        (N'FULL_TIME', N'Full Time'), (N'CONTRACT', N'Contract'),
        (N'INTERN', N'Intern'), (N'CONSULTANT', N'Consultant');

    INSERT INTO ref.EmploymentType (TenantId, Code, Name, IsActive, CreatedAtUtc)
    SELECT @TenantId, e.Code, e.Name, 1, @ExecutionUtc
    FROM @EmploymentTypes e
    WHERE NOT EXISTS (
        SELECT 1 FROM ref.EmploymentType x
        WHERE x.TenantId = @TenantId AND x.Code = e.Code AND x.IsDeleted = 0
    );

    -- --- Job grades -------------------------------------------------------
    DECLARE @JobGrades TABLE (Code nvarchar(100), Name nvarchar(400), Level int);
    INSERT INTO @JobGrades (Code, Name, Level) VALUES
        (N'G1', N'Entry', 1), (N'G2', N'Associate', 2), (N'G3', N'Senior Associate', 3),
        (N'G4', N'Lead', 4), (N'G5', N'Manager', 5), (N'G6', N'Senior Manager', 6);

    INSERT INTO org.JobGrade (TenantId, GradeCode, GradeName, GradeLevel, IsActive, CreatedAtUtc)
    SELECT @TenantId, g.Code, g.Name, g.Level, 1, @ExecutionUtc
    FROM @JobGrades g
    WHERE NOT EXISTS (
        SELECT 1 FROM org.JobGrade x
        WHERE x.TenantId = @TenantId AND x.GradeCode = g.Code AND x.IsDeleted = 0
    );

    -- --- Designations -------------------------------------------------------
    DECLARE @Designations TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @Designations (Code, Name) VALUES
        (N'SOFTWARE_ENGINEER', N'Software Engineer'),
        (N'SENIOR_SOFTWARE_ENGINEER', N'Senior Software Engineer'),
        (N'TECHNICAL_LEAD', N'Technical Lead'),
        (N'PROJECT_MANAGER', N'Project Manager'),
        (N'HR_EXECUTIVE', N'HR Executive'),
        (N'HR_MANAGER', N'HR Manager'),
        (N'TALENT_ACQUISITION_SPECIALIST', N'Talent Acquisition Specialist'),
        (N'RECRUITER', N'Recruiter'),
        (N'SYSTEM_ADMINISTRATOR', N'System Administrator');

    INSERT INTO org.Designation (TenantId, DesignationCode, DesignationName, IsActive, CreatedAtUtc)
    SELECT @TenantId, d.Code, d.Name, 1, @ExecutionUtc
    FROM @Designations d
    WHERE NOT EXISTS (
        SELECT 1 FROM org.Designation x
        WHERE x.TenantId = @TenantId AND x.DesignationCode = d.Code AND x.IsDeleted = 0
    );

    -- --- Cost centers (mapped to the closest matching department) ---------
    DECLARE @CostCenters TABLE (Code nvarchar(100), Name nvarchar(400), DepartmentCode nvarchar(100));
    INSERT INTO @CostCenters (Code, Name, DepartmentCode) VALUES
        (N'DEMO-HR-CC', N'HR Cost Center', N'DEMO-HR-DEPT'),
        (N'DEMO-ENG-CC', N'Engineering Cost Center', N'DEMO-ENG-DEPT'),
        (N'DEMO-OPS-CC', N'Operations Cost Center', N'DEMO-OPS-DEPT');

    INSERT INTO org.CostCenter (TenantId, CostCenterCode, CostCenterName, DepartmentId, IsActive, CreatedAtUtc)
    SELECT @TenantId, cc.Code, cc.Name, d.DepartmentId, 1, @ExecutionUtc
    FROM @CostCenters cc
    JOIN org.Department d ON d.TenantId = @TenantId AND d.DepartmentCode = cc.DepartmentCode AND d.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM org.CostCenter x
        WHERE x.TenantId = @TenantId AND x.CostCenterCode = cc.Code AND x.IsDeleted = 0
    );

    COMMIT TRAN;

    PRINT N'01-seed-tenant-organization.sql complete. TenantId = ' + CAST(@TenantId AS nvarchar(50));
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
