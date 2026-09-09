/* ============================================================================
   08-seed-ai-rag-integration-configuration.sql
   Purpose : Seed AI model configuration metadata (excluding
             CANDIDATE_MATCHING_MODEL, owned by 06), AI skills, RAG corpus
             metadata, and MCP/integration provider configuration metadata.
             Configuration only — no secrets, endpoints, vectors, or raw
             documents.
   Depends on: 01, 02, 03.
   Idempotent: Yes.

   SCHEMA NOTE (M9/M10 — see final report): ai.AiSkill has no dedicated
   "requires human approval" column; it is encoded as a key inside the
   existing ToolAllowlistJson column. ref.RagConfiguration has no dedicated
   columns for chunking strategy / retrieval method / reranking / citation-
   required / raw-content-indexing flags; all are encoded in the existing
   ParametersJson column, which is exactly what that column exists for.

   SCHEMA NOTE: ref.IntegrationConfiguration.SecretVaultKeyRef has a CHECK
   constraint requiring it to be NULL or start with 'kv://' — every value
   below is a non-resolving placeholder reference, never a literal secret.
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
    -- A. AI model configurations (CANDIDATE_MATCHING_MODEL owned by 06)
    -- ========================================================================
    DECLARE @Models TABLE (Code nvarchar(200), Purpose nvarchar(200), ConfidenceThreshold decimal(5,4), HumanReview bit, PiiRedaction bit);
    INSERT INTO @Models (Code, Purpose, ConfidenceThreshold, HumanReview, PiiRedaction) VALUES
    (N'CV_PARSING_MODEL', N'CV/resume field extraction', 0.7000, 1, 1),
    (N'DOCUMENT_CLASSIFICATION_MODEL', N'Uploaded document type/quality classification', 0.7000, 1, 1),
    (N'DISCREPANCY_SUGGESTION_MODEL', N'Draft discrepancy suggestions from verification signals', 0.6500, 1, 1),
    (N'POLICY_RAG_MODEL', N'HR policy question answering via RAG', 0.7000, 0, 1),
    (N'SUMMARIZATION_MODEL', N'Candidate/case summarization for reviewer screens', 0.6000, 1, 1);

    INSERT INTO ref.AiModelConfiguration (TenantId, Code, Purpose, ProviderName, ModelIdentifier, ConfidenceThreshold, ParametersJson, IsActive, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, m.Code, m.Purpose, N'__set_per_env__', N'__set_per_env__', m.ConfidenceThreshold,
        N'{"temperature":0.2,"maxTokens":4096,"timeoutSeconds":30,"retryCount":2,"humanReviewRequired":' + CASE WHEN m.HumanReview = 1 THEN N'true' ELSE N'false' END +
        N',"piiRedactionRequired":' + CASE WHEN m.PiiRedaction = 1 THEN N'true' ELSE N'false' END +
        N',"promptVersionRef":"__set_per_env__"}',
        1, N'Approved', @ExecutionUtc, @ActorUserId
    FROM @Models m
    WHERE NOT EXISTS (SELECT 1 FROM ref.AiModelConfiguration x WHERE x.TenantId = @TenantId AND x.Code = m.Code AND x.IsDeleted = 0);

    -- ========================================================================
    -- B. AI skills
    -- ========================================================================
    DECLARE @Skills TABLE (SkillCode nvarchar(300), Purpose nvarchar(400), RequiresHumanApproval bit);
    INSERT INTO @Skills (SkillCode, Purpose, RequiresHumanApproval) VALUES
    (N'PARSE_CV', N'Extract structured fields from an uploaded CV', 1),
    (N'NORMALIZE_CANDIDATE', N'Normalize candidate contact/profile fields for de-duplication', 0),
    (N'MATCH_CANDIDATES', N'Score candidates against a job requisition', 1),
    (N'EXPLAIN_MATCH', N'Produce job-related evidence explaining a match score', 0),
    (N'SCHEDULE_INTERVIEW', N'Propose interview time slots via calendar integration', 1),
    (N'VALIDATE_FEEDBACK', N'Check interview feedback completeness before submission', 0),
    (N'DRAFT_OFFER', N'Draft an offer from an approved template and approved inputs', 1),
    (N'VALIDATE_OFFER_POLICY', N'Check a draft offer against configured policy rules', 1),
    (N'ISSUE_GREEN_FORM', N'Issue a Green Form submission link to a candidate', 0),
    (N'CHECK_DOCUMENT_COMPLETENESS', N'Check uploaded documents against the configured checklist', 0),
    (N'SUGGEST_DISCREPANCY', N'Suggest a discrepancy from verification signals — never closes one', 1),
    (N'GENERATE_DISCREPANCY_REPORT', N'Generate a discrepancy summary report for HR review', 1),
    (N'CHECK_EMPLOYEE_CONVERSION_ELIGIBILITY', N'Evaluate the employee-conversion checklist — never approves conversion', 1),
    (N'POLICY_RAG_RETRIEVAL', N'Retrieve HR policy passages with citations for an assistant answer', 0);

    INSERT INTO ai.AiSkill (TenantId, SkillCode, Purpose, ToolAllowlistJson, IsActive, CreatedAtUtc)
    SELECT @TenantId, s.SkillCode, s.Purpose,
        N'{"requiresHumanApproval":' + CASE WHEN s.RequiresHumanApproval = 1 THEN N'true' ELSE N'false' END + N',"allowedTools":[]}',
        1, @ExecutionUtc
    FROM @Skills s
    WHERE NOT EXISTS (SELECT 1 FROM ai.AiSkill x WHERE x.TenantId = @TenantId AND x.SkillCode = s.SkillCode);

    INSERT INTO ai.AiSkillVersion (AiSkillId, VersionNumber, ApprovalStatus, CreatedAtUtc)
    SELECT sk.AiSkillId, 1, N'Approved', @ExecutionUtc
    FROM ai.AiSkill sk
    WHERE sk.TenantId = @TenantId AND sk.SkillCode IN (SELECT SkillCode FROM @Skills)
      AND NOT EXISTS (SELECT 1 FROM ai.AiSkillVersion x WHERE x.AiSkillId = sk.AiSkillId AND x.VersionNumber = 1);

    -- ========================================================================
    -- C. RAG corpus metadata
    -- ========================================================================
    DECLARE @RagParametersJson nvarchar(max) = N'{
  "chunkingStrategy": "SEMANTIC_HIERARCHICAL",
  "targetChunkTokenRange": [400, 800],
  "overlapPercentageRange": [10, 15],
  "retrievalMethod": "HYBRID",
  "rerankingEnabled": true,
  "metadataAclFilterRequired": true,
  "citationRequired": true,
  "rawCandidateDocumentIndexingDisabled": true,
  "confidentialInterviewFeedbackIndexingDisabled": true,
  "tenantFilteringRequired": true,
  "policyVersionEffectiveDateFilteringRequired": true
}';

    IF NOT EXISTS (SELECT 1 FROM ref.RagConfiguration WHERE TenantId = @TenantId AND Code = N'HR_POLICY_RAG_STD' AND IsDeleted = 0)
        INSERT INTO ref.RagConfiguration (TenantId, Code, EmbeddingModelIdentifier, VectorStoreProvider, ChunkSizeTokens, ChunkOverlapTokens, TopK, MinRelevanceScore, ParametersJson, IsActive, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'HR_POLICY_RAG_STD', N'__set_per_env__', N'__set_per_env__', 600, 75, 5, 0.5000, @RagParametersJson, 1, N'Approved', @ExecutionUtc, @ActorUserId);

    DECLARE @RagConfigurationId UNIQUEIDENTIFIER = (SELECT RagConfigurationId FROM ref.RagConfiguration WHERE TenantId = @TenantId AND Code = N'HR_POLICY_RAG_STD' AND IsDeleted = 0);

    DECLARE @Corpora TABLE (CorpusCode nvarchar(100), Name nvarchar(400));
    INSERT INTO @Corpora (CorpusCode, Name) VALUES
    (N'HR_POLICIES', N'HR Policies'), (N'RECRUITMENT_SOPS', N'Recruitment SOPs'),
    (N'INTERVIEW_GUIDELINES', N'Interview Guidelines'), (N'OFFER_TEMPLATE_GUIDANCE', N'Offer Template Guidance'),
    (N'ONBOARDING_CHECKLISTS', N'Onboarding Checklists'), (N'DOCUMENT_VERIFICATION_RULES', N'Document Verification Rules');

    INSERT INTO ai.RagCorpus (TenantId, CorpusCode, Name, RagConfigurationId, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, c.CorpusCode, c.Name, @RagConfigurationId, 1, @ExecutionUtc, @ActorUserId
    FROM @Corpora c
    WHERE NOT EXISTS (SELECT 1 FROM ai.RagCorpus x WHERE x.TenantId = @TenantId AND x.CorpusCode = c.CorpusCode);

    INSERT INTO ai.RagAccessPolicy (TenantId, RagCorpusId, Classification, AllowedRoleIdsJson, CreatedAtUtc)
    SELECT @TenantId, rc.RagCorpusId, N'Internal', N'[]', @ExecutionUtc
    FROM ai.RagCorpus rc
    WHERE rc.TenantId = @TenantId AND rc.CorpusCode IN (SELECT CorpusCode FROM @Corpora)
      AND NOT EXISTS (SELECT 1 FROM ai.RagAccessPolicy x WHERE x.RagCorpusId = rc.RagCorpusId);

    -- ========================================================================
    -- D. MCP/integration provider configuration metadata
    -- ========================================================================
    DECLARE @Providers TABLE (Code nvarchar(200), ProviderName nvarchar(200), IntegrationType nvarchar(100), Sensitivity nvarchar(50));
    INSERT INTO @Providers (Code, ProviderName, IntegrationType, Sensitivity) VALUES
    (N'CALENDAR_PROVIDER', N'__set_per_env__', N'MCP', N'Propose'),
    (N'EMAIL_PROVIDER', N'__set_per_env__', N'MCP', N'Propose'),
    (N'HRMS_PROVIDER', N'__set_per_env__', N'MCP', N'SensitiveWrite'),
    (N'ESIGN_PROVIDER', N'__set_per_env__', N'MCP', N'SensitiveWrite'),
    (N'OBJECT_STORAGE_PROVIDER', N'__set_per_env__', N'Direct', N'ReadOnly'),
    (N'BACKGROUND_VERIFICATION_PROVIDER', N'__set_per_env__', N'MCP', N'Propose'),
    (N'PAYROLL_PROVIDER', N'__set_per_env__', N'MCP', N'SensitiveWrite'),
    (N'IT_PROVISIONING_PROVIDER', N'__set_per_env__', N'MCP', N'SensitiveWrite');

    INSERT INTO ref.IntegrationConfiguration (TenantId, Code, ProviderName, EndpointUrl, SecretVaultKeyRef, IsActive, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, p.Code, p.ProviderName, N'https://__set_per_env__.invalid', N'kv://demo-hr/integration/' + LOWER(p.Code), 0, N'Approved', @ExecutionUtc, @ActorUserId
    FROM @Providers p
    WHERE NOT EXISTS (SELECT 1 FROM ref.IntegrationConfiguration x WHERE x.TenantId = @TenantId AND x.Code = p.Code AND x.IsDeleted = 0);
    -- IsActive = 0: these are configuration placeholders for a demo tenant —
    -- no real endpoint/credential exists to connect to, so the config is
    -- seeded present-but-disabled rather than falsely marked active.

    INSERT INTO integration.ExternalSystem (TenantId, SystemCode, SystemName, IntegrationConfigurationId, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, p.Code, p.Code + N' (Demo Placeholder)', ic.IntegrationConfigurationId, 0, @ExecutionUtc, @ActorUserId
    FROM @Providers p
    JOIN ref.IntegrationConfiguration ic ON ic.TenantId = @TenantId AND ic.Code = p.Code AND ic.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM integration.ExternalSystem x WHERE x.TenantId = @TenantId AND x.SystemCode = p.Code);

    COMMIT TRAN;
    PRINT N'08-seed-ai-rag-integration-configuration.sql complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
