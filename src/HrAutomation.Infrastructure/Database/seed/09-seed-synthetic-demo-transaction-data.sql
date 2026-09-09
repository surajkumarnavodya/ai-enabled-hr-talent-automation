/* ============================================================================
   09-seed-synthetic-demo-transaction-data.sql
   Purpose : Seed the minimal synthetic transactional data needed to
             demonstrate the recruitment/onboarding screens and workflow
             gates end-to-end. Uses the real stored procedures from
             Database/scripts/07-create-stored-procedures.sql wherever one
             exists (proving the approval gates actually hold for this data,
             not just describing them) — direct guarded INSERTs only where no
             procedure exists yet.
   Depends on: 01 through 08.
   Idempotent: Yes — every entity is looked up by a stable business key
   (tag name, email, TAN number, etc.) before being created.

   ALL DATA IS SYNTHETIC. No real candidate, employee, or company data.
   Fictional names only: Alex Morgan, Jordan Taylor, Casey Lee, Riley Patel,
   Morgan Reyes, Taylor Kim. Emails use @example.test. No DOB, no government
   ID values, no bank data, no real document content.

   BUSINESS-CODE MARKER (M5 workaround): recruitment.Candidate has no
   business-reference/code column (see final report). Each demo candidate is
   tagged with its own recruitment.CandidateTag (e.g. "DEMO-CAN-001"), which
   doubles as both a human-readable reference AND this package's positive
   demo-data marker for the cleanup script (11-seed-cleanup-demo-data.sql
   deletes exactly the candidates carrying a DEMO-CAN-% tag).
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

IF NOT EXISTS (SELECT 1 FROM ref.OfferStatus WHERE TenantId = @TenantId AND IsDeleted = 0)
    THROW 50003, 'Seed execution failed: reference master data was not found. Run 04 through 08 first.', 1;

EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
EXEC sys.sp_set_session_context @key = N'UserId', @value = @ActorUserId;
EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

DECLARE @RecruiterUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.recruiter@example.test');
DECLARE @TaManagerUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.ta.manager@example.test');
DECLARE @HiringManagerUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.hiring.manager@example.test');
DECLARE @Interviewer1UserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.interviewer.1@example.test');
DECLARE @OfferApproverUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.offer.approver@example.test');
DECLARE @HrAdminUserId UNIQUEIDENTIFIER = @ActorUserId;
DECLARE @DocVerifierUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.document.verifier@example.test');
DECLARE @OnboardingAdminUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.onboarding.admin@example.test');

BEGIN TRY
    BEGIN TRAN;

    -- ========================================================================
    -- A. TAN + Job Requisition (Approved / Active Sourcing)
    -- ========================================================================
    DECLARE @TanId UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM recruitment.TalentAcquisitionNumber WHERE TenantId = @TenantId AND TanNumber = N'DEMO-TAN-2026-00001' AND IsDeleted = 0)
    BEGIN
        EXEC recruitment.usp_CreateTalentAcquisitionNumber @TenantId = @TenantId, @RequestedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        SELECT TOP (1) @TanId = TalentAcquisitionNumberId FROM recruitment.TalentAcquisitionNumber WHERE TenantId = @TenantId ORDER BY CreatedAtUtc DESC;
        -- Cosmetic override to the spec's exact demo business code — the
        -- procedure's real auto-numbering does not parse {YYYY} tokens (see
        -- final report M6); this keeps the demo screen readable while still
        -- proving the procedure/sequence-reservation path executed for real.
        UPDATE recruitment.TalentAcquisitionNumber SET TanNumber = N'DEMO-TAN-2026-00001' WHERE TalentAcquisitionNumberId = @TanId;
    END
    ELSE
        SELECT @TanId = TalentAcquisitionNumberId FROM recruitment.TalentAcquisitionNumber WHERE TenantId = @TenantId AND TanNumber = N'DEMO-TAN-2026-00001' AND IsDeleted = 0;

    DECLARE @JobRequisitionId UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM recruitment.JobRequisition WHERE TenantId = @TenantId AND TalentAcquisitionNumberId = @TanId AND IsDeleted = 0)
    BEGIN
        EXEC recruitment.usp_CreateJobRequisition
            @TenantId = @TenantId, @TalentAcquisitionNumberId = @TanId, @Title = N'Senior .NET Full Stack Developer',
            @HeadcountRequested = 2, @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;

        SELECT TOP (1) @JobRequisitionId = JobRequisitionId FROM recruitment.JobRequisition WHERE TenantId = @TenantId AND TalentAcquisitionNumberId = @TanId ORDER BY CreatedAtUtc DESC;

        DECLARE @DesignationId UNIQUEIDENTIFIER = (SELECT DesignationId FROM org.Designation WHERE TenantId = @TenantId AND DesignationCode = N'SENIOR_SOFTWARE_ENGINEER');
        DECLARE @JobGradeId UNIQUEIDENTIFIER = (SELECT JobGradeId FROM org.JobGrade WHERE TenantId = @TenantId AND GradeCode = N'G3');
        DECLARE @EmploymentTypeId UNIQUEIDENTIFIER = (SELECT EmploymentTypeId FROM ref.EmploymentType WHERE TenantId = @TenantId AND Code = N'FULL_TIME');
        DECLARE @LocationId UNIQUEIDENTIFIER = (SELECT LocationId FROM org.Location WHERE TenantId = @TenantId AND LocationCode = N'DEMO-MUM');
        DECLARE @WorkModeId UNIQUEIDENTIFIER = (SELECT WorkModeId FROM org.WorkMode WHERE TenantId = @TenantId AND Code = N'HYBRID');

        UPDATE recruitment.JobRequisition
            SET DesignationId = @DesignationId, JobGradeId = @JobGradeId, EmploymentTypeId = @EmploymentTypeId,
                LocationId = @LocationId, WorkModeId = @WorkModeId
            WHERE JobRequisitionId = @JobRequisitionId;

        -- Job description
        INSERT INTO recruitment.JobDescription (TenantId, JobRequisitionId, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @JobRequisitionId, @ExecutionUtc, @RecruiterUserId);
        DECLARE @JobDescriptionId UNIQUEIDENTIFIER = (SELECT JobDescriptionId FROM recruitment.JobDescription WHERE JobRequisitionId = @JobRequisitionId);

        INSERT INTO recruitment.JobDescriptionVersion (TenantId, JobDescriptionId, VersionNumber, Summary, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @JobDescriptionId, 1, N'Senior .NET Full Stack Developer building recruitment platform features across the API and React front end. (Synthetic demo job description.)', N'Approved', @ExecutionUtc, @RecruiterUserId);

        DECLARE @JdVersionId UNIQUEIDENTIFIER = (SELECT JobDescriptionVersionId FROM recruitment.JobDescriptionVersion WHERE JobDescriptionId = @JobDescriptionId AND VersionNumber = 1);
        UPDATE recruitment.JobDescription SET CurrentVersionId = @JdVersionId WHERE JobDescriptionId = @JobDescriptionId;

        -- Mandatory + preferred skills
        DECLARE @ReqSkills TABLE (SkillCode nvarchar(200), IsMandatory bit);
        INSERT INTO @ReqSkills (SkillCode, IsMandatory) VALUES
        (N'C_SHARP', 1), (N'DOTNET', 1), (N'ASPNET_CORE', 1), (N'SQL_SERVER', 1), (N'REACT', 1), (N'TYPESCRIPT', 1),
        (N'AZURE', 0), (N'DOCKER', 0), (N'CI_CD', 0), (N'SCRUM', 0);

        INSERT INTO recruitment.JobRequirementSkill (TenantId, JobRequisitionId, SkillId, IsMandatory, CreatedAtUtc, CreatedByUserId)
        SELECT @TenantId, @JobRequisitionId, sk.SkillId, rs.IsMandatory, @ExecutionUtc, @RecruiterUserId
        FROM @ReqSkills rs
        JOIN ref.Skill sk ON sk.TenantId = @TenantId AND sk.Code = rs.SkillCode AND sk.IsDeleted = 0;

        INSERT INTO recruitment.JobRequisitionHiringManager (TenantId, JobRequisitionId, UserId, IsPrimary, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @JobRequisitionId, @HiringManagerUserId, 1, @ExecutionUtc, @RecruiterUserId);

        -- Approve the TAN through the real workflow gate.
        EXEC recruitment.usp_SubmitJobRequisitionForApproval @TenantId = @TenantId, @JobRequisitionId = @JobRequisitionId, @ApprovalMatrixCode = N'TAN_APPROVAL_STD', @RequestedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        EXEC recruitment.usp_ApproveJobRequisition @TenantId = @TenantId, @JobRequisitionId = @JobRequisitionId, @ApproverUserId = @TaManagerUserId, @Comments = N'Approved for active sourcing (synthetic demo data).', @CorrelationId = @CorrelationId;

        -- Approved -> ActiveSourcing: no dedicated procedure exists yet for
        -- this specific transition (see docs/stored-procedure-catalog.md
        -- backlog) — applied directly, matching the audit-trail pattern used
        -- by every procedure in this schema.
        UPDATE recruitment.JobRequisition SET RequisitionStatusCode = N'ActiveSourcing', UpdatedAtUtc = @ExecutionUtc, UpdatedByUserId = @TaManagerUserId WHERE JobRequisitionId = @JobRequisitionId;
        INSERT INTO recruitment.JobRequisitionStatusHistory (TenantId, JobRequisitionId, FromStatusCode, ToStatusCode, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @JobRequisitionId, N'Approved', N'ActiveSourcing', @TaManagerUserId, @CorrelationId);
    END
    ELSE
        SELECT @JobRequisitionId = JobRequisitionId FROM recruitment.JobRequisition WHERE TenantId = @TenantId AND TalentAcquisitionNumberId = @TanId AND IsDeleted = 0;

    -- ========================================================================
    -- B/C. Four candidates + skills + tag-based demo reference codes
    -- ========================================================================
    DECLARE @Candidates TABLE (TagCode nvarchar(100), FirstName nvarchar(100), LastName nvarchar(100), Email nvarchar(320), Phone nvarchar(30));
    INSERT INTO @Candidates (TagCode, FirstName, LastName, Email, Phone) VALUES
    (N'DEMO-CAN-001', N'Alex', N'Morgan', N'alex.morgan@example.test', N'+1-555-0101'),
    (N'DEMO-CAN-002', N'Jordan', N'Taylor', N'jordan.taylor@example.test', N'+1-555-0102'),
    (N'DEMO-CAN-003', N'Casey', N'Lee', N'casey.lee@example.test', N'+1-555-0103'),
    (N'DEMO-CAN-004', N'Riley', N'Patel', N'riley.patel@example.test', N'+1-555-0104');

    DECLARE cand_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT TagCode, FirstName, LastName, Email, Phone FROM @Candidates;
    DECLARE @TagCode nvarchar(100), @FirstName nvarchar(100), @LastName nvarchar(100), @Email nvarchar(320), @Phone nvarchar(30);
    -- Declared ONCE, outside the loop, and explicitly reset to NULL at the
    -- top of every iteration below: DECLARE @x TYPE; only NULL-initializes
    -- on the first pass through a loop body — on later passes it is a no-op
    -- and the variable silently keeps its previous iteration's value. This
    -- is a real bug this package hit and fixed during authoring (see
    -- final report) — SET @x = NULL; is the safe, explicit pattern.
    DECLARE @CandidateId UNIQUEIDENTIFIER;
    OPEN cand_cursor;
    FETCH NEXT FROM cand_cursor INTO @TagCode, @FirstName, @LastName, @Email, @Phone;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateTag WHERE TenantId = @TenantId AND TagName = @TagCode AND IsDeleted = 0)
            INSERT INTO recruitment.CandidateTag (TenantId, TagName, CreatedAtUtc, CreatedByUserId) VALUES (@TenantId, @TagCode, @ExecutionUtc, @RecruiterUserId);

        SET @CandidateId = NULL;
        SELECT @CandidateId = c.CandidateId FROM recruitment.Candidate c
            JOIN recruitment.CandidateTagMapping ctm ON ctm.CandidateId = c.CandidateId
            JOIN recruitment.CandidateTag ct ON ct.CandidateTagId = ctm.CandidateTagId
            WHERE ct.TenantId = @TenantId AND ct.TagName = @TagCode AND c.IsDeleted = 0;

        IF @CandidateId IS NULL
        BEGIN
            EXEC recruitment.usp_CreateCandidate @TenantId = @TenantId, @FirstName = @FirstName, @LastName = @LastName, @Email = @Email, @Phone = @Phone, @CandidateSourceCode = N'CAREER_SITE', @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
            SELECT TOP (1) @CandidateId = CandidateId FROM recruitment.Candidate WHERE TenantId = @TenantId AND FirstName = @FirstName AND LastName = @LastName AND IsDeleted = 0 ORDER BY CreatedAtUtc DESC;

            INSERT INTO recruitment.CandidateTagMapping (TenantId, CandidateId, CandidateTagId, CreatedAtUtc, CreatedByUserId)
            SELECT @TenantId, @CandidateId, CandidateTagId, @ExecutionUtc, @RecruiterUserId FROM recruitment.CandidateTag WHERE TenantId = @TenantId AND TagName = @TagCode;

            EXEC recruitment.usp_CreateCandidateApplication @TenantId = @TenantId, @CandidateId = @CandidateId, @JobRequisitionId = @JobRequisitionId, @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        END

        FETCH NEXT FROM cand_cursor INTO @TagCode, @FirstName, @LastName, @Email, @Phone;
    END
    CLOSE cand_cursor;
    DEALLOCATE cand_cursor;

    -- Candidate skills (job-related evidence only)
    DECLARE @CandidateSkills TABLE (TagCode nvarchar(100), SkillCode nvarchar(200), Proficiency nvarchar(60), Years decimal(4,1));
    INSERT INTO @CandidateSkills (TagCode, SkillCode, Proficiency, Years) VALUES
    (N'DEMO-CAN-001', N'C_SHARP', N'Advanced', 6.0), (N'DEMO-CAN-001', N'DOTNET', N'Advanced', 6.0),
    (N'DEMO-CAN-001', N'ASPNET_CORE', N'Advanced', 5.0), (N'DEMO-CAN-001', N'SQL_SERVER', N'Advanced', 5.0),
    (N'DEMO-CAN-001', N'REACT', N'Intermediate', 3.0), (N'DEMO-CAN-001', N'TYPESCRIPT', N'Intermediate', 3.0),
    (N'DEMO-CAN-002', N'C_SHARP', N'Intermediate', 3.0), (N'DEMO-CAN-002', N'DOTNET', N'Intermediate', 3.0),
    (N'DEMO-CAN-002', N'SQL_SERVER', N'Intermediate', 3.0), (N'DEMO-CAN-002', N'REACT', N'Beginner', 1.0),
    (N'DEMO-CAN-003', N'SQL_SERVER', N'Beginner', 1.0), (N'DEMO-CAN-003', N'REACT', N'Beginner', 1.0),
    (N'DEMO-CAN-004', N'C_SHARP', N'Intermediate', 2.5), (N'DEMO-CAN-004', N'DOTNET', N'Intermediate', 2.5),
    (N'DEMO-CAN-004', N'ASPNET_CORE', N'Intermediate', 2.0), (N'DEMO-CAN-004', N'SQL_SERVER', N'Intermediate', 2.5);

    INSERT INTO recruitment.CandidateSkill (TenantId, CandidateId, SkillId, ProficiencyLevel, YearsExperience, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, c.CandidateId, sk.SkillId, cs.Proficiency, cs.Years, @ExecutionUtc, @RecruiterUserId
    FROM @CandidateSkills cs
    JOIN recruitment.CandidateTag ct ON ct.TenantId = @TenantId AND ct.TagName = cs.TagCode
    JOIN recruitment.CandidateTagMapping ctm ON ctm.CandidateTagId = ct.CandidateTagId
    JOIN recruitment.Candidate c ON c.CandidateId = ctm.CandidateId
    JOIN ref.Skill sk ON sk.TenantId = @TenantId AND sk.Code = cs.SkillCode AND sk.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM recruitment.CandidateSkill x WHERE x.CandidateId = c.CandidateId AND x.SkillId = sk.SkillId AND x.IsDeleted = 0);

    -- Convenience lookups for the rest of this script
    DECLARE @Cand1 UNIQUEIDENTIFIER, @Cand2 UNIQUEIDENTIFIER, @Cand3 UNIQUEIDENTIFIER, @Cand4 UNIQUEIDENTIFIER;
    DECLARE @App1 UNIQUEIDENTIFIER, @App2 UNIQUEIDENTIFIER, @App3 UNIQUEIDENTIFIER, @App4 UNIQUEIDENTIFIER;
    SELECT @Cand1 = c.CandidateId FROM recruitment.Candidate c JOIN recruitment.CandidateTagMapping m ON m.CandidateId=c.CandidateId JOIN recruitment.CandidateTag t ON t.CandidateTagId=m.CandidateTagId WHERE t.TenantId=@TenantId AND t.TagName=N'DEMO-CAN-001';
    SELECT @Cand2 = c.CandidateId FROM recruitment.Candidate c JOIN recruitment.CandidateTagMapping m ON m.CandidateId=c.CandidateId JOIN recruitment.CandidateTag t ON t.CandidateTagId=m.CandidateTagId WHERE t.TenantId=@TenantId AND t.TagName=N'DEMO-CAN-002';
    SELECT @Cand3 = c.CandidateId FROM recruitment.Candidate c JOIN recruitment.CandidateTagMapping m ON m.CandidateId=c.CandidateId JOIN recruitment.CandidateTag t ON t.CandidateTagId=m.CandidateTagId WHERE t.TenantId=@TenantId AND t.TagName=N'DEMO-CAN-003';
    SELECT @Cand4 = c.CandidateId FROM recruitment.Candidate c JOIN recruitment.CandidateTagMapping m ON m.CandidateId=c.CandidateId JOIN recruitment.CandidateTag t ON t.CandidateTagId=m.CandidateTagId WHERE t.TenantId=@TenantId AND t.TagName=N'DEMO-CAN-004';
    SELECT @App1 = CandidateApplicationId FROM recruitment.CandidateApplication WHERE TenantId=@TenantId AND CandidateId=@Cand1 AND JobRequisitionId=@JobRequisitionId;
    SELECT @App2 = CandidateApplicationId FROM recruitment.CandidateApplication WHERE TenantId=@TenantId AND CandidateId=@Cand2 AND JobRequisitionId=@JobRequisitionId;
    SELECT @App3 = CandidateApplicationId FROM recruitment.CandidateApplication WHERE TenantId=@TenantId AND CandidateId=@Cand3 AND JobRequisitionId=@JobRequisitionId;
    SELECT @App4 = CandidateApplicationId FROM recruitment.CandidateApplication WHERE TenantId=@TenantId AND CandidateId=@Cand4 AND JobRequisitionId=@JobRequisitionId;

    -- ========================================================================
    -- D. Candidate matching (one completed run, four scores + explanations)
    -- ========================================================================
    DECLARE @MatchRunId UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateMatchRun WHERE TenantId = @TenantId AND JobRequisitionId = @JobRequisitionId AND IsDeleted = 0)
    BEGIN
        DECLARE @MatchModelId UNIQUEIDENTIFIER = (SELECT AiModelConfigurationId FROM ref.AiModelConfiguration WHERE TenantId = @TenantId AND Code = N'CANDIDATE_MATCHING_MODEL');
        INSERT INTO recruitment.CandidateMatchRun (TenantId, JobRequisitionId, AiModelConfigurationId, RunStatus, RequestedByUserId, RequestedAtUtc, CompletedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @JobRequisitionId, @MatchModelId, N'Succeeded', @RecruiterUserId, @ExecutionUtc, @ExecutionUtc, @ExecutionUtc, @RecruiterUserId);
        SELECT @MatchRunId = CandidateMatchRunId FROM recruitment.CandidateMatchRun WHERE TenantId = @TenantId AND JobRequisitionId = @JobRequisitionId AND IsDeleted = 0;

        DECLARE @Scores TABLE (CandidateId UNIQUEIDENTIFIER, OverallScore decimal(5,4), ConfidenceScore decimal(5,4), Rank int, RequiresReview bit, Evidence nvarchar(500), SkillGapNote nvarchar(500));
        INSERT INTO @Scores (CandidateId, OverallScore, ConfidenceScore, Rank, RequiresReview, Evidence, SkillGapNote) VALUES
        (@Cand1, 0.8500, 0.9000, 1, 0, N'Relevant C#/.NET/ASP.NET Core, SQL Server, and React/TypeScript experience recorded.', NULL),
        (@Cand2, 0.6800, 0.8000, 2, 0, N'Relevant .NET and SQL Server experience recorded; frontend depth is lighter.', N'ASP.NET Core and TypeScript experience not confirmed.'),
        (@Cand3, 0.3500, 0.7500, 4, 1, N'Limited overlap with mandatory skill set.', N'Mandatory C#/.NET/ASP.NET Core experience not confirmed.'),
        (@Cand4, 0.6200, 0.7800, 3, 0, N'Relevant .NET and SQL Server experience recorded.', N'React/TypeScript experience not confirmed.');

        INSERT INTO recruitment.CandidateMatchScore (TenantId, CandidateMatchRunId, CandidateId, OverallScore, ConfidenceScore, Rank, RequiresHumanReview, CreatedAtUtc, CreatedByUserId)
        SELECT @TenantId, @MatchRunId, s.CandidateId, s.OverallScore, s.ConfidenceScore, s.Rank, s.RequiresReview, @ExecutionUtc, @RecruiterUserId
        FROM @Scores s;

        INSERT INTO recruitment.CandidateMatchExplanation (TenantId, CandidateMatchScoreId, FactorName, FactorWeight, FactorScore, ExplanationText, CreatedAtUtc)
        SELECT @TenantId, cms.CandidateMatchScoreId, N'MandatorySkillCoverage', 0.3500, s.OverallScore, s.Evidence, @ExecutionUtc
        FROM @Scores s JOIN recruitment.CandidateMatchScore cms ON cms.CandidateMatchRunId = @MatchRunId AND cms.CandidateId = s.CandidateId;

        INSERT INTO recruitment.CandidateMatchExplanation (TenantId, CandidateMatchScoreId, FactorName, FactorWeight, FactorScore, ExplanationText, CreatedAtUtc)
        SELECT @TenantId, cms.CandidateMatchScoreId, N'SkillGap', 0.0000, 0.0000, s.SkillGapNote, @ExecutionUtc
        FROM @Scores s JOIN recruitment.CandidateMatchScore cms ON cms.CandidateMatchRunId = @MatchRunId AND cms.CandidateId = s.CandidateId
        WHERE s.SkillGapNote IS NOT NULL;
    END
    ELSE
        SELECT @MatchRunId = CandidateMatchRunId FROM recruitment.CandidateMatchRun WHERE TenantId = @TenantId AND JobRequisitionId = @JobRequisitionId AND IsDeleted = 0;

    -- ========================================================================
    -- Candidate 1: Shortlisted, L1 scheduled (future slot)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateShortlist WHERE CandidateApplicationId = @App1 AND IsDeleted = 0)
        INSERT INTO recruitment.CandidateShortlist (TenantId, CandidateApplicationId, ShortlistedByUserId, ShortlistedAtUtc, IsAiRecommended, CandidateMatchRunId, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @App1, @RecruiterUserId, @ExecutionUtc, 1, @MatchRunId, @ExecutionUtc, @RecruiterUserId);

    DECLARE @Shortlist1Id UNIQUEIDENTIFIER = (SELECT CandidateShortlistId FROM recruitment.CandidateShortlist WHERE CandidateApplicationId = @App1 AND IsDeleted = 0);

    -- F. Pending shortlist approval task
    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateShortlistApproval WHERE CandidateShortlistId = @Shortlist1Id)
        INSERT INTO recruitment.CandidateShortlistApproval (TenantId, CandidateShortlistId, ApproverUserId, DecisionStatus, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Shortlist1Id, @TaManagerUserId, N'Pending', @ExecutionUtc, @RecruiterUserId);

    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'SHORTLISTED' WHERE CandidateApplicationId = @App1 AND ApplicationStatusCode = N'Applied';

    -- E. Interview (L1, scheduled, future slot)
    IF NOT EXISTS (SELECT 1 FROM recruitment.Interview WHERE CandidateApplicationId = @App1 AND IsDeleted = 0)
        INSERT INTO recruitment.Interview (TenantId, CandidateApplicationId, Status, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @App1, N'Scheduled', @ExecutionUtc, @RecruiterUserId);

    DECLARE @Interview1Id UNIQUEIDENTIFIER = (SELECT InterviewId FROM recruitment.Interview WHERE CandidateApplicationId = @App1 AND IsDeleted = 0);
    DECLARE @L1RoundDefId UNIQUEIDENTIFIER = (SELECT InterviewRoundDefinitionId FROM ref.InterviewRoundDefinition WHERE TenantId = @TenantId AND Code = N'L1_TECHNICAL');

    IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewRound WHERE InterviewId = @Interview1Id AND SequenceNumber = 1 AND IsDeleted = 0)
        INSERT INTO recruitment.InterviewRound (TenantId, InterviewId, InterviewRoundDefinitionId, SequenceNumber, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Interview1Id, @L1RoundDefId, 1, @ExecutionUtc, @RecruiterUserId);

    DECLARE @Round1Id UNIQUEIDENTIFIER = (SELECT InterviewRoundId FROM recruitment.InterviewRound WHERE InterviewId = @Interview1Id AND SequenceNumber = 1 AND IsDeleted = 0);

    IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewPanelMember WHERE InterviewRoundId = @Round1Id AND UserId = @Interviewer1UserId AND IsDeleted = 0)
        INSERT INTO recruitment.InterviewPanelMember (TenantId, InterviewRoundId, UserId, IsLeadInterviewer, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Round1Id, @Interviewer1UserId, 1, @ExecutionUtc, @RecruiterUserId);

    IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewScheduleSlot WHERE InterviewRoundId = @Round1Id AND IsCurrent = 1)
        INSERT INTO recruitment.InterviewScheduleSlot (TenantId, InterviewRoundId, ScheduledStartUtc, ScheduledEndUtc, TimeZoneId, LocationOrLink, IsCurrent, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Round1Id, DATEADD(DAY, 5, @ExecutionUtc), DATEADD(MINUTE, 45, DATEADD(DAY, 5, @ExecutionUtc)), N'Asia/Kolkata', N'Demo Meeting Room (synthetic — not a live link): meet.example.test/demo-l1-001', 1, @ExecutionUtc, @RecruiterUserId);

    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'L1_SCHEDULED' WHERE CandidateApplicationId = @App1;

    -- ========================================================================
    -- Candidate 2: L1 feedback pending (past slot, no feedback submitted)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM recruitment.Interview WHERE CandidateApplicationId = @App2 AND IsDeleted = 0)
        INSERT INTO recruitment.Interview (TenantId, CandidateApplicationId, Status, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @App2, N'Scheduled', @ExecutionUtc, @RecruiterUserId);

    DECLARE @Interview2Id UNIQUEIDENTIFIER = (SELECT InterviewId FROM recruitment.Interview WHERE CandidateApplicationId = @App2 AND IsDeleted = 0);

    IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewRound WHERE InterviewId = @Interview2Id AND SequenceNumber = 1 AND IsDeleted = 0)
        INSERT INTO recruitment.InterviewRound (TenantId, InterviewId, InterviewRoundDefinitionId, SequenceNumber, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Interview2Id, @L1RoundDefId, 1, @ExecutionUtc, @RecruiterUserId);

    DECLARE @Round2Id UNIQUEIDENTIFIER = (SELECT InterviewRoundId FROM recruitment.InterviewRound WHERE InterviewId = @Interview2Id AND SequenceNumber = 1 AND IsDeleted = 0);

    IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewPanelMember WHERE InterviewRoundId = @Round2Id AND UserId = @Interviewer1UserId AND IsDeleted = 0)
        INSERT INTO recruitment.InterviewPanelMember (TenantId, InterviewRoundId, UserId, IsLeadInterviewer, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Round2Id, @Interviewer1UserId, 1, @ExecutionUtc, @RecruiterUserId);

    IF NOT EXISTS (SELECT 1 FROM recruitment.InterviewScheduleSlot WHERE InterviewRoundId = @Round2Id AND IsCurrent = 1)
        INSERT INTO recruitment.InterviewScheduleSlot (TenantId, InterviewRoundId, ScheduledStartUtc, ScheduledEndUtc, TimeZoneId, LocationOrLink, IsCurrent, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @Round2Id, DATEADD(DAY, -2, @ExecutionUtc), DATEADD(MINUTE, 45, DATEADD(DAY, -2, @ExecutionUtc)), N'Asia/Kolkata', N'Demo Meeting Room (synthetic — not a live link): meet.example.test/demo-l1-002', 1, @ExecutionUtc, @RecruiterUserId);

    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'L1_FEEDBACK_PENDING' WHERE CandidateApplicationId = @App2;

    -- F. Pending interview-outcome approval task (no InterviewOutcome row
    -- exists yet — that table requires an immediate decision, so the
    -- "pending" task is represented at the workflow.ApprovalRequest layer,
    -- pointed at the InterviewRound awaiting a decision).
    DECLARE @L1OutcomeMatrixId UNIQUEIDENTIFIER = (SELECT ApprovalMatrixId FROM ref.ApprovalMatrix WHERE TenantId = @TenantId AND MatrixCode = N'INTERVIEW_L1_OUTCOME_STD');
    IF NOT EXISTS (SELECT 1 FROM workflow.ApprovalRequest WHERE TenantId = @TenantId AND EntityType = N'recruitment.InterviewOutcome' AND EntityId = @Round2Id AND IsDeleted = 0)
    BEGIN
        DECLARE @OutcomeApprovalRequestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO workflow.ApprovalRequest (ApprovalRequestId, TenantId, ApprovalMatrixId, EntityType, EntityId, Status, RequestedByUserId, CorrelationId, CreatedAtUtc, CreatedByUserId)
        VALUES (@OutcomeApprovalRequestId, @TenantId, @L1OutcomeMatrixId, N'recruitment.InterviewOutcome', @Round2Id, N'Pending', @RecruiterUserId, @CorrelationId, @ExecutionUtc, @RecruiterUserId);

        INSERT INTO workflow.ApprovalStep (TenantId, ApprovalRequestId, ApprovalMatrixRuleId, StepOrder, AssignedApproverUserId, Status, CreatedAtUtc)
        SELECT @TenantId, @OutcomeApprovalRequestId, amr.ApprovalMatrixRuleId, amr.StepOrder, @HiringManagerUserId, N'Pending', @ExecutionUtc
        FROM ref.ApprovalMatrixRule amr WHERE amr.ApprovalMatrixId = @L1OutcomeMatrixId AND amr.StepOrder = 1;
    END

    -- ========================================================================
    -- Candidate 3: Rejected for this TAN (SKILL_MISMATCH)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateRejection WHERE CandidateApplicationId = @App3)
        EXEC recruitment.usp_RejectCandidateForRequisition
            @TenantId = @TenantId, @CandidateApplicationId = @App3, @RejectionReasonCode = N'SKILL_MISMATCH',
            @RejectionNotes = N'Mandatory technical skill set not sufficiently demonstrated for this requisition (synthetic demo reason).',
            @DecidedByUserId = @TaManagerUserId, @CorrelationId = @CorrelationId;

    -- ========================================================================
    -- Candidate 4: On hold / available as replacement
    -- (no usp_PlaceCandidateOnHold exists yet — applied directly, matching
    -- the audit-trail pattern used throughout this schema.)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateHoldReason WHERE CandidateApplicationId = @App4)
        INSERT INTO recruitment.CandidateHoldReason (TenantId, CandidateApplicationId, HoldReasonCode, HoldNotes, PlacedByUserId, PlacedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @App4, N'AVAILABLE_AS_REPLACEMENT', N'Kept available as a replacement candidate for this requisition (synthetic demo data).', @RecruiterUserId, @ExecutionUtc, @ExecutionUtc, @RecruiterUserId);

    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'ON_HOLD' WHERE CandidateApplicationId = @App4;

    -- ========================================================================
    -- G/H. One draft-offer-pending-approval for Candidate 1 (never Sent/Accepted here)
    -- ========================================================================
    DECLARE @OfferTemplateId UNIQUEIDENTIFIER = (SELECT OfferTemplateId FROM ref.OfferTemplate WHERE TenantId = @TenantId AND Code = N'DEMO_STANDARD_OFFER');
    DECLARE @Offer1Id UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM offer.Offer WHERE TenantId = @TenantId AND CandidateApplicationId = @App1 AND IsDeleted = 0)
    BEGIN
        EXEC offer.usp_CreateOfferDraft @TenantId = @TenantId, @CandidateApplicationId = @App1, @OfferTemplateId = @OfferTemplateId, @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        SELECT TOP (1) @Offer1Id = OfferId FROM offer.Offer WHERE TenantId = @TenantId AND CandidateApplicationId = @App1 ORDER BY CreatedAtUtc DESC;
        UPDATE offer.Offer SET ProposedStartDate = DATEADD(DAY, 30, CAST(@ExecutionUtc AS date)) WHERE OfferId = @Offer1Id;

        -- Placeholder-only offer document reference (see final report M8-style
        -- note: offer.OfferDocument requires NOT NULL storage columns).
        DECLARE @Offer1VersionId UNIQUEIDENTIFIER = (SELECT OfferVersionId FROM offer.OfferVersion WHERE OfferId = @Offer1Id AND VersionNumber = 1);
        INSERT INTO offer.OfferDocument (TenantId, OfferVersionId, ObjectStorageUri, FileName, MimeType, ContentHash, Status, GeneratedAtUtc)
        VALUES (@TenantId, @Offer1VersionId, N'demo://placeholder/offer-document/not-a-real-object', N'demo-offer-DEMO-CAN-001.pdf', N'application/pdf', HASHBYTES('SHA2_256', N'DEMO-PLACEHOLDER-OFFER-DOCUMENT-NOT-A-REAL-FILE'), N'Generated', @ExecutionUtc);

        -- Deliberately no offer.OfferCompensation row — see final report M7:
        -- TotalAnnualAmount is NOT NULL, and this package never fabricates a
        -- compensation figure, real or placeholder.

        EXEC offer.usp_SubmitOfferForApproval @TenantId = @TenantId, @OfferId = @Offer1Id, @ApprovalMatrixCode = N'OFFER_APPROVAL_STD', @RequestedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        -- Left at PendingApproval — never approved/sent in this script.
    END

    COMMIT TRAN;
    PRINT N'09-seed-synthetic-demo-transaction-data.sql PART 1 (TAN/candidates/matching/interviews/offer) complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO

/* ============================================================================
   PART 2 — Green Form, documents, verification, discrepancy, and the
   employee-conversion-pending candidate (section 13 H/I/J/K).

   Two additional fictional candidates carry this part of the demo:
     - DEMO-CAN-005 (Morgan Reyes): further along the pipeline — Green Form
       Submitted, one verified document, one pending, one needing re-upload,
       one open discrepancy, and a conversion request that is NOT YET
       approved (checklist intentionally incomplete).
     - DEMO-CAN-006 (Taylor Kim): carries the second Green Form example, left
       in the schema's "InProgress" status (see M17 mismatch note below).

   SCHEMA NOTE (M17): the request asks for a Green Form in "PENDING" state;
   onboarding.GreenFormSubmission.Status is constrained by
   CK_GreenFormSubmission_Status to ('InProgress','Submitted','UnderReview',
   'Completed') — there is no 'Pending' value. 'InProgress' (issued, not yet
   completed) is used as the closest equivalent.
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

DECLARE @JobRequisitionId UNIQUEIDENTIFIER = (
    SELECT jr.JobRequisitionId FROM recruitment.JobRequisition jr
    JOIN recruitment.TalentAcquisitionNumber tan ON tan.TalentAcquisitionNumberId = jr.TalentAcquisitionNumberId
    WHERE jr.TenantId = @TenantId AND tan.TanNumber = N'DEMO-TAN-2026-00001' AND jr.IsDeleted = 0
);
IF @JobRequisitionId IS NULL
    THROW 50003, 'Seed execution failed: demo TAN/job requisition was not found. Run PART 1 of this script first.', 1;

EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
EXEC sys.sp_set_session_context @key = N'UserId', @value = @ActorUserId;
EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

DECLARE @RecruiterUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.recruiter@example.test');
DECLARE @DocVerifierUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.document.verifier@example.test');
DECLARE @OnboardingAdminUserId UNIQUEIDENTIFIER = (SELECT UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.onboarding.admin@example.test');
DECLARE @HrAdminUserId UNIQUEIDENTIFIER = @ActorUserId;

BEGIN TRY
    BEGIN TRAN;

    -- --- Candidates 5 and 6 -------------------------------------------------
    DECLARE @Cand5 UNIQUEIDENTIFIER, @Cand6 UNIQUEIDENTIFIER, @App5 UNIQUEIDENTIFIER, @App6 UNIQUEIDENTIFIER;

    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateTag WHERE TenantId = @TenantId AND TagName = N'DEMO-CAN-005' AND IsDeleted = 0)
        INSERT INTO recruitment.CandidateTag (TenantId, TagName, CreatedAtUtc, CreatedByUserId) VALUES (@TenantId, N'DEMO-CAN-005', @ExecutionUtc, @RecruiterUserId);
    IF NOT EXISTS (SELECT 1 FROM recruitment.CandidateTag WHERE TenantId = @TenantId AND TagName = N'DEMO-CAN-006' AND IsDeleted = 0)
        INSERT INTO recruitment.CandidateTag (TenantId, TagName, CreatedAtUtc, CreatedByUserId) VALUES (@TenantId, N'DEMO-CAN-006', @ExecutionUtc, @RecruiterUserId);

    SELECT @Cand5 = c.CandidateId FROM recruitment.Candidate c JOIN recruitment.CandidateTagMapping m ON m.CandidateId=c.CandidateId JOIN recruitment.CandidateTag t ON t.CandidateTagId=m.CandidateTagId WHERE t.TenantId=@TenantId AND t.TagName=N'DEMO-CAN-005';
    IF @Cand5 IS NULL
    BEGIN
        EXEC recruitment.usp_CreateCandidate @TenantId = @TenantId, @FirstName = N'Morgan', @LastName = N'Reyes', @Email = N'morgan.reyes@example.test', @Phone = N'+1-555-0105', @CandidateSourceCode = N'CAREER_SITE', @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        SELECT TOP (1) @Cand5 = CandidateId FROM recruitment.Candidate WHERE TenantId = @TenantId AND FirstName = N'Morgan' AND LastName = N'Reyes' AND IsDeleted = 0 ORDER BY CreatedAtUtc DESC;
        INSERT INTO recruitment.CandidateTagMapping (TenantId, CandidateId, CandidateTagId, CreatedAtUtc, CreatedByUserId)
        SELECT @TenantId, @Cand5, CandidateTagId, @ExecutionUtc, @RecruiterUserId FROM recruitment.CandidateTag WHERE TenantId = @TenantId AND TagName = N'DEMO-CAN-005';
        EXEC recruitment.usp_CreateCandidateApplication @TenantId = @TenantId, @CandidateId = @Cand5, @JobRequisitionId = @JobRequisitionId, @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
    END
    SELECT @App5 = CandidateApplicationId FROM recruitment.CandidateApplication WHERE TenantId = @TenantId AND CandidateId = @Cand5 AND JobRequisitionId = @JobRequisitionId;

    SELECT @Cand6 = c.CandidateId FROM recruitment.Candidate c JOIN recruitment.CandidateTagMapping m ON m.CandidateId=c.CandidateId JOIN recruitment.CandidateTag t ON t.CandidateTagId=m.CandidateTagId WHERE t.TenantId=@TenantId AND t.TagName=N'DEMO-CAN-006';
    IF @Cand6 IS NULL
    BEGIN
        EXEC recruitment.usp_CreateCandidate @TenantId = @TenantId, @FirstName = N'Taylor', @LastName = N'Kim', @Email = N'taylor.kim@example.test', @Phone = N'+1-555-0106', @CandidateSourceCode = N'CAREER_SITE', @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        SELECT TOP (1) @Cand6 = CandidateId FROM recruitment.Candidate WHERE TenantId = @TenantId AND FirstName = N'Taylor' AND LastName = N'Kim' AND IsDeleted = 0 ORDER BY CreatedAtUtc DESC;
        INSERT INTO recruitment.CandidateTagMapping (TenantId, CandidateId, CandidateTagId, CreatedAtUtc, CreatedByUserId)
        SELECT @TenantId, @Cand6, CandidateTagId, @ExecutionUtc, @RecruiterUserId FROM recruitment.CandidateTag WHERE TenantId = @TenantId AND TagName = N'DEMO-CAN-006';
        EXEC recruitment.usp_CreateCandidateApplication @TenantId = @TenantId, @CandidateId = @Cand6, @JobRequisitionId = @JobRequisitionId, @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
    END
    SELECT @App6 = CandidateApplicationId FROM recruitment.CandidateApplication WHERE TenantId = @TenantId AND CandidateId = @Cand6 AND JobRequisitionId = @JobRequisitionId;

    -- --- H. Green Forms -------------------------------------------------------
    DECLARE @GreenFormVersionId UNIQUEIDENTIFIER = (
        SELECT gfv.GreenFormVersionId FROM onboarding.GreenFormVersion gfv
        JOIN onboarding.GreenForm gf ON gf.GreenFormId = gfv.GreenFormId
        WHERE gf.TenantId = @TenantId AND gf.Code = N'DEMO_STANDARD_GREEN_FORM' AND gfv.VersionNumber = 1
    );

    IF NOT EXISTS (SELECT 1 FROM onboarding.GreenFormSubmission WHERE CandidateApplicationId = @App5 AND IsDeleted = 0)
        INSERT INTO onboarding.GreenFormSubmission (TenantId, GreenFormVersionId, CandidateApplicationId, Status, SubmittedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @GreenFormVersionId, @App5, N'Submitted', @ExecutionUtc, @ExecutionUtc, @RecruiterUserId);

    IF NOT EXISTS (SELECT 1 FROM onboarding.GreenFormSubmission WHERE CandidateApplicationId = @App6 AND IsDeleted = 0)
        INSERT INTO onboarding.GreenFormSubmission (TenantId, GreenFormVersionId, CandidateApplicationId, Status, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @GreenFormVersionId, @App6, N'InProgress', @ExecutionUtc, @RecruiterUserId);

    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'DOCUMENT_VERIFICATION' WHERE CandidateApplicationId = @App5;
    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'GREEN_FORM_PENDING' WHERE CandidateApplicationId = @App6;

    -- --- I. Documents (metadata only — placeholder storage refs/hashes) ----
    DECLARE @ResumeTypeId UNIQUEIDENTIFIER = (SELECT DocumentTypeId FROM ref.DocumentType WHERE TenantId = @TenantId AND Code = N'RESUME');
    DECLARE @EduCertTypeId UNIQUEIDENTIFIER = (SELECT DocumentTypeId FROM ref.DocumentType WHERE TenantId = @TenantId AND Code = N'EDUCATION_CERTIFICATE');
    DECLARE @AddressProofTypeId UNIQUEIDENTIFIER = (SELECT DocumentTypeId FROM ref.DocumentType WHERE TenantId = @TenantId AND Code = N'ADDRESS_PROOF');
    DECLARE @VerifiedStatusId UNIQUEIDENTIFIER = (SELECT DocumentStatusId FROM ref.DocumentStatus WHERE TenantId = @TenantId AND Code = N'VERIFIED');
    DECLARE @UploadedStatusId UNIQUEIDENTIFIER = (SELECT DocumentStatusId FROM ref.DocumentStatus WHERE TenantId = @TenantId AND Code = N'UPLOADED');
    DECLARE @ReuploadStatusId UNIQUEIDENTIFIER = (SELECT DocumentStatusId FROM ref.DocumentStatus WHERE TenantId = @TenantId AND Code = N'REUPLOAD_REQUIRED');

    -- Document 1: verified resume
    DECLARE @Doc1Id UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM onboarding.CandidateDocument WHERE CandidateApplicationId = @App5 AND DocumentTypeId = @ResumeTypeId AND IsDeleted = 0)
    BEGIN
        SET @Doc1Id = NEWID();
        INSERT INTO onboarding.CandidateDocument (CandidateDocumentId, TenantId, CandidateApplicationId, DocumentTypeId, DocumentStatusId, CreatedAtUtc, CreatedByUserId)
        VALUES (@Doc1Id, @TenantId, @App5, @ResumeTypeId, @VerifiedStatusId, @ExecutionUtc, @RecruiterUserId);

        DECLARE @Doc1VersionId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO onboarding.CandidateDocumentVersion (CandidateDocumentVersionId, TenantId, CandidateDocumentId, VersionNumber, ObjectStorageUri, FileName, MimeType, FileSizeBytes, ContentHash, MalwareScanStatus, Classification, UploadedByUserId, CreatedAtUtc, CreatedByUserId)
        VALUES (@Doc1VersionId, @TenantId, @Doc1Id, 1, N'demo://placeholder/document/not-a-real-object/resume', N'demo-resume-DEMO-CAN-005.pdf', N'application/pdf', 0, HASHBYTES('SHA2_256', N'DEMO-PLACEHOLDER-RESUME-NOT-A-REAL-FILE'), N'Clean', N'Confidential', @Cand5, @ExecutionUtc, @RecruiterUserId);
        UPDATE onboarding.CandidateDocument SET CurrentVersionId = @Doc1VersionId WHERE CandidateDocumentId = @Doc1Id;

        INSERT INTO onboarding.DocumentValidationResult (TenantId, CandidateDocumentVersionId, ValidationType, IsValid, Details, ValidatedAtUtc)
        VALUES (@TenantId, @Doc1VersionId, N'MalwareScan', 1, N'Synthetic demo validation — clean.', @ExecutionUtc);
    END

    -- Document 2: pending education certificate upload (Uploaded, not yet verified)
    IF NOT EXISTS (SELECT 1 FROM onboarding.CandidateDocument WHERE CandidateApplicationId = @App5 AND DocumentTypeId = @EduCertTypeId AND IsDeleted = 0)
    BEGIN
        DECLARE @Doc2Id UNIQUEIDENTIFIER = NEWID();
        INSERT INTO onboarding.CandidateDocument (CandidateDocumentId, TenantId, CandidateApplicationId, DocumentTypeId, DocumentStatusId, CreatedAtUtc, CreatedByUserId)
        VALUES (@Doc2Id, @TenantId, @App5, @EduCertTypeId, @UploadedStatusId, @ExecutionUtc, @RecruiterUserId);

        DECLARE @Doc2VersionId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO onboarding.CandidateDocumentVersion (CandidateDocumentVersionId, TenantId, CandidateDocumentId, VersionNumber, ObjectStorageUri, FileName, MimeType, FileSizeBytes, ContentHash, MalwareScanStatus, Classification, UploadedByUserId, CreatedAtUtc, CreatedByUserId)
        VALUES (@Doc2VersionId, @TenantId, @Doc2Id, 1, N'demo://placeholder/document/not-a-real-object/education-certificate', N'demo-education-cert-DEMO-CAN-005.pdf', N'application/pdf', 0, HASHBYTES('SHA2_256', N'DEMO-PLACEHOLDER-EDU-CERT-NOT-A-REAL-FILE'), N'Pending', N'Confidential', @Cand5, @ExecutionUtc, @RecruiterUserId);
        UPDATE onboarding.CandidateDocument SET CurrentVersionId = @Doc2VersionId WHERE CandidateDocumentId = @Doc2Id;
    END

    -- Document 3: needs re-upload — simulated unreadability
    DECLARE @Doc3Id UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM onboarding.CandidateDocument WHERE CandidateApplicationId = @App5 AND DocumentTypeId = @AddressProofTypeId AND IsDeleted = 0)
    BEGIN
        SET @Doc3Id = NEWID();
        INSERT INTO onboarding.CandidateDocument (CandidateDocumentId, TenantId, CandidateApplicationId, DocumentTypeId, DocumentStatusId, CreatedAtUtc, CreatedByUserId)
        VALUES (@Doc3Id, @TenantId, @App5, @AddressProofTypeId, @ReuploadStatusId, @ExecutionUtc, @RecruiterUserId);

        DECLARE @Doc3VersionId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO onboarding.CandidateDocumentVersion (CandidateDocumentVersionId, TenantId, CandidateDocumentId, VersionNumber, ObjectStorageUri, FileName, MimeType, FileSizeBytes, ContentHash, MalwareScanStatus, Classification, UploadedByUserId, CreatedAtUtc, CreatedByUserId)
        VALUES (@Doc3VersionId, @TenantId, @Doc3Id, 1, N'demo://placeholder/document/not-a-real-object/address-proof', N'demo-address-proof-DEMO-CAN-005.pdf', N'application/pdf', 0, HASHBYTES('SHA2_256', N'DEMO-PLACEHOLDER-ADDRESS-PROOF-NOT-A-REAL-FILE'), N'Clean', N'Restricted', @Cand5, @ExecutionUtc, @RecruiterUserId);
        UPDATE onboarding.CandidateDocument SET CurrentVersionId = @Doc3VersionId WHERE CandidateDocumentId = @Doc3Id;

        INSERT INTO onboarding.DocumentValidationResult (TenantId, CandidateDocumentVersionId, ValidationType, IsValid, Details, ValidatedAtUtc)
        VALUES (@TenantId, @Doc3VersionId, N'Readability', 0, N'Synthetic demo validation — simulated unreadable scan.', @ExecutionUtc);
    END
    ELSE
        SELECT @Doc3Id = CandidateDocumentId FROM onboarding.CandidateDocument WHERE CandidateApplicationId = @App5 AND DocumentTypeId = @AddressProofTypeId AND IsDeleted = 0;

    -- Re-upload request task for the unreadable document
    IF NOT EXISTS (SELECT 1 FROM onboarding.DocumentUploadRequest WHERE CandidateApplicationId = @App5 AND DocumentTypeId = @AddressProofTypeId AND Status = N'Pending')
        INSERT INTO onboarding.DocumentUploadRequest (TenantId, CandidateApplicationId, DocumentTypeId, RequestedByUserId, RequestedAtUtc, Status)
        VALUES (@TenantId, @App5, @AddressProofTypeId, @DocVerifierUserId, @ExecutionUtc, N'Pending');

    -- --- Verification case/checks ---------------------------------------------
    DECLARE @VerificationCaseId UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM onboarding.VerificationCase WHERE CandidateApplicationId = @App5 AND IsDeleted = 0)
    BEGIN
        SET @VerificationCaseId = NEWID();
        INSERT INTO onboarding.VerificationCase (VerificationCaseId, TenantId, CandidateApplicationId, Status, OpenedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@VerificationCaseId, @TenantId, @App5, N'InProgress', @ExecutionUtc, @ExecutionUtc, @DocVerifierUserId);
    END
    ELSE
        SELECT @VerificationCaseId = VerificationCaseId FROM onboarding.VerificationCase WHERE CandidateApplicationId = @App5 AND IsDeleted = 0;

    DECLARE @AddressVerificationTypeId UNIQUEIDENTIFIER = (SELECT VerificationTypeId FROM ref.VerificationType WHERE TenantId = @TenantId AND Code = N'ADDRESS');
    DECLARE @InProgressVerifStatusId UNIQUEIDENTIFIER = (SELECT VerificationStatusId FROM ref.VerificationStatus WHERE TenantId = @TenantId AND Code = N'IN_PROGRESS');
    DECLARE @VerificationCheckId UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM onboarding.VerificationCheck WHERE VerificationCaseId = @VerificationCaseId AND VerificationTypeId = @AddressVerificationTypeId)
    BEGIN
        SET @VerificationCheckId = NEWID();
        INSERT INTO onboarding.VerificationCheck (VerificationCheckId, TenantId, VerificationCaseId, VerificationTypeId, VerificationStatusId, InitiatedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@VerificationCheckId, @TenantId, @VerificationCaseId, @AddressVerificationTypeId, @InProgressVerifStatusId, @ExecutionUtc, @ExecutionUtc, @DocVerifierUserId);
    END
    ELSE
        SELECT @VerificationCheckId = VerificationCheckId FROM onboarding.VerificationCheck WHERE VerificationCaseId = @VerificationCaseId AND VerificationTypeId = @AddressVerificationTypeId;

    -- --- J. Discrepancy (LOW/MEDIUM, unreadable document) ---------------------
    IF NOT EXISTS (SELECT 1 FROM onboarding.Discrepancy WHERE CandidateApplicationId = @App5 AND IsDeleted = 0)
        EXEC onboarding.usp_CreateDiscrepancy
            @TenantId = @TenantId, @CandidateApplicationId = @App5, @DiscrepancyTypeCode = N'UNREADABLE_DOCUMENT',
            @DiscrepancySeverityCode = N'MEDIUM',
            @Description = N'A replacement upload is required because the submitted sample document cannot be read.',
            @Source = N'Manual', @VerificationCheckId = @VerificationCheckId, @CreatedByUserId = @DocVerifierUserId, @CorrelationId = @CorrelationId;

    DECLARE @DiscrepancyId UNIQUEIDENTIFIER = (SELECT DiscrepancyId FROM onboarding.Discrepancy WHERE CandidateApplicationId = @App5 AND IsDeleted = 0);
    DECLARE @AwaitingResponseStatusId UNIQUEIDENTIFIER = (SELECT DiscrepancyStatusId FROM ref.DiscrepancyStatus WHERE TenantId = @TenantId AND Code = N'AWAITING_CANDIDATE_RESPONSE');
    IF EXISTS (SELECT 1 FROM onboarding.Discrepancy WHERE DiscrepancyId = @DiscrepancyId AND DiscrepancyStatusId <> @AwaitingResponseStatusId)
    BEGIN
        UPDATE onboarding.Discrepancy SET DiscrepancyStatusId = @AwaitingResponseStatusId, UpdatedAtUtc = @ExecutionUtc, UpdatedByUserId = @DocVerifierUserId WHERE DiscrepancyId = @DiscrepancyId;
        INSERT INTO onboarding.DiscrepancyStatusHistory (TenantId, DiscrepancyId, ToStatusId, ChangedByUserId, CorrelationId)
        VALUES (@TenantId, @DiscrepancyId, @AwaitingResponseStatusId, @DocVerifierUserId, @CorrelationId);
    END

    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'DISCREPANCY_PENDING' WHERE CandidateApplicationId = @App5;

    -- --- K. Employee conversion — pending, NOT approved, NO Employee row ------
    -- Requires an associated offer.Offer row (employee.EmployeeConversion.OfferId
    -- is NOT NULL) — a full, legitimately-approved offer chain is created via
    -- the real procedures so the FK is satisfiable without fabricating data
    -- outside the approval workflow.
    DECLARE @Offer5Id UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM offer.Offer WHERE TenantId = @TenantId AND CandidateApplicationId = @App5 AND IsDeleted = 0)
    BEGIN
        DECLARE @OfferTemplateId UNIQUEIDENTIFIER = (SELECT OfferTemplateId FROM ref.OfferTemplate WHERE TenantId = @TenantId AND Code = N'DEMO_STANDARD_OFFER');
        EXEC offer.usp_CreateOfferDraft @TenantId = @TenantId, @CandidateApplicationId = @App5, @OfferTemplateId = @OfferTemplateId, @CreatedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        SELECT TOP (1) @Offer5Id = OfferId FROM offer.Offer WHERE TenantId = @TenantId AND CandidateApplicationId = @App5 ORDER BY CreatedAtUtc DESC;

        EXEC offer.usp_SubmitOfferForApproval @TenantId = @TenantId, @OfferId = @Offer5Id, @ApprovalMatrixCode = N'OFFER_APPROVAL_STD', @RequestedByUserId = @RecruiterUserId, @CorrelationId = @CorrelationId;
        EXEC offer.usp_ApproveOffer @TenantId = @TenantId, @OfferId = @Offer5Id, @ApproverUserId = @OnboardingAdminUserId, @Comments = N'Synthetic demo approval.', @CorrelationId = @CorrelationId;
        EXEC offer.usp_ApproveOffer @TenantId = @TenantId, @OfferId = @Offer5Id, @ApproverUserId = @HrAdminUserId, @Comments = N'Synthetic demo approval.', @CorrelationId = @CorrelationId;
        EXEC offer.usp_MarkOfferSent @TenantId = @TenantId, @OfferId = @Offer5Id, @SentByUserId = @HrAdminUserId, @CorrelationId = @CorrelationId;

        -- No usp_RecordOfferAcceptance exists yet (see docs/stored-procedure-
        -- catalog.md backlog) — applied directly, matching this schema's
        -- established audit-trail pattern.
        INSERT INTO offer.OfferAcceptance (TenantId, OfferId, AcceptedAtUtc, RecordedByUserId)
        VALUES (@TenantId, @Offer5Id, @ExecutionUtc, @HrAdminUserId);
        DECLARE @AcceptedStatusId UNIQUEIDENTIFIER = (SELECT OfferStatusId FROM ref.OfferStatus WHERE TenantId = @TenantId AND Code = N'Accepted');
        UPDATE offer.Offer SET OfferStatusId = @AcceptedStatusId, UpdatedAtUtc = @ExecutionUtc, UpdatedByUserId = @HrAdminUserId WHERE OfferId = @Offer5Id;
    END
    ELSE
        SELECT @Offer5Id = OfferId FROM offer.Offer WHERE TenantId = @TenantId AND CandidateApplicationId = @App5 AND IsDeleted = 0;
    DECLARE @EmployeeConversionId UNIQUEIDENTIFIER;
    IF NOT EXISTS (SELECT 1 FROM employee.EmployeeConversion WHERE CandidateApplicationId = @App5 AND IsDeleted = 0)
    BEGIN
        SET @EmployeeConversionId = NEWID();
        INSERT INTO employee.EmployeeConversion (EmployeeConversionId, TenantId, CandidateApplicationId, OfferId, Status, RequestedAtUtc, CreatedAtUtc, CreatedByUserId)
        VALUES (@EmployeeConversionId, @TenantId, @App5, @Offer5Id, N'Pending', @ExecutionUtc, @ExecutionUtc, @OnboardingAdminUserId);
    END
    ELSE
        SELECT @EmployeeConversionId = EmployeeConversionId FROM employee.EmployeeConversion WHERE CandidateApplicationId = @App5 AND IsDeleted = 0;

    -- Checklist: OfferAccepted true, GreenFormCompleted false (Submitted, not
    -- Completed), VerificationCleared false (in progress), DiscrepanciesResolved
    -- false (open) — matches employee.usp_CheckEmployeeConversionEligibility's
    -- own logic, so the eligibility check will correctly report NOT eligible.
    DECLARE @ChecklistChecks TABLE (CheckName nvarchar(200), IsSatisfied bit);
    INSERT INTO @ChecklistChecks (CheckName, IsSatisfied) VALUES
    (N'OfferAccepted', 1), (N'GreenFormCompleted', 0), (N'VerificationCleared', 0), (N'DiscrepanciesResolved', 0);

    INSERT INTO employee.EmployeeConversionChecklist (TenantId, EmployeeConversionId, CheckName, IsSatisfied, CheckedAtUtc)
    SELECT @TenantId, @EmployeeConversionId, cc.CheckName, cc.IsSatisfied, CASE WHEN cc.IsSatisfied = 1 THEN @ExecutionUtc ELSE NULL END
    FROM @ChecklistChecks cc
    WHERE NOT EXISTS (SELECT 1 FROM employee.EmployeeConversionChecklist x WHERE x.EmployeeConversionId = @EmployeeConversionId AND x.CheckName = cc.CheckName);

    -- Pending conversion approval task (NOT decided — usp_ApproveEmployeeConversion
    -- is deliberately never called here, and it would refuse anyway since the
    -- eligibility checklist above is not fully satisfied).
    DECLARE @ConversionMatrixId UNIQUEIDENTIFIER = (SELECT ApprovalMatrixId FROM ref.ApprovalMatrix WHERE TenantId = @TenantId AND MatrixCode = N'EMPLOYEE_CONVERSION_STD');
    IF NOT EXISTS (SELECT 1 FROM employee.EmployeeConversionApproval WHERE EmployeeConversionId = @EmployeeConversionId)
    BEGIN
        DECLARE @ConversionApprovalRequestId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO workflow.ApprovalRequest (ApprovalRequestId, TenantId, ApprovalMatrixId, EntityType, EntityId, Status, RequestedByUserId, CorrelationId, CreatedAtUtc, CreatedByUserId)
        VALUES (@ConversionApprovalRequestId, @TenantId, @ConversionMatrixId, N'employee.EmployeeConversion', @EmployeeConversionId, N'Pending', @OnboardingAdminUserId, @CorrelationId, @ExecutionUtc, @OnboardingAdminUserId);

        INSERT INTO employee.EmployeeConversionApproval (TenantId, EmployeeConversionId, ApprovalRequestId, Status, RequestedAtUtc)
        VALUES (@TenantId, @EmployeeConversionId, @ConversionApprovalRequestId, N'Pending', @ExecutionUtc);

        INSERT INTO workflow.ApprovalStep (TenantId, ApprovalRequestId, ApprovalMatrixRuleId, StepOrder, AssignedApproverUserId, Status, CreatedAtUtc)
        SELECT @TenantId, @ConversionApprovalRequestId, amr.ApprovalMatrixRuleId, amr.StepOrder, @HrAdminUserId, N'Pending', @ExecutionUtc
        FROM ref.ApprovalMatrixRule amr WHERE amr.ApprovalMatrixId = @ConversionMatrixId AND amr.StepOrder = 1;
    END

    -- 'EMPLOYEE_CONVERSION_PENDING_APPROVAL' (the matching workflow StateCode,
    -- 36 chars) does not fit recruitment.CandidateApplication.
    -- ApplicationStatusCode, which is nvarchar(30) — see final report M18:
    -- this free-text column is narrower than 3 of the 32 seeded workflow
    -- state codes. A shortened code is used here instead.
    UPDATE recruitment.CandidateApplication SET ApplicationStatusCode = N'CONVERSION_PENDING_APPROVAL' WHERE CandidateApplicationId = @App5;

    -- Explicitly confirmed by design: no employee.Employee row is created —
    -- see the non-negotiable "Employee creation must be idempotent" /
    -- "never bypass approval gates" rules; eligibility is intentionally unmet.

    COMMIT TRAN;
    PRINT N'09-seed-synthetic-demo-transaction-data.sql PART 2 (Green Form/documents/verification/discrepancy/conversion) complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
