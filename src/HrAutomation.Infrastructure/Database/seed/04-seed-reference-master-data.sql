/* ============================================================================
   04-seed-reference-master-data.sql
   Purpose : Seed baseline reference/master data: candidate sources, skill
             categories/skills, document types, verification types,
             discrepancy types/severities, candidate/offer/document/
             verification/discrepancy/employee statuses, notification
             channels, and feature flags.
   Depends on: 01, 02, 03.
   Idempotent: Yes.

   SCHEMA NOTE (DBCollation = SQL_Latin1_General_CP1_CI_AS, case-insensitive):
   recruitment.usp_CreateCandidate looks up a candidate-bank status by
   `Code = N'New'` — this script seeds the code as NEW (spec's ALL_CAPS
   convention); CI collation means it satisfies that lookup unchanged.

   SCHEMA NOTE: ref.DocumentType has one Classification column
   (Public/Internal/Confidential/Restricted) — there are no separate
   Required/Conditional/Optional/CandidateUploadable/HRUploadable columns.
   "Required vs conditional" is expressed per-checklist via
   ref.DocumentChecklistItem.IsMandatory (seeded in 07); uploadable-by
   distinction is documented in Name/Description text only (see final report
   mismatch list, item M11).
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

SELECT @TenantId = TenantId FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0;
IF @TenantId IS NULL
    THROW 50001, 'Seed execution failed: tenant was not found. Run 01-seed-tenant-organization.sql first.', 1;

SELECT @ActorUserId = UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.hr.admin@example.test' AND IsDeleted = 0;
IF @ActorUserId IS NULL
    THROW 50002, 'Seed execution failed: seed administrator user was not found. Run 03-seed-iam-users-access.sql first.', 1;

EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
EXEC sys.sp_set_session_context @key = N'UserId', @value = @ActorUserId;
EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

BEGIN TRY
    BEGIN TRAN;

    -- ========================================================================
    -- A. Candidate sources
    -- ========================================================================
    DECLARE @CandidateSources TABLE (Code nvarchar(100), Name nvarchar(400), SortOrder int);
    INSERT INTO @CandidateSources (Code, Name, SortOrder) VALUES
    (N'INTERNAL_REFERRAL', N'Internal Referral', 10), (N'JOB_PORTAL', N'Job Portal', 20),
    (N'LINKEDIN', N'LinkedIn', 30), (N'CAREER_SITE', N'Career Site', 40),
    (N'RECRUITMENT_AGENCY', N'Recruitment Agency', 50), (N'CLIENT_REFERENCE', N'Client Reference', 60),
    (N'WALK_IN', N'Walk-In', 70), (N'CAMPUS_HIRING', N'Campus Hiring', 80),
    (N'TALENT_POOL', N'Talent Pool', 90), (N'OTHER', N'Other', 100);

    INSERT INTO ref.CandidateSource (TenantId, Code, Name, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @CandidateSources s
    WHERE NOT EXISTS (SELECT 1 FROM ref.CandidateSource x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- B. Skill categories
    -- ========================================================================
    DECLARE @SkillCategories TABLE (Code nvarchar(100), Name nvarchar(400), SortOrder int);
    INSERT INTO @SkillCategories (Code, Name, SortOrder) VALUES
    (N'BACKEND', N'Backend', 10), (N'FRONTEND', N'Frontend', 20), (N'DATABASE', N'Database', 30),
    (N'CLOUD', N'Cloud', 40), (N'DEVOPS', N'DevOps', 50), (N'TESTING', N'Testing', 60),
    (N'PROJECT_MANAGEMENT', N'Project Management', 70), (N'AGILE', N'Agile', 80),
    (N'HR', N'Human Resources', 90), (N'COMMUNICATION', N'Communication', 100),
    (N'DOMAIN', N'Domain Knowledge', 110), (N'SECURITY', N'Security', 120), (N'DATA_AI', N'Data & AI', 130);

    INSERT INTO ref.SkillCategory (TenantId, Code, Name, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, c.Code, c.Name, c.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @SkillCategories c
    WHERE NOT EXISTS (SELECT 1 FROM ref.SkillCategory x WHERE x.TenantId = @TenantId AND x.Code = c.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- C. Skills (mapped to a category)
    -- ========================================================================
    DECLARE @Skills TABLE (Code nvarchar(200), Name nvarchar(400), CategoryCode nvarchar(100));
    INSERT INTO @Skills (Code, Name, CategoryCode) VALUES
    (N'C_SHARP', N'C#', N'BACKEND'), (N'DOTNET', N'.NET', N'BACKEND'), (N'ASPNET_CORE', N'ASP.NET Core', N'BACKEND'),
    (N'SQL_SERVER', N'SQL Server', N'DATABASE'), (N'REACT', N'React', N'FRONTEND'), (N'TYPESCRIPT', N'TypeScript', N'FRONTEND'),
    (N'JAVASCRIPT', N'JavaScript', N'FRONTEND'), (N'HTML', N'HTML', N'FRONTEND'), (N'CSS', N'CSS', N'FRONTEND'),
    (N'AZURE', N'Azure', N'CLOUD'), (N'AWS', N'AWS', N'CLOUD'), (N'DOCKER', N'Docker', N'DEVOPS'),
    (N'KUBERNETES', N'Kubernetes', N'DEVOPS'), (N'GIT', N'Git', N'DEVOPS'), (N'CI_CD', N'CI/CD', N'DEVOPS'),
    (N'REST_API', N'REST API', N'BACKEND'), (N'MICROSERVICES', N'Microservices', N'BACKEND'),
    (N'ENTITY_FRAMEWORK_CORE', N'Entity Framework Core', N'BACKEND'), (N'PYTHON', N'Python', N'BACKEND'),
    (N'LANGCHAIN', N'LangChain', N'DATA_AI'), (N'LANGGRAPH', N'LangGraph', N'DATA_AI'),
    (N'RAG', N'RAG (Retrieval-Augmented Generation)', N'DATA_AI'), (N'MCP', N'Model Context Protocol', N'DATA_AI'),
    (N'SCRUM', N'Scrum', N'AGILE'), (N'PROJECT_MGMT', N'Project Management', N'PROJECT_MANAGEMENT'),
    (N'STAKEHOLDER_MANAGEMENT', N'Stakeholder Management', N'COMMUNICATION'),
    (N'RECRUITMENT', N'Recruitment', N'HR'), (N'HR_OPERATIONS', N'HR Operations', N'HR'),
    (N'DOCUMENT_VERIFICATION', N'Document Verification', N'HR');
    -- Note: spec listed "AGILE" and "PROJECT_MANAGEMENT" both as a skill-category
    -- code and a skill code; SCRUM/PROJECT_MGMT above are the corresponding
    -- skill-level entries to avoid a Skill.Code / SkillCategory.Code collision
    -- (both live in different tables, so no collision — kept distinct names
    -- for readability).

    INSERT INTO ref.Skill (TenantId, SkillCategoryId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, sc.SkillCategoryId, s.Code, s.Name, 1, @ExecutionUtc, @ActorUserId
    FROM @Skills s
    JOIN ref.SkillCategory sc ON sc.TenantId = @TenantId AND sc.Code = s.CategoryCode AND sc.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM ref.Skill x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- D. Document types (Classification: Public/Internal/Confidential/Restricted)
    -- ========================================================================
    DECLARE @DocumentTypes TABLE (Code nvarchar(100), Name nvarchar(400), Classification nvarchar(60));
    INSERT INTO @DocumentTypes (Code, Name, Classification) VALUES
    (N'RESUME', N'Resume (required; candidate-uploadable)', N'Confidential'),
    (N'PROFILE_PHOTO', N'Profile Photo (optional; candidate-uploadable) [TENANT_CONFIGURATION_REQUIRED: confirm policy allows]', N'Internal'),
    (N'GOVERNMENT_ID', N'Government ID (conditional; restricted; candidate-uploadable)', N'Restricted'),
    (N'ADDRESS_PROOF', N'Address Proof (conditional; restricted; candidate-uploadable)', N'Restricted'),
    (N'EDUCATION_CERTIFICATE', N'Education Certificate (required; candidate-uploadable)', N'Confidential'),
    (N'EXPERIENCE_LETTER', N'Experience Letter (conditional on prior employment; candidate-uploadable)', N'Confidential'),
    (N'RELIEVING_LETTER', N'Relieving Letter (conditional; candidate-uploadable)', N'Confidential'),
    (N'PAYSLIP', N'Payslip (conditional; restricted; candidate-uploadable)', N'Restricted'),
    (N'OFFER_LETTER_PREVIOUS_EMPLOYER', N'Previous Employer Offer Letter (optional; candidate-uploadable)', N'Confidential'),
    (N'BANK_DETAILS', N'Bank Details (conditional; restricted; candidate-uploadable)', N'Restricted'),
    (N'TAX_DOCUMENT', N'Tax Document (conditional; restricted; candidate-uploadable)', N'Restricted'),
    (N'SIGNED_OFFER_LETTER', N'Signed Offer Letter (required; HR-uploadable)', N'Confidential'),
    (N'OTHER', N'Other (optional; candidate-uploadable)', N'Internal');

    INSERT INTO ref.DocumentType (TenantId, Code, Name, Classification, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, d.Code, d.Name, d.Classification, 1, @ExecutionUtc, @ActorUserId
    FROM @DocumentTypes d
    WHERE NOT EXISTS (SELECT 1 FROM ref.DocumentType x WHERE x.TenantId = @TenantId AND x.Code = d.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- E. Verification types
    -- ========================================================================
    DECLARE @VerificationTypes TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @VerificationTypes (Code, Name) VALUES
    (N'IDENTITY', N'Identity Verification'), (N'ADDRESS', N'Address Verification'),
    (N'EDUCATION', N'Education Verification'), (N'EMPLOYMENT', N'Employment Verification'),
    (N'REFERENCE', N'Reference Verification'), (N'DOCUMENT_AUTHENTICITY', N'Document Authenticity Check'),
    (N'CRIMINAL_CHECK', N'Criminal Record Check [LEGAL_REVIEW_REQUIRED: confirm jurisdictional lawfulness and candidate consent basis before enabling]'),
    (N'OTHER', N'Other');

    INSERT INTO ref.VerificationType (TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, v.Code, v.Name, CASE WHEN v.Code = N'CRIMINAL_CHECK' THEN 0 ELSE 1 END, @ExecutionUtc, @ActorUserId
    FROM @VerificationTypes v
    WHERE NOT EXISTS (SELECT 1 FROM ref.VerificationType x WHERE x.TenantId = @TenantId AND x.Code = v.Code AND x.IsDeleted = 0);
    -- CRIMINAL_CHECK is seeded IsActive = 0 (present for configuration
    -- completeness, disabled by default) pending the [LEGAL_REVIEW_REQUIRED]
    -- sign-off noted above and in docs/data-retention-and-privacy.md.

    -- ========================================================================
    -- F. Discrepancy severities (RankOrder ascending = increasing severity)
    -- ========================================================================
    DECLARE @Severities TABLE (Code nvarchar(100), Name nvarchar(400), RankOrder int);
    INSERT INTO @Severities (Code, Name, RankOrder) VALUES
    (N'LOW', N'Low', 1), (N'MEDIUM', N'Medium', 2), (N'HIGH', N'High', 3), (N'CRITICAL', N'Critical', 4);

    INSERT INTO ref.DiscrepancySeverity (TenantId, Code, Name, RankOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.RankOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @Severities s
    WHERE NOT EXISTS (SELECT 1 FROM ref.DiscrepancySeverity x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- G. Discrepancy types
    -- ========================================================================
    DECLARE @DiscrepancyTypes TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @DiscrepancyTypes (Code, Name) VALUES
    (N'NAME_MISMATCH', N'Name Mismatch'), (N'DATE_MISMATCH', N'Date Mismatch'),
    (N'EMPLOYER_MISMATCH', N'Employer Mismatch'), (N'DESIGNATION_MISMATCH', N'Designation Mismatch'),
    (N'EDUCATION_MISMATCH', N'Education Mismatch'), (N'EMPLOYMENT_GAP', N'Employment Gap'),
    (N'MISSING_DOCUMENT', N'Missing Document'), (N'UNREADABLE_DOCUMENT', N'Unreadable Document'),
    (N'EXPIRED_DOCUMENT', N'Expired Document'), (N'INCOMPLETE_FORM', N'Incomplete Form'),
    (N'ADDRESS_MISMATCH', N'Address Mismatch'), (N'OTHER', N'Other');

    INSERT INTO ref.DiscrepancyType (TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, d.Code, d.Name, 1, @ExecutionUtc, @ActorUserId
    FROM @DiscrepancyTypes d
    WHERE NOT EXISTS (SELECT 1 FROM ref.DiscrepancyType x WHERE x.TenantId = @TenantId AND x.Code = d.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- H. Candidate statuses (CV-bank-level; see script header note on the
    -- reconciliation with the full pipeline-status list, which is seeded as
    -- workflow states in 05-seed-workflow-approval-sla.sql).
    -- ========================================================================
    DECLARE @CandidateStatuses TABLE (Code nvarchar(100), Name nvarchar(400), IsTerminal bit, SortOrder int);
    INSERT INTO @CandidateStatuses (Code, Name, IsTerminal, SortOrder) VALUES
    (N'NEW', N'New', 0, 10),
    (N'AVAILABLE_IN_CV_BANK', N'Available in CV Bank', 0, 20),
    (N'UNDER_REVIEW', N'Under Review', 0, 30),
    (N'SHORTLISTED', N'Shortlisted', 0, 40),
    (N'ON_HOLD', N'On Hold', 0, 50),
    (N'IN_PROCESS', N'In Process (active on one or more TANs)', 0, 60),
    (N'READY_FOR_CONVERSION', N'Ready for Conversion', 0, 70),
    (N'CONVERTED_TO_EMPLOYEE', N'Converted to Employee', 1, 80),
    (N'WITHDRAWN', N'Withdrawn', 1, 90),
    (N'INACTIVE', N'Inactive', 1, 100);

    INSERT INTO ref.CandidateStatus (TenantId, Code, Name, IsTerminal, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.IsTerminal, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @CandidateStatuses s
    WHERE NOT EXISTS (SELECT 1 FROM ref.CandidateStatus x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- I. Offer statuses
    -- ========================================================================
    DECLARE @OfferStatuses TABLE (Code nvarchar(100), Name nvarchar(400), IsTerminal bit, SortOrder int);
    INSERT INTO @OfferStatuses (Code, Name, IsTerminal, SortOrder) VALUES
    (N'Draft', N'Draft', 0, 10), (N'PendingApproval', N'Pending Approval', 0, 20),
    (N'Approved', N'Approved', 0, 30), (N'Sent', N'Sent', 0, 40), (N'Viewed', N'Viewed', 0, 50),
    (N'Accepted', N'Accepted', 1, 60), (N'Declined', N'Declined', 1, 70),
    (N'Expired', N'Expired', 1, 80), (N'Withdrawn', N'Withdrawn', 1, 90);
    -- NOTE: codes use the exact casing already relied on by offer.usp_*
    -- procedures (Draft/PendingApproval/Approved/Sent) — case-insensitive
    -- collation makes this cosmetic, but kept literal for readability/grep.

    INSERT INTO ref.OfferStatus (TenantId, Code, Name, IsTerminal, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.IsTerminal, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @OfferStatuses s
    WHERE NOT EXISTS (SELECT 1 FROM ref.OfferStatus x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- J. Document statuses
    -- ========================================================================
    DECLARE @DocumentStatuses TABLE (Code nvarchar(100), Name nvarchar(400), IsTerminal bit, SortOrder int);
    INSERT INTO @DocumentStatuses (Code, Name, IsTerminal, SortOrder) VALUES
    (N'REQUESTED', N'Requested', 0, 10), (N'UPLOADED', N'Uploaded', 0, 20), (N'SCANNING', N'Scanning', 0, 30),
    (N'VALIDATED', N'Validated', 0, 40), (N'VERIFIED', N'Verified', 1, 50),
    (N'REUPLOAD_REQUIRED', N'Re-upload Required', 0, 60), (N'REJECTED', N'Rejected', 1, 70),
    (N'EXPIRED', N'Expired', 1, 80), (N'ARCHIVED', N'Archived', 1, 90);

    INSERT INTO ref.DocumentStatus (TenantId, Code, Name, IsTerminal, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.IsTerminal, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @DocumentStatuses s
    WHERE NOT EXISTS (SELECT 1 FROM ref.DocumentStatus x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- K. Verification statuses
    -- ========================================================================
    DECLARE @VerificationStatuses TABLE (Code nvarchar(100), Name nvarchar(400), IsTerminal bit, SortOrder int);
    INSERT INTO @VerificationStatuses (Code, Name, IsTerminal, SortOrder) VALUES
    (N'NOT_STARTED', N'Not Started', 0, 10), (N'IN_PROGRESS', N'In Progress', 0, 20),
    (N'PENDING_INFORMATION', N'Pending Information', 0, 30), (N'COMPLETED', N'Completed', 1, 40),
    (N'FAILED', N'Failed', 1, 50), (N'ON_HOLD', N'On Hold', 0, 60), (N'WAIVED', N'Waived', 1, 70);

    INSERT INTO ref.VerificationStatus (TenantId, Code, Name, IsTerminal, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.IsTerminal, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @VerificationStatuses s
    WHERE NOT EXISTS (SELECT 1 FROM ref.VerificationStatus x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- L'. Discrepancy statuses (spec section 11G's resolution-status list)
    -- ========================================================================
    DECLARE @DiscrepancyStatuses TABLE (Code nvarchar(100), Name nvarchar(400), IsTerminal bit, SortOrder int);
    INSERT INTO @DiscrepancyStatuses (Code, Name, IsTerminal, SortOrder) VALUES
    (N'OPEN', N'Open', 0, 10), (N'AWAITING_CANDIDATE_RESPONSE', N'Awaiting Candidate Response', 0, 20),
    (N'UNDER_REVIEW', N'Under Review', 0, 30), (N'RESOLVED', N'Resolved', 0, 40),
    (N'EXCEPTION_APPROVED', N'Exception Approved', 0, 50), (N'CLOSED', N'Closed', 1, 60), (N'REJECTED', N'Rejected', 1, 70);

    INSERT INTO ref.DiscrepancyStatus (TenantId, Code, Name, IsTerminal, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.IsTerminal, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @DiscrepancyStatuses s
    WHERE NOT EXISTS (SELECT 1 FROM ref.DiscrepancyStatus x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- L. Employee statuses
    -- ========================================================================
    DECLARE @EmployeeStatuses TABLE (Code nvarchar(100), Name nvarchar(400), IsTerminal bit, SortOrder int);
    INSERT INTO @EmployeeStatuses (Code, Name, IsTerminal, SortOrder) VALUES
    (N'PRE_JOINING', N'Pre-Joining', 0, 10), (N'Active', N'Active', 0, 20), (N'ONBOARDING', N'Onboarding', 0, 30),
    (N'INACTIVE', N'Inactive', 0, 40), (N'EXITED', N'Exited', 1, 50);
    -- 'Active' keeps the exact casing employee.usp_CreateEmployeeFromCandidate
    -- looks up (Code = 'Active') — cosmetic under CI collation, kept literal.

    INSERT INTO ref.EmployeeStatus (TenantId, Code, Name, IsTerminal, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, s.Code, s.Name, s.IsTerminal, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @EmployeeStatuses s
    WHERE NOT EXISTS (SELECT 1 FROM ref.EmployeeStatus x WHERE x.TenantId = @TenantId AND x.Code = s.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- M. Notification channels (global — no TenantId column on this table)
    -- ========================================================================
    DECLARE @Channels TABLE (Code nvarchar(100), Name nvarchar(400));
    INSERT INTO @Channels (Code, Name) VALUES
    (N'EMAIL', N'Email'), (N'SMS', N'SMS'), (N'IN_APP', N'In-App'), (N'WEBHOOK', N'Webhook');

    INSERT INTO ref.NotificationChannel (Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT c.Code, c.Name, 1, @ExecutionUtc, @ActorUserId
    FROM @Channels c
    WHERE NOT EXISTS (SELECT 1 FROM ref.NotificationChannel x WHERE x.Code = c.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- N. Feature flags (global definition) + tenant-scoped assignment
    -- ========================================================================
    DECLARE @FeatureFlags TABLE (Code nvarchar(200), Name nvarchar(400), DefaultEnabled bit, TenantEnabled bit);
    INSERT INTO @FeatureFlags (Code, Name, DefaultEnabled, TenantEnabled) VALUES
    (N'AI_CANDIDATE_MATCHING', N'AI Candidate Matching', 0, 1),
    (N'AI_CV_PARSING', N'AI CV Parsing', 0, 1),
    (N'AI_DISCREPANCY_SUGGESTIONS', N'AI Discrepancy Suggestions', 0, 1),
    (N'CLIENT_INTERVIEW_ENABLED', N'Client Interview Enabled', 0, 1),
    (N'OFFER_ESIGN_ENABLED', N'Offer E-Sign Enabled', 0, 0),
    (N'GREEN_FORM_ENABLED', N'Green Form Enabled', 0, 1),
    (N'DOCUMENT_VERIFICATION_ENABLED', N'Document Verification Enabled', 0, 1),
    (N'EMPLOYEE_CONVERSION_ENABLED', N'Employee Conversion Enabled', 0, 1),
    (N'RAG_POLICY_ASSISTANT_ENABLED', N'RAG Policy Assistant Enabled', 0, 1),
    (N'MCP_CALENDAR_ENABLED', N'MCP Calendar Enabled', 0, 0),
    (N'MCP_EMAIL_ENABLED', N'MCP Email Enabled', 0, 0),
    (N'MCP_HRMS_ENABLED', N'MCP HRMS Enabled', 0, 0),
    (N'MCP_PAYROLL_ENABLED', N'MCP Payroll Enabled', 0, 0),
    (N'MCP_IT_PROVISIONING_ENABLED', N'MCP IT Provisioning Enabled', 0, 0),
    (N'AUDIT_EXPORT_ENABLED', N'Audit Export Enabled', 0, 1);
    -- DefaultEnabled = 0 (global platform default OFF); TenantEnabled marks
    -- what DEMO-HR turns on for demonstration purposes via FeatureFlagAssignment.
    -- MCP_* integration flags default OFF even for DEMO-HR since 08 seeds
    -- MCP/integration *configuration metadata* only, not a live connection.

    INSERT INTO ref.FeatureFlag (Code, Name, DefaultEnabled, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT f.Code, f.Name, f.DefaultEnabled, 1, @ExecutionUtc, @ActorUserId
    FROM @FeatureFlags f
    WHERE NOT EXISTS (SELECT 1 FROM ref.FeatureFlag x WHERE x.Code = f.Code AND x.IsDeleted = 0);

    INSERT INTO ref.FeatureFlagAssignment (FeatureFlagId, TenantId, IsEnabled, CreatedAtUtc, CreatedByUserId)
    SELECT ff.FeatureFlagId, @TenantId, f.TenantEnabled, @ExecutionUtc, @ActorUserId
    FROM @FeatureFlags f
    JOIN ref.FeatureFlag ff ON ff.Code = f.Code AND ff.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM ref.FeatureFlagAssignment x WHERE x.FeatureFlagId = ff.FeatureFlagId AND x.TenantId = @TenantId AND x.IsDeleted = 0);

    COMMIT TRAN;
    PRINT N'04-seed-reference-master-data.sql complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
