/* ============================================================================
   03-create-tables.sql
   Purpose : All table DDL, organized by schema/domain in the order tables are
             first referenced by a foreign key (org -> iam -> ref -> recruitment
             -> offer -> onboarding -> employee -> workflow -> integration ->
             ai -> audit). Appended to across the delivery phases documented in
             ../README.md; each PART is self-contained and re-runnable.
   Idempotent: Each CREATE TABLE is guarded by an existence check.
   Depends on: 01-create-schemas.sql, 02-create-types.sql.
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   Shared column-set convention used by every CREATE TABLE below (see
   02-create-types.sql "CONVENTIONS" for the full rationale):

       <BusinessColumns...>
       CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
       CreatedByUserId UNIQUEIDENTIFIER NULL,
       UpdatedAtUtc    datetime2(7)     NULL,
       UpdatedByUserId UNIQUEIDENTIFIER NULL,
       IsDeleted       bit              NOT NULL DEFAULT (0),
       DeletedAtUtc    datetime2(7)     NULL,
       DeletedByUserId UNIQUEIDENTIFIER NULL,
       RowVersion      rowversion       NOT NULL

   Configuration/reference tables additionally carry:
       IsActive         bit          NOT NULL DEFAULT (1)
       EffectiveFromUtc datetime2(7) NOT NULL DEFAULT SYSUTCDATETIME()
       EffectiveToUtc   datetime2(7) NULL
       VersionNumber    int          NOT NULL DEFAULT (1)
       ApprovalStatus   nvarchar(20) NOT NULL DEFAULT ('Approved')
           CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))

   Tenant-overridable reference tables use TenantId UNIQUEIDENTIFIER NULL
   (NULL = system-wide baseline) with two filtered unique indexes: one on
   (Code) WHERE TenantId IS NULL, one on (TenantId, Code) WHERE TenantId IS
   NOT NULL — this is the "tenant-specific override pattern" required by
   section 5 of the design spec.
   ============================================================================ */

-- ============================================================================
-- PART 1 — org schema (tenant & organization structure)
-- ============================================================================

