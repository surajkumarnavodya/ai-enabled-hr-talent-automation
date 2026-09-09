/* ============================================================================
   06-seed-recruitment-configuration.sql
   Purpose : Seed interview round definitions/competencies, the default
             candidate-match scoring configuration, the TAN numbering rule,
             and the candidate tag vocabulary.
   Depends on: 01, 02, 03, 04.
   Idempotent: Yes.

   SCHEMA MISMATCH (M14 — see final report): the request's "interview
   feedback recommendation options" (SELECTED/REJECTED/ON_HOLD/
   NEED_ANOTHER_ROUND/PENDING) have no backing reference table.
   recruitment.InterviewFeedback.OverallRecommendation is instead governed by
   a hard CHECK constraint already on that table —
   CK_InterviewFeedback_Recommendation restricts it to exactly
   ('StrongYes','Yes','No','StrongNo'). This script does not attempt to seed
   the requested option set anywhere (there is no table to seed it into, and
   altering the CHECK constraint is out of scope per this package's
   constraints) — documented here and in the final report rather than
   silently skipped.

   SPLIT WITH 07/08 (avoids duplicate-config conflicts): this script owns the
   TAN numbering rule and the CANDIDATE_MATCHING_MODEL AI configuration
   (matching config is recruitment-specific); 07-seed-onboarding-offer-
   configuration.sql owns the remaining numbering rules (CandidateReference/
   Offer/EmployeeID/DiscrepancyReport), and 08-seed-ai-rag-integration-
   configuration.sql owns every other AI model configuration.
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
    -- A. Interview round definitions
    -- ========================================================================
    DECLARE @Rounds TABLE (Code nvarchar(100), Name nvarchar(400), SortOrder int);
    INSERT INTO @Rounds (Code, Name, SortOrder) VALUES
    (N'L1_TECHNICAL', N'L1 — Technical', 10), (N'L2_MANAGERIAL', N'L2 — Managerial', 20),
    (N'CLIENT_INTERVIEW', N'Client Interview', 30), (N'HR_DISCUSSION', N'HR Discussion', 40),
    (N'FINAL_DISCUSSION', N'Final Discussion', 50);

    INSERT INTO ref.InterviewRoundDefinition (TenantId, Code, Name, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, r.Code, r.Name, r.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @Rounds r
    WHERE NOT EXISTS (SELECT 1 FROM ref.InterviewRoundDefinition x WHERE x.TenantId = @TenantId AND x.Code = r.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- B. Interview competencies
    -- ========================================================================
    DECLARE @Competencies TABLE (Code nvarchar(100), Name nvarchar(400), SortOrder int);
    INSERT INTO @Competencies (Code, Name, SortOrder) VALUES
    (N'TECHNICAL_SKILLS', N'Technical Skills', 10), (N'PROBLEM_SOLVING', N'Problem Solving', 20),
    (N'COMMUNICATION', N'Communication', 30), (N'ROLE_FIT', N'Role Fit', 40),
    (N'DOMAIN_KNOWLEDGE', N'Domain Knowledge', 50), (N'CULTURE_CONTRIBUTION', N'Culture Contribution', 60),
    (N'LEADERSHIP', N'Leadership', 70), (N'STAKEHOLDER_MANAGEMENT', N'Stakeholder Management', 80);

    INSERT INTO ref.InterviewCompetency (TenantId, Code, Name, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, c.Code, c.Name, c.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @Competencies c
    WHERE NOT EXISTS (SELECT 1 FROM ref.InterviewCompetency x WHERE x.TenantId = @TenantId AND x.Code = c.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- D. Candidate match configuration (stored as an ai model configuration —
    -- see docs/ai-guardrails-policy.md-style note embedded in ParametersJson;
    -- AI matching is recommendation-only and requires human shortlist
    -- approval per recruitment.usp_ApproveCandidateShortlist).
    -- ========================================================================
    DECLARE @MatchParametersJson nvarchar(max) = N'{
  "note": "AI-assisted matching must use approved job-related factors only and requires human shortlist approval.",
  "scoringWeights": {
    "mandatorySkills": 35,
    "relevantExperience": 25,
    "roleTitleRelevance": 15,
    "preferredSkills": 10,
    "domainExperience": 5,
    "locationWorkMode": 5,
    "noticePeriodAvailability": 3,
    "compensationFit": 2
  },
  "scoringWeightTotal": 100,
  "confidenceThresholds": {
    "highRecommendation": 80,
    "mediumRecommendation": 60,
    "lowRecommendationBelow": 60
  },
  "thresholdsAreTenantConfigurable": true,
  "recommendationOnly": true
}';

    IF NOT EXISTS (SELECT 1 FROM ref.AiModelConfiguration WHERE TenantId = @TenantId AND Code = N'CANDIDATE_MATCHING_MODEL' AND IsDeleted = 0)
        INSERT INTO ref.AiModelConfiguration (TenantId, Code, Purpose, ProviderName, ModelIdentifier, ConfidenceThreshold, ParametersJson, IsActive, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'CANDIDATE_MATCHING_MODEL', N'Candidate-to-requisition matching and scoring', N'__set_per_env__', N'__set_per_env__', 0.6000, @MatchParametersJson, 1, N'Approved', @ExecutionUtc, @ActorUserId);
    -- ProviderName/ModelIdentifier are intentionally non-resolving placeholders
    -- — never a real provider endpoint/model id in seed data (see .env.example
    -- LLM_PROVIDER/LLM_MODEL_PRIMARY for where the real value is configured).

    -- ========================================================================
    -- E. TAN numbering rule (see script header: 07 owns the remaining ones)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM ref.NumberingRule WHERE TenantId = @TenantId AND EntityType = N'TAN' AND IsDeleted = 0)
        INSERT INTO ref.NumberingRule (TenantId, EntityType, Prefix, Suffix, NumberFormat, PaddingWidth, ResetPolicy, IsActive, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'TAN', N'TAN-', NULL, N'TAN-{YYYY}-{SEQ:5}', 5, N'Yearly', 1, @ExecutionUtc, @ActorUserId);
    -- NOTE (see final report M6): NumberFormat documents the intended
    -- TAN-{YYYY}-{SEQ:5} pattern, but recruitment.usp_CreateTalentAcquisitionNumber
    -- only concatenates Prefix + zero-padded CurrentSequence + Suffix today —
    -- it does not parse {YYYY}/{SEQ:n} tokens, so generated numbers look like
    -- "TAN-00001", not "TAN-2026-00001", until that procedure is extended.

    -- ========================================================================
    -- F. Candidate tags (reusable vocabulary; demo-candidate-specific
    -- reference tags such as DEMO-CAN-001 are seeded in 09, not here).
    -- ========================================================================
    DECLARE @Tags TABLE (TagName nvarchar(200));
    INSERT INTO @Tags (TagName) VALUES
    (N'HOTLIST'), (N'AVAILABLE'), (N'REFERRED'), (N'PRIOR_APPLICANT'),
    (N'SKILL_GAP'), (N'DOCUMENT_PENDING'), (N'HIGH_PRIORITY');

    INSERT INTO recruitment.CandidateTag (TenantId, TagName, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, t.TagName, @ExecutionUtc, @ActorUserId
    FROM @Tags t
    WHERE NOT EXISTS (SELECT 1 FROM recruitment.CandidateTag x WHERE x.TenantId = @TenantId AND x.TagName = t.TagName AND x.IsDeleted = 0);

    COMMIT TRAN;
    PRINT N'06-seed-recruitment-configuration.sql complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
