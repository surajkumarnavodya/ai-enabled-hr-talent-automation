/* ============================================================================
   04-create-keys-indexes-constraints.sql
   Purpose : Foreign keys that could not be declared in 03-create-tables.sql
             because the referenced table did not exist yet at that point in
             the script (true circular references, e.g. Parent.CurrentVersionId
             -> Child -> Parent), plus a handful of FKs deliberately deferred
             until a later-created table existed (e.g. *.WorkflowInstanceId ->
             workflow.WorkflowInstance, created in PART 7 of 03, after some
             earlier tables that carry that column).
   Idempotent: Yes — every ADD CONSTRAINT is guarded by an existence check.
   Depends on: 03-create-tables.sql (all parts).
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ----------------------------------------------------------------------------
   Circular "current version" pointers.
   ---------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_JobDescription_CurrentVersion')
    ALTER TABLE recruitment.JobDescription
        ADD CONSTRAINT FK_JobDescription_CurrentVersion FOREIGN KEY (CurrentVersionId)
        REFERENCES recruitment.JobDescriptionVersion(JobDescriptionVersionId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_GreenForm_CurrentVersion')
    ALTER TABLE onboarding.GreenForm
        ADD CONSTRAINT FK_GreenForm_CurrentVersion FOREIGN KEY (CurrentVersionId)
        REFERENCES onboarding.GreenFormVersion(GreenFormVersionId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CandidateDocument_CurrentVersion')
    ALTER TABLE onboarding.CandidateDocument
        ADD CONSTRAINT FK_CandidateDocument_CurrentVersion FOREIGN KEY (CurrentVersionId)
        REFERENCES onboarding.CandidateDocumentVersion(CandidateDocumentVersionId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RagSourceDocument_CurrentVersion')
    ALTER TABLE ai.RagSourceDocument
        ADD CONSTRAINT FK_RagSourceDocument_CurrentVersion FOREIGN KEY (CurrentVersionId)
        REFERENCES ai.RagSourceDocumentVersion(RagSourceDocumentVersionId);
GO

/* ----------------------------------------------------------------------------
   Deferred WorkflowInstanceId FKs — workflow.WorkflowInstance (03 PART 7)
   is created after recruitment.CandidateApplication (03 PART 6).
   ---------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CandidateApplication_WorkflowInstance')
    ALTER TABLE recruitment.CandidateApplication
        ADD CONSTRAINT FK_CandidateApplication_WorkflowInstance FOREIGN KEY (WorkflowInstanceId)
        REFERENCES workflow.WorkflowInstance(WorkflowInstanceId);
GO

/* ----------------------------------------------------------------------------
   Deferred approval/workflow FKs — workflow.ApprovalRequest (03 PART 7) is
   created after recruitment.* application/TAN tables (03 PARTs 5-6).
   ---------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_JobReqApprover_ApprovalRequest')
    ALTER TABLE recruitment.JobRequisitionApprover
        ADD CONSTRAINT FK_JobReqApprover_ApprovalRequest FOREIGN KEY (ApprovalRequestId)
        REFERENCES workflow.ApprovalRequest(ApprovalRequestId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CandShortlistApproval_ApprovalRequest')
    ALTER TABLE recruitment.CandidateShortlistApproval
        ADD CONSTRAINT FK_CandShortlistApproval_ApprovalRequest FOREIGN KEY (ApprovalRequestId)
        REFERENCES workflow.ApprovalRequest(ApprovalRequestId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CandidateRejection_ApprovalRequest')
    ALTER TABLE recruitment.CandidateRejection
        ADD CONSTRAINT FK_CandidateRejection_ApprovalRequest FOREIGN KEY (ApprovalRequestId)
        REFERENCES workflow.ApprovalRequest(ApprovalRequestId);
GO

/* ----------------------------------------------------------------------------
   Deferred CandidateMatchRun -> CandidateShortlist link and AiAgentRun link —
   recruitment.CandidateShortlist (03 PART 6) precedes recruitment.CandidateMatchRun
   in creation order relative to ai.AiAgentRun (03 PART 17, much later).
   ---------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CandidateShortlist_MatchRun')
    ALTER TABLE recruitment.CandidateShortlist
        ADD CONSTRAINT FK_CandidateShortlist_MatchRun FOREIGN KEY (CandidateMatchRunId)
        REFERENCES recruitment.CandidateMatchRun(CandidateMatchRunId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CandidateMatchRun_AiAgentRun')
    ALTER TABLE recruitment.CandidateMatchRun
        ADD CONSTRAINT FK_CandidateMatchRun_AiAgentRun FOREIGN KEY (AiAgentRunId)
        REFERENCES ai.AiAgentRun(AiAgentRunId);
GO

/* ----------------------------------------------------------------------------
   Deferred CvParsingResult -> ai.AiSkillVersion (03 PART 4 precedes 03 PART 17).
   ---------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CvParsingResult_AiSkillVersion')
    ALTER TABLE recruitment.CvParsingResult
        ADD CONSTRAINT FK_CvParsingResult_AiSkillVersion FOREIGN KEY (AiSkillVersionId)
        REFERENCES ai.AiSkillVersion(AiSkillVersionId);
GO

/* ----------------------------------------------------------------------------
   Schema-consistency patch: these *StatusHistory tables were originally
   created without CorrelationId, unlike every sibling *StatusHistory table
   (CandidateStatusHistory, JobRequisitionStatusHistory, OfferStatusHistory,
   etc.) — caught when 07-create-stored-procedures.sql failed to compile
   against the live database. Fixed at the source in 03-create-tables.sql for
   fresh deployments; patched here for a database that already ran the old
   version of that script.
   ---------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'recruitment.InterviewOutcomeHistory') AND name = 'CorrelationId')
    ALTER TABLE recruitment.InterviewOutcomeHistory ADD CorrelationId UNIQUEIDENTIFIER NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'onboarding.OnboardingTaskStatusHistory') AND name = 'CorrelationId')
    ALTER TABLE onboarding.OnboardingTaskStatusHistory ADD CorrelationId UNIQUEIDENTIFIER NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'onboarding.VerificationStatusHistory') AND name = 'CorrelationId')
    ALTER TABLE onboarding.VerificationStatusHistory ADD CorrelationId UNIQUEIDENTIFIER NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'onboarding.DiscrepancyStatusHistory') AND name = 'CorrelationId')
    ALTER TABLE onboarding.DiscrepancyStatusHistory ADD CorrelationId UNIQUEIDENTIFIER NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'employee.EmployeeStatusHistory') AND name = 'CorrelationId')
    ALTER TABLE employee.EmployeeStatusHistory ADD CorrelationId UNIQUEIDENTIFIER NULL;
GO

PRINT N'04-create-keys-indexes-constraints.sql complete - deferred/circular foreign keys added.';
GO