IF OBJECT_ID(N'org.Tenant', N'U') IS NULL
CREATE TABLE org.Tenant
(
    TenantId        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantCode      nvarchar(50)     NOT NULL,
    TenantName      nvarchar(200)    NOT NULL,
    LegalName       nvarchar(200)    NULL,
    PrimaryDomain   nvarchar(200)    NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Tenant PRIMARY KEY CLUSTERED (TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Tenant_TenantCode')
    CREATE UNIQUE INDEX UQ_org_Tenant_TenantCode ON org.Tenant(TenantCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.TenantConfiguration', N'U') IS NULL
CREATE TABLE org.TenantConfiguration
(
    TenantConfigurationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId              UNIQUEIDENTIFIER NOT NULL,
    ConfigKey              nvarchar(200)    NOT NULL,
    ConfigValueJson         nvarchar(max)    NOT NULL,
    Description            nvarchar(500)    NULL,
    IsActive               bit              NOT NULL DEFAULT (1),
    EffectiveFromUtc       datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc         datetime2(7)     NULL,
    VersionNumber          int              NOT NULL DEFAULT (1),
    ApprovalStatus         nvarchar(20)     NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_TenantConfiguration PRIMARY KEY CLUSTERED (TenantConfigurationId),
    CONSTRAINT FK_TenantConfiguration_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_TenantConfiguration_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired')),
    CONSTRAINT CK_TenantConfiguration_ConfigValueJson CHECK (ISJSON(ConfigValueJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_TenantConfiguration_Key')
    CREATE UNIQUE INDEX UQ_org_TenantConfiguration_Key ON org.TenantConfiguration(TenantId, ConfigKey) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.Organization', N'U') IS NULL
CREATE TABLE org.Organization
(
    OrganizationId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OrganizationCode nvarchar(50)    NOT NULL,
    OrganizationName nvarchar(200)   NOT NULL,
    ParentOrganizationId UNIQUEIDENTIFIER NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Organization PRIMARY KEY CLUSTERED (OrganizationId),
    CONSTRAINT FK_Organization_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Organization_Parent FOREIGN KEY (ParentOrganizationId) REFERENCES org.Organization(OrganizationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Organization_Code')
    CREATE UNIQUE INDEX UQ_org_Organization_Code ON org.Organization(TenantId, OrganizationCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.BusinessUnit', N'U') IS NULL
CREATE TABLE org.BusinessUnit
(
    BusinessUnitId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OrganizationId  UNIQUEIDENTIFIER NOT NULL,
    BusinessUnitCode nvarchar(50)    NOT NULL,
    BusinessUnitName nvarchar(200)   NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_BusinessUnit PRIMARY KEY CLUSTERED (BusinessUnitId),
    CONSTRAINT FK_BusinessUnit_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_BusinessUnit_Organization FOREIGN KEY (OrganizationId) REFERENCES org.Organization(OrganizationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_BusinessUnit_Code')
    CREATE UNIQUE INDEX UQ_org_BusinessUnit_Code ON org.BusinessUnit(TenantId, BusinessUnitCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.Department', N'U') IS NULL
CREATE TABLE org.Department
(
    DepartmentId    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    BusinessUnitId  UNIQUEIDENTIFIER NULL,
    DepartmentCode  nvarchar(50)     NOT NULL,
    DepartmentName  nvarchar(200)    NOT NULL,
    ParentDepartmentId UNIQUEIDENTIFIER NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Department PRIMARY KEY CLUSTERED (DepartmentId),
    CONSTRAINT FK_Department_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Department_BusinessUnit FOREIGN KEY (BusinessUnitId) REFERENCES org.BusinessUnit(BusinessUnitId),
    CONSTRAINT FK_Department_Parent FOREIGN KEY (ParentDepartmentId) REFERENCES org.Department(DepartmentId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Department_Code')
    CREATE UNIQUE INDEX UQ_org_Department_Code ON org.Department(TenantId, DepartmentCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.Designation', N'U') IS NULL
CREATE TABLE org.Designation
(
    DesignationId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DesignationCode nvarchar(50)     NOT NULL,
    DesignationName nvarchar(200)    NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Designation PRIMARY KEY CLUSTERED (DesignationId),
    CONSTRAINT FK_Designation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Designation_Code')
    CREATE UNIQUE INDEX UQ_org_Designation_Code ON org.Designation(TenantId, DesignationCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.JobGrade', N'U') IS NULL
CREATE TABLE org.JobGrade
(
    JobGradeId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GradeCode       nvarchar(50)     NOT NULL,
    GradeName       nvarchar(200)    NOT NULL,
    GradeLevel      int              NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_JobGrade PRIMARY KEY CLUSTERED (JobGradeId),
    CONSTRAINT FK_JobGrade_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_JobGrade_Code')
    CREATE UNIQUE INDEX UQ_org_JobGrade_Code ON org.JobGrade(TenantId, GradeCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.Location', N'U') IS NULL
CREATE TABLE org.Location
(
    LocationId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    LocationCode    nvarchar(50)     NOT NULL,
    LocationName    nvarchar(200)    NOT NULL,
    AddressLine1    nvarchar(200)    NULL,
    AddressLine2    nvarchar(200)    NULL,
    City            nvarchar(100)    NULL,
    StateProvince   nvarchar(100)    NULL,
    PostalCode      nvarchar(20)     NULL,
    CountryCode     char(2)          NULL,
    TimeZoneId      nvarchar(60)     NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Location PRIMARY KEY CLUSTERED (LocationId),
    CONSTRAINT FK_Location_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Location_Code')
    CREATE UNIQUE INDEX UQ_org_Location_Code ON org.Location(TenantId, LocationCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.WorkMode', N'U') IS NULL
CREATE TABLE org.WorkMode
(
    WorkModeId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NULL,
    Code            nvarchar(50)     NOT NULL,
    Name            nvarchar(200)    NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_WorkMode PRIMARY KEY CLUSTERED (WorkModeId),
    CONSTRAINT FK_WorkMode_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_WorkMode_Global')
    CREATE UNIQUE INDEX UQ_org_WorkMode_Global ON org.WorkMode(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_WorkMode_Tenant')
    CREATE UNIQUE INDEX UQ_org_WorkMode_Tenant ON org.WorkMode(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'org.Client', N'U') IS NULL
CREATE TABLE org.Client
(
    ClientId        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ClientCode      nvarchar(50)     NOT NULL,
    ClientName      nvarchar(200)    NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Client PRIMARY KEY CLUSTERED (ClientId),
    CONSTRAINT FK_Client_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Client_Code')
    CREATE UNIQUE INDEX UQ_org_Client_Code ON org.Client(TenantId, ClientCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.CostCenter', N'U') IS NULL
CREATE TABLE org.CostCenter
(
    CostCenterId    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CostCenterCode  nvarchar(50)     NOT NULL,
    CostCenterName  nvarchar(200)    NOT NULL,
    DepartmentId    UNIQUEIDENTIFIER NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_CostCenter PRIMARY KEY CLUSTERED (CostCenterId),
    CONSTRAINT FK_CostCenter_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CostCenter_Department FOREIGN KEY (DepartmentId) REFERENCES org.Department(DepartmentId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_CostCenter_Code')
    CREATE UNIQUE INDEX UQ_org_CostCenter_Code ON org.CostCenter(TenantId, CostCenterCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.HolidayCalendar', N'U') IS NULL
CREATE TABLE org.HolidayCalendar
(
    HolidayCalendarId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId          UNIQUEIDENTIFIER NOT NULL,
    CalendarCode      nvarchar(50)     NOT NULL,
    CalendarName      nvarchar(200)    NOT NULL,
    CountryCode       char(2)          NULL,
    IsActive          bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_HolidayCalendar PRIMARY KEY CLUSTERED (HolidayCalendarId),
    CONSTRAINT FK_HolidayCalendar_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_HolidayCalendar_Code')
    CREATE UNIQUE INDEX UQ_org_HolidayCalendar_Code ON org.HolidayCalendar(TenantId, CalendarCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'org.Holiday', N'U') IS NULL
CREATE TABLE org.Holiday
(
    HolidayId         UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId          UNIQUEIDENTIFIER NOT NULL,
    HolidayCalendarId UNIQUEIDENTIFIER NOT NULL,
    HolidayDate       date             NOT NULL,
    HolidayName       nvarchar(200)    NOT NULL,
    IsOptional        bit              NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_Holiday PRIMARY KEY CLUSTERED (HolidayId),
    CONSTRAINT FK_Holiday_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Holiday_Calendar FOREIGN KEY (HolidayCalendarId) REFERENCES org.HolidayCalendar(HolidayCalendarId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_Holiday_CalendarDate')
    CREATE UNIQUE INDEX UQ_org_Holiday_CalendarDate ON org.Holiday(HolidayCalendarId, HolidayDate) WHERE IsDeleted = 0;
GO

/* ReportingManagerMapping references iam.User, created after iam.User below —
   forward-declared here as the last org table, added once iam.User exists. */

PRINT N'03-create-tables.sql PART 1 (org) complete.';
GO

-- ============================================================================
-- PART 2 — iam schema (identity and access management)
-- ============================================================================

IF OBJECT_ID(N'iam.User', N'U') IS NULL
CREATE TABLE iam.[User]
(
    UserId          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    Email           nvarchar(320)    NOT NULL,
    NormalizedEmail AS (dbo.fn_normalize_email(Email)) PERSISTED,
    DisplayName     nvarchar(200)    NOT NULL,
    UserStatus      nvarchar(20)     NOT NULL DEFAULT ('Pending'),
    IsSystemServiceAccount bit       NOT NULL DEFAULT (0),
    LastLoginAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_User PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_User_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_User_Status CHECK (UserStatus IN ('Pending','Active','Inactive','Locked','Deleted'))
) ;
GO
-- NOTE: NormalizedEmail computed column above requires dbo.fn_normalize_email to
-- exist first — see scripts/06-create-functions.sql, which must run before this
-- table is created on a fresh database. scripts/99-validate-database.sql checks
-- deployment order. (Deployment guide documents functions-before-tables bootstrap
-- exception for this one computed column.)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_User_Email')
    CREATE UNIQUE INDEX UQ_iam_User_Email ON iam.[User](TenantId, NormalizedEmail) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserProfile', N'U') IS NULL
CREATE TABLE iam.UserProfile
(
    UserProfileId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    FirstName       nvarchar(100)    NULL,
    LastName        nvarchar(100)    NULL,
    PhoneNumber     nvarchar(30)     NULL,
    JobTitle        nvarchar(150)    NULL,
    DepartmentId    UNIQUEIDENTIFIER NULL,
    LocationId      UNIQUEIDENTIFIER NULL,
    PreferredTimeZoneId nvarchar(60) NULL,
    PreferredLanguage   nvarchar(10) NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserProfile PRIMARY KEY CLUSTERED (UserProfileId),
    CONSTRAINT FK_UserProfile_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserProfile_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_UserProfile_Department FOREIGN KEY (DepartmentId) REFERENCES org.Department(DepartmentId),
    CONSTRAINT FK_UserProfile_Location FOREIGN KEY (LocationId) REFERENCES org.Location(LocationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_UserProfile_UserId')
    CREATE UNIQUE INDEX UQ_iam_UserProfile_UserId ON iam.UserProfile(UserId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserAuthenticationProvider', N'U') IS NULL
CREATE TABLE iam.UserAuthenticationProvider
(
    UserAuthenticationProviderId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId          UNIQUEIDENTIFIER NOT NULL,
    UserId            UNIQUEIDENTIFIER NOT NULL,
    ProviderName      nvarchar(50)     NOT NULL, -- e.g. 'AzureAd','Okta','Google','Local'
    ProviderSubjectId nvarchar(200)    NOT NULL, -- IdP's opaque subject/sub claim only — no credential material
    IsPrimary         bit              NOT NULL DEFAULT (1),
    LinkedAtUtc       datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserAuthenticationProvider PRIMARY KEY CLUSTERED (UserAuthenticationProviderId),
    CONSTRAINT FK_UserAuthProvider_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserAuthProvider_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_UserAuthProvider_Subject')
    CREATE UNIQUE INDEX UQ_iam_UserAuthProvider_Subject ON iam.UserAuthenticationProvider(ProviderName, ProviderSubjectId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.Role', N'U') IS NULL
CREATE TABLE iam.Role
(
    RoleId          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NULL, -- NULL = system baseline role available to every tenant
    RoleName        nvarchar(100)    NOT NULL,
    Description     nvarchar(500)    NULL,
    IsSystemRole    bit              NOT NULL DEFAULT (0),
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_Role PRIMARY KEY CLUSTERED (RoleId),
    CONSTRAINT FK_Role_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_Role_Global')
    CREATE UNIQUE INDEX UQ_iam_Role_Global ON iam.Role(RoleName) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_Role_Tenant')
    CREATE UNIQUE INDEX UQ_iam_Role_Tenant ON iam.Role(TenantId, RoleName) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.Permission', N'U') IS NULL
CREATE TABLE iam.Permission
(
    PermissionId    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    PermissionKey   nvarchar(150)    NOT NULL, -- e.g. 'recruitment.candidate.read'
    Description     nvarchar(500)    NULL,
    ResourceCategory nvarchar(100)   NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_Permission PRIMARY KEY CLUSTERED (PermissionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_Permission_Key')
    CREATE UNIQUE INDEX UQ_iam_Permission_Key ON iam.Permission(PermissionKey) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserRole', N'U') IS NULL
CREATE TABLE iam.UserRole
(
    UserRoleId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    RoleId          UNIQUEIDENTIFIER NOT NULL,
    AssignedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    AssignedByUserId UNIQUEIDENTIFIER NULL,
    RevokedAtUtc    datetime2(7)     NULL,
    RevokedByUserId UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserRole PRIMARY KEY CLUSTERED (UserRoleId),
    CONSTRAINT FK_UserRole_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES iam.Role(RoleId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_UserRole_Active')
    CREATE UNIQUE INDEX UQ_iam_UserRole_Active ON iam.UserRole(UserId, RoleId) WHERE RevokedAtUtc IS NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.RolePermission', N'U') IS NULL
CREATE TABLE iam.RolePermission
(
    RolePermissionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    RoleId          UNIQUEIDENTIFIER NOT NULL,
    PermissionId    UNIQUEIDENTIFIER NOT NULL,
    GrantedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    GrantedByUserId UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_RolePermission PRIMARY KEY CLUSTERED (RolePermissionId),
    CONSTRAINT FK_RolePermission_Role FOREIGN KEY (RoleId) REFERENCES iam.Role(RoleId),
    CONSTRAINT FK_RolePermission_Permission FOREIGN KEY (PermissionId) REFERENCES iam.Permission(PermissionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_RolePermission')
    CREATE UNIQUE INDEX UQ_iam_RolePermission ON iam.RolePermission(RoleId, PermissionId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserTenantAccess', N'U') IS NULL
CREATE TABLE iam.UserTenantAccess
(
    UserTenantAccessId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    UserId          UNIQUEIDENTIFIER NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserTenantAccess PRIMARY KEY CLUSTERED (UserTenantAccessId),
    CONSTRAINT FK_UserTenantAccess_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_UserTenantAccess_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_UserTenantAccess')
    CREATE UNIQUE INDEX UQ_iam_UserTenantAccess ON iam.UserTenantAccess(UserId, TenantId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserDepartmentAccess', N'U') IS NULL
CREATE TABLE iam.UserDepartmentAccess
(
    UserDepartmentAccessId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    DepartmentId    UNIQUEIDENTIFIER NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserDepartmentAccess PRIMARY KEY CLUSTERED (UserDepartmentAccessId),
    CONSTRAINT FK_UserDeptAccess_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserDeptAccess_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_UserDeptAccess_Department FOREIGN KEY (DepartmentId) REFERENCES org.Department(DepartmentId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_UserDepartmentAccess')
    CREATE UNIQUE INDEX UQ_iam_UserDepartmentAccess ON iam.UserDepartmentAccess(UserId, DepartmentId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserLocationAccess', N'U') IS NULL
CREATE TABLE iam.UserLocationAccess
(
    UserLocationAccessId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    LocationId      UNIQUEIDENTIFIER NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserLocationAccess PRIMARY KEY CLUSTERED (UserLocationAccessId),
    CONSTRAINT FK_UserLocAccess_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserLocAccess_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_UserLocAccess_Location FOREIGN KEY (LocationId) REFERENCES org.Location(LocationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_UserLocationAccess')
    CREATE UNIQUE INDEX UQ_iam_UserLocationAccess ON iam.UserLocationAccess(UserId, LocationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserSessionAudit', N'U') IS NULL
CREATE TABLE iam.UserSessionAudit
(
    UserSessionAuditId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    SessionId       nvarchar(100)    NOT NULL,
    LoginAtUtc      datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    LogoutAtUtc     datetime2(7)     NULL,
    IpAddressHash   varbinary(32)    NULL, -- hashed, never raw IP at rest by default
    UserAgent       nvarchar(300)    NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_iam_UserSessionAudit PRIMARY KEY CLUSTERED (UserSessionAuditId),
    CONSTRAINT FK_UserSessionAudit_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserSessionAudit_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId)
);
GO

IF OBJECT_ID(N'iam.ApiClient', N'U') IS NULL
CREATE TABLE iam.ApiClient
(
    ApiClientId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ClientName      nvarchar(150)    NOT NULL,
    ClientIdentifier nvarchar(100)   NOT NULL, -- public client_id; the client secret lives only in the vault
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_ApiClient PRIMARY KEY CLUSTERED (ApiClientId),
    CONSTRAINT FK_ApiClient_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_ApiClient_Identifier')
    CREATE UNIQUE INDEX UQ_iam_ApiClient_Identifier ON iam.ApiClient(ClientIdentifier) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.ApiClientScope', N'U') IS NULL
CREATE TABLE iam.ApiClientScope
(
    ApiClientScopeId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    ApiClientId     UNIQUEIDENTIFIER NOT NULL,
    ScopeKey        nvarchar(150)    NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_ApiClientScope PRIMARY KEY CLUSTERED (ApiClientScopeId),
    CONSTRAINT FK_ApiClientScope_Client FOREIGN KEY (ApiClientId) REFERENCES iam.ApiClient(ApiClientId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_iam_ApiClientScope')
    CREATE UNIQUE INDEX UQ_iam_ApiClientScope ON iam.ApiClientScope(ApiClientId, ScopeKey) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'iam.UserConsent', N'U') IS NULL
CREATE TABLE iam.UserConsent
(
    UserConsentId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    ConsentType     nvarchar(100)    NOT NULL, -- e.g. 'DataProcessing','Communication'
    ConsentVersion  nvarchar(20)     NOT NULL,
    GrantedAtUtc    datetime2(7)     NULL,
    WithdrawnAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_UserConsent PRIMARY KEY CLUSTERED (UserConsentId),
    CONSTRAINT FK_UserConsent_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_UserConsent_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId)
);
GO

/* iam.PasswordHistory — CONDITIONAL. Only created/used if local username/password
   authentication is explicitly enabled for a deployment (see docs/security-model.md).
   Default posture is external-IdP-only (see iam.UserAuthenticationProvider) — this
   table stores no plaintext or reversibly-encrypted password, only a hash produced by
   the application's modern password-hashing component (Argon2id/PBKDF2 via ASP.NET
   Core Identity), never computed in T-SQL. */
IF OBJECT_ID(N'iam.PasswordHistory', N'U') IS NULL
CREATE TABLE iam.PasswordHistory
(
    PasswordHistoryId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId          UNIQUEIDENTIFIER NOT NULL,
    UserId            UNIQUEIDENTIFIER NOT NULL,
    PasswordHash      varbinary(256)   NOT NULL, -- application-computed hash only, never plaintext
    HashAlgorithm     nvarchar(50)     NOT NULL,
    CreatedAtUtc      datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_iam_PasswordHistory PRIMARY KEY CLUSTERED (PasswordHistoryId),
    CONSTRAINT FK_PasswordHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_PasswordHistory_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId)
);
GO

IF OBJECT_ID(N'iam.AuthenticationEvent', N'U') IS NULL
CREATE TABLE iam.AuthenticationEvent
(
    AuthenticationEventId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NULL,
    UserId          UNIQUEIDENTIFIER NULL,
    EventType       nvarchar(50)     NOT NULL, -- LoginSucceeded, LoginFailed, TokenRefreshed, LockedOut, PasswordReset...
    ProviderName    nvarchar(50)     NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    MetadataJson    nvarchar(max)    NULL,
    CONSTRAINT PK_iam_AuthenticationEvent PRIMARY KEY CLUSTERED (AuthenticationEventId),
    CONSTRAINT CK_AuthenticationEvent_MetadataJson CHECK (MetadataJson IS NULL OR ISJSON(MetadataJson) = 1)
);
GO

IF OBJECT_ID(N'iam.AuthorizationPolicy', N'U') IS NULL
CREATE TABLE iam.AuthorizationPolicy
(
    AuthorizationPolicyId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId          UNIQUEIDENTIFIER NULL,
    PolicyName        nvarchar(150)    NOT NULL,
    Description       nvarchar(500)    NULL,
    IsActive          bit              NOT NULL DEFAULT (1),
    EffectiveFromUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc    datetime2(7)     NULL,
    VersionNumber     int              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_AuthorizationPolicy PRIMARY KEY CLUSTERED (AuthorizationPolicyId),
    CONSTRAINT FK_AuthorizationPolicy_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO

IF OBJECT_ID(N'iam.AuthorizationPolicyRule', N'U') IS NULL
CREATE TABLE iam.AuthorizationPolicyRule
(
    AuthorizationPolicyRuleId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AuthorizationPolicyId UNIQUEIDENTIFIER NOT NULL,
    RuleExpression     nvarchar(1000)   NOT NULL, -- documented ABAC expression evaluated by the Application layer, not by SQL
    Effect             nvarchar(10)     NOT NULL DEFAULT ('Allow'),
    SortOrder          int              NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_iam_AuthorizationPolicyRule PRIMARY KEY CLUSTERED (AuthorizationPolicyRuleId),
    CONSTRAINT FK_AuthorizationPolicyRule_Policy FOREIGN KEY (AuthorizationPolicyId) REFERENCES iam.AuthorizationPolicy(AuthorizationPolicyId),
    CONSTRAINT CK_AuthorizationPolicyRule_Effect CHECK (Effect IN ('Allow','Deny'))
);
GO

/* org.ReportingManagerMapping — placed here because it references iam.User. */
IF OBJECT_ID(N'org.ReportingManagerMapping', N'U') IS NULL
CREATE TABLE org.ReportingManagerMapping
(
    ReportingManagerMappingId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId          UNIQUEIDENTIFIER NOT NULL,
    UserId            UNIQUEIDENTIFIER NOT NULL,
    ManagerUserId     UNIQUEIDENTIFIER NOT NULL,
    EffectiveFromUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc    datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_org_ReportingManagerMapping PRIMARY KEY CLUSTERED (ReportingManagerMappingId),
    CONSTRAINT FK_ReportingMgrMap_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ReportingMgrMap_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_ReportingMgrMap_Manager FOREIGN KEY (ManagerUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_ReportingMgrMap_NotSelf CHECK (UserId <> ManagerUserId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_org_ReportingMgrMap_Active')
    CREATE UNIQUE INDEX UQ_org_ReportingMgrMap_Active ON org.ReportingManagerMapping(UserId) WHERE EffectiveToUtc IS NULL AND IsDeleted = 0;
GO

PRINT N'03-create-tables.sql PART 2 (iam) complete.';
GO

-- ============================================================================
-- PART 3 — ref schema (configurable workflow/master data)
-- Every table below follows the tenant-override pattern documented at the top
-- of this file: TenantId NULL = system-wide baseline, non-NULL = tenant
-- override, enforced by two filtered unique indexes per table.
-- ============================================================================

IF OBJECT_ID(N'ref.WorkflowDefinition', N'U') IS NULL
CREATE TABLE ref.WorkflowDefinition
(
    WorkflowDefinitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId         UNIQUEIDENTIFIER NULL,
    WorkflowCode     nvarchar(100)    NOT NULL, -- e.g. 'TAN_APPROVAL','OFFER_APPROVAL','DISCREPANCY_RESOLUTION'
    WorkflowName     nvarchar(200)    NOT NULL,
    Description      nvarchar(500)    NULL,
    EntityType       nvarchar(100)    NOT NULL, -- domain entity this workflow governs
    IsActive         bit              NOT NULL DEFAULT (1),
    EffectiveFromUtc datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc   datetime2(7)     NULL,
    VersionNumber    int              NOT NULL DEFAULT (1),
    ApprovalStatus   nvarchar(20)     NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId  UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc     datetime2(7)     NULL,
    UpdatedByUserId  UNIQUEIDENTIFIER NULL,
    IsDeleted        bit              NOT NULL DEFAULT (0),
    DeletedAtUtc     datetime2(7)     NULL,
    DeletedByUserId  UNIQUEIDENTIFIER NULL,
    RowVersion       rowversion       NOT NULL,
    CONSTRAINT PK_ref_WorkflowDefinition PRIMARY KEY CLUSTERED (WorkflowDefinitionId),
    CONSTRAINT FK_WorkflowDefinition_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_WorkflowDefinition_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_WorkflowDefinition_Global')
    CREATE UNIQUE INDEX UQ_ref_WorkflowDefinition_Global ON ref.WorkflowDefinition(WorkflowCode) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_WorkflowDefinition_Tenant')
    CREATE UNIQUE INDEX UQ_ref_WorkflowDefinition_Tenant ON ref.WorkflowDefinition(TenantId, WorkflowCode) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.WorkflowStateDefinition', N'U') IS NULL
CREATE TABLE ref.WorkflowStateDefinition
(
    WorkflowStateDefinitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    WorkflowDefinitionId UNIQUEIDENTIFIER NOT NULL,
    StateCode        nvarchar(100)    NOT NULL,
    StateName        nvarchar(200)    NOT NULL,
    IsInitialState   bit              NOT NULL DEFAULT (0),
    IsTerminalState  bit              NOT NULL DEFAULT (0),
    RequiresApproval bit              NOT NULL DEFAULT (0),
    SortOrder        int              NOT NULL DEFAULT (0),
    IsActive         bit              NOT NULL DEFAULT (1),
    VersionNumber    int              NOT NULL DEFAULT (1),
    CreatedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId  UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc     datetime2(7)     NULL,
    UpdatedByUserId  UNIQUEIDENTIFIER NULL,
    IsDeleted        bit              NOT NULL DEFAULT (0),
    DeletedAtUtc     datetime2(7)     NULL,
    DeletedByUserId  UNIQUEIDENTIFIER NULL,
    RowVersion       rowversion       NOT NULL,
    CONSTRAINT PK_ref_WorkflowStateDefinition PRIMARY KEY CLUSTERED (WorkflowStateDefinitionId),
    CONSTRAINT FK_WorkflowStateDefinition_Workflow FOREIGN KEY (WorkflowDefinitionId) REFERENCES ref.WorkflowDefinition(WorkflowDefinitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_WorkflowStateDefinition')
    CREATE UNIQUE INDEX UQ_ref_WorkflowStateDefinition ON ref.WorkflowStateDefinition(WorkflowDefinitionId, StateCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.WorkflowTransitionDefinition', N'U') IS NULL
CREATE TABLE ref.WorkflowTransitionDefinition
(
    WorkflowTransitionDefinitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    WorkflowDefinitionId UNIQUEIDENTIFIER NOT NULL,
    FromStateId      UNIQUEIDENTIFIER NOT NULL,
    ToStateId        UNIQUEIDENTIFIER NOT NULL,
    TransitionCode   nvarchar(100)    NOT NULL,
    RequiresApproval bit              NOT NULL DEFAULT (0),
    RequiredPermissionKey nvarchar(150) NULL,
    IsActive         bit              NOT NULL DEFAULT (1),
    VersionNumber    int              NOT NULL DEFAULT (1),
    CreatedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId  UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc     datetime2(7)     NULL,
    UpdatedByUserId  UNIQUEIDENTIFIER NULL,
    IsDeleted        bit              NOT NULL DEFAULT (0),
    DeletedAtUtc     datetime2(7)     NULL,
    DeletedByUserId  UNIQUEIDENTIFIER NULL,
    RowVersion       rowversion       NOT NULL,
    CONSTRAINT PK_ref_WorkflowTransitionDefinition PRIMARY KEY CLUSTERED (WorkflowTransitionDefinitionId),
    CONSTRAINT FK_WorkflowTransitionDefinition_Workflow FOREIGN KEY (WorkflowDefinitionId) REFERENCES ref.WorkflowDefinition(WorkflowDefinitionId),
    CONSTRAINT FK_WorkflowTransitionDefinition_From FOREIGN KEY (FromStateId) REFERENCES ref.WorkflowStateDefinition(WorkflowStateDefinitionId),
    CONSTRAINT FK_WorkflowTransitionDefinition_To FOREIGN KEY (ToStateId) REFERENCES ref.WorkflowStateDefinition(WorkflowStateDefinitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_WorkflowTransitionDefinition')
    CREATE UNIQUE INDEX UQ_ref_WorkflowTransitionDefinition ON ref.WorkflowTransitionDefinition(WorkflowDefinitionId, FromStateId, ToStateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.ApprovalMatrix', N'U') IS NULL
CREATE TABLE ref.ApprovalMatrix
(
    ApprovalMatrixId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId         UNIQUEIDENTIFIER NOT NULL,
    MatrixCode       nvarchar(100)    NOT NULL, -- e.g. 'OFFER_APPROVAL_STANDARD'
    MatrixName       nvarchar(200)    NOT NULL,
    EntityType       nvarchar(100)    NOT NULL,
    IsActive         bit              NOT NULL DEFAULT (1),
    EffectiveFromUtc datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc   datetime2(7)     NULL,
    VersionNumber    int              NOT NULL DEFAULT (1),
    ApprovalStatus   nvarchar(20)     NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId  UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc     datetime2(7)     NULL,
    UpdatedByUserId  UNIQUEIDENTIFIER NULL,
    IsDeleted        bit              NOT NULL DEFAULT (0),
    DeletedAtUtc     datetime2(7)     NULL,
    DeletedByUserId  UNIQUEIDENTIFIER NULL,
    RowVersion       rowversion       NOT NULL,
    CONSTRAINT PK_ref_ApprovalMatrix PRIMARY KEY CLUSTERED (ApprovalMatrixId),
    CONSTRAINT FK_ApprovalMatrix_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_ApprovalMatrix_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_ApprovalMatrix')
    CREATE UNIQUE INDEX UQ_ref_ApprovalMatrix ON ref.ApprovalMatrix(TenantId, MatrixCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.ApprovalMatrixRule', N'U') IS NULL
CREATE TABLE ref.ApprovalMatrixRule
(
    ApprovalMatrixRuleId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    ApprovalMatrixId UNIQUEIDENTIFIER NOT NULL,
    StepOrder        int              NOT NULL,
    ApproverRoleId   UNIQUEIDENTIFIER NULL,
    MinAmountThreshold decimal(19,4)  NULL,
    MaxAmountThreshold decimal(19,4)  NULL,
    CurrencyCode     char(3)          NULL,
    ConditionExpression nvarchar(500) NULL,
    IsMandatory      bit              NOT NULL DEFAULT (1),
    CreatedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId  UNIQUEIDENTIFIER NULL,
    IsDeleted        bit              NOT NULL DEFAULT (0),
    DeletedAtUtc     datetime2(7)     NULL,
    DeletedByUserId  UNIQUEIDENTIFIER NULL,
    RowVersion       rowversion       NOT NULL,
    CONSTRAINT PK_ref_ApprovalMatrixRule PRIMARY KEY CLUSTERED (ApprovalMatrixRuleId),
    CONSTRAINT FK_ApprovalMatrixRule_Matrix FOREIGN KEY (ApprovalMatrixId) REFERENCES ref.ApprovalMatrix(ApprovalMatrixId),
    CONSTRAINT FK_ApprovalMatrixRule_Role FOREIGN KEY (ApproverRoleId) REFERENCES iam.Role(RoleId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_ApprovalMatrixRule')
    CREATE UNIQUE INDEX UQ_ref_ApprovalMatrixRule ON ref.ApprovalMatrixRule(ApprovalMatrixId, StepOrder) WHERE IsDeleted = 0;
GO

PRINT N'03-create-tables.sql PART 3a (ref: workflow/approval definitions) complete.';
GO

/* ---- Simple, tenant-overridable code/lookup tables ------------------------
   All follow: Id, TenantId NULL=global, Code, Name, Description, SortOrder,
   IsActive, audit columns, RowVersion, two filtered unique indexes on Code. */

IF OBJECT_ID(N'ref.InterviewRoundDefinition', N'U') IS NULL
CREATE TABLE ref.InterviewRoundDefinition
(
    InterviewRoundDefinitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- L1, L2, HR, Client, Technical, Managerial, ...
    Name        nvarchar(200)    NOT NULL,
    Description nvarchar(500)    NULL,
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_InterviewRoundDefinition PRIMARY KEY CLUSTERED (InterviewRoundDefinitionId),
    CONSTRAINT FK_InterviewRoundDefinition_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_InterviewRoundDefinition_Global')
    CREATE UNIQUE INDEX UQ_ref_InterviewRoundDefinition_Global ON ref.InterviewRoundDefinition(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_InterviewRoundDefinition_Tenant')
    CREATE UNIQUE INDEX UQ_ref_InterviewRoundDefinition_Tenant ON ref.InterviewRoundDefinition(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.InterviewCompetency', N'U') IS NULL
CREATE TABLE ref.InterviewCompetency
(
    InterviewCompetencyId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    Description nvarchar(500)    NULL,
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_InterviewCompetency PRIMARY KEY CLUSTERED (InterviewCompetencyId),
    CONSTRAINT FK_InterviewCompetency_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_InterviewCompetency_Global')
    CREATE UNIQUE INDEX UQ_ref_InterviewCompetency_Global ON ref.InterviewCompetency(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_InterviewCompetency_Tenant')
    CREATE UNIQUE INDEX UQ_ref_InterviewCompetency_Tenant ON ref.InterviewCompetency(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.InterviewFeedbackTemplate', N'U') IS NULL
CREATE TABLE ref.InterviewFeedbackTemplate
(
    InterviewFeedbackTemplateId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    InterviewRoundDefinitionId UNIQUEIDENTIFIER NULL,
    TemplateSchemaJson nvarchar(max) NOT NULL, -- competency/question structure, validated below
    VersionNumber int            NOT NULL DEFAULT (1),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_InterviewFeedbackTemplate PRIMARY KEY CLUSTERED (InterviewFeedbackTemplateId),
    CONSTRAINT FK_InterviewFeedbackTemplate_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewFeedbackTemplate_Round FOREIGN KEY (InterviewRoundDefinitionId) REFERENCES ref.InterviewRoundDefinition(InterviewRoundDefinitionId),
    CONSTRAINT CK_InterviewFeedbackTemplate_SchemaJson CHECK (ISJSON(TemplateSchemaJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_InterviewFeedbackTemplate_Global')
    CREATE UNIQUE INDEX UQ_ref_InterviewFeedbackTemplate_Global ON ref.InterviewFeedbackTemplate(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_InterviewFeedbackTemplate_Tenant')
    CREATE UNIQUE INDEX UQ_ref_InterviewFeedbackTemplate_Tenant ON ref.InterviewFeedbackTemplate(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.CandidateSource', N'U') IS NULL
CREATE TABLE ref.CandidateSource
(
    CandidateSourceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- Referral, JobBoard, Agency, CareerSite, SocialMedia, ...
    Name        nvarchar(200)    NOT NULL,
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_CandidateSource PRIMARY KEY CLUSTERED (CandidateSourceId),
    CONSTRAINT FK_CandidateSource_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_CandidateSource_Global')
    CREATE UNIQUE INDEX UQ_ref_CandidateSource_Global ON ref.CandidateSource(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_CandidateSource_Tenant')
    CREATE UNIQUE INDEX UQ_ref_CandidateSource_Tenant ON ref.CandidateSource(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.SkillCategory', N'U') IS NULL
CREATE TABLE ref.SkillCategory
(
    SkillCategoryId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_SkillCategory PRIMARY KEY CLUSTERED (SkillCategoryId),
    CONSTRAINT FK_SkillCategory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_SkillCategory_Global')
    CREATE UNIQUE INDEX UQ_ref_SkillCategory_Global ON ref.SkillCategory(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_SkillCategory_Tenant')
    CREATE UNIQUE INDEX UQ_ref_SkillCategory_Tenant ON ref.SkillCategory(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.Skill', N'U') IS NULL
CREATE TABLE ref.Skill
(
    SkillId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    SkillCategoryId UNIQUEIDENTIFIER NULL,
    Code        nvarchar(100)    NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_Skill PRIMARY KEY CLUSTERED (SkillId),
    CONSTRAINT FK_Skill_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Skill_Category FOREIGN KEY (SkillCategoryId) REFERENCES ref.SkillCategory(SkillCategoryId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_Skill_Global')
    CREATE UNIQUE INDEX UQ_ref_Skill_Global ON ref.Skill(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_Skill_Tenant')
    CREATE UNIQUE INDEX UQ_ref_Skill_Tenant ON ref.Skill(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DocumentType', N'U') IS NULL
CREATE TABLE ref.DocumentType
(
    DocumentTypeId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- PAN, Aadhaar-equivalent, Degree, PayslipSample, ...
    Name        nvarchar(200)    NOT NULL,
    Classification nvarchar(30)  NOT NULL DEFAULT ('Confidential'), -- Public, Internal, Confidential, Restricted
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DocumentType PRIMARY KEY CLUSTERED (DocumentTypeId),
    CONSTRAINT FK_DocumentType_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_DocumentType_Classification CHECK (Classification IN ('Public','Internal','Confidential','Restricted'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DocumentType_Global')
    CREATE UNIQUE INDEX UQ_ref_DocumentType_Global ON ref.DocumentType(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DocumentType_Tenant')
    CREATE UNIQUE INDEX UQ_ref_DocumentType_Tenant ON ref.DocumentType(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DocumentChecklist', N'U') IS NULL
CREATE TABLE ref.DocumentChecklist
(
    DocumentChecklistId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NOT NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    ApplicabilityRuleJson nvarchar(max) NULL, -- e.g. employment type / grade condition
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DocumentChecklist PRIMARY KEY CLUSTERED (DocumentChecklistId),
    CONSTRAINT FK_DocumentChecklist_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_DocumentChecklist_RuleJson CHECK (ApplicabilityRuleJson IS NULL OR ISJSON(ApplicabilityRuleJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DocumentChecklist')
    CREATE UNIQUE INDEX UQ_ref_DocumentChecklist ON ref.DocumentChecklist(TenantId, Code) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DocumentChecklistItem', N'U') IS NULL
CREATE TABLE ref.DocumentChecklistItem
(
    DocumentChecklistItemId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    DocumentChecklistId UNIQUEIDENTIFIER NOT NULL,
    DocumentTypeId  UNIQUEIDENTIFIER NOT NULL,
    IsMandatory     bit              NOT NULL DEFAULT (1),
    SortOrder       int              NOT NULL DEFAULT (0),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DocumentChecklistItem PRIMARY KEY CLUSTERED (DocumentChecklistItemId),
    CONSTRAINT FK_DocumentChecklistItem_Checklist FOREIGN KEY (DocumentChecklistId) REFERENCES ref.DocumentChecklist(DocumentChecklistId),
    CONSTRAINT FK_DocumentChecklistItem_DocType FOREIGN KEY (DocumentTypeId) REFERENCES ref.DocumentType(DocumentTypeId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DocumentChecklistItem')
    CREATE UNIQUE INDEX UQ_ref_DocumentChecklistItem ON ref.DocumentChecklistItem(DocumentChecklistId, DocumentTypeId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.VerificationType', N'U') IS NULL
CREATE TABLE ref.VerificationType
(
    VerificationTypeId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- Education, Employment, Identity, Criminal, Address, Reference
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_VerificationType PRIMARY KEY CLUSTERED (VerificationTypeId),
    CONSTRAINT FK_VerificationType_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_VerificationType_Global')
    CREATE UNIQUE INDEX UQ_ref_VerificationType_Global ON ref.VerificationType(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_VerificationType_Tenant')
    CREATE UNIQUE INDEX UQ_ref_VerificationType_Tenant ON ref.VerificationType(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DiscrepancyType', N'U') IS NULL
CREATE TABLE ref.DiscrepancyType
(
    DiscrepancyTypeId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DiscrepancyType PRIMARY KEY CLUSTERED (DiscrepancyTypeId),
    CONSTRAINT FK_DiscrepancyType_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DiscrepancyType_Global')
    CREATE UNIQUE INDEX UQ_ref_DiscrepancyType_Global ON ref.DiscrepancyType(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DiscrepancyType_Tenant')
    CREATE UNIQUE INDEX UQ_ref_DiscrepancyType_Tenant ON ref.DiscrepancyType(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DiscrepancySeverity', N'U') IS NULL
CREATE TABLE ref.DiscrepancySeverity
(
    DiscrepancySeverityId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- Low, Medium, High, Critical
    Name        nvarchar(200)    NOT NULL,
    RankOrder   int              NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DiscrepancySeverity PRIMARY KEY CLUSTERED (DiscrepancySeverityId),
    CONSTRAINT FK_DiscrepancySeverity_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DiscrepancySeverity_Global')
    CREATE UNIQUE INDEX UQ_ref_DiscrepancySeverity_Global ON ref.DiscrepancySeverity(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DiscrepancySeverity_Tenant')
    CREATE UNIQUE INDEX UQ_ref_DiscrepancySeverity_Tenant ON ref.DiscrepancySeverity(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.NotificationChannel', N'U') IS NULL
CREATE TABLE ref.NotificationChannel
(
    NotificationChannelId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    Code        nvarchar(50)     NOT NULL, -- Email, Sms, InApp, Push
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_NotificationChannel PRIMARY KEY CLUSTERED (NotificationChannelId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_NotificationChannel')
    CREATE UNIQUE INDEX UQ_ref_NotificationChannel ON ref.NotificationChannel(Code) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.NotificationTemplate', N'U') IS NULL
CREATE TABLE ref.NotificationTemplate
(
    NotificationTemplateId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(100)    NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    NotificationChannelId UNIQUEIDENTIFIER NOT NULL,
    Locale      nvarchar(10)     NOT NULL DEFAULT ('en-US'),
    SubjectTemplate nvarchar(500) NULL,
    BodyTemplate    nvarchar(max) NOT NULL, -- placeholder-driven, never includes raw PII in the template itself
    VersionNumber int            NOT NULL DEFAULT (1),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_NotificationTemplate PRIMARY KEY CLUSTERED (NotificationTemplateId),
    CONSTRAINT FK_NotificationTemplate_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_NotificationTemplate_Channel FOREIGN KEY (NotificationChannelId) REFERENCES ref.NotificationChannel(NotificationChannelId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_NotificationTemplate_Global')
    CREATE UNIQUE INDEX UQ_ref_NotificationTemplate_Global ON ref.NotificationTemplate(Code, NotificationChannelId, Locale) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_NotificationTemplate_Tenant')
    CREATE UNIQUE INDEX UQ_ref_NotificationTemplate_Tenant ON ref.NotificationTemplate(TenantId, Code, NotificationChannelId, Locale) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.SlaPolicy', N'U') IS NULL
CREATE TABLE ref.SlaPolicy
(
    SlaPolicyId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NOT NULL,
    Code        nvarchar(100)    NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_SlaPolicy PRIMARY KEY CLUSTERED (SlaPolicyId),
    CONSTRAINT FK_SlaPolicy_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_SlaPolicy')
    CREATE UNIQUE INDEX UQ_ref_SlaPolicy ON ref.SlaPolicy(TenantId, Code) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.SlaRule', N'U') IS NULL
CREATE TABLE ref.SlaRule
(
    SlaRuleId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    SlaPolicyId UNIQUEIDENTIFIER NOT NULL,
    EntityType  nvarchar(100)    NOT NULL, -- WorkflowTask, Discrepancy, VerificationCase, ...
    StageCode   nvarchar(100)    NOT NULL,
    DueWithinHours int           NOT NULL,
    EscalationRoleId UNIQUEIDENTIFIER NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_SlaRule PRIMARY KEY CLUSTERED (SlaRuleId),
    CONSTRAINT FK_SlaRule_Policy FOREIGN KEY (SlaPolicyId) REFERENCES ref.SlaPolicy(SlaPolicyId),
    CONSTRAINT FK_SlaRule_EscalationRole FOREIGN KEY (EscalationRoleId) REFERENCES iam.Role(RoleId),
    CONSTRAINT CK_SlaRule_DueWithinHours CHECK (DueWithinHours > 0)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_SlaRule')
    CREATE UNIQUE INDEX UQ_ref_SlaRule ON ref.SlaRule(SlaPolicyId, EntityType, StageCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.RetentionPolicy', N'U') IS NULL
CREATE TABLE ref.RetentionPolicy
(
    RetentionPolicyId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(100)    NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    DataCategory nvarchar(100)   NOT NULL, -- CandidateProfile, Document, InterviewFeedback, AuditEvent, ...
    RetentionPeriodDays int      NOT NULL,
    LegalHoldOverridable bit     NOT NULL DEFAULT (1),
    ActionOnExpiry nvarchar(30)  NOT NULL DEFAULT ('Anonymize'), -- Anonymize, Archive, Purge
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    ApprovalStatus nvarchar(20)  NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_RetentionPolicy PRIMARY KEY CLUSTERED (RetentionPolicyId),
    CONSTRAINT FK_RetentionPolicy_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_RetentionPolicy_Action CHECK (ActionOnExpiry IN ('Anonymize','Archive','Purge')),
    CONSTRAINT CK_RetentionPolicy_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired')),
    CONSTRAINT CK_RetentionPolicy_PeriodDays CHECK (RetentionPeriodDays > 0)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_RetentionPolicy_Global')
    CREATE UNIQUE INDEX UQ_ref_RetentionPolicy_Global ON ref.RetentionPolicy(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_RetentionPolicy_Tenant')
    CREATE UNIQUE INDEX UQ_ref_RetentionPolicy_Tenant ON ref.RetentionPolicy(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.FeatureFlag', N'U') IS NULL
CREATE TABLE ref.FeatureFlag
(
    FeatureFlagId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    Code        nvarchar(100)    NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    Description nvarchar(500)    NULL,
    DefaultEnabled bit           NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_FeatureFlag PRIMARY KEY CLUSTERED (FeatureFlagId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_FeatureFlag')
    CREATE UNIQUE INDEX UQ_ref_FeatureFlag ON ref.FeatureFlag(Code) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.FeatureFlagAssignment', N'U') IS NULL
CREATE TABLE ref.FeatureFlagAssignment
(
    FeatureFlagAssignmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    FeatureFlagId UNIQUEIDENTIFIER NOT NULL,
    TenantId    UNIQUEIDENTIFIER NOT NULL,
    IsEnabled   bit              NOT NULL DEFAULT (0),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_FeatureFlagAssignment PRIMARY KEY CLUSTERED (FeatureFlagAssignmentId),
    CONSTRAINT FK_FeatureFlagAssignment_Flag FOREIGN KEY (FeatureFlagId) REFERENCES ref.FeatureFlag(FeatureFlagId),
    CONSTRAINT FK_FeatureFlagAssignment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_FeatureFlagAssignment')
    CREATE UNIQUE INDEX UQ_ref_FeatureFlagAssignment ON ref.FeatureFlagAssignment(FeatureFlagId, TenantId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.NumberingRule', N'U') IS NULL
CREATE TABLE ref.NumberingRule
(
    NumberingRuleId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NOT NULL,
    EntityType  nvarchar(100)    NOT NULL, -- TAN, EmployeeId, OfferNumber, ...
    Prefix      nvarchar(20)     NULL,
    Suffix      nvarchar(20)     NULL,
    NumberFormat nvarchar(100)   NOT NULL DEFAULT ('{PREFIX}{YYYY}{SEQ:6}{SUFFIX}'),
    PaddingWidth int             NOT NULL DEFAULT (6),
    ResetPolicy nvarchar(20)     NOT NULL DEFAULT ('Never'), -- Never, Yearly, Monthly
    CurrentSequence bigint       NOT NULL DEFAULT (0),
    LastResetAtUtc datetime2(7)  NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_NumberingRule PRIMARY KEY CLUSTERED (NumberingRuleId),
    CONSTRAINT FK_NumberingRule_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_NumberingRule_ResetPolicy CHECK (ResetPolicy IN ('Never','Yearly','Monthly'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_NumberingRule')
    CREATE UNIQUE INDEX UQ_ref_NumberingRule ON ref.NumberingRule(TenantId, EntityType) WHERE IsDeleted = 0;
GO
-- NOTE: CurrentSequence is only ever advanced inside employee.usp_GenerateEmployeeId /
-- the equivalent TAN/offer-number procedures, under UPDLOCK/HOLDLOCK — never read-then-
-- write from application code. See docs/stored-procedure-catalog.md.

IF OBJECT_ID(N'ref.OfferTemplate', N'U') IS NULL
CREATE TABLE ref.OfferTemplate
(
    OfferTemplateId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NOT NULL,
    Code        nvarchar(100)    NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_OfferTemplate PRIMARY KEY CLUSTERED (OfferTemplateId),
    CONSTRAINT FK_OfferTemplate_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_OfferTemplate')
    CREATE UNIQUE INDEX UQ_ref_OfferTemplate ON ref.OfferTemplate(TenantId, Code) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.OfferTemplateVersion', N'U') IS NULL
CREATE TABLE ref.OfferTemplateVersion
(
    OfferTemplateVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    OfferTemplateId UNIQUEIDENTIFIER NOT NULL,
    VersionNumber int              NOT NULL,
    BodyTemplate  nvarchar(max)    NOT NULL, -- placeholder-driven document template, no embedded compensation values
    ApprovalStatus nvarchar(20)    NOT NULL DEFAULT ('Draft'),
    EffectiveFromUtc datetime2(7)  NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc   datetime2(7)  NULL,
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_OfferTemplateVersion PRIMARY KEY CLUSTERED (OfferTemplateVersionId),
    CONSTRAINT FK_OfferTemplateVersion_Template FOREIGN KEY (OfferTemplateId) REFERENCES ref.OfferTemplate(OfferTemplateId),
    CONSTRAINT CK_OfferTemplateVersion_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_OfferTemplateVersion')
    CREATE UNIQUE INDEX UQ_ref_OfferTemplateVersion ON ref.OfferTemplateVersion(OfferTemplateId, VersionNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.EmploymentType', N'U') IS NULL
CREATE TABLE ref.EmploymentType
(
    EmploymentTypeId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- FullTime, PartTime, Contract, Intern
    Name        nvarchar(200)    NOT NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_EmploymentType PRIMARY KEY CLUSTERED (EmploymentTypeId),
    CONSTRAINT FK_EmploymentType_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_EmploymentType_Global')
    CREATE UNIQUE INDEX UQ_ref_EmploymentType_Global ON ref.EmploymentType(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_EmploymentType_Tenant')
    CREATE UNIQUE INDEX UQ_ref_EmploymentType_Tenant ON ref.EmploymentType(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

/* ---- Status reference tables (CandidateStatus, OfferStatus, DocumentStatus,
   VerificationStatus, DiscrepancyStatus, EmployeeStatus) — same shape, one
   IsTerminal flag to mark closed states for reporting/SLA logic. ---- */

IF OBJECT_ID(N'ref.CandidateStatus', N'U') IS NULL
CREATE TABLE ref.CandidateStatus
(
    CandidateStatusId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsTerminal  bit              NOT NULL DEFAULT (0),
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_CandidateStatus PRIMARY KEY CLUSTERED (CandidateStatusId),
    CONSTRAINT FK_CandidateStatus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_CandidateStatus_Global')
    CREATE UNIQUE INDEX UQ_ref_CandidateStatus_Global ON ref.CandidateStatus(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_CandidateStatus_Tenant')
    CREATE UNIQUE INDEX UQ_ref_CandidateStatus_Tenant ON ref.CandidateStatus(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.OfferStatus', N'U') IS NULL
CREATE TABLE ref.OfferStatus
(
    OfferStatusId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- Draft, PendingApproval, Approved, Sent, Viewed, Accepted, Declined, Expired, Withdrawn
    Name        nvarchar(200)    NOT NULL,
    IsTerminal  bit              NOT NULL DEFAULT (0),
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_OfferStatus PRIMARY KEY CLUSTERED (OfferStatusId),
    CONSTRAINT FK_OfferStatus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_OfferStatus_Global')
    CREATE UNIQUE INDEX UQ_ref_OfferStatus_Global ON ref.OfferStatus(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_OfferStatus_Tenant')
    CREATE UNIQUE INDEX UQ_ref_OfferStatus_Tenant ON ref.OfferStatus(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DocumentStatus', N'U') IS NULL
CREATE TABLE ref.DocumentStatus
(
    DocumentStatusId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsTerminal  bit              NOT NULL DEFAULT (0),
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DocumentStatus PRIMARY KEY CLUSTERED (DocumentStatusId),
    CONSTRAINT FK_DocumentStatus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DocumentStatus_Global')
    CREATE UNIQUE INDEX UQ_ref_DocumentStatus_Global ON ref.DocumentStatus(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DocumentStatus_Tenant')
    CREATE UNIQUE INDEX UQ_ref_DocumentStatus_Tenant ON ref.DocumentStatus(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.VerificationStatus', N'U') IS NULL
CREATE TABLE ref.VerificationStatus
(
    VerificationStatusId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsTerminal  bit              NOT NULL DEFAULT (0),
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_VerificationStatus PRIMARY KEY CLUSTERED (VerificationStatusId),
    CONSTRAINT FK_VerificationStatus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_VerificationStatus_Global')
    CREATE UNIQUE INDEX UQ_ref_VerificationStatus_Global ON ref.VerificationStatus(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_VerificationStatus_Tenant')
    CREATE UNIQUE INDEX UQ_ref_VerificationStatus_Tenant ON ref.VerificationStatus(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.DiscrepancyStatus', N'U') IS NULL
CREATE TABLE ref.DiscrepancyStatus
(
    DiscrepancyStatusId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL,
    Name        nvarchar(200)    NOT NULL,
    IsTerminal  bit              NOT NULL DEFAULT (0),
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_DiscrepancyStatus PRIMARY KEY CLUSTERED (DiscrepancyStatusId),
    CONSTRAINT FK_DiscrepancyStatus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DiscrepancyStatus_Global')
    CREATE UNIQUE INDEX UQ_ref_DiscrepancyStatus_Global ON ref.DiscrepancyStatus(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_DiscrepancyStatus_Tenant')
    CREATE UNIQUE INDEX UQ_ref_DiscrepancyStatus_Tenant ON ref.DiscrepancyStatus(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.EmployeeStatus', N'U') IS NULL
CREATE TABLE ref.EmployeeStatus
(
    EmployeeStatusId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(50)     NOT NULL, -- Active, OnLeave, Suspended, Terminated, ...
    Name        nvarchar(200)    NOT NULL,
    IsTerminal  bit              NOT NULL DEFAULT (0),
    SortOrder   int              NOT NULL DEFAULT (0),
    IsActive    bit              NOT NULL DEFAULT (1),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_EmployeeStatus PRIMARY KEY CLUSTERED (EmployeeStatusId),
    CONSTRAINT FK_EmployeeStatus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_EmployeeStatus_Global')
    CREATE UNIQUE INDEX UQ_ref_EmployeeStatus_Global ON ref.EmployeeStatus(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_EmployeeStatus_Tenant')
    CREATE UNIQUE INDEX UQ_ref_EmployeeStatus_Tenant ON ref.EmployeeStatus(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.AiModelConfiguration', N'U') IS NULL
CREATE TABLE ref.AiModelConfiguration
(
    AiModelConfigurationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(100)    NOT NULL,
    Purpose     nvarchar(100)    NOT NULL, -- CvExtraction, Matching, DiscrepancyDrafting, ...
    ProviderName nvarchar(50)    NOT NULL, -- anthropic, azure_openai, openai, other — never a literal API key here
    ModelIdentifier nvarchar(100) NOT NULL,
    ConfidenceThreshold decimal(5,4) NOT NULL DEFAULT (0.7000),
    ParametersJson nvarchar(max)  NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    ApprovalStatus nvarchar(20)  NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_AiModelConfiguration PRIMARY KEY CLUSTERED (AiModelConfigurationId),
    CONSTRAINT FK_AiModelConfiguration_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_AiModelConfiguration_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired')),
    CONSTRAINT CK_AiModelConfiguration_ParametersJson CHECK (ParametersJson IS NULL OR ISJSON(ParametersJson) = 1),
    CONSTRAINT CK_AiModelConfiguration_Threshold CHECK (ConfidenceThreshold BETWEEN 0 AND 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_AiModelConfiguration_Global')
    CREATE UNIQUE INDEX UQ_ref_AiModelConfiguration_Global ON ref.AiModelConfiguration(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_AiModelConfiguration_Tenant')
    CREATE UNIQUE INDEX UQ_ref_AiModelConfiguration_Tenant ON ref.AiModelConfiguration(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.RagConfiguration', N'U') IS NULL
CREATE TABLE ref.RagConfiguration
(
    RagConfigurationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NULL,
    Code        nvarchar(100)    NOT NULL,
    EmbeddingModelIdentifier nvarchar(100) NOT NULL,
    VectorStoreProvider nvarchar(50) NOT NULL, -- pgvector, azure_ai_search, qdrant, pinecone, weaviate
    ChunkSizeTokens int          NOT NULL DEFAULT (512),
    ChunkOverlapTokens int       NOT NULL DEFAULT (64),
    TopK        int              NOT NULL DEFAULT (5),
    MinRelevanceScore decimal(5,4) NOT NULL DEFAULT (0.5000),
    ParametersJson nvarchar(max) NULL,
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    ApprovalStatus nvarchar(20)  NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_RagConfiguration PRIMARY KEY CLUSTERED (RagConfigurationId),
    CONSTRAINT FK_RagConfiguration_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_RagConfiguration_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired')),
    CONSTRAINT CK_RagConfiguration_ParametersJson CHECK (ParametersJson IS NULL OR ISJSON(ParametersJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_RagConfiguration_Global')
    CREATE UNIQUE INDEX UQ_ref_RagConfiguration_Global ON ref.RagConfiguration(Code) WHERE TenantId IS NULL AND IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_RagConfiguration_Tenant')
    CREATE UNIQUE INDEX UQ_ref_RagConfiguration_Tenant ON ref.RagConfiguration(TenantId, Code) WHERE TenantId IS NOT NULL AND IsDeleted = 0;
GO

IF OBJECT_ID(N'ref.IntegrationConfiguration', N'U') IS NULL
CREATE TABLE ref.IntegrationConfiguration
(
    IntegrationConfigurationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId    UNIQUEIDENTIFIER NOT NULL,
    Code        nvarchar(100)    NOT NULL, -- HRMS, Payroll, ITProvisioning, ESignature, BackgroundVerification, ...
    ProviderName nvarchar(100)   NOT NULL,
    EndpointUrl nvarchar(500)    NULL,       -- never an embedded API key/secret — see integration.ExternalSystem
    SecretVaultKeyRef nvarchar(200) NULL,    -- kv://... reference only, never a literal secret
    IsActive    bit              NOT NULL DEFAULT (1),
    VersionNumber int            NOT NULL DEFAULT (1),
    ApprovalStatus nvarchar(20)  NOT NULL DEFAULT ('Approved'),
    CreatedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(), CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc datetime2(7)    NULL, UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted   bit              NOT NULL DEFAULT (0), DeletedAtUtc datetime2(7) NULL, DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion  rowversion       NOT NULL,
    CONSTRAINT PK_ref_IntegrationConfiguration PRIMARY KEY CLUSTERED (IntegrationConfigurationId),
    CONSTRAINT FK_IntegrationConfiguration_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_IntegrationConfiguration_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired')),
    CONSTRAINT CK_IntegrationConfiguration_NoLiteralSecret CHECK (SecretVaultKeyRef IS NULL OR SecretVaultKeyRef LIKE 'kv://%')
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ref_IntegrationConfiguration')
    CREATE UNIQUE INDEX UQ_ref_IntegrationConfiguration ON ref.IntegrationConfiguration(TenantId, Code) WHERE IsDeleted = 0;
GO

PRINT N'03-create-tables.sql PART 3 (ref) complete.';
GO

-- ============================================================================
-- PART 4 — recruitment schema, Section A: Master CV Bank and candidate profile
-- A candidate can exist independently of any TAN (sourced/CV-banked before any
-- requisition exists). No FK from recruitment.Candidate to a requisition.
-- ============================================================================

IF OBJECT_ID(N'recruitment.Candidate', N'U') IS NULL
CREATE TABLE recruitment.Candidate
(
    CandidateId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    FirstName       nvarchar(100)    NOT NULL,
    MiddleName      nvarchar(100)    NULL,
    LastName        nvarchar(100)    NOT NULL,
    CandidateStatusId UNIQUEIDENTIFIER NOT NULL,
    PrimaryCandidateSourceId UNIQUEIDENTIFIER NULL,
    HeadlineSummary nvarchar(500)    NULL, -- short professional summary, not full CV text
    TotalExperienceYears decimal(4,1) NULL,
    CurrentLocationId UNIQUEIDENTIFIER NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_Candidate PRIMARY KEY CLUSTERED (CandidateId),
    CONSTRAINT FK_Candidate_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Candidate_Status FOREIGN KEY (CandidateStatusId) REFERENCES ref.CandidateStatus(CandidateStatusId),
    CONSTRAINT FK_Candidate_Source FOREIGN KEY (PrimaryCandidateSourceId) REFERENCES ref.CandidateSource(CandidateSourceId),
    CONSTRAINT FK_Candidate_Location FOREIGN KEY (CurrentLocationId) REFERENCES org.Location(LocationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_Candidate_TenantStatus')
    CREATE INDEX IX_recruitment_Candidate_TenantStatus ON recruitment.Candidate(TenantId, CandidateStatusId) WHERE IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_Candidate_TenantCreated')
    CREATE INDEX IX_recruitment_Candidate_TenantCreated ON recruitment.Candidate(TenantId, CreatedAtUtc);
GO

IF OBJECT_ID(N'recruitment.CandidateContact', N'U') IS NULL
CREATE TABLE recruitment.CandidateContact
(
    CandidateContactId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    ContactType     nvarchar(20)     NOT NULL, -- Email, Phone, LinkedIn, Other
    ContactValue    nvarchar(320)    NOT NULL,
    NormalizedValue nvarchar(320)    NULL, -- populated via dbo.fn_normalize_email/fn_normalize_phone by
                                            -- recruitment.usp_CreateCandidate / usp_UpdateCandidateProfile
                                            -- (not a computed column: normalization function depends on ContactType)
    IsPrimary       bit              NOT NULL DEFAULT (0),
    IsVerified      bit              NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateContact PRIMARY KEY CLUSTERED (CandidateContactId),
    CONSTRAINT FK_CandidateContact_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateContact_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT CK_CandidateContact_Type CHECK (ContactType IN ('Email','Phone','LinkedIn','Other'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateContact_Candidate')
    CREATE INDEX IX_recruitment_CandidateContact_Candidate ON recruitment.CandidateContact(CandidateId) WHERE IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateContact_Normalized')
    CREATE INDEX IX_recruitment_CandidateContact_Normalized ON recruitment.CandidateContact(TenantId, NormalizedValue) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateAddress', N'U') IS NULL
CREATE TABLE recruitment.CandidateAddress
(
    CandidateAddressId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    AddressType     nvarchar(20)     NOT NULL DEFAULT ('Current'), -- Current, Permanent
    AddressLine1    nvarchar(200)    NULL,
    AddressLine2    nvarchar(200)    NULL,
    City            nvarchar(100)    NULL,
    StateProvince   nvarchar(100)    NULL,
    PostalCode      nvarchar(20)     NULL,
    CountryCode     char(2)          NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateAddress PRIMARY KEY CLUSTERED (CandidateAddressId),
    CONSTRAINT FK_CandidateAddress_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateAddress_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT CK_CandidateAddress_Type CHECK (AddressType IN ('Current','Permanent'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateAddress_Candidate')
    CREATE INDEX IX_recruitment_CandidateAddress_Candidate ON recruitment.CandidateAddress(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateConsent', N'U') IS NULL
CREATE TABLE recruitment.CandidateConsent
(
    CandidateConsentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    ConsentType     nvarchar(100)    NOT NULL, -- DataProcessing, CvBankRetention, Communication, BackgroundCheck
    ConsentVersion  nvarchar(20)     NOT NULL,
    GrantedAtUtc    datetime2(7)     NULL,
    WithdrawnAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateConsent PRIMARY KEY CLUSTERED (CandidateConsentId),
    CONSTRAINT FK_CandidateConsent_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateConsent_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateConsent_Candidate')
    CREATE INDEX IX_recruitment_CandidateConsent_Candidate ON recruitment.CandidateConsent(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateSourceMapping', N'U') IS NULL
CREATE TABLE recruitment.CandidateSourceMapping
(
    CandidateSourceMappingId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    CandidateSourceId UNIQUEIDENTIFIER NOT NULL,
    SourceReference nvarchar(200)    NULL, -- e.g. job-board posting id, referrer employee id (as text ref)
    SourcedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateSourceMapping PRIMARY KEY CLUSTERED (CandidateSourceMappingId),
    CONSTRAINT FK_CandidateSourceMapping_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateSourceMapping_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateSourceMapping_Source FOREIGN KEY (CandidateSourceId) REFERENCES ref.CandidateSource(CandidateSourceId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateSkill', N'U') IS NULL
CREATE TABLE recruitment.CandidateSkill
(
    CandidateSkillId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    SkillId         UNIQUEIDENTIFIER NOT NULL,
    ProficiencyLevel nvarchar(30)    NULL, -- Beginner, Intermediate, Advanced, Expert
    YearsExperience decimal(4,1)     NULL,
    IsSelfReported  bit              NOT NULL DEFAULT (1), -- vs. extracted/assessed
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateSkill PRIMARY KEY CLUSTERED (CandidateSkillId),
    CONSTRAINT FK_CandidateSkill_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateSkill_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateSkill_Skill FOREIGN KEY (SkillId) REFERENCES ref.Skill(SkillId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateSkill')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateSkill ON recruitment.CandidateSkill(CandidateId, SkillId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateSkillAssessment', N'U') IS NULL
CREATE TABLE recruitment.CandidateSkillAssessment
(
    CandidateSkillAssessmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateSkillId UNIQUEIDENTIFIER NOT NULL,
    AssessmentSource nvarchar(50)    NOT NULL, -- InterviewFeedback, CvExtraction, ExternalTest
    Score           decimal(5,2)     NULL,
    MaxScore        decimal(5,2)     NULL,
    AssessedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    AssessedByUserId UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateSkillAssessment PRIMARY KEY CLUSTERED (CandidateSkillAssessmentId),
    CONSTRAINT FK_CandidateSkillAssessment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateSkillAssessment_Skill FOREIGN KEY (CandidateSkillId) REFERENCES recruitment.CandidateSkill(CandidateSkillId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateWorkPreference', N'U') IS NULL
CREATE TABLE recruitment.CandidateWorkPreference
(
    CandidateWorkPreferenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    PreferredWorkModeId UNIQUEIDENTIFIER NULL,
    PreferredLocationId UNIQUEIDENTIFIER NULL,
    WillingToRelocate bit            NOT NULL DEFAULT (0),
    NoticePeriodDays int             NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateWorkPreference PRIMARY KEY CLUSTERED (CandidateWorkPreferenceId),
    CONSTRAINT FK_CandidateWorkPreference_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateWorkPreference_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateWorkPreference_WorkMode FOREIGN KEY (PreferredWorkModeId) REFERENCES org.WorkMode(WorkModeId),
    CONSTRAINT FK_CandidateWorkPreference_Location FOREIGN KEY (PreferredLocationId) REFERENCES org.Location(LocationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateWorkPreference')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateWorkPreference ON recruitment.CandidateWorkPreference(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateCompensationExpectation', N'U') IS NULL
CREATE TABLE recruitment.CandidateCompensationExpectation
(
    CandidateCompensationExpectationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    CurrentCompensationAmount decimal(19,4) NULL,
    ExpectedCompensationAmount decimal(19,4) NULL,
    CurrencyCode    char(3)          NULL,
    Notes           nvarchar(500)    NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateCompensationExpectation PRIMARY KEY CLUSTERED (CandidateCompensationExpectationId),
    CONSTRAINT FK_CandidateCompExpectation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateCompExpectation_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO
-- Restricted column set: compensation expectation is access-controlled the same as
-- offer.OfferCompensation — see docs/security-model.md "Compensation data access".
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateCompExpectation')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateCompExpectation ON recruitment.CandidateCompensationExpectation(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateAvailability', N'U') IS NULL
CREATE TABLE recruitment.CandidateAvailability
(
    CandidateAvailabilityId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    EarliestStartDate date           NULL,
    IsImmediatelyAvailable bit       NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateAvailability PRIMARY KEY CLUSTERED (CandidateAvailabilityId),
    CONSTRAINT FK_CandidateAvailability_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateAvailability_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateAvailability')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateAvailability ON recruitment.CandidateAvailability(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateTag', N'U') IS NULL
CREATE TABLE recruitment.CandidateTag
(
    CandidateTagId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    TagName         nvarchar(100)    NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateTag PRIMARY KEY CLUSTERED (CandidateTagId),
    CONSTRAINT FK_CandidateTag_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateTag')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateTag ON recruitment.CandidateTag(TenantId, TagName) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateTagMapping', N'U') IS NULL
CREATE TABLE recruitment.CandidateTagMapping
(
    CandidateTagMappingId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    CandidateTagId  UNIQUEIDENTIFIER NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateTagMapping PRIMARY KEY CLUSTERED (CandidateTagMappingId),
    CONSTRAINT FK_CandidateTagMapping_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateTagMapping_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateTagMapping_Tag FOREIGN KEY (CandidateTagId) REFERENCES recruitment.CandidateTag(CandidateTagId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateTagMapping')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateTagMapping ON recruitment.CandidateTagMapping(CandidateId, CandidateTagId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateCv', N'U') IS NULL
CREATE TABLE recruitment.CandidateCv
(
    CandidateCvId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    IsPrimary       bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateCv PRIMARY KEY CLUSTERED (CandidateCvId),
    CONSTRAINT FK_CandidateCv_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateCv_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateCv_Candidate')
    CREATE INDEX IX_recruitment_CandidateCv_Candidate ON recruitment.CandidateCv(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateCvVersion', N'U') IS NULL
CREATE TABLE recruitment.CandidateCvVersion
(
    CandidateCvVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateCvId   UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ObjectStorageUri nvarchar(1000)  NOT NULL, -- reference only — see conventions: no binary content in this table
    FileName        nvarchar(260)    NOT NULL,
    MimeType        nvarchar(100)    NOT NULL,
    FileSizeBytes   bigint           NOT NULL,
    ContentHash     varbinary(32)    NOT NULL, -- SHA-256 of the stored object, for integrity verification
    MalwareScanStatus nvarchar(20)   NOT NULL DEFAULT ('Pending'), -- Pending, Clean, Infected, Failed
    UploadedByUserId UNIQUEIDENTIFIER NULL,
    UploadedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateCvVersion PRIMARY KEY CLUSTERED (CandidateCvVersionId),
    CONSTRAINT FK_CandidateCvVersion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateCvVersion_Cv FOREIGN KEY (CandidateCvId) REFERENCES recruitment.CandidateCv(CandidateCvId),
    CONSTRAINT CK_CandidateCvVersion_ScanStatus CHECK (MalwareScanStatus IN ('Pending','Clean','Infected','Failed'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateCvVersion')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateCvVersion ON recruitment.CandidateCvVersion(CandidateCvId, VersionNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CvParsingResult', N'U') IS NULL
CREATE TABLE recruitment.CvParsingResult
(
    CvParsingResultId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateCvVersionId UNIQUEIDENTIFIER NOT NULL,
    AiSkillVersionId UNIQUEIDENTIFIER NULL, -- FK added in Phase 5 once ai.AiSkillVersion exists (see 04-create-keys-indexes-constraints.sql)
    ParseStatus     nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Succeeded, Failed, LowConfidence
    ConfidenceScore decimal(5,4)     NULL,
    RawOutputObjectStorageUri nvarchar(1000) NULL, -- structured extraction output reference, never raw CV text inline
    RequiresHumanReview bit          NOT NULL DEFAULT (0),
    ReviewedByUserId UNIQUEIDENTIFIER NULL,
    ReviewedAtUtc   datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CvParsingResult PRIMARY KEY CLUSTERED (CvParsingResultId),
    CONSTRAINT FK_CvParsingResult_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CvParsingResult_CvVersion FOREIGN KEY (CandidateCvVersionId) REFERENCES recruitment.CandidateCvVersion(CandidateCvVersionId),
    CONSTRAINT CK_CvParsingResult_Status CHECK (ParseStatus IN ('Pending','Succeeded','Failed','LowConfidence'))
);
GO

IF OBJECT_ID(N'recruitment.CvExtractionField', N'U') IS NULL
CREATE TABLE recruitment.CvExtractionField
(
    CvExtractionFieldId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CvParsingResultId UNIQUEIDENTIFIER NOT NULL,
    FieldName       nvarchar(100)    NOT NULL, -- e.g. 'TotalExperienceYears','CurrentEmployer'
    FieldValue      nvarchar(1000)   NULL,
    ConfidenceScore decimal(5,4)     NULL,
    IsAcceptedByHuman bit            NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CvExtractionField PRIMARY KEY CLUSTERED (CvExtractionFieldId),
    CONSTRAINT FK_CvExtractionField_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CvExtractionField_ParsingResult FOREIGN KEY (CvParsingResultId) REFERENCES recruitment.CvParsingResult(CvParsingResultId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateDuplicateReview', N'U') IS NULL
CREATE TABLE recruitment.CandidateDuplicateReview
(
    CandidateDuplicateReviewId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    PrimaryCandidateId UNIQUEIDENTIFIER NOT NULL,
    SuspectedDuplicateCandidateId UNIQUEIDENTIFIER NOT NULL,
    MatchConfidenceScore decimal(5,4) NULL,
    MatchReason     nvarchar(500)    NULL,
    ReviewStatus    nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, ConfirmedDuplicate, NotDuplicate
    ReviewedByUserId UNIQUEIDENTIFIER NULL,
    ReviewedAtUtc   datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateDuplicateReview PRIMARY KEY CLUSTERED (CandidateDuplicateReviewId),
    CONSTRAINT FK_CandidateDupReview_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateDupReview_Primary FOREIGN KEY (PrimaryCandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateDupReview_Suspect FOREIGN KEY (SuspectedDuplicateCandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT CK_CandidateDupReview_Status CHECK (ReviewStatus IN ('Pending','ConfirmedDuplicate','NotDuplicate')),
    CONSTRAINT CK_CandidateDupReview_NotSelf CHECK (PrimaryCandidateId <> SuspectedDuplicateCandidateId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateMergeHistory', N'U') IS NULL
CREATE TABLE recruitment.CandidateMergeHistory
(
    CandidateMergeHistoryId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateDuplicateReviewId UNIQUEIDENTIFIER NOT NULL,
    SurvivingCandidateId UNIQUEIDENTIFIER NOT NULL,
    MergedCandidateId UNIQUEIDENTIFIER NOT NULL, -- soft-deleted after merge; history retained per non-negotiable "do not delete candidate history"
    MergedByUserId  UNIQUEIDENTIFIER NULL,
    MergedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_recruitment_CandidateMergeHistory PRIMARY KEY CLUSTERED (CandidateMergeHistoryId),
    CONSTRAINT FK_CandidateMergeHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateMergeHistory_Review FOREIGN KEY (CandidateDuplicateReviewId) REFERENCES recruitment.CandidateDuplicateReview(CandidateDuplicateReviewId),
    CONSTRAINT FK_CandidateMergeHistory_Surviving FOREIGN KEY (SurvivingCandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateMergeHistory_Merged FOREIGN KEY (MergedCandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateStatusHistory', N'U') IS NULL
CREATE TABLE recruitment.CandidateStatusHistory
(
    CandidateStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    FromCandidateStatusId UNIQUEIDENTIFIER NULL,
    ToCandidateStatusId UNIQUEIDENTIFIER NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason          nvarchar(500)    NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_recruitment_CandidateStatusHistory PRIMARY KEY CLUSTERED (CandidateStatusHistoryId),
    CONSTRAINT FK_CandidateStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateStatusHistory_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateStatusHistory_From FOREIGN KEY (FromCandidateStatusId) REFERENCES ref.CandidateStatus(CandidateStatusId),
    CONSTRAINT FK_CandidateStatusHistory_To FOREIGN KEY (ToCandidateStatusId) REFERENCES ref.CandidateStatus(CandidateStatusId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateStatusHistory_Candidate')
    CREATE INDEX IX_recruitment_CandidateStatusHistory_Candidate ON recruitment.CandidateStatusHistory(CandidateId, ChangedAtUtc);
GO

PRINT N'03-create-tables.sql PART 4 (recruitment: CV Bank / candidate profile) complete.';
GO

-- ============================================================================
-- PART 5 — recruitment schema, Section B: TAN / job requisition
-- ============================================================================

IF OBJECT_ID(N'recruitment.TalentAcquisitionNumber', N'U') IS NULL
CREATE TABLE recruitment.TalentAcquisitionNumber
(
    TalentAcquisitionNumberId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    TanNumber       nvarchar(50)     NOT NULL, -- generated via ref.NumberingRule + employee.fn_preview_employee_id-style proc for TAN
    NumberingRuleId UNIQUEIDENTIFIER NULL,
    DepartmentId    UNIQUEIDENTIFIER NULL,
    BusinessUnitId  UNIQUEIDENTIFIER NULL,
    RequestedByUserId UNIQUEIDENTIFIER NULL,
    IssuedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_TalentAcquisitionNumber PRIMARY KEY CLUSTERED (TalentAcquisitionNumberId),
    CONSTRAINT FK_Tan_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Tan_Department FOREIGN KEY (DepartmentId) REFERENCES org.Department(DepartmentId),
    CONSTRAINT FK_Tan_BusinessUnit FOREIGN KEY (BusinessUnitId) REFERENCES org.BusinessUnit(BusinessUnitId),
    CONSTRAINT FK_Tan_NumberingRule FOREIGN KEY (NumberingRuleId) REFERENCES ref.NumberingRule(NumberingRuleId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_Tan_Number')
    CREATE UNIQUE INDEX UQ_recruitment_Tan_Number ON recruitment.TalentAcquisitionNumber(TenantId, TanNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.JobRequisition', N'U') IS NULL
CREATE TABLE recruitment.JobRequisition
(
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    TalentAcquisitionNumberId UNIQUEIDENTIFIER NOT NULL,
    Title           nvarchar(200)    NOT NULL,
    DesignationId   UNIQUEIDENTIFIER NULL,
    JobGradeId      UNIQUEIDENTIFIER NULL,
    EmploymentTypeId UNIQUEIDENTIFIER NULL,
    LocationId      UNIQUEIDENTIFIER NULL,
    WorkModeId      UNIQUEIDENTIFIER NULL,
    ClientId        UNIQUEIDENTIFIER NULL,
    HeadcountRequested int           NOT NULL DEFAULT (1),
    RequisitionStatusCode nvarchar(30) NOT NULL DEFAULT ('Draft'),
        -- Draft, PendingApproval, Approved, ActiveSourcing, OnHold, ClosedFilled, Cancelled
    Priority        nvarchar(20)     NOT NULL DEFAULT ('Normal'),
    TargetFillDate  date             NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobRequisition PRIMARY KEY CLUSTERED (JobRequisitionId),
    CONSTRAINT FK_JobRequisition_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobRequisition_Tan FOREIGN KEY (TalentAcquisitionNumberId) REFERENCES recruitment.TalentAcquisitionNumber(TalentAcquisitionNumberId),
    CONSTRAINT FK_JobRequisition_Designation FOREIGN KEY (DesignationId) REFERENCES org.Designation(DesignationId),
    CONSTRAINT FK_JobRequisition_Grade FOREIGN KEY (JobGradeId) REFERENCES org.JobGrade(JobGradeId),
    CONSTRAINT FK_JobRequisition_EmploymentType FOREIGN KEY (EmploymentTypeId) REFERENCES ref.EmploymentType(EmploymentTypeId),
    CONSTRAINT FK_JobRequisition_Location FOREIGN KEY (LocationId) REFERENCES org.Location(LocationId),
    CONSTRAINT FK_JobRequisition_WorkMode FOREIGN KEY (WorkModeId) REFERENCES org.WorkMode(WorkModeId),
    CONSTRAINT FK_JobRequisition_Client FOREIGN KEY (ClientId) REFERENCES org.Client(ClientId),
    CONSTRAINT CK_JobRequisition_Status CHECK (RequisitionStatusCode IN ('Draft','PendingApproval','Approved','ActiveSourcing','OnHold','ClosedFilled','Cancelled')),
    CONSTRAINT CK_JobRequisition_Priority CHECK (Priority IN ('Low','Normal','High','Urgent')),
    CONSTRAINT CK_JobRequisition_Headcount CHECK (HeadcountRequested > 0)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_JobRequisition_TenantStatus')
    CREATE INDEX IX_recruitment_JobRequisition_TenantStatus ON recruitment.JobRequisition(TenantId, RequisitionStatusCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.JobDescription', N'U') IS NULL
CREATE TABLE recruitment.JobDescription
(
    JobDescriptionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    CurrentVersionId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql (circular with JobDescriptionVersion)
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobDescription PRIMARY KEY CLUSTERED (JobDescriptionId),
    CONSTRAINT FK_JobDescription_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobDescription_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_JobDescription_Requisition')
    CREATE UNIQUE INDEX UQ_recruitment_JobDescription_Requisition ON recruitment.JobDescription(JobRequisitionId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.JobDescriptionVersion', N'U') IS NULL
CREATE TABLE recruitment.JobDescriptionVersion
(
    JobDescriptionVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobDescriptionId UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    Summary         nvarchar(2000)   NULL,
    ResponsibilitiesText nvarchar(max) NULL,
    ApprovalStatus  nvarchar(20)     NOT NULL DEFAULT ('Draft'),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobDescriptionVersion PRIMARY KEY CLUSTERED (JobDescriptionVersionId),
    CONSTRAINT FK_JobDescriptionVersion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobDescriptionVersion_Jd FOREIGN KEY (JobDescriptionId) REFERENCES recruitment.JobDescription(JobDescriptionId),
    CONSTRAINT CK_JobDescriptionVersion_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_JobDescriptionVersion')
    CREATE UNIQUE INDEX UQ_recruitment_JobDescriptionVersion ON recruitment.JobDescriptionVersion(JobDescriptionId, VersionNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.JobRequirement', N'U') IS NULL
CREATE TABLE recruitment.JobRequirement
(
    JobRequirementId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    RequirementText nvarchar(1000)   NOT NULL,
    MinExperienceYears decimal(4,1)  NULL,
    MinEducationLevel nvarchar(100)  NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobRequirement PRIMARY KEY CLUSTERED (JobRequirementId),
    CONSTRAINT FK_JobRequirement_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobRequirement_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId)
);
GO

IF OBJECT_ID(N'recruitment.JobRequirementSkill', N'U') IS NULL
CREATE TABLE recruitment.JobRequirementSkill
(
    JobRequirementSkillId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    SkillId         UNIQUEIDENTIFIER NOT NULL,
    IsMandatory     bit              NOT NULL DEFAULT (1), -- mandatory vs. preferred, per spec section 6B
    MinYearsExperience decimal(4,1)  NULL,
    Weight          decimal(5,4)     NOT NULL DEFAULT (1.0000), -- scoring weight, configuration-driven default in ref.AiModelConfiguration params
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobRequirementSkill PRIMARY KEY CLUSTERED (JobRequirementSkillId),
    CONSTRAINT FK_JobRequirementSkill_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobRequirementSkill_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId),
    CONSTRAINT FK_JobRequirementSkill_Skill FOREIGN KEY (SkillId) REFERENCES ref.Skill(SkillId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_JobRequirementSkill')
    CREATE UNIQUE INDEX UQ_recruitment_JobRequirementSkill ON recruitment.JobRequirementSkill(JobRequisitionId, SkillId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.JobRequisitionHiringManager', N'U') IS NULL
CREATE TABLE recruitment.JobRequisitionHiringManager
(
    JobRequisitionHiringManagerId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    IsPrimary       bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobRequisitionHiringManager PRIMARY KEY CLUSTERED (JobRequisitionHiringManagerId),
    CONSTRAINT FK_JobReqHiringManager_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobReqHiringManager_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId),
    CONSTRAINT FK_JobReqHiringManager_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_JobReqHiringManager')
    CREATE UNIQUE INDEX UQ_recruitment_JobReqHiringManager ON recruitment.JobRequisitionHiringManager(JobRequisitionId, UserId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.JobRequisitionApprover', N'U') IS NULL
CREATE TABLE recruitment.JobRequisitionApprover
(
    JobRequisitionApproverId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql once workflow.ApprovalRequest exists
    UserId          UNIQUEIDENTIFIER NOT NULL,
    StepOrder       int              NOT NULL,
    DecisionStatus  nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Approved, Rejected, Delegated
    DecidedAtUtc    datetime2(7)     NULL,
    Comments        nvarchar(1000)   NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobRequisitionApprover PRIMARY KEY CLUSTERED (JobRequisitionApproverId),
    CONSTRAINT FK_JobReqApprover_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobReqApprover_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId),
    CONSTRAINT FK_JobReqApprover_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_JobReqApprover_Status CHECK (DecisionStatus IN ('Pending','Approved','Rejected','Delegated'))
);
GO

IF OBJECT_ID(N'recruitment.JobRequisitionStatusHistory', N'U') IS NULL
CREATE TABLE recruitment.JobRequisitionStatusHistory
(
    JobRequisitionStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    FromStatusCode  nvarchar(30)     NULL,
    ToStatusCode    nvarchar(30)     NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason          nvarchar(500)    NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_recruitment_JobRequisitionStatusHistory PRIMARY KEY CLUSTERED (JobRequisitionStatusHistoryId),
    CONSTRAINT FK_JobReqStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobReqStatusHistory_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_JobReqStatusHistory_Requisition')
    CREATE INDEX IX_recruitment_JobReqStatusHistory_Requisition ON recruitment.JobRequisitionStatusHistory(JobRequisitionId, ChangedAtUtc);
GO

IF OBJECT_ID(N'recruitment.JobOpening', N'U') IS NULL
CREATE TABLE recruitment.JobOpening
(
    JobOpeningId    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    OpeningSequenceNumber int        NOT NULL, -- 1..HeadcountRequested
    IsFilled        bit              NOT NULL DEFAULT (0),
    FilledByCandidateId UNIQUEIDENTIFIER NULL,
    FilledAtUtc     datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_JobOpening PRIMARY KEY CLUSTERED (JobOpeningId),
    CONSTRAINT FK_JobOpening_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_JobOpening_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId),
    CONSTRAINT FK_JobOpening_Candidate FOREIGN KEY (FilledByCandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_JobOpening')
    CREATE UNIQUE INDEX UQ_recruitment_JobOpening ON recruitment.JobOpening(JobRequisitionId, OpeningSequenceNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.RequisitionAttachment', N'U') IS NULL
CREATE TABLE recruitment.RequisitionAttachment
(
    RequisitionAttachmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    ObjectStorageUri nvarchar(1000)  NOT NULL,
    FileName        nvarchar(260)    NOT NULL,
    MimeType        nvarchar(100)    NOT NULL,
    FileSizeBytes   bigint           NOT NULL,
    ContentHash     varbinary(32)    NOT NULL,
    UploadedByUserId UNIQUEIDENTIFIER NULL,
    UploadedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_RequisitionAttachment PRIMARY KEY CLUSTERED (RequisitionAttachmentId),
    CONSTRAINT FK_RequisitionAttachment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RequisitionAttachment_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId)
);
GO

PRINT N'03-create-tables.sql PART 5 (recruitment: TAN / job requisition) complete.';
GO

-- ============================================================================
-- PART 6 — recruitment schema, Section C: candidate application and AI match
-- A candidate may apply to multiple TANs — no unique constraint on CandidateId
-- alone; uniqueness is CandidateId + JobRequisitionId (one active application
-- per candidate per requisition, re-application after rejection subject to
-- policy is a new row after the prior one is terminal).
-- ============================================================================

IF OBJECT_ID(N'recruitment.CandidateApplication', N'U') IS NULL
CREATE TABLE recruitment.CandidateApplication
(
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    ApplicationStatusCode nvarchar(30) NOT NULL DEFAULT ('Applied'),
    AppliedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    WorkflowInstanceId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql once workflow.WorkflowInstance exists
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateApplication PRIMARY KEY CLUSTERED (CandidateApplicationId),
    CONSTRAINT FK_CandidateApplication_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateApplication_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandidateApplication_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId)
);
GO
-- Deliberately NOT a hard unique constraint on (CandidateId, JobRequisitionId) —
-- a candidate may have a new application after a prior one for the same
-- requisition reached a terminal state (Rejected/Withdrawn); one *active*
-- (non-terminal) application per candidate+requisition is enforced by
-- recruitment.usp_CreateCandidateApplication, not by the schema, since
-- "terminal" is configuration-driven via ref.CandidateStatus.IsTerminal.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateApplication_Candidate')
    CREATE INDEX IX_recruitment_CandidateApplication_Candidate ON recruitment.CandidateApplication(CandidateId) WHERE IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateApplication_Requisition')
    CREATE INDEX IX_recruitment_CandidateApplication_Requisition ON recruitment.CandidateApplication(JobRequisitionId, ApplicationStatusCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateApplicationStatusHistory', N'U') IS NULL
CREATE TABLE recruitment.CandidateApplicationStatusHistory
(
    CandidateApplicationStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    FromStatusCode  nvarchar(30)     NULL,
    ToStatusCode    nvarchar(30)     NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason          nvarchar(500)    NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_recruitment_CandidateApplicationStatusHistory PRIMARY KEY CLUSTERED (CandidateApplicationStatusHistoryId),
    CONSTRAINT FK_CandAppStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandAppStatusHistory_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandAppStatusHistory_Application')
    CREATE INDEX IX_recruitment_CandAppStatusHistory_Application ON recruitment.CandidateApplicationStatusHistory(CandidateApplicationId, ChangedAtUtc);
GO

IF OBJECT_ID(N'recruitment.CandidateShortlist', N'U') IS NULL
CREATE TABLE recruitment.CandidateShortlist
(
    CandidateShortlistId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    ShortlistedByUserId UNIQUEIDENTIFIER NULL, -- human who shortlisted; AI never sets this alone
    ShortlistedAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(),
    IsAiRecommended bit              NOT NULL DEFAULT (0), -- AI recommendation surfaced but never auto-shortlisted
    CandidateMatchRunId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateShortlist PRIMARY KEY CLUSTERED (CandidateShortlistId),
    CONSTRAINT FK_CandidateShortlist_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateShortlist_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateShortlist')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateShortlist ON recruitment.CandidateShortlist(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.CandidateShortlistApproval', N'U') IS NULL
CREATE TABLE recruitment.CandidateShortlistApproval
(
    CandidateShortlistApprovalId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateShortlistId UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql
    ApproverUserId  UNIQUEIDENTIFIER NOT NULL,
    DecisionStatus  nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Approved, Rejected
    DecidedAtUtc    datetime2(7)     NULL,
    Comments        nvarchar(1000)   NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateShortlistApproval PRIMARY KEY CLUSTERED (CandidateShortlistApprovalId),
    CONSTRAINT FK_CandShortlistApproval_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandShortlistApproval_Shortlist FOREIGN KEY (CandidateShortlistId) REFERENCES recruitment.CandidateShortlist(CandidateShortlistId),
    CONSTRAINT FK_CandShortlistApproval_Approver FOREIGN KEY (ApproverUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_CandShortlistApproval_Status CHECK (DecisionStatus IN ('Pending','Approved','Rejected'))
);
GO

IF OBJECT_ID(N'recruitment.CandidateMatchRun', N'U') IS NULL
CREATE TABLE recruitment.CandidateMatchRun
(
    CandidateMatchRunId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    JobRequisitionId UNIQUEIDENTIFIER NOT NULL,
    AiModelConfigurationId UNIQUEIDENTIFIER NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql once ai.AiAgentRun exists
    RunStatus       nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Succeeded, Failed
    RequestedByUserId UNIQUEIDENTIFIER NULL,
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateMatchRun PRIMARY KEY CLUSTERED (CandidateMatchRunId),
    CONSTRAINT FK_CandidateMatchRun_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateMatchRun_Requisition FOREIGN KEY (JobRequisitionId) REFERENCES recruitment.JobRequisition(JobRequisitionId),
    CONSTRAINT FK_CandidateMatchRun_AiModel FOREIGN KEY (AiModelConfigurationId) REFERENCES ref.AiModelConfiguration(AiModelConfigurationId),
    CONSTRAINT CK_CandidateMatchRun_Status CHECK (RunStatus IN ('Pending','Succeeded','Failed'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_CandidateMatchRun_Requisition')
    CREATE INDEX IX_recruitment_CandidateMatchRun_Requisition ON recruitment.CandidateMatchRun(JobRequisitionId, RequestedAtUtc);
GO

IF OBJECT_ID(N'recruitment.CandidateMatchScore', N'U') IS NULL
CREATE TABLE recruitment.CandidateMatchScore
(
    CandidateMatchScoreId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateMatchRunId UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    OverallScore    decimal(5,4)     NOT NULL, -- 0..1, explainable job-related evidence only — never protected attributes
    ConfidenceScore decimal(5,4)     NOT NULL,
    Rank            int              NULL,
    RequiresHumanReview bit          NOT NULL DEFAULT (0), -- true when below ref.AiModelConfiguration.ConfidenceThreshold
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateMatchScore PRIMARY KEY CLUSTERED (CandidateMatchScoreId),
    CONSTRAINT FK_CandidateMatchScore_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateMatchScore_Run FOREIGN KEY (CandidateMatchRunId) REFERENCES recruitment.CandidateMatchRun(CandidateMatchRunId),
    CONSTRAINT FK_CandidateMatchScore_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT CK_CandidateMatchScore_Overall CHECK (OverallScore BETWEEN 0 AND 1),
    CONSTRAINT CK_CandidateMatchScore_Confidence CHECK (ConfidenceScore BETWEEN 0 AND 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateMatchScore')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateMatchScore ON recruitment.CandidateMatchScore(CandidateMatchRunId, CandidateId);
GO

IF OBJECT_ID(N'recruitment.CandidateMatchExplanation', N'U') IS NULL
CREATE TABLE recruitment.CandidateMatchExplanation
(
    CandidateMatchExplanationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateMatchScoreId UNIQUEIDENTIFIER NOT NULL,
    FactorName      nvarchar(150)    NOT NULL, -- e.g. 'RequiredSkillCoverage','ExperienceYearsMatch'
    FactorWeight    decimal(5,4)     NOT NULL,
    FactorScore     decimal(5,4)     NOT NULL,
    ExplanationText nvarchar(1000)   NOT NULL, -- human-readable, job-related rationale only
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_CandidateMatchExplanation PRIMARY KEY CLUSTERED (CandidateMatchExplanationId),
    CONSTRAINT FK_CandidateMatchExplanation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateMatchExplanation_Score FOREIGN KEY (CandidateMatchScoreId) REFERENCES recruitment.CandidateMatchScore(CandidateMatchScoreId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateMatchEvidence', N'U') IS NULL
CREATE TABLE recruitment.CandidateMatchEvidence
(
    CandidateMatchEvidenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateMatchExplanationId UNIQUEIDENTIFIER NOT NULL,
    EvidenceSource  nvarchar(100)    NOT NULL, -- CvExtractionField, InterviewFeedback, CandidateSkill, ...
    EvidenceReferenceId UNIQUEIDENTIFIER NULL, -- polymorphic pointer to the source row id; no FK (source table varies)
    EvidenceSnippet nvarchar(500)    NULL, -- short excerpt only, never full CV text
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_CandidateMatchEvidence PRIMARY KEY CLUSTERED (CandidateMatchEvidenceId),
    CONSTRAINT FK_CandidateMatchEvidence_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateMatchEvidence_Explanation FOREIGN KEY (CandidateMatchExplanationId) REFERENCES recruitment.CandidateMatchExplanation(CandidateMatchExplanationId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateMatchRisk', N'U') IS NULL
CREATE TABLE recruitment.CandidateMatchRisk
(
    CandidateMatchRiskId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateMatchScoreId UNIQUEIDENTIFIER NOT NULL,
    RiskType        nvarchar(100)    NOT NULL, -- e.g. 'EmploymentGap','SkillGap','LowConfidenceExtraction'
    RiskSeverity    nvarchar(20)     NOT NULL DEFAULT ('Low'),
    Description     nvarchar(500)    NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_CandidateMatchRisk PRIMARY KEY CLUSTERED (CandidateMatchRiskId),
    CONSTRAINT FK_CandidateMatchRisk_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateMatchRisk_Score FOREIGN KEY (CandidateMatchScoreId) REFERENCES recruitment.CandidateMatchScore(CandidateMatchScoreId),
    CONSTRAINT CK_CandidateMatchRisk_Severity CHECK (RiskSeverity IN ('Low','Medium','High','Critical'))
);
GO

IF OBJECT_ID(N'recruitment.CandidateRejection', N'U') IS NULL
CREATE TABLE recruitment.CandidateRejection
(
    CandidateRejectionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    RejectionReasonCode nvarchar(50) NOT NULL,
    RejectionNotes  nvarchar(1000)   NULL,
    DecidedByUserId UNIQUEIDENTIFIER NOT NULL, -- always a human — AI never sets this row, per non-negotiable rules
    ApprovalRequestId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql; required when policy mandates approval
    DecidedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateRejection PRIMARY KEY CLUSTERED (CandidateRejectionId),
    CONSTRAINT FK_CandidateRejection_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateRejection_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_CandidateRejection_DecidedBy FOREIGN KEY (DecidedByUserId) REFERENCES iam.[User](UserId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandidateRejection')
    CREATE UNIQUE INDEX UQ_recruitment_CandidateRejection ON recruitment.CandidateRejection(CandidateApplicationId);
GO

IF OBJECT_ID(N'recruitment.CandidateHoldReason', N'U') IS NULL
CREATE TABLE recruitment.CandidateHoldReason
(
    CandidateHoldReasonId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    HoldReasonCode  nvarchar(50)     NOT NULL,
    HoldNotes       nvarchar(1000)   NULL,
    PlacedByUserId  UNIQUEIDENTIFIER NULL,
    PlacedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ReleasedAtUtc   datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateHoldReason PRIMARY KEY CLUSTERED (CandidateHoldReasonId),
    CONSTRAINT FK_CandidateHoldReason_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateHoldReason_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId)
);
GO

IF OBJECT_ID(N'recruitment.CandidateCommunicationPreference', N'U') IS NULL
CREATE TABLE recruitment.CandidateCommunicationPreference
(
    CandidateCommunicationPreferenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    NotificationChannelId UNIQUEIDENTIFIER NOT NULL,
    IsOptedIn       bit              NOT NULL DEFAULT (1),
    PreferredLocale nvarchar(10)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_CandidateCommunicationPreference PRIMARY KEY CLUSTERED (CandidateCommunicationPreferenceId),
    CONSTRAINT FK_CandCommPreference_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandCommPreference_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_CandCommPreference_Channel FOREIGN KEY (NotificationChannelId) REFERENCES ref.NotificationChannel(NotificationChannelId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_CandCommPreference')
    CREATE UNIQUE INDEX UQ_recruitment_CandCommPreference ON recruitment.CandidateCommunicationPreference(CandidateId, NotificationChannelId);
GO

PRINT N'03-create-tables.sql PART 6 (recruitment: application / AI match) complete.';
GO

-- ============================================================================
-- PART 7 — workflow schema (generic engine backing every approval-gated
-- transition across recruitment/offer/onboarding/employee). EntityType +
-- EntityId is a polymorphic pointer (no FK — the referenced table varies);
-- the API/Application layer is responsible for validating EntityId against
-- EntityType before writing here.
-- ============================================================================

IF OBJECT_ID(N'workflow.WorkflowInstance', N'U') IS NULL
CREATE TABLE workflow.WorkflowInstance
(
    WorkflowInstanceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowDefinitionId UNIQUEIDENTIFIER NOT NULL,
    EntityType      nvarchar(100)    NOT NULL,
    EntityId        UNIQUEIDENTIFIER NOT NULL,
    CurrentStateId  UNIQUEIDENTIFIER NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Active'), -- Active, Completed, Cancelled
    StartedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_workflow_WorkflowInstance PRIMARY KEY CLUSTERED (WorkflowInstanceId),
    CONSTRAINT FK_WorkflowInstance_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowInstance_Definition FOREIGN KEY (WorkflowDefinitionId) REFERENCES ref.WorkflowDefinition(WorkflowDefinitionId),
    CONSTRAINT FK_WorkflowInstance_State FOREIGN KEY (CurrentStateId) REFERENCES ref.WorkflowStateDefinition(WorkflowStateDefinitionId),
    CONSTRAINT CK_WorkflowInstance_Status CHECK (Status IN ('Active','Completed','Cancelled'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowInstance_Entity')
    CREATE INDEX IX_workflow_WorkflowInstance_Entity ON workflow.WorkflowInstance(EntityType, EntityId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowInstance_TenantStatus')
    CREATE INDEX IX_workflow_WorkflowInstance_TenantStatus ON workflow.WorkflowInstance(TenantId, Status) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'workflow.WorkflowState', N'U') IS NULL
CREATE TABLE workflow.WorkflowState
(
    WorkflowStateId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NOT NULL,
    WorkflowStateDefinitionId UNIQUEIDENTIFIER NOT NULL,
    EnteredAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ExitedAtUtc     datetime2(7)     NULL,
    CONSTRAINT PK_workflow_WorkflowState PRIMARY KEY CLUSTERED (WorkflowStateId),
    CONSTRAINT FK_WorkflowState_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowState_Instance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_WorkflowState_Definition FOREIGN KEY (WorkflowStateDefinitionId) REFERENCES ref.WorkflowStateDefinition(WorkflowStateDefinitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowState_Instance')
    CREATE INDEX IX_workflow_WorkflowState_Instance ON workflow.WorkflowState(WorkflowInstanceId, EnteredAtUtc);
GO

IF OBJECT_ID(N'workflow.WorkflowTransition', N'U') IS NULL
CREATE TABLE workflow.WorkflowTransition
(
    WorkflowTransitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NOT NULL,
    WorkflowTransitionDefinitionId UNIQUEIDENTIFIER NOT NULL,
    FromStateId     UNIQUEIDENTIFIER NOT NULL,
    ToStateId       UNIQUEIDENTIFIER NOT NULL,
    TransitionedByUserId UNIQUEIDENTIFIER NULL, -- NULL only for system/AI-proposed transitions that don't change approval-gated state
    TransitionedAtUtc datetime2(7)   NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason          nvarchar(500)    NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_workflow_WorkflowTransition PRIMARY KEY CLUSTERED (WorkflowTransitionId),
    CONSTRAINT FK_WorkflowTransition_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowTransition_Instance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_WorkflowTransition_Definition FOREIGN KEY (WorkflowTransitionDefinitionId) REFERENCES ref.WorkflowTransitionDefinition(WorkflowTransitionDefinitionId),
    CONSTRAINT FK_WorkflowTransition_From FOREIGN KEY (FromStateId) REFERENCES ref.WorkflowStateDefinition(WorkflowStateDefinitionId),
    CONSTRAINT FK_WorkflowTransition_To FOREIGN KEY (ToStateId) REFERENCES ref.WorkflowStateDefinition(WorkflowStateDefinitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowTransition_Instance')
    CREATE INDEX IX_workflow_WorkflowTransition_Instance ON workflow.WorkflowTransition(WorkflowInstanceId, TransitionedAtUtc);
GO

IF OBJECT_ID(N'workflow.WorkflowTask', N'U') IS NULL
CREATE TABLE workflow.WorkflowTask
(
    WorkflowTaskId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NOT NULL,
    TaskType        nvarchar(100)    NOT NULL,
    Title           nvarchar(200)    NOT NULL,
    Priority        nvarchar(20)     NOT NULL DEFAULT ('Normal'),
    DueAtUtc        datetime2(7)     NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Open'), -- Open, InProgress, Completed, Cancelled
    CompletedAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_workflow_WorkflowTask PRIMARY KEY CLUSTERED (WorkflowTaskId),
    CONSTRAINT FK_WorkflowTask_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowTask_Instance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT CK_WorkflowTask_Priority CHECK (Priority IN ('Low','Normal','High','Urgent')),
    CONSTRAINT CK_WorkflowTask_Status CHECK (Status IN ('Open','InProgress','Completed','Cancelled'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowTask_DueAtUtc')
    CREATE INDEX IX_workflow_WorkflowTask_DueAtUtc ON workflow.WorkflowTask(TenantId, DueAtUtc) WHERE Status IN ('Open','InProgress') AND IsDeleted = 0;
GO

IF OBJECT_ID(N'workflow.WorkflowTaskAssignment', N'U') IS NULL
CREATE TABLE workflow.WorkflowTaskAssignment
(
    WorkflowTaskAssignmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowTaskId  UNIQUEIDENTIFIER NOT NULL,
    AssignedUserId  UNIQUEIDENTIFIER NOT NULL,
    AssignedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    UnassignedAtUtc datetime2(7)     NULL,
    CONSTRAINT PK_workflow_WorkflowTaskAssignment PRIMARY KEY CLUSTERED (WorkflowTaskAssignmentId),
    CONSTRAINT FK_WorkflowTaskAssignment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowTaskAssignment_Task FOREIGN KEY (WorkflowTaskId) REFERENCES workflow.WorkflowTask(WorkflowTaskId),
    CONSTRAINT FK_WorkflowTaskAssignment_User FOREIGN KEY (AssignedUserId) REFERENCES iam.[User](UserId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowTaskAssignment_User')
    CREATE INDEX IX_workflow_WorkflowTaskAssignment_User ON workflow.WorkflowTaskAssignment(AssignedUserId) WHERE UnassignedAtUtc IS NULL;
GO

IF OBJECT_ID(N'workflow.WorkflowComment', N'U') IS NULL
CREATE TABLE workflow.WorkflowComment
(
    WorkflowCommentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NOT NULL,
    CommentText     nvarchar(2000)   NOT NULL,
    CommentedByUserId UNIQUEIDENTIFIER NOT NULL,
    CommentedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_workflow_WorkflowComment PRIMARY KEY CLUSTERED (WorkflowCommentId),
    CONSTRAINT FK_WorkflowComment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowComment_Instance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_WorkflowComment_User FOREIGN KEY (CommentedByUserId) REFERENCES iam.[User](UserId)
);
GO

IF OBJECT_ID(N'workflow.WorkflowSlaTracking', N'U') IS NULL
CREATE TABLE workflow.WorkflowSlaTracking
(
    WorkflowSlaTrackingId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NOT NULL,
    SlaRuleId       UNIQUEIDENTIFIER NOT NULL,
    DueAtUtc        datetime2(7)     NOT NULL,
    BreachedAtUtc   datetime2(7)     NULL,
    MetAtUtc        datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_workflow_WorkflowSlaTracking PRIMARY KEY CLUSTERED (WorkflowSlaTrackingId),
    CONSTRAINT FK_WorkflowSlaTracking_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowSlaTracking_Instance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_WorkflowSlaTracking_Rule FOREIGN KEY (SlaRuleId) REFERENCES ref.SlaRule(SlaRuleId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_WorkflowSlaTracking_DueAtUtc')
    CREATE INDEX IX_workflow_WorkflowSlaTracking_DueAtUtc ON workflow.WorkflowSlaTracking(DueAtUtc) WHERE BreachedAtUtc IS NULL AND MetAtUtc IS NULL;
GO

IF OBJECT_ID(N'workflow.WorkflowEscalation', N'U') IS NULL
CREATE TABLE workflow.WorkflowEscalation
(
    WorkflowEscalationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowSlaTrackingId UNIQUEIDENTIFIER NOT NULL,
    EscalatedToUserId UNIQUEIDENTIFIER NULL,
    EscalatedToRoleId UNIQUEIDENTIFIER NULL,
    EscalatedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Notes           nvarchar(500)    NULL,
    CONSTRAINT PK_workflow_WorkflowEscalation PRIMARY KEY CLUSTERED (WorkflowEscalationId),
    CONSTRAINT FK_WorkflowEscalation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WorkflowEscalation_Tracking FOREIGN KEY (WorkflowSlaTrackingId) REFERENCES workflow.WorkflowSlaTracking(WorkflowSlaTrackingId),
    CONSTRAINT FK_WorkflowEscalation_User FOREIGN KEY (EscalatedToUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_WorkflowEscalation_Role FOREIGN KEY (EscalatedToRoleId) REFERENCES iam.Role(RoleId)
);
GO

IF OBJECT_ID(N'workflow.ApprovalRequest', N'U') IS NULL
CREATE TABLE workflow.ApprovalRequest
(
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    ApprovalMatrixId UNIQUEIDENTIFIER NOT NULL,
    EntityType      nvarchar(100)    NOT NULL,
    EntityId        UNIQUEIDENTIFIER NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Approved, Rejected, Cancelled
    RequestedByUserId UNIQUEIDENTIFIER NULL,
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_workflow_ApprovalRequest PRIMARY KEY CLUSTERED (ApprovalRequestId),
    CONSTRAINT FK_ApprovalRequest_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ApprovalRequest_Instance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_ApprovalRequest_Matrix FOREIGN KEY (ApprovalMatrixId) REFERENCES ref.ApprovalMatrix(ApprovalMatrixId),
    CONSTRAINT CK_ApprovalRequest_Status CHECK (Status IN ('Pending','Approved','Rejected','Cancelled'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_ApprovalRequest_Entity')
    CREATE INDEX IX_workflow_ApprovalRequest_Entity ON workflow.ApprovalRequest(EntityType, EntityId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_ApprovalRequest_TenantStatus')
    CREATE INDEX IX_workflow_ApprovalRequest_TenantStatus ON workflow.ApprovalRequest(TenantId, Status) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'workflow.ApprovalStep', N'U') IS NULL
CREATE TABLE workflow.ApprovalStep
(
    ApprovalStepId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL,
    ApprovalMatrixRuleId UNIQUEIDENTIFIER NOT NULL,
    StepOrder       int              NOT NULL,
    AssignedApproverUserId UNIQUEIDENTIFIER NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Approved, Rejected, Delegated, Skipped
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_workflow_ApprovalStep PRIMARY KEY CLUSTERED (ApprovalStepId),
    CONSTRAINT FK_ApprovalStep_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ApprovalStep_Request FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId),
    CONSTRAINT FK_ApprovalStep_Rule FOREIGN KEY (ApprovalMatrixRuleId) REFERENCES ref.ApprovalMatrixRule(ApprovalMatrixRuleId),
    CONSTRAINT FK_ApprovalStep_Approver FOREIGN KEY (AssignedApproverUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_ApprovalStep_Status CHECK (Status IN ('Pending','Approved','Rejected','Delegated','Skipped'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_workflow_ApprovalStep')
    CREATE UNIQUE INDEX UQ_workflow_ApprovalStep ON workflow.ApprovalStep(ApprovalRequestId, StepOrder);
GO

IF OBJECT_ID(N'workflow.ApprovalDecision', N'U') IS NULL
CREATE TABLE workflow.ApprovalDecision
(
    ApprovalDecisionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ApprovalStepId  UNIQUEIDENTIFIER NOT NULL,
    DecidedByUserId UNIQUEIDENTIFIER NOT NULL,
    Decision        nvarchar(20)     NOT NULL, -- Approved, Rejected
    Comments        nvarchar(1000)   NULL,
    DecidedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_workflow_ApprovalDecision PRIMARY KEY CLUSTERED (ApprovalDecisionId),
    CONSTRAINT FK_ApprovalDecision_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ApprovalDecision_Step FOREIGN KEY (ApprovalStepId) REFERENCES workflow.ApprovalStep(ApprovalStepId),
    CONSTRAINT FK_ApprovalDecision_DecidedBy FOREIGN KEY (DecidedByUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_ApprovalDecision_Value CHECK (Decision IN ('Approved','Rejected'))
);
GO

IF OBJECT_ID(N'workflow.ApprovalDelegation', N'U') IS NULL
CREATE TABLE workflow.ApprovalDelegation
(
    ApprovalDelegationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DelegatorUserId UNIQUEIDENTIFIER NOT NULL,
    DelegateUserId  UNIQUEIDENTIFIER NOT NULL,
    EffectiveFromUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc  datetime2(7)     NULL,
    Reason          nvarchar(500)    NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_workflow_ApprovalDelegation PRIMARY KEY CLUSTERED (ApprovalDelegationId),
    CONSTRAINT FK_ApprovalDelegation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ApprovalDelegation_Delegator FOREIGN KEY (DelegatorUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_ApprovalDelegation_Delegate FOREIGN KEY (DelegateUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_ApprovalDelegation_NotSelf CHECK (DelegatorUserId <> DelegateUserId)
);
GO

IF OBJECT_ID(N'workflow.ApprovalHistory', N'U') IS NULL
CREATE TABLE workflow.ApprovalHistory
(
    ApprovalHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL,
    EventType       nvarchar(50)     NOT NULL, -- Requested, StepApproved, StepRejected, Delegated, Completed, Cancelled
    EventDetail     nvarchar(1000)   NULL,
    ActorUserId     UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_workflow_ApprovalHistory PRIMARY KEY CLUSTERED (ApprovalHistoryId),
    CONSTRAINT FK_ApprovalHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ApprovalHistory_Request FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_workflow_ApprovalHistory_Request')
    CREATE INDEX IX_workflow_ApprovalHistory_Request ON workflow.ApprovalHistory(ApprovalRequestId, OccurredAtUtc);
GO

PRINT N'03-create-tables.sql PART 7 (workflow) complete.';
GO

-- ============================================================================
-- PART 8 — recruitment schema, Section D: interview scheduling and feedback
-- ============================================================================

IF OBJECT_ID(N'recruitment.Interview', N'U') IS NULL
CREATE TABLE recruitment.Interview
(
    InterviewId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Scheduled'), -- Scheduled, Completed, Cancelled, NoShow
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_Interview PRIMARY KEY CLUSTERED (InterviewId),
    CONSTRAINT FK_Interview_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Interview_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_Interview_WorkflowInstance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT CK_Interview_Status CHECK (Status IN ('Scheduled','Completed','Cancelled','NoShow'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_Interview_Application')
    CREATE INDEX IX_recruitment_Interview_Application ON recruitment.Interview(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.InterviewRound', N'U') IS NULL
CREATE TABLE recruitment.InterviewRound
(
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewId     UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundDefinitionId UNIQUEIDENTIFIER NOT NULL,
    SequenceNumber  int              NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_InterviewRound PRIMARY KEY CLUSTERED (InterviewRoundId),
    CONSTRAINT FK_InterviewRound_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewRound_Interview FOREIGN KEY (InterviewId) REFERENCES recruitment.Interview(InterviewId),
    CONSTRAINT FK_InterviewRound_Definition FOREIGN KEY (InterviewRoundDefinitionId) REFERENCES ref.InterviewRoundDefinition(InterviewRoundDefinitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_InterviewRound')
    CREATE UNIQUE INDEX UQ_recruitment_InterviewRound ON recruitment.InterviewRound(InterviewId, SequenceNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.InterviewPanelMember', N'U') IS NULL
CREATE TABLE recruitment.InterviewPanelMember
(
    InterviewPanelMemberId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL,
    UserId          UNIQUEIDENTIFIER NOT NULL,
    IsLeadInterviewer bit            NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_InterviewPanelMember PRIMARY KEY CLUSTERED (InterviewPanelMemberId),
    CONSTRAINT FK_InterviewPanelMember_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewPanelMember_Round FOREIGN KEY (InterviewRoundId) REFERENCES recruitment.InterviewRound(InterviewRoundId),
    CONSTRAINT FK_InterviewPanelMember_User FOREIGN KEY (UserId) REFERENCES iam.[User](UserId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_InterviewPanelMember')
    CREATE UNIQUE INDEX UQ_recruitment_InterviewPanelMember ON recruitment.InterviewPanelMember(InterviewRoundId, UserId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.InterviewScheduleSlot', N'U') IS NULL
CREATE TABLE recruitment.InterviewScheduleSlot
(
    InterviewScheduleSlotId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL,
    ScheduledStartUtc datetime2(7)   NOT NULL,
    ScheduledEndUtc datetime2(7)     NOT NULL,
    TimeZoneId      nvarchar(60)     NULL,
    LocationOrLink  nvarchar(500)    NULL, -- physical location text or meeting link, no embedded secrets
    IsCurrent       bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_InterviewScheduleSlot PRIMARY KEY CLUSTERED (InterviewScheduleSlotId),
    CONSTRAINT FK_InterviewScheduleSlot_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewScheduleSlot_Round FOREIGN KEY (InterviewRoundId) REFERENCES recruitment.InterviewRound(InterviewRoundId),
    CONSTRAINT CK_InterviewScheduleSlot_TimeRange CHECK (ScheduledEndUtc > ScheduledStartUtc)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_recruitment_InterviewScheduleSlot_Round')
    CREATE INDEX IX_recruitment_InterviewScheduleSlot_Round ON recruitment.InterviewScheduleSlot(InterviewRoundId, IsCurrent);
GO

IF OBJECT_ID(N'recruitment.InterviewRescheduleHistory', N'U') IS NULL
CREATE TABLE recruitment.InterviewRescheduleHistory
(
    InterviewRescheduleHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL,
    PreviousSlotId  UNIQUEIDENTIFIER NULL,
    NewSlotId       UNIQUEIDENTIFIER NULL,
    RescheduledByUserId UNIQUEIDENTIFIER NULL,
    RescheduledAtUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason          nvarchar(500)    NULL,
    CONSTRAINT PK_recruitment_InterviewRescheduleHistory PRIMARY KEY CLUSTERED (InterviewRescheduleHistoryId),
    CONSTRAINT FK_InterviewRescheduleHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewRescheduleHistory_Round FOREIGN KEY (InterviewRoundId) REFERENCES recruitment.InterviewRound(InterviewRoundId),
    CONSTRAINT FK_InterviewRescheduleHistory_Prev FOREIGN KEY (PreviousSlotId) REFERENCES recruitment.InterviewScheduleSlot(InterviewScheduleSlotId),
    CONSTRAINT FK_InterviewRescheduleHistory_New FOREIGN KEY (NewSlotId) REFERENCES recruitment.InterviewScheduleSlot(InterviewScheduleSlotId)
);
GO

IF OBJECT_ID(N'recruitment.InterviewAttendance', N'U') IS NULL
CREATE TABLE recruitment.InterviewAttendance
(
    InterviewAttendanceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL,
    CandidateAttended bit            NULL,
    PanelAttendanceJson nvarchar(max) NULL, -- {UserId: attended bool} per panel member
    RecordedByUserId UNIQUEIDENTIFIER NULL,
    RecordedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_InterviewAttendance PRIMARY KEY CLUSTERED (InterviewAttendanceId),
    CONSTRAINT FK_InterviewAttendance_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewAttendance_Round FOREIGN KEY (InterviewRoundId) REFERENCES recruitment.InterviewRound(InterviewRoundId),
    CONSTRAINT CK_InterviewAttendance_PanelJson CHECK (PanelAttendanceJson IS NULL OR ISJSON(PanelAttendanceJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_InterviewAttendance')
    CREATE UNIQUE INDEX UQ_recruitment_InterviewAttendance ON recruitment.InterviewAttendance(InterviewRoundId);
GO

IF OBJECT_ID(N'recruitment.InterviewFeedback', N'U') IS NULL
CREATE TABLE recruitment.InterviewFeedback
(
    InterviewFeedbackId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL,
    InterviewFeedbackTemplateId UNIQUEIDENTIFIER NOT NULL,
    SubmittedByUserId UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL DEFAULT (1),
    OverallRecommendation nvarchar(20) NULL, -- StrongYes, Yes, No, StrongNo — always human-submitted
    SubmittedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    IsFinal         bit              NOT NULL DEFAULT (1), -- false while draft/versioned prior to submission
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_InterviewFeedback PRIMARY KEY CLUSTERED (InterviewFeedbackId),
    CONSTRAINT FK_InterviewFeedback_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewFeedback_Round FOREIGN KEY (InterviewRoundId) REFERENCES recruitment.InterviewRound(InterviewRoundId),
    CONSTRAINT FK_InterviewFeedback_Template FOREIGN KEY (InterviewFeedbackTemplateId) REFERENCES ref.InterviewFeedbackTemplate(InterviewFeedbackTemplateId),
    CONSTRAINT FK_InterviewFeedback_SubmittedBy FOREIGN KEY (SubmittedByUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_InterviewFeedback_Recommendation CHECK (OverallRecommendation IS NULL OR OverallRecommendation IN ('StrongYes','Yes','No','StrongNo'))
);
GO
-- Confidential interview feedback — access restricted per docs/security-model.md;
-- never indexed into the RAG vector store by default (see ADR-003 note in ai schema).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_InterviewFeedback')
    CREATE UNIQUE INDEX UQ_recruitment_InterviewFeedback ON recruitment.InterviewFeedback(InterviewRoundId, SubmittedByUserId, VersionNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'recruitment.InterviewFeedbackScore', N'U') IS NULL
CREATE TABLE recruitment.InterviewFeedbackScore
(
    InterviewFeedbackScoreId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewFeedbackId UNIQUEIDENTIFIER NOT NULL,
    InterviewCompetencyId UNIQUEIDENTIFIER NOT NULL,
    Score           decimal(5,2)     NOT NULL,
    MaxScore        decimal(5,2)     NOT NULL,
    CONSTRAINT PK_recruitment_InterviewFeedbackScore PRIMARY KEY CLUSTERED (InterviewFeedbackScoreId),
    CONSTRAINT FK_InterviewFeedbackScore_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewFeedbackScore_Feedback FOREIGN KEY (InterviewFeedbackId) REFERENCES recruitment.InterviewFeedback(InterviewFeedbackId),
    CONSTRAINT FK_InterviewFeedbackScore_Competency FOREIGN KEY (InterviewCompetencyId) REFERENCES ref.InterviewCompetency(InterviewCompetencyId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_InterviewFeedbackScore')
    CREATE UNIQUE INDEX UQ_recruitment_InterviewFeedbackScore ON recruitment.InterviewFeedbackScore(InterviewFeedbackId, InterviewCompetencyId);
GO

IF OBJECT_ID(N'recruitment.InterviewFeedbackComment', N'U') IS NULL
CREATE TABLE recruitment.InterviewFeedbackComment
(
    InterviewFeedbackCommentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewFeedbackId UNIQUEIDENTIFIER NOT NULL,
    CommentText     nvarchar(2000)   NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_InterviewFeedbackComment PRIMARY KEY CLUSTERED (InterviewFeedbackCommentId),
    CONSTRAINT FK_InterviewFeedbackComment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewFeedbackComment_Feedback FOREIGN KEY (InterviewFeedbackId) REFERENCES recruitment.InterviewFeedback(InterviewFeedbackId)
);
GO

IF OBJECT_ID(N'recruitment.InterviewFeedbackApproval', N'U') IS NULL
CREATE TABLE recruitment.InterviewFeedbackApproval
(
    InterviewFeedbackApprovalId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewFeedbackId UNIQUEIDENTIFIER NOT NULL,
    ApproverUserId  UNIQUEIDENTIFIER NOT NULL,
    DecisionStatus  nvarchar(20)     NOT NULL DEFAULT ('Pending'),
    DecidedAtUtc    datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_InterviewFeedbackApproval PRIMARY KEY CLUSTERED (InterviewFeedbackApprovalId),
    CONSTRAINT FK_InterviewFeedbackApproval_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewFeedbackApproval_Feedback FOREIGN KEY (InterviewFeedbackId) REFERENCES recruitment.InterviewFeedback(InterviewFeedbackId),
    CONSTRAINT FK_InterviewFeedbackApproval_Approver FOREIGN KEY (ApproverUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_InterviewFeedbackApproval_Status CHECK (DecisionStatus IN ('Pending','Approved','Rejected'))
);
GO

IF OBJECT_ID(N'recruitment.InterviewOutcome', N'U') IS NULL
CREATE TABLE recruitment.InterviewOutcome
(
    InterviewOutcomeId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewRoundId UNIQUEIDENTIFIER NOT NULL,
    OutcomeStatus   nvarchar(20)     NOT NULL, -- Progressed, Rejected, OnHold
    DecidedByUserId UNIQUEIDENTIFIER NOT NULL, -- always human — see workflow.ApprovalRequest for the gating approval
    ApprovalRequestId UNIQUEIDENTIFIER NULL,
    DecidedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_recruitment_InterviewOutcome PRIMARY KEY CLUSTERED (InterviewOutcomeId),
    CONSTRAINT FK_InterviewOutcome_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewOutcome_Round FOREIGN KEY (InterviewRoundId) REFERENCES recruitment.InterviewRound(InterviewRoundId),
    CONSTRAINT FK_InterviewOutcome_DecidedBy FOREIGN KEY (DecidedByUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_InterviewOutcome_ApprovalRequest FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId),
    CONSTRAINT CK_InterviewOutcome_Status CHECK (OutcomeStatus IN ('Progressed','Rejected','OnHold'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_recruitment_InterviewOutcome')
    CREATE UNIQUE INDEX UQ_recruitment_InterviewOutcome ON recruitment.InterviewOutcome(InterviewRoundId);
GO

IF OBJECT_ID(N'recruitment.InterviewOutcomeHistory', N'U') IS NULL
CREATE TABLE recruitment.InterviewOutcomeHistory
(
    InterviewOutcomeHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewOutcomeId UNIQUEIDENTIFIER NOT NULL,
    PreviousStatus  nvarchar(20)     NULL,
    NewStatus       nvarchar(20)     NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_recruitment_InterviewOutcomeHistory PRIMARY KEY CLUSTERED (InterviewOutcomeHistoryId),
    CONSTRAINT FK_InterviewOutcomeHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewOutcomeHistory_Outcome FOREIGN KEY (InterviewOutcomeId) REFERENCES recruitment.InterviewOutcome(InterviewOutcomeId)
);
GO

IF OBJECT_ID(N'recruitment.InterviewCalendarIntegration', N'U') IS NULL
CREATE TABLE recruitment.InterviewCalendarIntegration
(
    InterviewCalendarIntegrationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    InterviewScheduleSlotId UNIQUEIDENTIFIER NOT NULL,
    ProviderName    nvarchar(50)     NOT NULL, -- e.g. 'MicrosoftGraph','GoogleCalendar' — see mcp/servers for the actual MCP integration
    ExternalEventId nvarchar(200)    NOT NULL, -- opaque external reference only, never a token/credential
    SyncStatus      nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Synced, Failed
    LastSyncedAtUtc datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_recruitment_InterviewCalendarIntegration PRIMARY KEY CLUSTERED (InterviewCalendarIntegrationId),
    CONSTRAINT FK_InterviewCalendarIntegration_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_InterviewCalendarIntegration_Slot FOREIGN KEY (InterviewScheduleSlotId) REFERENCES recruitment.InterviewScheduleSlot(InterviewScheduleSlotId),
    CONSTRAINT CK_InterviewCalendarIntegration_SyncStatus CHECK (SyncStatus IN ('Pending','Synced','Failed'))
);
GO

PRINT N'03-create-tables.sql PART 8 (recruitment: interview) complete.';
GO

-- ============================================================================
-- PART 9 — offer schema. Compensation columns are access-restricted (see
-- docs/security-model.md "Compensation data access" and reporting.vw_* views,
-- which never surface OfferCompensation directly). "Sent" requires a prior
-- Approved offer.OfferApproval — enforced by offer.usp_MarkOfferSent, with
-- workflow.ApprovalRequest as the system-of-record approval gate.
-- ============================================================================

IF OBJECT_ID(N'offer.Offer', N'U') IS NULL
CREATE TABLE offer.Offer
(
    OfferId         UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    OfferTemplateId UNIQUEIDENTIFIER NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    OfferNumber     nvarchar(50)     NOT NULL,
    OfferStatusId   UNIQUEIDENTIFIER NOT NULL,
    ProposedStartDate date           NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_offer_Offer PRIMARY KEY CLUSTERED (OfferId),
    CONSTRAINT FK_Offer_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Offer_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_Offer_Template FOREIGN KEY (OfferTemplateId) REFERENCES ref.OfferTemplate(OfferTemplateId),
    CONSTRAINT FK_Offer_WorkflowInstance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_Offer_Status FOREIGN KEY (OfferStatusId) REFERENCES ref.OfferStatus(OfferStatusId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_offer_Offer_Number')
    CREATE UNIQUE INDEX UQ_offer_Offer_Number ON offer.Offer(TenantId, OfferNumber) WHERE IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_offer_Offer_Application')
    CREATE INDEX IX_offer_Offer_Application ON offer.Offer(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'offer.OfferVersion', N'U') IS NULL
CREATE TABLE offer.OfferVersion
(
    OfferVersionId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ChangeReason    nvarchar(500)    NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_offer_OfferVersion PRIMARY KEY CLUSTERED (OfferVersionId),
    CONSTRAINT FK_OfferVersion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferVersion_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_offer_OfferVersion')
    CREATE UNIQUE INDEX UQ_offer_OfferVersion ON offer.OfferVersion(OfferId, VersionNumber);
GO

IF OBJECT_ID(N'offer.OfferCompensation', N'U') IS NULL
CREATE TABLE offer.OfferCompensation
(
    OfferCompensationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferVersionId  UNIQUEIDENTIFIER NOT NULL,
    CurrencyCode    char(3)          NOT NULL,
    TotalAnnualAmount decimal(19,4)  NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_offer_OfferCompensation PRIMARY KEY CLUSTERED (OfferCompensationId),
    CONSTRAINT FK_OfferCompensation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferCompensation_Version FOREIGN KEY (OfferVersionId) REFERENCES offer.OfferVersion(OfferVersionId),
    CONSTRAINT CK_OfferCompensation_Amount CHECK (TotalAnnualAmount >= 0)
);
GO
-- RESTRICTED TABLE: never selected in reporting.* views; access via
-- offer.usp_* procedures and a narrow, explicitly-granted role only. This
-- table, not the UI or the database alone, is never the final authority on a
-- compensation decision — it stores an already-approved value.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_offer_OfferCompensation')
    CREATE UNIQUE INDEX UQ_offer_OfferCompensation ON offer.OfferCompensation(OfferVersionId);
GO

IF OBJECT_ID(N'offer.OfferCompensationComponent', N'U') IS NULL
CREATE TABLE offer.OfferCompensationComponent
(
    OfferCompensationComponentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferCompensationId UNIQUEIDENTIFIER NOT NULL,
    ComponentCode   nvarchar(50)     NOT NULL, -- Base, Bonus, Allowance, Equity, ...
    ComponentName   nvarchar(200)    NOT NULL,
    CurrencyCode    char(3)          NOT NULL,
    Amount          decimal(19,4)    NOT NULL,
    CONSTRAINT PK_offer_OfferCompensationComponent PRIMARY KEY CLUSTERED (OfferCompensationComponentId),
    CONSTRAINT FK_OfferCompComponent_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferCompComponent_Compensation FOREIGN KEY (OfferCompensationId) REFERENCES offer.OfferCompensation(OfferCompensationId),
    CONSTRAINT CK_OfferCompComponent_Amount CHECK (Amount >= 0)
);
GO

IF OBJECT_ID(N'offer.OfferBenefit', N'U') IS NULL
CREATE TABLE offer.OfferBenefit
(
    OfferBenefitId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferVersionId  UNIQUEIDENTIFIER NOT NULL,
    BenefitCode     nvarchar(50)     NOT NULL,
    BenefitDescription nvarchar(500) NULL,
    CONSTRAINT PK_offer_OfferBenefit PRIMARY KEY CLUSTERED (OfferBenefitId),
    CONSTRAINT FK_OfferBenefit_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferBenefit_Version FOREIGN KEY (OfferVersionId) REFERENCES offer.OfferVersion(OfferVersionId)
);
GO

IF OBJECT_ID(N'offer.OfferCondition', N'U') IS NULL
CREATE TABLE offer.OfferCondition
(
    OfferConditionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferVersionId  UNIQUEIDENTIFIER NOT NULL,
    ConditionText   nvarchar(1000)   NOT NULL, -- e.g. "subject to background verification"
    IsMandatory     bit              NOT NULL DEFAULT (1),
    CONSTRAINT PK_offer_OfferCondition PRIMARY KEY CLUSTERED (OfferConditionId),
    CONSTRAINT FK_OfferCondition_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferCondition_Version FOREIGN KEY (OfferVersionId) REFERENCES offer.OfferVersion(OfferVersionId)
);
GO

IF OBJECT_ID(N'offer.OfferApproval', N'U') IS NULL
CREATE TABLE offer.OfferApproval
(
    OfferApprovalId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'),
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_offer_OfferApproval PRIMARY KEY CLUSTERED (OfferApprovalId),
    CONSTRAINT FK_OfferApproval_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferApproval_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId),
    CONSTRAINT FK_OfferApproval_Request FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId),
    CONSTRAINT CK_OfferApproval_Status CHECK (Status IN ('Pending','Approved','Rejected'))
);
GO

IF OBJECT_ID(N'offer.OfferApprovalHistory', N'U') IS NULL
CREATE TABLE offer.OfferApprovalHistory
(
    OfferApprovalHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferApprovalId UNIQUEIDENTIFIER NOT NULL,
    EventType       nvarchar(50)     NOT NULL,
    ActorUserId     UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_offer_OfferApprovalHistory PRIMARY KEY CLUSTERED (OfferApprovalHistoryId),
    CONSTRAINT FK_OfferApprovalHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferApprovalHistory_Approval FOREIGN KEY (OfferApprovalId) REFERENCES offer.OfferApproval(OfferApprovalId)
);
GO

IF OBJECT_ID(N'offer.OfferDocument', N'U') IS NULL
CREATE TABLE offer.OfferDocument
(
    OfferDocumentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferVersionId  UNIQUEIDENTIFIER NOT NULL,
    ObjectStorageUri nvarchar(1000)  NOT NULL,
    FileName        nvarchar(260)    NOT NULL,
    MimeType        nvarchar(100)    NOT NULL,
    ContentHash     varbinary(32)    NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Generated'), -- Generated, Sent, Signed
    GeneratedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_offer_OfferDocument PRIMARY KEY CLUSTERED (OfferDocumentId),
    CONSTRAINT FK_OfferDocument_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferDocument_Version FOREIGN KEY (OfferVersionId) REFERENCES offer.OfferVersion(OfferVersionId),
    CONSTRAINT CK_OfferDocument_Status CHECK (Status IN ('Generated','Sent','Signed'))
);
GO

IF OBJECT_ID(N'offer.OfferSignatureRequest', N'U') IS NULL
CREATE TABLE offer.OfferSignatureRequest
(
    OfferSignatureRequestId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferDocumentId UNIQUEIDENTIFIER NOT NULL,
    SignatureProviderName nvarchar(50) NOT NULL, -- e.g. DocuSign, AdobeSign — see mcp/ for the e-signature MCP server
    ExternalRequestId nvarchar(200)  NOT NULL, -- opaque provider reference only, never a credential
    SignerEmailHash varbinary(32)    NULL, -- hashed for correlation without storing PII redundantly
    Status          nvarchar(20)     NOT NULL DEFAULT ('Sent'), -- Sent, Viewed, Signed, Declined, Expired
    SentAtUtc       datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CONSTRAINT PK_offer_OfferSignatureRequest PRIMARY KEY CLUSTERED (OfferSignatureRequestId),
    CONSTRAINT FK_OfferSignatureRequest_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferSignatureRequest_Document FOREIGN KEY (OfferDocumentId) REFERENCES offer.OfferDocument(OfferDocumentId),
    CONSTRAINT CK_OfferSignatureRequest_Status CHECK (Status IN ('Sent','Viewed','Signed','Declined','Expired'))
);
GO

IF OBJECT_ID(N'offer.OfferAcceptance', N'U') IS NULL
CREATE TABLE offer.OfferAcceptance
(
    OfferAcceptanceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    OfferSignatureRequestId UNIQUEIDENTIFIER NULL,
    AcceptedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    RecordedByUserId UNIQUEIDENTIFIER NULL, -- system-recorded from signature webhook, or HR manual entry
    CONSTRAINT PK_offer_OfferAcceptance PRIMARY KEY CLUSTERED (OfferAcceptanceId),
    CONSTRAINT FK_OfferAcceptance_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferAcceptance_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId),
    CONSTRAINT FK_OfferAcceptance_SignatureRequest FOREIGN KEY (OfferSignatureRequestId) REFERENCES offer.OfferSignatureRequest(OfferSignatureRequestId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_offer_OfferAcceptance')
    CREATE UNIQUE INDEX UQ_offer_OfferAcceptance ON offer.OfferAcceptance(OfferId);
GO

IF OBJECT_ID(N'offer.OfferRejection', N'U') IS NULL
CREATE TABLE offer.OfferRejection
(
    OfferRejectionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    RejectionReasonCode nvarchar(50) NULL,
    RejectionNotes  nvarchar(1000)   NULL,
    RejectedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    RecordedByUserId UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_offer_OfferRejection PRIMARY KEY CLUSTERED (OfferRejectionId),
    CONSTRAINT FK_OfferRejection_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferRejection_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_offer_OfferRejection')
    CREATE UNIQUE INDEX UQ_offer_OfferRejection ON offer.OfferRejection(OfferId);
GO

IF OBJECT_ID(N'offer.OfferWithdrawal', N'U') IS NULL
CREATE TABLE offer.OfferWithdrawal
(
    OfferWithdrawalId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    WithdrawalReasonCode nvarchar(50) NULL,
    WithdrawalNotes nvarchar(1000)   NULL,
    WithdrawnByUserId UNIQUEIDENTIFIER NOT NULL, -- always a human, approval-gated per policy
    ApprovalRequestId UNIQUEIDENTIFIER NULL,
    WithdrawnAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_offer_OfferWithdrawal PRIMARY KEY CLUSTERED (OfferWithdrawalId),
    CONSTRAINT FK_OfferWithdrawal_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferWithdrawal_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId),
    CONSTRAINT FK_OfferWithdrawal_WithdrawnBy FOREIGN KEY (WithdrawnByUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_OfferWithdrawal_ApprovalRequest FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_offer_OfferWithdrawal')
    CREATE UNIQUE INDEX UQ_offer_OfferWithdrawal ON offer.OfferWithdrawal(OfferId);
GO

IF OBJECT_ID(N'offer.OfferStatusHistory', N'U') IS NULL
CREATE TABLE offer.OfferStatusHistory
(
    OfferStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    FromOfferStatusId UNIQUEIDENTIFIER NULL,
    ToOfferStatusId UNIQUEIDENTIFIER NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_offer_OfferStatusHistory PRIMARY KEY CLUSTERED (OfferStatusHistoryId),
    CONSTRAINT FK_OfferStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferStatusHistory_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId),
    CONSTRAINT FK_OfferStatusHistory_From FOREIGN KEY (FromOfferStatusId) REFERENCES ref.OfferStatus(OfferStatusId),
    CONSTRAINT FK_OfferStatusHistory_To FOREIGN KEY (ToOfferStatusId) REFERENCES ref.OfferStatus(OfferStatusId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_offer_OfferStatusHistory_Offer')
    CREATE INDEX IX_offer_OfferStatusHistory_Offer ON offer.OfferStatusHistory(OfferId, ChangedAtUtc);
GO

IF OBJECT_ID(N'offer.OfferCommunication', N'U') IS NULL
CREATE TABLE offer.OfferCommunication
(
    OfferCommunicationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    NotificationTemplateId UNIQUEIDENTIFIER NULL,
    NotificationChannelId UNIQUEIDENTIFIER NOT NULL,
    SentAtUtc       datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    DeliveryStatus  nvarchar(20)     NOT NULL DEFAULT ('Sent'), -- Sent, Delivered, Failed
    CONSTRAINT PK_offer_OfferCommunication PRIMARY KEY CLUSTERED (OfferCommunicationId),
    CONSTRAINT FK_OfferCommunication_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OfferCommunication_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId),
    CONSTRAINT FK_OfferCommunication_Template FOREIGN KEY (NotificationTemplateId) REFERENCES ref.NotificationTemplate(NotificationTemplateId),
    CONSTRAINT FK_OfferCommunication_Channel FOREIGN KEY (NotificationChannelId) REFERENCES ref.NotificationChannel(NotificationChannelId),
    CONSTRAINT CK_OfferCommunication_DeliveryStatus CHECK (DeliveryStatus IN ('Sent','Delivered','Failed'))
);
GO

PRINT N'03-create-tables.sql PART 9 (offer) complete.';
GO

-- ============================================================================
-- PART 10 — onboarding schema, Section A: Green Form and onboarding tasks
-- ============================================================================

IF OBJECT_ID(N'onboarding.GreenForm', N'U') IS NULL
CREATE TABLE onboarding.GreenForm
(
    GreenFormId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    Code            nvarchar(50)     NOT NULL,
    Name            nvarchar(200)    NOT NULL,
    CurrentVersionId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql (circular with GreenFormVersion)
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_GreenForm PRIMARY KEY CLUSTERED (GreenFormId),
    CONSTRAINT FK_GreenForm_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_GreenForm')
    CREATE UNIQUE INDEX UQ_onboarding_GreenForm ON onboarding.GreenForm(TenantId, Code) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.GreenFormVersion', N'U') IS NULL
CREATE TABLE onboarding.GreenFormVersion
(
    GreenFormVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GreenFormId     UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ApprovalStatus  nvarchar(20)     NOT NULL DEFAULT ('Draft'),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_GreenFormVersion PRIMARY KEY CLUSTERED (GreenFormVersionId),
    CONSTRAINT FK_GreenFormVersion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_GreenFormVersion_Form FOREIGN KEY (GreenFormId) REFERENCES onboarding.GreenForm(GreenFormId),
    CONSTRAINT CK_GreenFormVersion_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_GreenFormVersion')
    CREATE UNIQUE INDEX UQ_onboarding_GreenFormVersion ON onboarding.GreenFormVersion(GreenFormId, VersionNumber);
GO

IF OBJECT_ID(N'onboarding.GreenFormSection', N'U') IS NULL
CREATE TABLE onboarding.GreenFormSection
(
    GreenFormSectionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GreenFormVersionId UNIQUEIDENTIFIER NOT NULL,
    SectionCode     nvarchar(50)     NOT NULL,
    SectionTitle    nvarchar(200)    NOT NULL,
    SortOrder       int              NOT NULL DEFAULT (0),
    CONSTRAINT PK_onboarding_GreenFormSection PRIMARY KEY CLUSTERED (GreenFormSectionId),
    CONSTRAINT FK_GreenFormSection_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_GreenFormSection_Version FOREIGN KEY (GreenFormVersionId) REFERENCES onboarding.GreenFormVersion(GreenFormVersionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_GreenFormSection')
    CREATE UNIQUE INDEX UQ_onboarding_GreenFormSection ON onboarding.GreenFormSection(GreenFormVersionId, SectionCode);
GO

IF OBJECT_ID(N'onboarding.GreenFormFieldDefinition', N'U') IS NULL
CREATE TABLE onboarding.GreenFormFieldDefinition
(
    GreenFormFieldDefinitionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GreenFormSectionId UNIQUEIDENTIFIER NOT NULL,
    FieldCode       nvarchar(100)    NOT NULL,
    FieldLabel      nvarchar(200)    NOT NULL,
    FieldType       nvarchar(30)     NOT NULL, -- Text, Number, Date, Boolean, Select, File
    IsRequired      bit              NOT NULL DEFAULT (0),
    ValidationRuleJson nvarchar(max) NULL,
    SortOrder       int              NOT NULL DEFAULT (0),
    CONSTRAINT PK_onboarding_GreenFormFieldDefinition PRIMARY KEY CLUSTERED (GreenFormFieldDefinitionId),
    CONSTRAINT FK_GreenFormFieldDef_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_GreenFormFieldDef_Section FOREIGN KEY (GreenFormSectionId) REFERENCES onboarding.GreenFormSection(GreenFormSectionId),
    CONSTRAINT CK_GreenFormFieldDef_Type CHECK (FieldType IN ('Text','Number','Date','Boolean','Select','File')),
    CONSTRAINT CK_GreenFormFieldDef_ValidationJson CHECK (ValidationRuleJson IS NULL OR ISJSON(ValidationRuleJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_GreenFormFieldDefinition')
    CREATE UNIQUE INDEX UQ_onboarding_GreenFormFieldDefinition ON onboarding.GreenFormFieldDefinition(GreenFormSectionId, FieldCode);
GO

IF OBJECT_ID(N'onboarding.GreenFormSubmission', N'U') IS NULL
CREATE TABLE onboarding.GreenFormSubmission
(
    GreenFormSubmissionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GreenFormVersionId UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('InProgress'), -- InProgress, Submitted, UnderReview, Completed
    SubmittedAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_GreenFormSubmission PRIMARY KEY CLUSTERED (GreenFormSubmissionId),
    CONSTRAINT FK_GreenFormSubmission_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_GreenFormSubmission_Version FOREIGN KEY (GreenFormVersionId) REFERENCES onboarding.GreenFormVersion(GreenFormVersionId),
    CONSTRAINT FK_GreenFormSubmission_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_GreenFormSubmission_WorkflowInstance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT CK_GreenFormSubmission_Status CHECK (Status IN ('InProgress','Submitted','UnderReview','Completed'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_GreenFormSubmission')
    CREATE UNIQUE INDEX UQ_onboarding_GreenFormSubmission ON onboarding.GreenFormSubmission(CandidateApplicationId, GreenFormVersionId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.GreenFormFieldValue', N'U') IS NULL
CREATE TABLE onboarding.GreenFormFieldValue
(
    GreenFormFieldValueId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GreenFormSubmissionId UNIQUEIDENTIFIER NOT NULL,
    GreenFormFieldDefinitionId UNIQUEIDENTIFIER NOT NULL,
    ValueText       nvarchar(2000)   NULL, -- File-type fields store an object-storage reference here, not binary content
    UpdatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_GreenFormFieldValue PRIMARY KEY CLUSTERED (GreenFormFieldValueId),
    CONSTRAINT FK_GreenFormFieldValue_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_GreenFormFieldValue_Submission FOREIGN KEY (GreenFormSubmissionId) REFERENCES onboarding.GreenFormSubmission(GreenFormSubmissionId),
    CONSTRAINT FK_GreenFormFieldValue_FieldDef FOREIGN KEY (GreenFormFieldDefinitionId) REFERENCES onboarding.GreenFormFieldDefinition(GreenFormFieldDefinitionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_GreenFormFieldValue')
    CREATE UNIQUE INDEX UQ_onboarding_GreenFormFieldValue ON onboarding.GreenFormFieldValue(GreenFormSubmissionId, GreenFormFieldDefinitionId);
GO

IF OBJECT_ID(N'onboarding.OnboardingChecklist', N'U') IS NULL
CREATE TABLE onboarding.OnboardingChecklist
(
    OnboardingChecklistId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    Code            nvarchar(50)     NOT NULL,
    Name            nvarchar(200)    NOT NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    VersionNumber   int              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_OnboardingChecklist PRIMARY KEY CLUSTERED (OnboardingChecklistId),
    CONSTRAINT FK_OnboardingChecklist_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_OnboardingChecklist')
    CREATE UNIQUE INDEX UQ_onboarding_OnboardingChecklist ON onboarding.OnboardingChecklist(TenantId, Code) WHERE IsActive = 1;
GO

IF OBJECT_ID(N'onboarding.OnboardingChecklistItem', N'U') IS NULL
CREATE TABLE onboarding.OnboardingChecklistItem
(
    OnboardingChecklistItemId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OnboardingChecklistId UNIQUEIDENTIFIER NOT NULL,
    ItemCode        nvarchar(100)    NOT NULL,
    ItemDescription nvarchar(500)    NOT NULL,
    IsMandatory     bit              NOT NULL DEFAULT (1),
    SortOrder       int              NOT NULL DEFAULT (0),
    CONSTRAINT PK_onboarding_OnboardingChecklistItem PRIMARY KEY CLUSTERED (OnboardingChecklistItemId),
    CONSTRAINT FK_OnboardingChecklistItem_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OnboardingChecklistItem_Checklist FOREIGN KEY (OnboardingChecklistId) REFERENCES onboarding.OnboardingChecklist(OnboardingChecklistId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_OnboardingChecklistItem')
    CREATE UNIQUE INDEX UQ_onboarding_OnboardingChecklistItem ON onboarding.OnboardingChecklistItem(OnboardingChecklistId, ItemCode);
GO

IF OBJECT_ID(N'onboarding.OnboardingTask', N'U') IS NULL
CREATE TABLE onboarding.OnboardingTask
(
    OnboardingTaskId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    OnboardingChecklistItemId UNIQUEIDENTIFIER NULL,
    Title           nvarchar(200)    NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Open'), -- Open, InProgress, Completed, Skipped
    DueAtUtc        datetime2(7)     NULL,
    CompletedAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_OnboardingTask PRIMARY KEY CLUSTERED (OnboardingTaskId),
    CONSTRAINT FK_OnboardingTask_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OnboardingTask_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_OnboardingTask_ChecklistItem FOREIGN KEY (OnboardingChecklistItemId) REFERENCES onboarding.OnboardingChecklistItem(OnboardingChecklistItemId),
    CONSTRAINT CK_OnboardingTask_Status CHECK (Status IN ('Open','InProgress','Completed','Skipped'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_OnboardingTask_Application')
    CREATE INDEX IX_onboarding_OnboardingTask_Application ON onboarding.OnboardingTask(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.OnboardingTaskAssignment', N'U') IS NULL
CREATE TABLE onboarding.OnboardingTaskAssignment
(
    OnboardingTaskAssignmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OnboardingTaskId UNIQUEIDENTIFIER NOT NULL,
    AssignedUserId  UNIQUEIDENTIFIER NOT NULL,
    AssignedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_onboarding_OnboardingTaskAssignment PRIMARY KEY CLUSTERED (OnboardingTaskAssignmentId),
    CONSTRAINT FK_OnboardingTaskAssignment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OnboardingTaskAssignment_Task FOREIGN KEY (OnboardingTaskId) REFERENCES onboarding.OnboardingTask(OnboardingTaskId),
    CONSTRAINT FK_OnboardingTaskAssignment_User FOREIGN KEY (AssignedUserId) REFERENCES iam.[User](UserId)
);
GO

IF OBJECT_ID(N'onboarding.OnboardingTaskStatusHistory', N'U') IS NULL
CREATE TABLE onboarding.OnboardingTaskStatusHistory
(
    OnboardingTaskStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    OnboardingTaskId UNIQUEIDENTIFIER NOT NULL,
    FromStatus      nvarchar(20)     NULL,
    ToStatus        nvarchar(20)     NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_onboarding_OnboardingTaskStatusHistory PRIMARY KEY CLUSTERED (OnboardingTaskStatusHistoryId),
    CONSTRAINT FK_OnboardingTaskStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_OnboardingTaskStatusHistory_Task FOREIGN KEY (OnboardingTaskId) REFERENCES onboarding.OnboardingTask(OnboardingTaskId)
);
GO

PRINT N'03-create-tables.sql PART 10 (onboarding: Green Form / tasks) complete.';
GO

-- ============================================================================
-- PART 11 — onboarding schema, Section B: professional & educational details
-- ============================================================================

IF OBJECT_ID(N'onboarding.CandidateEmploymentHistory', N'U') IS NULL
CREATE TABLE onboarding.CandidateEmploymentHistory
(
    CandidateEmploymentHistoryId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    EmployerName    nvarchar(200)    NOT NULL,
    JobTitle        nvarchar(150)    NULL,
    StartDate       date             NULL,
    EndDate         date             NULL,
    IsCurrent       bit              NOT NULL DEFAULT (0),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateEmploymentHistory PRIMARY KEY CLUSTERED (CandidateEmploymentHistoryId),
    CONSTRAINT FK_CandEmploymentHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandEmploymentHistory_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT CK_CandEmploymentHistory_Dates CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_CandEmploymentHistory_Candidate')
    CREATE INDEX IX_onboarding_CandEmploymentHistory_Candidate ON onboarding.CandidateEmploymentHistory(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.CandidateEmploymentReference', N'U') IS NULL
CREATE TABLE onboarding.CandidateEmploymentReference
(
    CandidateEmploymentReferenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateEmploymentHistoryId UNIQUEIDENTIFIER NOT NULL,
    ReferenceName   nvarchar(200)    NULL,
    ReferenceContactHash varbinary(32) NULL, -- hashed contact for duplicate-detection; raw contact lives in a restricted column
    ReferenceContactEncrypted varbinary(500) NULL, -- application-layer envelope-encrypted, see docs/security-model.md
    RelationshipToReferee nvarchar(100) NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateEmploymentReference PRIMARY KEY CLUSTERED (CandidateEmploymentReferenceId),
    CONSTRAINT FK_CandEmploymentReference_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandEmploymentReference_History FOREIGN KEY (CandidateEmploymentHistoryId) REFERENCES onboarding.CandidateEmploymentHistory(CandidateEmploymentHistoryId)
);
GO

IF OBJECT_ID(N'onboarding.CandidateEducationHistory', N'U') IS NULL
CREATE TABLE onboarding.CandidateEducationHistory
(
    CandidateEducationHistoryId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    InstitutionName nvarchar(200)    NOT NULL,
    QualificationName nvarchar(200)  NULL,
    FieldOfStudy    nvarchar(200)    NULL,
    StartDate       date             NULL,
    EndDate         date             NULL,
    GradeOrScore    nvarchar(50)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateEducationHistory PRIMARY KEY CLUSTERED (CandidateEducationHistoryId),
    CONSTRAINT FK_CandEducationHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandEducationHistory_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_CandEducationHistory_Candidate')
    CREATE INDEX IX_onboarding_CandEducationHistory_Candidate ON onboarding.CandidateEducationHistory(CandidateId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.CandidateCertification', N'U') IS NULL
CREATE TABLE onboarding.CandidateCertification
(
    CandidateCertificationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    CertificationName nvarchar(200)  NOT NULL,
    IssuingBody     nvarchar(200)    NULL,
    IssuedDate      date             NULL,
    ExpiryDate      date             NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateCertification PRIMARY KEY CLUSTERED (CandidateCertificationId),
    CONSTRAINT FK_CandCertification_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandCertification_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO

IF OBJECT_ID(N'onboarding.CandidateProfessionalReference', N'U') IS NULL
CREATE TABLE onboarding.CandidateProfessionalReference
(
    CandidateProfessionalReferenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    ReferenceName   nvarchar(200)    NULL,
    ReferenceContactEncrypted varbinary(500) NULL,
    RelationshipToReferee nvarchar(100) NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateProfessionalReference PRIMARY KEY CLUSTERED (CandidateProfessionalReferenceId),
    CONSTRAINT FK_CandProfessionalReference_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandProfessionalReference_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO

IF OBJECT_ID(N'onboarding.CandidateEmploymentGap', N'U') IS NULL
CREATE TABLE onboarding.CandidateEmploymentGap
(
    CandidateEmploymentGapId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateId     UNIQUEIDENTIFIER NOT NULL,
    GapStartDate    date             NOT NULL,
    GapEndDate      date             NULL,
    ExplanationText nvarchar(1000)   NULL, -- candidate-provided, never AI-inferred as fact
    IsAiFlagged     bit              NOT NULL DEFAULT (0), -- AI may flag a gap; a human confirms/dismisses via DiscrepancyResolution if relevant
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateEmploymentGap PRIMARY KEY CLUSTERED (CandidateEmploymentGapId),
    CONSTRAINT FK_CandEmploymentGap_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandEmploymentGap_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId)
);
GO

IF OBJECT_ID(N'onboarding.CandidateDeclaration', N'U') IS NULL
CREATE TABLE onboarding.CandidateDeclaration
(
    CandidateDeclarationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    GreenFormSubmissionId UNIQUEIDENTIFIER NOT NULL,
    DeclarationText nvarchar(2000)   NOT NULL,
    IsAccepted      bit              NOT NULL DEFAULT (0),
    AcceptedAtUtc   datetime2(7)     NULL,
    AcceptedFromIpHash varbinary(32) NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateDeclaration PRIMARY KEY CLUSTERED (CandidateDeclarationId),
    CONSTRAINT FK_CandDeclaration_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandDeclaration_Submission FOREIGN KEY (GreenFormSubmissionId) REFERENCES onboarding.GreenFormSubmission(GreenFormSubmissionId)
);
GO

PRINT N'03-create-tables.sql PART 11 (onboarding: employment / education history) complete.';
GO

-- ============================================================================
-- PART 12 — onboarding schema, Section C: document management. Only object-
-- storage references + metadata — never raw file content, per non-negotiable
-- rules in root CLAUDE.md and .claude/rules/data.md.
-- ============================================================================

IF OBJECT_ID(N'onboarding.CandidateDocument', N'U') IS NULL
CREATE TABLE onboarding.CandidateDocument
(
    CandidateDocumentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    DocumentTypeId  UNIQUEIDENTIFIER NOT NULL,
    DocumentStatusId UNIQUEIDENTIFIER NOT NULL,
    CurrentVersionId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql (circular with CandidateDocumentVersion)
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateDocument PRIMARY KEY CLUSTERED (CandidateDocumentId),
    CONSTRAINT FK_CandidateDocument_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandidateDocument_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_CandidateDocument_DocType FOREIGN KEY (DocumentTypeId) REFERENCES ref.DocumentType(DocumentTypeId),
    CONSTRAINT FK_CandidateDocument_Status FOREIGN KEY (DocumentStatusId) REFERENCES ref.DocumentStatus(DocumentStatusId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_CandidateDocument_Application')
    CREATE INDEX IX_onboarding_CandidateDocument_Application ON onboarding.CandidateDocument(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.CandidateDocumentVersion', N'U') IS NULL
CREATE TABLE onboarding.CandidateDocumentVersion
(
    CandidateDocumentVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateDocumentId UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ObjectStorageUri nvarchar(1000)  NOT NULL,
    EncryptionKeyRef nvarchar(200)   NULL, -- kv://... reference to the envelope-encryption key, never a literal key
    FileName        nvarchar(260)    NOT NULL,
    MimeType        nvarchar(100)    NOT NULL,
    FileSizeBytes   bigint           NOT NULL,
    ContentHash     varbinary(32)    NOT NULL,
    MalwareScanStatus nvarchar(20)   NOT NULL DEFAULT ('Pending'),
    Classification  nvarchar(30)     NOT NULL DEFAULT ('Confidential'),
    UploadedByUserId UNIQUEIDENTIFIER NULL,
    UploadedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_CandidateDocumentVersion PRIMARY KEY CLUSTERED (CandidateDocumentVersionId),
    CONSTRAINT FK_CandDocumentVersion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_CandDocumentVersion_Document FOREIGN KEY (CandidateDocumentId) REFERENCES onboarding.CandidateDocument(CandidateDocumentId),
    CONSTRAINT CK_CandDocumentVersion_ScanStatus CHECK (MalwareScanStatus IN ('Pending','Clean','Infected','Failed')),
    CONSTRAINT CK_CandDocumentVersion_Classification CHECK (Classification IN ('Public','Internal','Confidential','Restricted'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_CandDocumentVersion')
    CREATE UNIQUE INDEX UQ_onboarding_CandDocumentVersion ON onboarding.CandidateDocumentVersion(CandidateDocumentId, VersionNumber) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.DocumentUploadRequest', N'U') IS NULL
CREATE TABLE onboarding.DocumentUploadRequest
(
    DocumentUploadRequestId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    DocumentTypeId  UNIQUEIDENTIFIER NOT NULL,
    RequestedByUserId UNIQUEIDENTIFIER NULL,
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Fulfilled, Cancelled, Expired
    CONSTRAINT PK_onboarding_DocumentUploadRequest PRIMARY KEY CLUSTERED (DocumentUploadRequestId),
    CONSTRAINT FK_DocUploadRequest_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DocUploadRequest_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_DocUploadRequest_DocType FOREIGN KEY (DocumentTypeId) REFERENCES ref.DocumentType(DocumentTypeId),
    CONSTRAINT CK_DocUploadRequest_Status CHECK (Status IN ('Pending','Fulfilled','Cancelled','Expired'))
);
GO

IF OBJECT_ID(N'onboarding.DocumentUploadToken', N'U') IS NULL
CREATE TABLE onboarding.DocumentUploadToken
(
    DocumentUploadTokenId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DocumentUploadRequestId UNIQUEIDENTIFIER NOT NULL,
    TokenHash       varbinary(32)    NOT NULL, -- SHA-256 of the token; the raw token is never stored
    Purpose         nvarchar(50)     NOT NULL DEFAULT ('DocumentUpload'),
    ExpiresAtUtc    datetime2(7)     NOT NULL,
    UsageCount      int              NOT NULL DEFAULT (0),
    MaxUsageCount   int              NOT NULL DEFAULT (1), -- single-use by default
    IsRevoked       bit              NOT NULL DEFAULT (0),
    RevokedAtUtc    datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_onboarding_DocumentUploadToken PRIMARY KEY CLUSTERED (DocumentUploadTokenId),
    CONSTRAINT FK_DocUploadToken_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DocUploadToken_Request FOREIGN KEY (DocumentUploadRequestId) REFERENCES onboarding.DocumentUploadRequest(DocumentUploadRequestId),
    CONSTRAINT CK_DocUploadToken_UsageCount CHECK (UsageCount <= MaxUsageCount)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_DocUploadToken_Hash')
    CREATE UNIQUE INDEX UQ_onboarding_DocUploadToken_Hash ON onboarding.DocumentUploadToken(TokenHash);
GO

IF OBJECT_ID(N'onboarding.DocumentValidationResult', N'U') IS NULL
CREATE TABLE onboarding.DocumentValidationResult
(
    DocumentValidationResultId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateDocumentVersionId UNIQUEIDENTIFIER NOT NULL,
    ValidationType  nvarchar(50)     NOT NULL, -- ExtensionCheck, MimeCheck, SizeCheck, MalwareScan
    IsValid         bit              NOT NULL,
    Details         nvarchar(500)    NULL,
    ValidatedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_onboarding_DocumentValidationResult PRIMARY KEY CLUSTERED (DocumentValidationResultId),
    CONSTRAINT FK_DocValidationResult_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DocValidationResult_Version FOREIGN KEY (CandidateDocumentVersionId) REFERENCES onboarding.CandidateDocumentVersion(CandidateDocumentVersionId)
);
GO

IF OBJECT_ID(N'onboarding.DocumentAccessLog', N'U') IS NULL
CREATE TABLE onboarding.DocumentAccessLog
(
    DocumentAccessLogId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateDocumentVersionId UNIQUEIDENTIFIER NOT NULL,
    AccessedByUserId UNIQUEIDENTIFIER NULL,
    AccessType      nvarchar(20)     NOT NULL, -- View, Download
    AccessedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_onboarding_DocumentAccessLog PRIMARY KEY CLUSTERED (DocumentAccessLogId),
    CONSTRAINT FK_DocAccessLog_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DocAccessLog_Version FOREIGN KEY (CandidateDocumentVersionId) REFERENCES onboarding.CandidateDocumentVersion(CandidateDocumentVersionId),
    CONSTRAINT CK_DocAccessLog_Type CHECK (AccessType IN ('View','Download'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_DocAccessLog_Version')
    CREATE INDEX IX_onboarding_DocAccessLog_Version ON onboarding.DocumentAccessLog(CandidateDocumentVersionId, AccessedAtUtc);
GO

IF OBJECT_ID(N'onboarding.DocumentRetentionHold', N'U') IS NULL
CREATE TABLE onboarding.DocumentRetentionHold
(
    DocumentRetentionHoldId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateDocumentId UNIQUEIDENTIFIER NOT NULL,
    HoldReason      nvarchar(500)    NOT NULL, -- e.g. legal hold reference — see docs/data-retention-and-privacy.md
    PlacedByUserId  UNIQUEIDENTIFIER NULL,
    PlacedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ReleasedAtUtc   datetime2(7)     NULL,
    ReleasedByUserId UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_onboarding_DocumentRetentionHold PRIMARY KEY CLUSTERED (DocumentRetentionHoldId),
    CONSTRAINT FK_DocRetentionHold_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DocRetentionHold_Document FOREIGN KEY (CandidateDocumentId) REFERENCES onboarding.CandidateDocument(CandidateDocumentId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_DocRetentionHold_Active')
    CREATE INDEX IX_onboarding_DocRetentionHold_Active ON onboarding.DocumentRetentionHold(CandidateDocumentId) WHERE ReleasedAtUtc IS NULL;
GO

PRINT N'03-create-tables.sql PART 12 (onboarding: documents) complete.';
GO

-- ============================================================================
-- PART 13 — onboarding schema, Section D: verification
-- ============================================================================

IF OBJECT_ID(N'onboarding.VerificationCase', N'U') IS NULL
CREATE TABLE onboarding.VerificationCase
(
    VerificationCaseId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Open'), -- Open, InProgress, Completed, Cancelled
    OpenedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ClosedAtUtc     datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_VerificationCase PRIMARY KEY CLUSTERED (VerificationCaseId),
    CONSTRAINT FK_VerificationCase_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_VerificationCase_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_VerificationCase_WorkflowInstance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT CK_VerificationCase_Status CHECK (Status IN ('Open','InProgress','Completed','Cancelled'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_VerificationCase')
    CREATE UNIQUE INDEX UQ_onboarding_VerificationCase ON onboarding.VerificationCase(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.VerificationCheck', N'U') IS NULL
CREATE TABLE onboarding.VerificationCheck
(
    VerificationCheckId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    VerificationCaseId UNIQUEIDENTIFIER NOT NULL,
    VerificationTypeId UNIQUEIDENTIFIER NOT NULL,
    VerificationStatusId UNIQUEIDENTIFIER NOT NULL,
    InitiatedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_VerificationCheck PRIMARY KEY CLUSTERED (VerificationCheckId),
    CONSTRAINT FK_VerificationCheck_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_VerificationCheck_Case FOREIGN KEY (VerificationCaseId) REFERENCES onboarding.VerificationCase(VerificationCaseId),
    CONSTRAINT FK_VerificationCheck_Type FOREIGN KEY (VerificationTypeId) REFERENCES ref.VerificationType(VerificationTypeId),
    CONSTRAINT FK_VerificationCheck_Status FOREIGN KEY (VerificationStatusId) REFERENCES ref.VerificationStatus(VerificationStatusId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_VerificationCheck_Case')
    CREATE INDEX IX_onboarding_VerificationCheck_Case ON onboarding.VerificationCheck(VerificationCaseId);
GO

IF OBJECT_ID(N'onboarding.VerificationProviderRequest', N'U') IS NULL
CREATE TABLE onboarding.VerificationProviderRequest
(
    VerificationProviderRequestId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    VerificationCheckId UNIQUEIDENTIFIER NOT NULL,
    ProviderName    nvarchar(100)    NOT NULL, -- see mcp/servers/background-verification for the MCP integration
    ExternalRequestId nvarchar(200)  NULL, -- opaque provider reference only, never a credential
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Status          nvarchar(20)     NOT NULL DEFAULT ('Sent'), -- Sent, Acknowledged, Failed
    CONSTRAINT PK_onboarding_VerificationProviderRequest PRIMARY KEY CLUSTERED (VerificationProviderRequestId),
    CONSTRAINT FK_VerifProviderRequest_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_VerifProviderRequest_Check FOREIGN KEY (VerificationCheckId) REFERENCES onboarding.VerificationCheck(VerificationCheckId),
    CONSTRAINT CK_VerifProviderRequest_Status CHECK (Status IN ('Sent','Acknowledged','Failed'))
);
GO

IF OBJECT_ID(N'onboarding.VerificationProviderResponse', N'U') IS NULL
CREATE TABLE onboarding.VerificationProviderResponse
(
    VerificationProviderResponseId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    VerificationProviderRequestId UNIQUEIDENTIFIER NOT NULL,
    ReceivedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    RawResponseObjectStorageUri nvarchar(1000) NULL, -- raw provider payload reference, never inlined (may contain PII)
    ResultSummary   nvarchar(500)    NULL,
    CONSTRAINT PK_onboarding_VerificationProviderResponse PRIMARY KEY CLUSTERED (VerificationProviderResponseId),
    CONSTRAINT FK_VerifProviderResponse_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_VerifProviderResponse_Request FOREIGN KEY (VerificationProviderRequestId) REFERENCES onboarding.VerificationProviderRequest(VerificationProviderRequestId)
);
GO

IF OBJECT_ID(N'onboarding.VerificationResult', N'U') IS NULL
CREATE TABLE onboarding.VerificationResult
(
    VerificationResultId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    VerificationCheckId UNIQUEIDENTIFIER NOT NULL,
    Outcome         nvarchar(20)     NOT NULL, -- Verified, Discrepant, Inconclusive
    DeterminedByUserId UNIQUEIDENTIFIER NULL, -- human confirmation; AI may draft ResultSummary but never sets Outcome alone
    DeterminedAtUtc datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Notes           nvarchar(1000)   NULL,
    CONSTRAINT PK_onboarding_VerificationResult PRIMARY KEY CLUSTERED (VerificationResultId),
    CONSTRAINT FK_VerificationResult_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_VerificationResult_Check FOREIGN KEY (VerificationCheckId) REFERENCES onboarding.VerificationCheck(VerificationCheckId),
    CONSTRAINT CK_VerificationResult_Outcome CHECK (Outcome IN ('Verified','Discrepant','Inconclusive'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_VerificationResult')
    CREATE UNIQUE INDEX UQ_onboarding_VerificationResult ON onboarding.VerificationResult(VerificationCheckId);
GO

IF OBJECT_ID(N'onboarding.VerificationStatusHistory', N'U') IS NULL
CREATE TABLE onboarding.VerificationStatusHistory
(
    VerificationStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    VerificationCheckId UNIQUEIDENTIFIER NOT NULL,
    FromStatusId    UNIQUEIDENTIFIER NULL,
    ToStatusId      UNIQUEIDENTIFIER NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_onboarding_VerificationStatusHistory PRIMARY KEY CLUSTERED (VerificationStatusHistoryId),
    CONSTRAINT FK_VerificationStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_VerificationStatusHistory_Check FOREIGN KEY (VerificationCheckId) REFERENCES onboarding.VerificationCheck(VerificationCheckId),
    CONSTRAINT FK_VerificationStatusHistory_From FOREIGN KEY (FromStatusId) REFERENCES ref.VerificationStatus(VerificationStatusId),
    CONSTRAINT FK_VerificationStatusHistory_To FOREIGN KEY (ToStatusId) REFERENCES ref.VerificationStatus(VerificationStatusId)
);
GO

PRINT N'03-create-tables.sql PART 13 (onboarding: verification) complete.';
GO

-- ============================================================================
-- PART 14 — onboarding schema, Section E: discrepancies. AI may draft a
-- suggestion (Discrepancy.IsAiSuggested); only a human resolves/closes one
-- (DiscrepancyResolution.ResolvedByUserId is NOT NULL and DiscrepancyApproval
-- is required before Discrepancy.DiscrepancyStatusId can move to a terminal
-- state — enforced by onboarding.usp_ResolveDiscrepancy).
-- ============================================================================

IF OBJECT_ID(N'onboarding.Discrepancy', N'U') IS NULL
CREATE TABLE onboarding.Discrepancy
(
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    VerificationCheckId UNIQUEIDENTIFIER NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyTypeId UNIQUEIDENTIFIER NOT NULL,
    DiscrepancySeverityId UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyStatusId UNIQUEIDENTIFIER NOT NULL,
    Source          nvarchar(50)     NOT NULL DEFAULT ('Manual'), -- Manual, AiSuggested, VerificationProvider
    IsAiSuggested   bit              NOT NULL DEFAULT (0),
    Description     nvarchar(2000)   NOT NULL,
    OwnerUserId     UNIQUEIDENTIFIER NULL,
    DueAtUtc        datetime2(7)     NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_Discrepancy PRIMARY KEY CLUSTERED (DiscrepancyId),
    CONSTRAINT FK_Discrepancy_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Discrepancy_VerificationCheck FOREIGN KEY (VerificationCheckId) REFERENCES onboarding.VerificationCheck(VerificationCheckId),
    CONSTRAINT FK_Discrepancy_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_Discrepancy_Type FOREIGN KEY (DiscrepancyTypeId) REFERENCES ref.DiscrepancyType(DiscrepancyTypeId),
    CONSTRAINT FK_Discrepancy_Severity FOREIGN KEY (DiscrepancySeverityId) REFERENCES ref.DiscrepancySeverity(DiscrepancySeverityId),
    CONSTRAINT FK_Discrepancy_Status FOREIGN KEY (DiscrepancyStatusId) REFERENCES ref.DiscrepancyStatus(DiscrepancyStatusId),
    CONSTRAINT FK_Discrepancy_WorkflowInstance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT FK_Discrepancy_Owner FOREIGN KEY (OwnerUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_Discrepancy_Source CHECK (Source IN ('Manual','AiSuggested','VerificationProvider'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_Discrepancy_Application')
    CREATE INDEX IX_onboarding_Discrepancy_Application ON onboarding.Discrepancy(CandidateApplicationId) WHERE IsDeleted = 0;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_onboarding_Discrepancy_TenantDue')
    CREATE INDEX IX_onboarding_Discrepancy_TenantDue ON onboarding.Discrepancy(TenantId, DueAtUtc) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'onboarding.DiscrepancyEvidence', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyEvidence
(
    DiscrepancyEvidenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL,
    EvidenceSource  nvarchar(100)    NOT NULL, -- CandidateDocument, VerificationProviderResponse, GreenFormFieldValue, ...
    EvidenceReferenceId UNIQUEIDENTIFIER NULL, -- polymorphic pointer; no FK (source table varies)
    EvidenceSnippet nvarchar(500)    NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_onboarding_DiscrepancyEvidence PRIMARY KEY CLUSTERED (DiscrepancyEvidenceId),
    CONSTRAINT FK_DiscrepancyEvidence_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyEvidence_Discrepancy FOREIGN KEY (DiscrepancyId) REFERENCES onboarding.Discrepancy(DiscrepancyId)
);
GO

IF OBJECT_ID(N'onboarding.DiscrepancyResolution', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyResolution
(
    DiscrepancyResolutionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL,
    ResolutionType  nvarchar(50)     NOT NULL, -- Cleared, Confirmed, WaivedWithException
    CorrectiveAction nvarchar(1000)  NULL,
    HrDecisionNotes nvarchar(1000)   NULL,
    ResolvedByUserId UNIQUEIDENTIFIER NOT NULL, -- always a human; never AI, per non-negotiable rules
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL, -- resolution/closure requires an approval record
    ResolvedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_onboarding_DiscrepancyResolution PRIMARY KEY CLUSTERED (DiscrepancyResolutionId),
    CONSTRAINT FK_DiscrepancyResolution_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyResolution_Discrepancy FOREIGN KEY (DiscrepancyId) REFERENCES onboarding.Discrepancy(DiscrepancyId),
    CONSTRAINT FK_DiscrepancyResolution_ResolvedBy FOREIGN KEY (ResolvedByUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT FK_DiscrepancyResolution_Approval FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId),
    CONSTRAINT CK_DiscrepancyResolution_Type CHECK (ResolutionType IN ('Cleared','Confirmed','WaivedWithException'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_DiscrepancyResolution')
    CREATE UNIQUE INDEX UQ_onboarding_DiscrepancyResolution ON onboarding.DiscrepancyResolution(DiscrepancyId);
GO

IF OBJECT_ID(N'onboarding.DiscrepancyApproval', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyApproval
(
    DiscrepancyApprovalId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'),
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CONSTRAINT PK_onboarding_DiscrepancyApproval PRIMARY KEY CLUSTERED (DiscrepancyApprovalId),
    CONSTRAINT FK_DiscrepancyApproval_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyApproval_Discrepancy FOREIGN KEY (DiscrepancyId) REFERENCES onboarding.Discrepancy(DiscrepancyId),
    CONSTRAINT FK_DiscrepancyApproval_Request FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId),
    CONSTRAINT CK_DiscrepancyApproval_Status CHECK (Status IN ('Pending','Approved','Rejected'))
);
GO

IF OBJECT_ID(N'onboarding.DiscrepancyCommunication', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyCommunication
(
    DiscrepancyCommunicationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL,
    NotificationTemplateId UNIQUEIDENTIFIER NULL,
    NotificationChannelId UNIQUEIDENTIFIER NOT NULL,
    SentAtUtc       datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    DeliveryStatus  nvarchar(20)     NOT NULL DEFAULT ('Sent'),
    CONSTRAINT PK_onboarding_DiscrepancyCommunication PRIMARY KEY CLUSTERED (DiscrepancyCommunicationId),
    CONSTRAINT FK_DiscrepancyCommunication_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyCommunication_Discrepancy FOREIGN KEY (DiscrepancyId) REFERENCES onboarding.Discrepancy(DiscrepancyId),
    CONSTRAINT FK_DiscrepancyCommunication_Template FOREIGN KEY (NotificationTemplateId) REFERENCES ref.NotificationTemplate(NotificationTemplateId),
    CONSTRAINT FK_DiscrepancyCommunication_Channel FOREIGN KEY (NotificationChannelId) REFERENCES ref.NotificationChannel(NotificationChannelId),
    CONSTRAINT CK_DiscrepancyCommunication_DeliveryStatus CHECK (DeliveryStatus IN ('Sent','Delivered','Failed'))
);
GO

IF OBJECT_ID(N'onboarding.DiscrepancyReport', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyReport
(
    DiscrepancyReportId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    GeneratedByUserId UNIQUEIDENTIFIER NULL,
    GeneratedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ObjectStorageUri nvarchar(1000)  NULL, -- generated PDF/summary reference
    CONSTRAINT PK_onboarding_DiscrepancyReport PRIMARY KEY CLUSTERED (DiscrepancyReportId),
    CONSTRAINT FK_DiscrepancyReport_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyReport_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId)
);
GO

IF OBJECT_ID(N'onboarding.DiscrepancyReportItem', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyReportItem
(
    DiscrepancyReportItemId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyReportId UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_onboarding_DiscrepancyReportItem PRIMARY KEY CLUSTERED (DiscrepancyReportItemId),
    CONSTRAINT FK_DiscrepancyReportItem_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyReportItem_Report FOREIGN KEY (DiscrepancyReportId) REFERENCES onboarding.DiscrepancyReport(DiscrepancyReportId),
    CONSTRAINT FK_DiscrepancyReportItem_Discrepancy FOREIGN KEY (DiscrepancyId) REFERENCES onboarding.Discrepancy(DiscrepancyId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_onboarding_DiscrepancyReportItem')
    CREATE UNIQUE INDEX UQ_onboarding_DiscrepancyReportItem ON onboarding.DiscrepancyReportItem(DiscrepancyReportId, DiscrepancyId);
GO

IF OBJECT_ID(N'onboarding.DiscrepancyStatusHistory', N'U') IS NULL
CREATE TABLE onboarding.DiscrepancyStatusHistory
(
    DiscrepancyStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    DiscrepancyId   UNIQUEIDENTIFIER NOT NULL,
    FromStatusId    UNIQUEIDENTIFIER NULL,
    ToStatusId      UNIQUEIDENTIFIER NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_onboarding_DiscrepancyStatusHistory PRIMARY KEY CLUSTERED (DiscrepancyStatusHistoryId),
    CONSTRAINT FK_DiscrepancyStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_DiscrepancyStatusHistory_Discrepancy FOREIGN KEY (DiscrepancyId) REFERENCES onboarding.Discrepancy(DiscrepancyId),
    CONSTRAINT FK_DiscrepancyStatusHistory_From FOREIGN KEY (FromStatusId) REFERENCES ref.DiscrepancyStatus(DiscrepancyStatusId),
    CONSTRAINT FK_DiscrepancyStatusHistory_To FOREIGN KEY (ToStatusId) REFERENCES ref.DiscrepancyStatus(DiscrepancyStatusId)
);
GO

PRINT N'03-create-tables.sql PART 14 (onboarding: discrepancies) complete.';
GO

-- ============================================================================
-- PART 15 — employee schema. Employee creation is the single most gated
-- transition in the platform: employee.usp_CreateEmployeeFromCandidate (see
-- docs/stored-procedure-catalog.md) refuses to run unless offer acceptance,
-- Green Form completion, verification status, discrepancy status, and an
-- EmployeeConversionApproval are all confirmed — enforced in the procedure,
-- with EmployeeConversionChecklist as defense-in-depth evidence.
-- ============================================================================

IF OBJECT_ID(N'employee.EmployeeConversion', N'U') IS NULL
CREATE TABLE employee.EmployeeConversion
(
    EmployeeConversionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CandidateApplicationId UNIQUEIDENTIFIER NOT NULL,
    OfferId         UNIQUEIDENTIFIER NOT NULL,
    WorkflowInstanceId UNIQUEIDENTIFIER NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Eligible, Approved, Converted, Blocked
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ConvertedAtUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_employee_EmployeeConversion PRIMARY KEY CLUSTERED (EmployeeConversionId),
    CONSTRAINT FK_EmployeeConversion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeConversion_Application FOREIGN KEY (CandidateApplicationId) REFERENCES recruitment.CandidateApplication(CandidateApplicationId),
    CONSTRAINT FK_EmployeeConversion_Offer FOREIGN KEY (OfferId) REFERENCES offer.Offer(OfferId),
    CONSTRAINT FK_EmployeeConversion_WorkflowInstance FOREIGN KEY (WorkflowInstanceId) REFERENCES workflow.WorkflowInstance(WorkflowInstanceId),
    CONSTRAINT CK_EmployeeConversion_Status CHECK (Status IN ('Pending','Eligible','Approved','Converted','Blocked'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_EmployeeConversion')
    CREATE UNIQUE INDEX UQ_employee_EmployeeConversion ON employee.EmployeeConversion(CandidateApplicationId) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'employee.EmployeeConversionChecklist', N'U') IS NULL
CREATE TABLE employee.EmployeeConversionChecklist
(
    EmployeeConversionChecklistId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeConversionId UNIQUEIDENTIFIER NOT NULL,
    CheckName       nvarchar(100)    NOT NULL, -- OfferAccepted, GreenFormCompleted, VerificationCleared, DiscrepanciesResolved
    IsSatisfied     bit              NOT NULL DEFAULT (0),
    EvidenceReferenceId UNIQUEIDENTIFIER NULL, -- polymorphic pointer to the satisfying record; no FK (source table varies)
    CheckedAtUtc    datetime2(7)     NULL,
    CONSTRAINT PK_employee_EmployeeConversionChecklist PRIMARY KEY CLUSTERED (EmployeeConversionChecklistId),
    CONSTRAINT FK_EmployeeConvChecklist_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeConvChecklist_Conversion FOREIGN KEY (EmployeeConversionId) REFERENCES employee.EmployeeConversion(EmployeeConversionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_EmployeeConvChecklist')
    CREATE UNIQUE INDEX UQ_employee_EmployeeConvChecklist ON employee.EmployeeConversionChecklist(EmployeeConversionId, CheckName);
GO

IF OBJECT_ID(N'employee.EmployeeConversionApproval', N'U') IS NULL
CREATE TABLE employee.EmployeeConversionApproval
(
    EmployeeConversionApprovalId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeConversionId UNIQUEIDENTIFIER NOT NULL,
    ApprovalRequestId UNIQUEIDENTIFIER NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'),
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CONSTRAINT PK_employee_EmployeeConversionApproval PRIMARY KEY CLUSTERED (EmployeeConversionApprovalId),
    CONSTRAINT FK_EmployeeConvApproval_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeConvApproval_Conversion FOREIGN KEY (EmployeeConversionId) REFERENCES employee.EmployeeConversion(EmployeeConversionId),
    CONSTRAINT FK_EmployeeConvApproval_Request FOREIGN KEY (ApprovalRequestId) REFERENCES workflow.ApprovalRequest(ApprovalRequestId),
    CONSTRAINT CK_EmployeeConvApproval_Status CHECK (Status IN ('Pending','Approved','Rejected'))
);
GO

IF OBJECT_ID(N'employee.Employee', N'U') IS NULL
CREATE TABLE employee.Employee
(
    EmployeeId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeConversionId UNIQUEIDENTIFIER NOT NULL, -- always created via conversion — no direct-create path
    CandidateId     UNIQUEIDENTIFIER NOT NULL, -- retained: candidate history is never deleted after conversion
    EmployeeCode    nvarchar(50)     NOT NULL, -- the human-facing "Employee ID", from ref.NumberingRule
    FirstName       nvarchar(100)    NOT NULL,
    LastName        nvarchar(100)    NOT NULL,
    EmployeeStatusId UNIQUEIDENTIFIER NOT NULL,
    DesignationId   UNIQUEIDENTIFIER NULL,
    JobGradeId      UNIQUEIDENTIFIER NULL,
    EmploymentTypeId UNIQUEIDENTIFIER NULL,
    DateOfJoining   date             NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    UpdatedAtUtc    datetime2(7)     NULL,
    UpdatedByUserId UNIQUEIDENTIFIER NULL,
    IsDeleted       bit              NOT NULL DEFAULT (0),
    DeletedAtUtc    datetime2(7)     NULL,
    DeletedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_employee_Employee PRIMARY KEY CLUSTERED (EmployeeId),
    CONSTRAINT FK_Employee_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_Employee_Conversion FOREIGN KEY (EmployeeConversionId) REFERENCES employee.EmployeeConversion(EmployeeConversionId),
    CONSTRAINT FK_Employee_Candidate FOREIGN KEY (CandidateId) REFERENCES recruitment.Candidate(CandidateId),
    CONSTRAINT FK_Employee_Status FOREIGN KEY (EmployeeStatusId) REFERENCES ref.EmployeeStatus(EmployeeStatusId),
    CONSTRAINT FK_Employee_Designation FOREIGN KEY (DesignationId) REFERENCES org.Designation(DesignationId),
    CONSTRAINT FK_Employee_Grade FOREIGN KEY (JobGradeId) REFERENCES org.JobGrade(JobGradeId),
    CONSTRAINT FK_Employee_EmploymentType FOREIGN KEY (EmploymentTypeId) REFERENCES ref.EmploymentType(EmploymentTypeId)
);
GO
-- Idempotency for employee creation: one Employee row per EmployeeConversionId,
-- enforced here as well as by employee.usp_CreateEmployeeFromCandidate's
-- existence check under UPDLOCK — belt-and-braces per non-negotiable rule
-- "Employee creation must be idempotent."
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_Employee_Conversion')
    CREATE UNIQUE INDEX UQ_employee_Employee_Conversion ON employee.Employee(EmployeeConversionId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_Employee_Code')
    CREATE UNIQUE INDEX UQ_employee_Employee_Code ON employee.Employee(TenantId, EmployeeCode) WHERE IsDeleted = 0;
GO

IF OBJECT_ID(N'employee.EmployeeIdRegistry', N'U') IS NULL
CREATE TABLE employee.EmployeeIdRegistry
(
    EmployeeIdRegistryId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeCode    nvarchar(50)     NOT NULL, -- reserved the instant it's issued, before the Employee row commits, to guarantee uniqueness under concurrency
    EmployeeConversionId UNIQUEIDENTIFIER NOT NULL,
    IssuedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_employee_EmployeeIdRegistry PRIMARY KEY CLUSTERED (EmployeeIdRegistryId),
    CONSTRAINT FK_EmployeeIdRegistry_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeIdRegistry_Conversion FOREIGN KEY (EmployeeConversionId) REFERENCES employee.EmployeeConversion(EmployeeConversionId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_EmployeeIdRegistry')
    CREATE UNIQUE INDEX UQ_employee_EmployeeIdRegistry ON employee.EmployeeIdRegistry(TenantId, EmployeeCode);
GO

IF OBJECT_ID(N'employee.EmployeeStatusHistory', N'U') IS NULL
CREATE TABLE employee.EmployeeStatusHistory
(
    EmployeeStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeId      UNIQUEIDENTIFIER NOT NULL,
    FromEmployeeStatusId UNIQUEIDENTIFIER NULL,
    ToEmployeeStatusId UNIQUEIDENTIFIER NOT NULL,
    ChangedByUserId UNIQUEIDENTIFIER NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Reason          nvarchar(500)    NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_employee_EmployeeStatusHistory PRIMARY KEY CLUSTERED (EmployeeStatusHistoryId),
    CONSTRAINT FK_EmployeeStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeStatusHistory_Employee FOREIGN KEY (EmployeeId) REFERENCES employee.Employee(EmployeeId),
    CONSTRAINT FK_EmployeeStatusHistory_From FOREIGN KEY (FromEmployeeStatusId) REFERENCES ref.EmployeeStatus(EmployeeStatusId),
    CONSTRAINT FK_EmployeeStatusHistory_To FOREIGN KEY (ToEmployeeStatusId) REFERENCES ref.EmployeeStatus(EmployeeStatusId)
);
GO

IF OBJECT_ID(N'employee.EmployeeOrganizationAssignment', N'U') IS NULL
CREATE TABLE employee.EmployeeOrganizationAssignment
(
    EmployeeOrganizationAssignmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeId      UNIQUEIDENTIFIER NOT NULL,
    DepartmentId    UNIQUEIDENTIFIER NULL,
    BusinessUnitId  UNIQUEIDENTIFIER NULL,
    LocationId      UNIQUEIDENTIFIER NULL,
    CostCenterId    UNIQUEIDENTIFIER NULL,
    EffectiveFromUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_employee_EmployeeOrganizationAssignment PRIMARY KEY CLUSTERED (EmployeeOrganizationAssignmentId),
    CONSTRAINT FK_EmployeeOrgAssignment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeOrgAssignment_Employee FOREIGN KEY (EmployeeId) REFERENCES employee.Employee(EmployeeId),
    CONSTRAINT FK_EmployeeOrgAssignment_Department FOREIGN KEY (DepartmentId) REFERENCES org.Department(DepartmentId),
    CONSTRAINT FK_EmployeeOrgAssignment_BusinessUnit FOREIGN KEY (BusinessUnitId) REFERENCES org.BusinessUnit(BusinessUnitId),
    CONSTRAINT FK_EmployeeOrgAssignment_Location FOREIGN KEY (LocationId) REFERENCES org.Location(LocationId),
    CONSTRAINT FK_EmployeeOrgAssignment_CostCenter FOREIGN KEY (CostCenterId) REFERENCES org.CostCenter(CostCenterId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_employee_EmployeeOrgAssignment_Active')
    CREATE INDEX IX_employee_EmployeeOrgAssignment_Active ON employee.EmployeeOrganizationAssignment(EmployeeId) WHERE EffectiveToUtc IS NULL;
GO

IF OBJECT_ID(N'employee.EmployeeManagerAssignment', N'U') IS NULL
CREATE TABLE employee.EmployeeManagerAssignment
(
    EmployeeManagerAssignmentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeId      UNIQUEIDENTIFIER NOT NULL,
    ManagerEmployeeId UNIQUEIDENTIFIER NOT NULL,
    EffectiveFromUtc datetime2(7)    NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveToUtc  datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_employee_EmployeeManagerAssignment PRIMARY KEY CLUSTERED (EmployeeManagerAssignmentId),
    CONSTRAINT FK_EmployeeManagerAssignment_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeManagerAssignment_Employee FOREIGN KEY (EmployeeId) REFERENCES employee.Employee(EmployeeId),
    CONSTRAINT FK_EmployeeManagerAssignment_Manager FOREIGN KEY (ManagerEmployeeId) REFERENCES employee.Employee(EmployeeId),
    CONSTRAINT CK_EmployeeManagerAssignment_NotSelf CHECK (EmployeeId <> ManagerEmployeeId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_EmployeeManagerAssignment_Active')
    CREATE UNIQUE INDEX UQ_employee_EmployeeManagerAssignment_Active ON employee.EmployeeManagerAssignment(EmployeeId) WHERE EffectiveToUtc IS NULL;
GO

IF OBJECT_ID(N'employee.EmployeeIntegrationMapping', N'U') IS NULL
CREATE TABLE employee.EmployeeIntegrationMapping
(
    EmployeeIntegrationMappingId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeId      UNIQUEIDENTIFIER NOT NULL,
    ExternalSystemCode nvarchar(100) NOT NULL, -- HRMS, Payroll, ITProvisioning, ...
    ExternalEntityId nvarchar(200)   NOT NULL,
    SyncedAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_employee_EmployeeIntegrationMapping PRIMARY KEY CLUSTERED (EmployeeIntegrationMappingId),
    CONSTRAINT FK_EmployeeIntegrationMapping_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeIntegrationMapping_Employee FOREIGN KEY (EmployeeId) REFERENCES employee.Employee(EmployeeId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_employee_EmployeeIntegrationMapping')
    CREATE UNIQUE INDEX UQ_employee_EmployeeIntegrationMapping ON employee.EmployeeIntegrationMapping(EmployeeId, ExternalSystemCode);
GO

IF OBJECT_ID(N'employee.EmployeeProvisioningRequest', N'U') IS NULL
CREATE TABLE employee.EmployeeProvisioningRequest
(
    EmployeeProvisioningRequestId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeId      UNIQUEIDENTIFIER NOT NULL,
    ProvisioningType nvarchar(50)    NOT NULL, -- ItAccess, PayrollSetup, HrmsRecord, ...
    Status          nvarchar(20)     NOT NULL DEFAULT ('Requested'), -- Requested, InProgress, Completed, Failed
    RequestedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_employee_EmployeeProvisioningRequest PRIMARY KEY CLUSTERED (EmployeeProvisioningRequestId),
    CONSTRAINT FK_EmployeeProvisioningRequest_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeProvisioningRequest_Employee FOREIGN KEY (EmployeeId) REFERENCES employee.Employee(EmployeeId),
    CONSTRAINT CK_EmployeeProvisioningRequest_Status CHECK (Status IN ('Requested','InProgress','Completed','Failed'))
);
GO

IF OBJECT_ID(N'employee.EmployeeProvisioningStatusHistory', N'U') IS NULL
CREATE TABLE employee.EmployeeProvisioningStatusHistory
(
    EmployeeProvisioningStatusHistoryId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EmployeeProvisioningRequestId UNIQUEIDENTIFIER NOT NULL,
    FromStatus      nvarchar(20)     NULL,
    ToStatus        nvarchar(20)     NOT NULL,
    ChangedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    Details         nvarchar(500)    NULL,
    CONSTRAINT PK_employee_EmployeeProvisioningStatusHistory PRIMARY KEY CLUSTERED (EmployeeProvisioningStatusHistoryId),
    CONSTRAINT FK_EmployeeProvStatusHistory_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_EmployeeProvStatusHistory_Request FOREIGN KEY (EmployeeProvisioningRequestId) REFERENCES employee.EmployeeProvisioningRequest(EmployeeProvisioningRequestId)
);
GO

PRINT N'03-create-tables.sql PART 15 (employee) complete.';
GO

-- ============================================================================
-- PART 16 — integration schema (transactional outbox pattern, inbox
-- idempotency, external system config/mapping, webhook delivery). bigint
-- IDENTITY is used for OutboxMessage/InboxMessage per the high-volume
-- append-only exception in the conventions block at the top of this file.
-- ============================================================================

IF OBJECT_ID(N'integration.OutboxMessage', N'U') IS NULL
CREATE TABLE integration.OutboxMessage
(
    OutboxMessageId bigint IDENTITY(1,1) NOT NULL,
    MessageId       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(), -- stable id exposed to consumers; OutboxMessageId is internal ordering only
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    EventType       nvarchar(150)    NOT NULL,
    PayloadVersion  int              NOT NULL DEFAULT (1),
    PayloadJson     nvarchar(max)    NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Processing, Processed, Failed, DeadLettered
    RetryCount      int              NOT NULL DEFAULT (0),
    MaxRetryCount   int              NOT NULL DEFAULT (5),
    VisibleAfterUtc datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(), -- defer/backoff time
    LastErrorMessage nvarchar(1000)  NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ProcessedAtUtc  datetime2(7)     NULL,
    CONSTRAINT PK_integration_OutboxMessage PRIMARY KEY CLUSTERED (OutboxMessageId),
    CONSTRAINT FK_OutboxMessage_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_OutboxMessage_Status CHECK (Status IN ('Pending','Processing','Processed','Failed','DeadLettered')),
    CONSTRAINT CK_OutboxMessage_PayloadJson CHECK (ISJSON(PayloadJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_integration_OutboxMessage_MessageId')
    CREATE UNIQUE INDEX UQ_integration_OutboxMessage_MessageId ON integration.OutboxMessage(MessageId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_integration_OutboxMessage_Dispatch')
    CREATE INDEX IX_integration_OutboxMessage_Dispatch ON integration.OutboxMessage(Status, VisibleAfterUtc) WHERE Status IN ('Pending','Failed');
GO

IF OBJECT_ID(N'integration.InboxMessage', N'U') IS NULL
CREATE TABLE integration.InboxMessage
(
    InboxMessageId  bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ExternalMessageId nvarchar(200)  NOT NULL, -- source system's message/event id — the idempotency key
    SourceSystemCode nvarchar(100)  NOT NULL,
    EventType       nvarchar(150)    NOT NULL,
    PayloadJson     nvarchar(max)    NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Received'), -- Received, Processed, Failed, Duplicate
    ReceivedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ProcessedAtUtc  datetime2(7)     NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_integration_InboxMessage PRIMARY KEY CLUSTERED (InboxMessageId),
    CONSTRAINT FK_InboxMessage_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_InboxMessage_Status CHECK (Status IN ('Received','Processed','Failed','Duplicate')),
    CONSTRAINT CK_InboxMessage_PayloadJson CHECK (PayloadJson IS NULL OR ISJSON(PayloadJson) = 1)
);
GO
-- The idempotency guarantee: a second delivery of the same ExternalMessageId
-- from the same source violates this unique index; integration.usp_RegisterInboxMessage
-- catches 2627/2601 and returns Status='Duplicate' rather than reprocessing.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_integration_InboxMessage')
    CREATE UNIQUE INDEX UQ_integration_InboxMessage ON integration.InboxMessage(SourceSystemCode, ExternalMessageId);
GO

IF OBJECT_ID(N'integration.IdempotencyKey', N'U') IS NULL
CREATE TABLE integration.IdempotencyKey
(
    IdempotencyKeyId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    IdempotencyKeyValue nvarchar(200) NOT NULL, -- client-supplied Idempotency-Key header value, per docs/04-api/api-standards.md
    RequestPath     nvarchar(300)    NOT NULL,
    ResponseStatusCode int          NULL,
    ResponseBodyHash varbinary(32)  NULL, -- hash only, not the full response body
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ExpiresAtUtc    datetime2(7)     NOT NULL,
    CONSTRAINT PK_integration_IdempotencyKey PRIMARY KEY CLUSTERED (IdempotencyKeyId),
    CONSTRAINT FK_IdempotencyKey_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_integration_IdempotencyKey')
    CREATE UNIQUE INDEX UQ_integration_IdempotencyKey ON integration.IdempotencyKey(TenantId, RequestPath, IdempotencyKeyValue);
GO

IF OBJECT_ID(N'integration.ExternalSystem', N'U') IS NULL
CREATE TABLE integration.ExternalSystem
(
    ExternalSystemId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    SystemCode      nvarchar(100)    NOT NULL, -- HRMS, Payroll, ITProvisioning, ESignature, BackgroundVerification, ...
    SystemName      nvarchar(200)    NOT NULL,
    IntegrationConfigurationId UNIQUEIDENTIFIER NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_integration_ExternalSystem PRIMARY KEY CLUSTERED (ExternalSystemId),
    CONSTRAINT FK_ExternalSystem_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ExternalSystem_Config FOREIGN KEY (IntegrationConfigurationId) REFERENCES ref.IntegrationConfiguration(IntegrationConfigurationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_integration_ExternalSystem')
    CREATE UNIQUE INDEX UQ_integration_ExternalSystem ON integration.ExternalSystem(TenantId, SystemCode);
GO

IF OBJECT_ID(N'integration.ExternalEntityMapping', N'U') IS NULL
CREATE TABLE integration.ExternalEntityMapping
(
    ExternalEntityMappingId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ExternalSystemId UNIQUEIDENTIFIER NOT NULL,
    EntityType      nvarchar(100)    NOT NULL, -- Employee, Candidate, JobRequisition, ...
    LocalEntityId   UNIQUEIDENTIFIER NOT NULL, -- polymorphic pointer; no FK (source table varies by EntityType)
    ExternalEntityId nvarchar(200)   NOT NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_integration_ExternalEntityMapping PRIMARY KEY CLUSTERED (ExternalEntityMappingId),
    CONSTRAINT FK_ExternalEntityMapping_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_ExternalEntityMapping_System FOREIGN KEY (ExternalSystemId) REFERENCES integration.ExternalSystem(ExternalSystemId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_integration_ExternalEntityMapping')
    CREATE UNIQUE INDEX UQ_integration_ExternalEntityMapping ON integration.ExternalEntityMapping(ExternalSystemId, EntityType, LocalEntityId);
GO

IF OBJECT_ID(N'integration.IntegrationExecutionLog', N'U') IS NULL
CREATE TABLE integration.IntegrationExecutionLog
(
    IntegrationExecutionLogId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ExternalSystemId UNIQUEIDENTIFIER NULL,
    OperationName   nvarchar(150)    NOT NULL,
    Status          nvarchar(20)     NOT NULL, -- Succeeded, Failed, TimedOut, CircuitOpen
    DurationMs      int              NULL,
    ErrorMessage    nvarchar(1000)   NULL, -- redacted — never a raw payload/PII, see logging-and-redaction-standard.md
    CorrelationId   UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_integration_IntegrationExecutionLog PRIMARY KEY CLUSTERED (IntegrationExecutionLogId),
    CONSTRAINT FK_IntegrationExecutionLog_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_IntegrationExecutionLog_System FOREIGN KEY (ExternalSystemId) REFERENCES integration.ExternalSystem(ExternalSystemId),
    CONSTRAINT CK_IntegrationExecutionLog_Status CHECK (Status IN ('Succeeded','Failed','TimedOut','CircuitOpen'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_integration_ExecutionLog_System')
    CREATE INDEX IX_integration_ExecutionLog_System ON integration.IntegrationExecutionLog(ExternalSystemId, OccurredAtUtc);
GO

IF OBJECT_ID(N'integration.WebhookSubscription', N'U') IS NULL
CREATE TABLE integration.WebhookSubscription
(
    WebhookSubscriptionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ExternalSystemId UNIQUEIDENTIFIER NOT NULL,
    EventType       nvarchar(150)    NOT NULL,
    CallbackUrl     nvarchar(500)    NOT NULL,
    SigningSecretVaultKeyRef nvarchar(200) NOT NULL, -- kv://... reference only, never a literal secret
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_integration_WebhookSubscription PRIMARY KEY CLUSTERED (WebhookSubscriptionId),
    CONSTRAINT FK_WebhookSubscription_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WebhookSubscription_System FOREIGN KEY (ExternalSystemId) REFERENCES integration.ExternalSystem(ExternalSystemId),
    CONSTRAINT CK_WebhookSubscription_SecretRef CHECK (SigningSecretVaultKeyRef LIKE 'kv://%')
);
GO

IF OBJECT_ID(N'integration.WebhookDeliveryAttempt', N'U') IS NULL
CREATE TABLE integration.WebhookDeliveryAttempt
(
    WebhookDeliveryAttemptId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    WebhookSubscriptionId UNIQUEIDENTIFIER NOT NULL,
    OutboxMessageId bigint           NULL,
    AttemptNumber   int              NOT NULL DEFAULT (1),
    ResponseStatusCode int          NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Pending'), -- Pending, Delivered, Failed
    AttemptedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_integration_WebhookDeliveryAttempt PRIMARY KEY CLUSTERED (WebhookDeliveryAttemptId),
    CONSTRAINT FK_WebhookDeliveryAttempt_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_WebhookDeliveryAttempt_Subscription FOREIGN KEY (WebhookSubscriptionId) REFERENCES integration.WebhookSubscription(WebhookSubscriptionId),
    CONSTRAINT FK_WebhookDeliveryAttempt_Outbox FOREIGN KEY (OutboxMessageId) REFERENCES integration.OutboxMessage(OutboxMessageId),
    CONSTRAINT CK_WebhookDeliveryAttempt_Status CHECK (Status IN ('Pending','Delivered','Failed'))
);
GO

IF OBJECT_ID(N'integration.DeadLetterMessage', N'U') IS NULL
CREATE TABLE integration.DeadLetterMessage
(
    DeadLetterMessageId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    SourceType      nvarchar(20)     NOT NULL, -- Outbox, Inbox, Webhook
    SourceMessageId nvarchar(100)    NOT NULL,
    PayloadJson     nvarchar(max)    NULL,
    FailureReason   nvarchar(1000)   NULL,
    DeadLetteredAtUtc datetime2(7)   NOT NULL DEFAULT SYSUTCDATETIME(),
    ReprocessedAtUtc datetime2(7)    NULL,
    CONSTRAINT PK_integration_DeadLetterMessage PRIMARY KEY CLUSTERED (DeadLetterMessageId),
    CONSTRAINT FK_DeadLetterMessage_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_DeadLetterMessage_SourceType CHECK (SourceType IN ('Outbox','Inbox','Webhook')),
    CONSTRAINT CK_DeadLetterMessage_PayloadJson CHECK (PayloadJson IS NULL OR ISJSON(PayloadJson) = 1)
);
GO

PRINT N'03-create-tables.sql PART 16 (integration) complete.';
GO

-- ============================================================================
-- PART 17 — ai schema, Section A: model/prompt/skill/evaluation/guardrail/
-- human-review metadata. Never the system of record for a business decision —
-- see ai.AiHumanReview, which every sensitive AiAgentRun output links to.
-- ============================================================================

IF OBJECT_ID(N'ai.AiModel', N'U') IS NULL
CREATE TABLE ai.AiModel
(
    AiModelId       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    ProviderName    nvarchar(50)     NOT NULL, -- anthropic, azure_openai, openai, other
    ModelFamily     nvarchar(100)    NOT NULL, -- e.g. 'claude'
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiModel PRIMARY KEY CLUSTERED (AiModelId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiModel')
    CREATE UNIQUE INDEX UQ_ai_AiModel ON ai.AiModel(ProviderName, ModelFamily);
GO

IF OBJECT_ID(N'ai.AiModelVersion', N'U') IS NULL
CREATE TABLE ai.AiModelVersion
(
    AiModelVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiModelId       UNIQUEIDENTIFIER NOT NULL,
    ModelIdentifier nvarchar(100)    NOT NULL, -- exact model id string, e.g. 'claude-sonnet-5'
    ReleasedAtUtc   datetime2(7)     NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    RetiredAtUtc    datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiModelVersion PRIMARY KEY CLUSTERED (AiModelVersionId),
    CONSTRAINT FK_AiModelVersion_Model FOREIGN KEY (AiModelId) REFERENCES ai.AiModel(AiModelId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiModelVersion')
    CREATE UNIQUE INDEX UQ_ai_AiModelVersion ON ai.AiModelVersion(AiModelId, ModelIdentifier);
GO

IF OBJECT_ID(N'ai.AiPrompt', N'U') IS NULL
CREATE TABLE ai.AiPrompt
(
    AiPromptId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NULL,
    PromptCode      nvarchar(150)    NOT NULL, -- matches a file under prompts/, per prompt-management.md
    Purpose         nvarchar(200)    NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiPrompt PRIMARY KEY CLUSTERED (AiPromptId),
    CONSTRAINT FK_AiPrompt_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiPrompt_Global')
    CREATE UNIQUE INDEX UQ_ai_AiPrompt_Global ON ai.AiPrompt(PromptCode) WHERE TenantId IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiPrompt_Tenant')
    CREATE UNIQUE INDEX UQ_ai_AiPrompt_Tenant ON ai.AiPrompt(TenantId, PromptCode) WHERE TenantId IS NOT NULL;
GO

IF OBJECT_ID(N'ai.AiPromptVersion', N'U') IS NULL
CREATE TABLE ai.AiPromptVersion
(
    AiPromptVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiPromptId      UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ContentHash     varbinary(32)    NOT NULL, -- hash of the versioned prompt file content, for drift detection — never the full prompt text inline (see prompts/ repo folder for the source of truth)
    ApprovalStatus  nvarchar(20)     NOT NULL DEFAULT ('Draft'),
    ApprovedByUserId UNIQUEIDENTIFIER NULL,
    ApprovedAtUtc   datetime2(7)     NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiPromptVersion PRIMARY KEY CLUSTERED (AiPromptVersionId),
    CONSTRAINT FK_AiPromptVersion_Prompt FOREIGN KEY (AiPromptId) REFERENCES ai.AiPrompt(AiPromptId),
    CONSTRAINT CK_AiPromptVersion_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiPromptVersion')
    CREATE UNIQUE INDEX UQ_ai_AiPromptVersion ON ai.AiPromptVersion(AiPromptId, VersionNumber);
GO

IF OBJECT_ID(N'ai.AiSkill', N'U') IS NULL
CREATE TABLE ai.AiSkill
(
    AiSkillId       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NULL,
    SkillCode       nvarchar(150)    NOT NULL, -- matches docs/06-ai-agents-rag/agent-skill-catalog.md entry
    Purpose         nvarchar(200)    NULL,
    ToolAllowlistJson nvarchar(max)  NULL, -- least-privilege MCP tool allowlist for this skill, per .claude/rules/ai-agents.md
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiSkill PRIMARY KEY CLUSTERED (AiSkillId),
    CONSTRAINT FK_AiSkill_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT CK_AiSkill_ToolAllowlistJson CHECK (ToolAllowlistJson IS NULL OR ISJSON(ToolAllowlistJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiSkill_Global')
    CREATE UNIQUE INDEX UQ_ai_AiSkill_Global ON ai.AiSkill(SkillCode) WHERE TenantId IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiSkill_Tenant')
    CREATE UNIQUE INDEX UQ_ai_AiSkill_Tenant ON ai.AiSkill(TenantId, SkillCode) WHERE TenantId IS NOT NULL;
GO

IF OBJECT_ID(N'ai.AiSkillVersion', N'U') IS NULL
CREATE TABLE ai.AiSkillVersion
(
    AiSkillVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiSkillId       UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ApprovalStatus  nvarchar(20)     NOT NULL DEFAULT ('Draft'),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiSkillVersion PRIMARY KEY CLUSTERED (AiSkillVersionId),
    CONSTRAINT FK_AiSkillVersion_Skill FOREIGN KEY (AiSkillId) REFERENCES ai.AiSkill(AiSkillId),
    CONSTRAINT CK_AiSkillVersion_ApprovalStatus CHECK (ApprovalStatus IN ('Draft','PendingApproval','Approved','Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiSkillVersion')
    CREATE UNIQUE INDEX UQ_ai_AiSkillVersion ON ai.AiSkillVersion(AiSkillId, VersionNumber);
GO

IF OBJECT_ID(N'ai.AiAgentRun', N'U') IS NULL
CREATE TABLE ai.AiAgentRun
(
    AiAgentRunId    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiSkillVersionId UNIQUEIDENTIFIER NOT NULL,
    AiModelVersionId UNIQUEIDENTIFIER NOT NULL,
    AiPromptVersionId UNIQUEIDENTIFIER NULL,
    EntityType      nvarchar(100)    NULL, -- polymorphic pointer, e.g. 'CandidateApplication'
    EntityId        UNIQUEIDENTIFIER NULL,
    MaskedInputObjectStorageUri nvarchar(1000) NULL, -- redacted/masked input reference — never raw prompt/PII inline
    MaskedOutputObjectStorageUri nvarchar(1000) NULL,
    InputTokenCount int              NULL,
    OutputTokenCount int             NULL,
    LatencyMs       int              NULL,
    EstimatedCostUsd decimal(10,4)   NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Succeeded'), -- Succeeded, Failed, GuardrailBlocked
    RequiresHumanReview bit          NOT NULL DEFAULT (0),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    StartedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    CONSTRAINT PK_ai_AiAgentRun PRIMARY KEY CLUSTERED (AiAgentRunId),
    CONSTRAINT FK_AiAgentRun_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_AiAgentRun_SkillVersion FOREIGN KEY (AiSkillVersionId) REFERENCES ai.AiSkillVersion(AiSkillVersionId),
    CONSTRAINT FK_AiAgentRun_ModelVersion FOREIGN KEY (AiModelVersionId) REFERENCES ai.AiModelVersion(AiModelVersionId),
    CONSTRAINT FK_AiAgentRun_PromptVersion FOREIGN KEY (AiPromptVersionId) REFERENCES ai.AiPromptVersion(AiPromptVersionId),
    CONSTRAINT CK_AiAgentRun_Status CHECK (Status IN ('Succeeded','Failed','GuardrailBlocked'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ai_AiAgentRun_Entity')
    CREATE INDEX IX_ai_AiAgentRun_Entity ON ai.AiAgentRun(EntityType, EntityId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ai_AiAgentRun_TenantStarted')
    CREATE INDEX IX_ai_AiAgentRun_TenantStarted ON ai.AiAgentRun(TenantId, StartedAtUtc);
GO

IF OBJECT_ID(N'ai.AiToolCall', N'U') IS NULL
CREATE TABLE ai.AiToolCall
(
    AiToolCallId    bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NOT NULL,
    ToolName        nvarchar(150)    NOT NULL, -- MCP tool name, must be within the calling skill's allowlist
    RequestSchemaValid bit           NOT NULL,
    ResponseSchemaValid bit          NULL,
    WasDenied       bit              NOT NULL DEFAULT (0), -- true when outside allowlist/scope — denied attempts are still audit-logged
    DurationMs      int              NULL,
    CalledAtUtc     datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiToolCall PRIMARY KEY CLUSTERED (AiToolCallId),
    CONSTRAINT FK_AiToolCall_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_AiToolCall_Run FOREIGN KEY (AiAgentRunId) REFERENCES ai.AiAgentRun(AiAgentRunId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ai_AiToolCall_Run')
    CREATE INDEX IX_ai_AiToolCall_Run ON ai.AiToolCall(AiAgentRunId);
GO

IF OBJECT_ID(N'ai.AiGuardrailEvaluation', N'U') IS NULL
CREATE TABLE ai.AiGuardrailEvaluation
(
    AiGuardrailEvaluationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NOT NULL,
    GuardrailName   nvarchar(150)    NOT NULL, -- e.g. PromptInjectionDetector, ProtectedAttributeFilter, ConfidenceThreshold
    Result          nvarchar(20)     NOT NULL, -- Passed, Blocked, Warned
    Details         nvarchar(1000)   NULL,
    EvaluatedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiGuardrailEvaluation PRIMARY KEY CLUSTERED (AiGuardrailEvaluationId),
    CONSTRAINT FK_AiGuardrailEvaluation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_AiGuardrailEvaluation_Run FOREIGN KEY (AiAgentRunId) REFERENCES ai.AiAgentRun(AiAgentRunId),
    CONSTRAINT CK_AiGuardrailEvaluation_Result CHECK (Result IN ('Passed','Blocked','Warned'))
);
GO

IF OBJECT_ID(N'ai.AiHumanReview', N'U') IS NULL
CREATE TABLE ai.AiHumanReview
(
    AiHumanReviewId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NOT NULL,
    ReviewedByUserId UNIQUEIDENTIFIER NOT NULL, -- always a human
    Decision        nvarchar(20)     NOT NULL, -- Accepted, Modified, Rejected
    FinalOutcomeNotes nvarchar(1000) NULL,
    ReviewedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiHumanReview PRIMARY KEY CLUSTERED (AiHumanReviewId),
    CONSTRAINT FK_AiHumanReview_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_AiHumanReview_Run FOREIGN KEY (AiAgentRunId) REFERENCES ai.AiAgentRun(AiAgentRunId),
    CONSTRAINT FK_AiHumanReview_ReviewedBy FOREIGN KEY (ReviewedByUserId) REFERENCES iam.[User](UserId),
    CONSTRAINT CK_AiHumanReview_Decision CHECK (Decision IN ('Accepted','Modified','Rejected'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiHumanReview')
    CREATE UNIQUE INDEX UQ_ai_AiHumanReview ON ai.AiHumanReview(AiAgentRunId);
GO

IF OBJECT_ID(N'ai.AiEvaluationRun', N'U') IS NULL
CREATE TABLE ai.AiEvaluationRun
(
    AiEvaluationRunId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiSkillVersionId UNIQUEIDENTIFIER NULL,
    AiPromptVersionId UNIQUEIDENTIFIER NULL,
    AiModelVersionId UNIQUEIDENTIFIER NULL,
    EvalSuiteName   nvarchar(150)    NOT NULL, -- matches evals/ dataset name, per ai-evaluation-strategy.md
    Status          nvarchar(20)     NOT NULL DEFAULT ('Running'), -- Running, Passed, Failed
    IncludesFairnessCheck bit        NOT NULL DEFAULT (0),
    IncludesRedTeamSuite bit         NOT NULL DEFAULT (0),
    StartedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    TriggeredByUserId UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_ai_AiEvaluationRun PRIMARY KEY CLUSTERED (AiEvaluationRunId),
    CONSTRAINT FK_AiEvaluationRun_SkillVersion FOREIGN KEY (AiSkillVersionId) REFERENCES ai.AiSkillVersion(AiSkillVersionId),
    CONSTRAINT FK_AiEvaluationRun_PromptVersion FOREIGN KEY (AiPromptVersionId) REFERENCES ai.AiPromptVersion(AiPromptVersionId),
    CONSTRAINT FK_AiEvaluationRun_ModelVersion FOREIGN KEY (AiModelVersionId) REFERENCES ai.AiModelVersion(AiModelVersionId),
    CONSTRAINT CK_AiEvaluationRun_Status CHECK (Status IN ('Running','Passed','Failed'))
);
GO

IF OBJECT_ID(N'ai.AiEvaluationMetric', N'U') IS NULL
CREATE TABLE ai.AiEvaluationMetric
(
    AiEvaluationMetricId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiEvaluationRunId UNIQUEIDENTIFIER NOT NULL,
    MetricName      nvarchar(100)    NOT NULL, -- Accuracy, F1, FairnessDisparity, HallucinationRate, ...
    MetricValue     decimal(9,6)     NOT NULL,
    ThresholdValue  decimal(9,6)     NULL,
    Passed          bit              NULL,
    CONSTRAINT PK_ai_AiEvaluationMetric PRIMARY KEY CLUSTERED (AiEvaluationMetricId),
    CONSTRAINT FK_AiEvaluationMetric_Run FOREIGN KEY (AiEvaluationRunId) REFERENCES ai.AiEvaluationRun(AiEvaluationRunId)
);
GO

IF OBJECT_ID(N'ai.AiEvaluationResult', N'U') IS NULL
CREATE TABLE ai.AiEvaluationResult
(
    AiEvaluationResultId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiEvaluationRunId UNIQUEIDENTIFIER NOT NULL,
    CaseIdentifier  nvarchar(150)    NOT NULL, -- id of the case within evals/cases/
    Passed          bit              NOT NULL,
    ActualOutputObjectStorageUri nvarchar(1000) NULL,
    Notes           nvarchar(1000)   NULL,
    CONSTRAINT PK_ai_AiEvaluationResult PRIMARY KEY CLUSTERED (AiEvaluationResultId),
    CONSTRAINT FK_AiEvaluationResult_Run FOREIGN KEY (AiEvaluationRunId) REFERENCES ai.AiEvaluationRun(AiEvaluationRunId)
);
GO

IF OBJECT_ID(N'ai.AiRedTeamCase', N'U') IS NULL
CREATE TABLE ai.AiRedTeamCase
(
    AiRedTeamCaseId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    CaseCode        nvarchar(150)    NOT NULL, -- matches prompts/red-team case id
    AttackCategory  nvarchar(100)    NOT NULL, -- PromptInjection, DataExfiltration, JailbreakAttempt, ...
    Description     nvarchar(1000)   NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CONSTRAINT PK_ai_AiRedTeamCase PRIMARY KEY CLUSTERED (AiRedTeamCaseId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiRedTeamCase')
    CREATE UNIQUE INDEX UQ_ai_AiRedTeamCase ON ai.AiRedTeamCase(CaseCode);
GO

IF OBJECT_ID(N'ai.AiRedTeamResult', N'U') IS NULL
CREATE TABLE ai.AiRedTeamResult
(
    AiRedTeamResultId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    AiEvaluationRunId UNIQUEIDENTIFIER NOT NULL,
    AiRedTeamCaseId UNIQUEIDENTIFIER NOT NULL,
    WasSuccessfullyDefended bit      NOT NULL,
    Notes           nvarchar(1000)   NULL,
    CONSTRAINT PK_ai_AiRedTeamResult PRIMARY KEY CLUSTERED (AiRedTeamResultId),
    CONSTRAINT FK_AiRedTeamResult_Run FOREIGN KEY (AiEvaluationRunId) REFERENCES ai.AiEvaluationRun(AiEvaluationRunId),
    CONSTRAINT FK_AiRedTeamResult_Case FOREIGN KEY (AiRedTeamCaseId) REFERENCES ai.AiRedTeamCase(AiRedTeamCaseId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_AiRedTeamResult')
    CREATE UNIQUE INDEX UQ_ai_AiRedTeamResult ON ai.AiRedTeamResult(AiEvaluationRunId, AiRedTeamCaseId);
GO

IF OBJECT_ID(N'ai.AiCostUsage', N'U') IS NULL
CREATE TABLE ai.AiCostUsage
(
    AiCostUsageId   bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NULL,
    UsageDate       date             NOT NULL,
    InputTokenCount bigint           NOT NULL DEFAULT (0),
    OutputTokenCount bigint          NOT NULL DEFAULT (0),
    EstimatedCostUsd decimal(12,4)   NOT NULL DEFAULT (0),
    CONSTRAINT PK_ai_AiCostUsage PRIMARY KEY CLUSTERED (AiCostUsageId),
    CONSTRAINT FK_AiCostUsage_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_AiCostUsage_Run FOREIGN KEY (AiAgentRunId) REFERENCES ai.AiAgentRun(AiAgentRunId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ai_AiCostUsage_TenantDate')
    CREATE INDEX IX_ai_AiCostUsage_TenantDate ON ai.AiCostUsage(TenantId, UsageDate);
GO

IF OBJECT_ID(N'ai.AiFeedback', N'U') IS NULL
CREATE TABLE ai.AiFeedback
(
    AiFeedbackId    UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NOT NULL,
    SubmittedByUserId UNIQUEIDENTIFIER NULL,
    Rating          int              NULL, -- 1-5
    CommentText     nvarchar(1000)   NULL,
    SubmittedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_AiFeedback PRIMARY KEY CLUSTERED (AiFeedbackId),
    CONSTRAINT FK_AiFeedback_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_AiFeedback_Run FOREIGN KEY (AiAgentRunId) REFERENCES ai.AiAgentRun(AiAgentRunId),
    CONSTRAINT CK_AiFeedback_Rating CHECK (Rating IS NULL OR Rating BETWEEN 1 AND 5)
);
GO

PRINT N'03-create-tables.sql PART 17 (ai: model/prompt/skill/evaluation metadata) complete.';
GO

-- ============================================================================
-- PART 18 — ai schema, Section B: RAG corpus/embedding metadata. Per ADR-003,
-- the vector store is retrieval-only and never authoritative for business
-- state; this schema stores metadata/references, and — per default policy —
-- does not store raw vectors (see ai.RagEmbeddingReference).
-- ============================================================================

IF OBJECT_ID(N'ai.RagCorpus', N'U') IS NULL
CREATE TABLE ai.RagCorpus
(
    RagCorpusId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    CorpusCode      nvarchar(100)    NOT NULL, -- e.g. 'hr-policy-rag'
    Name            nvarchar(200)    NOT NULL,
    RagConfigurationId UNIQUEIDENTIFIER NULL,
    IsActive        bit              NOT NULL DEFAULT (1),
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_ai_RagCorpus PRIMARY KEY CLUSTERED (RagCorpusId),
    CONSTRAINT FK_RagCorpus_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagCorpus_Config FOREIGN KEY (RagConfigurationId) REFERENCES ref.RagConfiguration(RagConfigurationId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_RagCorpus')
    CREATE UNIQUE INDEX UQ_ai_RagCorpus ON ai.RagCorpus(TenantId, CorpusCode);
GO

IF OBJECT_ID(N'ai.RagAccessPolicy', N'U') IS NULL
CREATE TABLE ai.RagAccessPolicy
(
    RagAccessPolicyId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagCorpusId     UNIQUEIDENTIFIER NOT NULL,
    Classification  nvarchar(30)     NOT NULL DEFAULT ('Internal'), -- Public, Internal, Confidential, Restricted
    AllowedRoleIdsJson nvarchar(max) NULL, -- ACL applied BEFORE vector search, per ADR-003 — never after
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_RagAccessPolicy PRIMARY KEY CLUSTERED (RagAccessPolicyId),
    CONSTRAINT FK_RagAccessPolicy_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagAccessPolicy_Corpus FOREIGN KEY (RagCorpusId) REFERENCES ai.RagCorpus(RagCorpusId),
    CONSTRAINT CK_RagAccessPolicy_Classification CHECK (Classification IN ('Public','Internal','Confidential','Restricted')),
    CONSTRAINT CK_RagAccessPolicy_RoleIdsJson CHECK (AllowedRoleIdsJson IS NULL OR ISJSON(AllowedRoleIdsJson) = 1)
);
GO

IF OBJECT_ID(N'ai.RagSourceDocument', N'U') IS NULL
CREATE TABLE ai.RagSourceDocument
(
    RagSourceDocumentId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagCorpusId     UNIQUEIDENTIFIER NOT NULL,
    SourceObjectStorageUri nvarchar(1000) NOT NULL,
    Title           nvarchar(300)    NULL,
    Classification  nvarchar(30)     NOT NULL DEFAULT ('Internal'),
    CurrentVersionId UNIQUEIDENTIFIER NULL, -- FK added in 04-create-keys-indexes-constraints.sql (circular)
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId UNIQUEIDENTIFIER NULL,
    RowVersion      rowversion       NOT NULL,
    CONSTRAINT PK_ai_RagSourceDocument PRIMARY KEY CLUSTERED (RagSourceDocumentId),
    CONSTRAINT FK_RagSourceDocument_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagSourceDocument_Corpus FOREIGN KEY (RagCorpusId) REFERENCES ai.RagCorpus(RagCorpusId),
    CONSTRAINT CK_RagSourceDocument_Classification CHECK (Classification IN ('Public','Internal','Confidential','Restricted'))
);
GO

IF OBJECT_ID(N'ai.RagSourceDocumentVersion', N'U') IS NULL
CREATE TABLE ai.RagSourceDocumentVersion
(
    RagSourceDocumentVersionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagSourceDocumentId UNIQUEIDENTIFIER NOT NULL,
    VersionNumber   int              NOT NULL,
    ContentHash     varbinary(32)    NOT NULL,
    EffectiveDate   date             NULL,
    ExpiryDate      date             NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_RagSourceDocumentVersion PRIMARY KEY CLUSTERED (RagSourceDocumentVersionId),
    CONSTRAINT FK_RagSourceDocVersion_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagSourceDocVersion_Document FOREIGN KEY (RagSourceDocumentId) REFERENCES ai.RagSourceDocument(RagSourceDocumentId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_RagSourceDocVersion')
    CREATE UNIQUE INDEX UQ_ai_RagSourceDocVersion ON ai.RagSourceDocumentVersion(RagSourceDocumentId, VersionNumber);
GO

IF OBJECT_ID(N'ai.RagChunk', N'U') IS NULL
CREATE TABLE ai.RagChunk
(
    RagChunkId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagCorpusId     UNIQUEIDENTIFIER NOT NULL,
    RagSourceDocumentVersionId UNIQUEIDENTIFIER NOT NULL,
    RagAccessPolicyId UNIQUEIDENTIFIER NOT NULL,
    ChunkIndex      int              NOT NULL,
    HeadingPath     nvarchar(500)    NULL, -- e.g. 'Section 3 > 3.2 Leave Policy'
    PageOrSection   nvarchar(100)    NULL,
    ContentHash     varbinary(32)    NOT NULL, -- hash of chunk text; the text itself lives in object storage, not inline
    ChunkTextObjectStorageUri nvarchar(1000) NULL,
    CreatedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_RagChunk PRIMARY KEY CLUSTERED (RagChunkId),
    CONSTRAINT FK_RagChunk_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagChunk_Corpus FOREIGN KEY (RagCorpusId) REFERENCES ai.RagCorpus(RagCorpusId),
    CONSTRAINT FK_RagChunk_SourceVersion FOREIGN KEY (RagSourceDocumentVersionId) REFERENCES ai.RagSourceDocumentVersion(RagSourceDocumentVersionId),
    CONSTRAINT FK_RagChunk_AccessPolicy FOREIGN KEY (RagAccessPolicyId) REFERENCES ai.RagAccessPolicy(RagAccessPolicyId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_RagChunk')
    CREATE UNIQUE INDEX UQ_ai_RagChunk ON ai.RagChunk(RagSourceDocumentVersionId, ChunkIndex);
GO

IF OBJECT_ID(N'ai.RagEmbeddingReference', N'U') IS NULL
CREATE TABLE ai.RagEmbeddingReference
(
    RagEmbeddingReferenceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagChunkId      UNIQUEIDENTIFIER NOT NULL,
    EmbeddingModelIdentifier nvarchar(100) NOT NULL,
    VectorStoreProvider nvarchar(50) NOT NULL,
    VectorStoreRecordId nvarchar(200) NOT NULL, -- opaque id in the external vector store — never the raw vector itself (see conventions note)
    EmbeddedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_RagEmbeddingReference PRIMARY KEY CLUSTERED (RagEmbeddingReferenceId),
    CONSTRAINT FK_RagEmbeddingReference_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagEmbeddingReference_Chunk FOREIGN KEY (RagChunkId) REFERENCES ai.RagChunk(RagChunkId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_RagEmbeddingReference')
    CREATE UNIQUE INDEX UQ_ai_RagEmbeddingReference ON ai.RagEmbeddingReference(RagChunkId, EmbeddingModelIdentifier);
GO

IF OBJECT_ID(N'ai.RagIngestionRun', N'U') IS NULL
CREATE TABLE ai.RagIngestionRun
(
    RagIngestionRunId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagCorpusId     UNIQUEIDENTIFIER NOT NULL,
    Status          nvarchar(20)     NOT NULL DEFAULT ('Running'), -- Running, Succeeded, Failed
    DocumentsProcessed int           NOT NULL DEFAULT (0),
    ChunksCreated   int              NOT NULL DEFAULT (0),
    StartedAtUtc    datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc  datetime2(7)     NULL,
    ErrorMessage    nvarchar(1000)   NULL,
    CONSTRAINT PK_ai_RagIngestionRun PRIMARY KEY CLUSTERED (RagIngestionRunId),
    CONSTRAINT FK_RagIngestionRun_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagIngestionRun_Corpus FOREIGN KEY (RagCorpusId) REFERENCES ai.RagCorpus(RagCorpusId),
    CONSTRAINT CK_RagIngestionRun_Status CHECK (Status IN ('Running','Succeeded','Failed'))
);
GO

IF OBJECT_ID(N'ai.RagRetrievalTrace', N'U') IS NULL
CREATE TABLE ai.RagRetrievalTrace
(
    RagRetrievalTraceId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    AiAgentRunId    UNIQUEIDENTIFIER NULL,
    RagCorpusId     UNIQUEIDENTIFIER NOT NULL,
    QueryTextHash   varbinary(32)    NULL, -- hash only, never the raw query text (may contain PII)
    ResultCount     int              NOT NULL DEFAULT (0),
    NoAnswerFallbackTriggered bit    NOT NULL DEFAULT (0), -- per ADR-003: insufficient grounding -> no-answer, never a silent best guess
    RetrievedAtUtc  datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ai_RagRetrievalTrace PRIMARY KEY CLUSTERED (RagRetrievalTraceId),
    CONSTRAINT FK_RagRetrievalTrace_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagRetrievalTrace_Run FOREIGN KEY (AiAgentRunId) REFERENCES ai.AiAgentRun(AiAgentRunId),
    CONSTRAINT FK_RagRetrievalTrace_Corpus FOREIGN KEY (RagCorpusId) REFERENCES ai.RagCorpus(RagCorpusId)
);
GO

IF OBJECT_ID(N'ai.RagCitation', N'U') IS NULL
CREATE TABLE ai.RagCitation
(
    RagCitationId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    RagRetrievalTraceId UNIQUEIDENTIFIER NOT NULL,
    RagChunkId      UNIQUEIDENTIFIER NOT NULL,
    RelevanceScore  decimal(5,4)     NULL,
    RankPosition    int              NOT NULL,
    CONSTRAINT PK_ai_RagCitation PRIMARY KEY CLUSTERED (RagCitationId),
    CONSTRAINT FK_RagCitation_Tenant FOREIGN KEY (TenantId) REFERENCES org.Tenant(TenantId),
    CONSTRAINT FK_RagCitation_Trace FOREIGN KEY (RagRetrievalTraceId) REFERENCES ai.RagRetrievalTrace(RagRetrievalTraceId),
    CONSTRAINT FK_RagCitation_Chunk FOREIGN KEY (RagChunkId) REFERENCES ai.RagChunk(RagChunkId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ai_RagCitation')
    CREATE UNIQUE INDEX UQ_ai_RagCitation ON ai.RagCitation(RagRetrievalTraceId, RagChunkId);
GO

PRINT N'03-create-tables.sql PART 18 (ai: RAG corpus / embedding metadata) complete.';
GO

-- ============================================================================
-- PART 19 — audit schema. Append-only: no UPDATE/DELETE code path is ever
-- added outside the documented retention/legal-hold purge process (see
-- docs/data-retention-and-privacy.md). Enforced by an INSTEAD OF UPDATE,
-- DELETE trigger in scripts/09-create-triggers.sql — this script only creates
-- the tables. bigint IDENTITY per the high-volume append-only convention.
-- ============================================================================

IF OBJECT_ID(N'audit.AuditEvent', N'U') IS NULL
CREATE TABLE audit.AuditEvent
(
    AuditEventId    bigint IDENTITY(1,1) NOT NULL,
    EventId         UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    TenantId        UNIQUEIDENTIFIER NULL, -- NULL only for platform-level events with no tenant context
    ActorUserId     UNIQUEIDENTIFIER NULL, -- NULL = system/service actor
    ActorType       nvarchar(20)     NOT NULL DEFAULT ('User'), -- User, System, AiAgent, ApiClient
    Action          nvarchar(150)    NOT NULL, -- e.g. 'Offer.Approve', 'Discrepancy.Resolve'
    EntityType      nvarchar(100)    NOT NULL,
    EntityId        UNIQUEIDENTIFIER NULL,
    PreviousStatus  nvarchar(50)     NULL,
    NewStatus       nvarchar(50)     NULL,
    Outcome         nvarchar(20)     NOT NULL DEFAULT ('Success'), -- Success, Denied, Failed
    MetadataJson    nvarchar(max)    NULL, -- redacted structured metadata only — never raw sensitive text, see logging-and-redaction-standard.md
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CausationId     UNIQUEIDENTIFIER NULL,
    TraceId         nvarchar(64)     NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_audit_AuditEvent PRIMARY KEY CLUSTERED (AuditEventId),
    CONSTRAINT CK_audit_AuditEvent_ActorType CHECK (ActorType IN ('User','System','AiAgent','ApiClient')),
    CONSTRAINT CK_audit_AuditEvent_Outcome CHECK (Outcome IN ('Success','Denied','Failed')),
    CONSTRAINT CK_audit_AuditEvent_MetadataJson CHECK (MetadataJson IS NULL OR ISJSON(MetadataJson) = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_AuditEvent_TenantOccurred')
    CREATE INDEX IX_audit_AuditEvent_TenantOccurred ON audit.AuditEvent(TenantId, OccurredAtUtc);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_AuditEvent_Entity')
    CREATE INDEX IX_audit_AuditEvent_Entity ON audit.AuditEvent(EntityType, EntityId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_AuditEvent_Correlation')
    CREATE INDEX IX_audit_AuditEvent_Correlation ON audit.AuditEvent(CorrelationId);
GO

IF OBJECT_ID(N'audit.SecurityEvent', N'U') IS NULL
CREATE TABLE audit.SecurityEvent
(
    SecurityEventId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NULL,
    ActorUserId     UNIQUEIDENTIFIER NULL,
    EventType       nvarchar(100)    NOT NULL, -- AccessDenied, PermissionEscalationAttempt, RlsPolicyBypassAttempt, TenantContextMissing
    Severity        nvarchar(20)     NOT NULL DEFAULT ('Medium'),
    Details         nvarchar(1000)   NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_audit_SecurityEvent PRIMARY KEY CLUSTERED (SecurityEventId),
    CONSTRAINT CK_audit_SecurityEvent_Severity CHECK (Severity IN ('Low','Medium','High','Critical'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_SecurityEvent_TenantOccurred')
    CREATE INDEX IX_audit_SecurityEvent_TenantOccurred ON audit.SecurityEvent(TenantId, OccurredAtUtc);
GO

IF OBJECT_ID(N'audit.DataAccessEvent', N'U') IS NULL
CREATE TABLE audit.DataAccessEvent
(
    DataAccessEventId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NOT NULL,
    ActorUserId     UNIQUEIDENTIFIER NULL,
    EntityType      nvarchar(100)    NOT NULL,
    EntityId        UNIQUEIDENTIFIER NULL,
    AccessType      nvarchar(20)     NOT NULL, -- Read, Export
    Classification  nvarchar(30)     NULL, -- classification of the accessed data, for restricted-column access review
    CorrelationId   UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_audit_DataAccessEvent PRIMARY KEY CLUSTERED (DataAccessEventId),
    CONSTRAINT CK_audit_DataAccessEvent_AccessType CHECK (AccessType IN ('Read','Export'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_DataAccessEvent_TenantOccurred')
    CREATE INDEX IX_audit_DataAccessEvent_TenantOccurred ON audit.DataAccessEvent(TenantId, OccurredAtUtc);
GO

IF OBJECT_ID(N'audit.PrivilegedActionEvent', N'U') IS NULL
CREATE TABLE audit.PrivilegedActionEvent
(
    PrivilegedActionEventId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NULL,
    ActorUserId     UNIQUEIDENTIFIER NULL,
    ActionType      nvarchar(100)    NOT NULL, -- RoleGranted, PermissionGranted, ProductionSupportAccess, ...
    TargetDescription nvarchar(500)  NULL,
    ApprovedByUserId UNIQUEIDENTIFIER NULL,
    CorrelationId   UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_audit_PrivilegedActionEvent PRIMARY KEY CLUSTERED (PrivilegedActionEventId)
);
GO

IF OBJECT_ID(N'audit.ErrorEvent', N'U') IS NULL
CREATE TABLE audit.ErrorEvent
(
    ErrorEventId    bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NULL,
    Source          nvarchar(150)    NOT NULL, -- e.g. 'HrAutomation.Api', a stored procedure name, an MCP server name
    ErrorCode       nvarchar(50)     NULL,
    Message         nvarchar(1000)   NULL, -- user-safe message only — no raw stack trace, per RFC 7807 / error-handling-and-problem-details.md
    CorrelationId   UNIQUEIDENTIFIER NULL,
    OccurredAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_audit_ErrorEvent PRIMARY KEY CLUSTERED (ErrorEventId)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_ErrorEvent_Occurred')
    CREATE INDEX IX_audit_ErrorEvent_Occurred ON audit.ErrorEvent(OccurredAtUtc);
GO

IF OBJECT_ID(N'audit.RetentionExecutionLog', N'U') IS NULL
CREATE TABLE audit.RetentionExecutionLog
(
    RetentionExecutionLogId bigint IDENTITY(1,1) NOT NULL,
    TenantId        UNIQUEIDENTIFIER NULL,
    RetentionPolicyId UNIQUEIDENTIFIER NULL,
    EntityType      nvarchar(100)    NOT NULL,
    ActionTaken     nvarchar(30)     NOT NULL, -- Anonymized, Archived, Purged, SkippedLegalHold
    RowsAffected    int              NOT NULL DEFAULT (0),
    ExecutedAtUtc   datetime2(7)     NOT NULL DEFAULT SYSUTCDATETIME(),
    CorrelationId   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_audit_RetentionExecutionLog PRIMARY KEY CLUSTERED (RetentionExecutionLogId),
    CONSTRAINT FK_RetentionExecutionLog_Policy FOREIGN KEY (RetentionPolicyId) REFERENCES ref.RetentionPolicy(RetentionPolicyId),
    CONSTRAINT CK_RetentionExecutionLog_Action CHECK (ActionTaken IN ('Anonymized','Archived','Purged','SkippedLegalHold'))
);
GO

PRINT N'03-create-tables.sql PART 19 (audit) complete.';
GO
PRINT N'03-create-tables.sql - ALL PARTS COMPLETE.';
GO
