/* ============================================================================
   05-seed-workflow-approval-sla.sql
   Purpose : Seed the RECRUITMENT_ONBOARDING_V1 workflow definition (32
             states + transitions), default approval matrices, SLA policy,
             and notification templates.
   Depends on: 01, 02, 03, 04 (approver roles + notification channels).
   Idempotent: Yes.

   IMPORTANT LIMITATION (read before wiring UI/reporting to this data): none
   of the 33 stored procedures already deployed in
   Database/scripts/07-create-stored-procedures.sql create a
   workflow.WorkflowInstance row against this WorkflowDefinition — they drive
   status directly via each entity's own status column
   (JobRequisition.RequisitionStatusCode, CandidateApplication.
   ApplicationStatusCode, Offer.OfferStatusId, Discrepancy.DiscrepancyStatusId)
   plus workflow.ApprovalRequest/ApprovalStep for gating. This script's 32
   states/transitions are seeded as configuration for the intended future
   state machine and for UI/reporting reference; 09-seed-synthetic-demo-
   transaction-data.sql leaves WorkflowInstanceId NULL on demo rows,
   matching actual current procedure behavior. See the final report's
   mismatch list (M13) for the full explanation.

   ASSUMPTION (SLA): ref.SlaRule.DueWithinHours is a flat duration with no
   business-calendar awareness in this schema (no holiday/weekend skip
   column). "N business days" from the request is modeled as N * 24 calendar
   hours — a coarser approximation, documented here rather than invented as a
   new column.

   ASSUMPTION (approval matrix "OR" semantics): ref.ApprovalMatrixRule models
   an ordered, sequential (AND) list of steps via StepOrder — it has no way
   to express "Role A OR Role B" as a single step. Where the request
   describes an OR (e.g. shortlist approval by "Talent Acquisition Manager or
   Hiring Manager"), a single step is seeded for the primary approver role
   and the alternate is documented in ConditionExpression text only, not
   functionally enforced by this schema today.
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
    -- Workflow definition
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM ref.WorkflowDefinition WHERE TenantId = @TenantId AND WorkflowCode = N'RECRUITMENT_ONBOARDING_V1' AND IsDeleted = 0)
        INSERT INTO ref.WorkflowDefinition (TenantId, WorkflowCode, WorkflowName, Description, EntityType, IsActive, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'RECRUITMENT_ONBOARDING_V1', N'Recruitment & Onboarding (v1)',
                N'End-to-end recruitment-to-employee-conversion state machine, from CV Bank availability through Employee ID creation.',
                N'recruitment.CandidateApplication', 1, @ExecutionUtc, @ActorUserId);

    DECLARE @WorkflowDefinitionId UNIQUEIDENTIFIER = (SELECT WorkflowDefinitionId FROM ref.WorkflowDefinition WHERE TenantId = @TenantId AND WorkflowCode = N'RECRUITMENT_ONBOARDING_V1' AND IsDeleted = 0);

    -- ========================================================================
    -- States (32)
    -- ========================================================================
    DECLARE @States TABLE (StateCode nvarchar(200), StateName nvarchar(400), IsInitial bit, IsTerminal bit, RequiresApproval bit, SortOrder int);
    INSERT INTO @States (StateCode, StateName, IsInitial, IsTerminal, RequiresApproval, SortOrder) VALUES
    (N'CV_BANK_AVAILABLE', N'CV Bank Available', 1, 0, 0, 10),
    (N'TAN_DRAFT', N'TAN Draft', 0, 0, 0, 20),
    (N'TAN_PENDING_APPROVAL', N'TAN Pending Approval', 0, 0, 1, 30),
    (N'TAN_APPROVED', N'TAN Approved', 0, 0, 0, 40),
    (N'CANDIDATE_MATCHING', N'Candidate Matching', 0, 0, 0, 50),
    (N'SHORTLIST_PENDING_APPROVAL', N'Shortlist Pending Approval', 0, 0, 1, 60),
    (N'SHORTLISTED', N'Shortlisted', 0, 0, 0, 70),
    (N'L1_SCHEDULING', N'L1 Scheduling', 0, 0, 0, 80),
    (N'L1_FEEDBACK_PENDING', N'L1 Feedback Pending', 0, 0, 0, 90),
    (N'L1_OUTCOME_PENDING_APPROVAL', N'L1 Outcome Pending Approval', 0, 0, 1, 100),
    (N'L2_SCHEDULING', N'L2 Scheduling', 0, 0, 0, 110),
    (N'L2_FEEDBACK_PENDING', N'L2 Feedback Pending', 0, 0, 0, 120),
    (N'L2_OUTCOME_PENDING_APPROVAL', N'L2 Outcome Pending Approval', 0, 0, 1, 130),
    (N'CLIENT_INTERVIEW_SCHEDULING', N'Client Interview Scheduling', 0, 0, 0, 140),
    (N'CLIENT_FEEDBACK_PENDING', N'Client Feedback Pending', 0, 0, 0, 150),
    (N'FINAL_SELECTION_PENDING_APPROVAL', N'Final Selection Pending Approval', 0, 0, 1, 160),
    (N'OFFER_DRAFT', N'Offer Draft', 0, 0, 0, 170),
    (N'OFFER_PENDING_APPROVAL', N'Offer Pending Approval', 0, 0, 1, 180),
    (N'OFFER_SENT', N'Offer Sent', 0, 0, 0, 190),
    (N'OFFER_ACCEPTANCE_PENDING', N'Offer Acceptance Pending', 0, 0, 0, 200),
    (N'GREEN_FORM_PENDING', N'Green Form Pending', 0, 0, 0, 210),
    (N'GREEN_FORM_SUBMITTED', N'Green Form Submitted', 0, 0, 0, 220),
    (N'DOCUMENT_VERIFICATION', N'Document Verification', 0, 0, 0, 230),
    (N'DISCREPANCY_PENDING', N'Discrepancy Pending', 0, 0, 0, 240),
    (N'DISCREPANCY_RESOLUTION_PENDING_APPROVAL', N'Discrepancy Resolution Pending Approval', 0, 0, 1, 250),
    (N'EMPLOYEE_CONVERSION_PENDING_APPROVAL', N'Employee Conversion Pending Approval', 0, 0, 1, 260),
    (N'EMPLOYEE_CREATED', N'Employee Created', 0, 1, 0, 270),
    (N'REJECTED_FOR_TAN', N'Rejected for TAN', 0, 1, 0, 280),
    (N'OFFER_DECLINED', N'Offer Declined', 0, 1, 0, 290),
    (N'WITHDRAWN', N'Withdrawn', 0, 1, 0, 300),
    (N'ON_HOLD', N'On Hold', 0, 0, 0, 310),
    (N'CLOSED', N'Closed', 0, 1, 0, 320);

    INSERT INTO ref.WorkflowStateDefinition (WorkflowDefinitionId, StateCode, StateName, IsInitialState, IsTerminalState, RequiresApproval, SortOrder, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @WorkflowDefinitionId, s.StateCode, s.StateName, s.IsInitial, s.IsTerminal, s.RequiresApproval, s.SortOrder, 1, @ExecutionUtc, @ActorUserId
    FROM @States s
    WHERE NOT EXISTS (SELECT 1 FROM ref.WorkflowStateDefinition x WHERE x.WorkflowDefinitionId = @WorkflowDefinitionId AND x.StateCode = s.StateCode AND x.IsDeleted = 0);

    -- ========================================================================
    -- Transitions — the request's explicit examples, plus the minimal
    -- additional connecting transitions noted in the header (L2 mirrors L1,
    -- client-round connector, CV Bank -> TAN Draft entry point, and a small
    -- set of reject/hold/withdraw escape routes so the graph is navigable
    -- end-to-end for the demo screens in 09).
    -- ========================================================================
    DECLARE @Transitions TABLE (FromCode nvarchar(200), ToCode nvarchar(200), TransitionCode nvarchar(200), RequiresApproval bit);
    INSERT INTO @Transitions (FromCode, ToCode, TransitionCode, RequiresApproval) VALUES
    (N'CV_BANK_AVAILABLE', N'TAN_DRAFT', N'START_TAN', 0),
    (N'TAN_DRAFT', N'TAN_PENDING_APPROVAL', N'SUBMIT_TAN', 0),
    (N'TAN_PENDING_APPROVAL', N'TAN_APPROVED', N'APPROVE_TAN', 1),
    (N'TAN_APPROVED', N'CANDIDATE_MATCHING', N'START_MATCHING', 0),
    (N'CANDIDATE_MATCHING', N'SHORTLIST_PENDING_APPROVAL', N'SUBMIT_SHORTLIST', 0),
    (N'SHORTLIST_PENDING_APPROVAL', N'SHORTLISTED', N'APPROVE_SHORTLIST', 1),
    (N'SHORTLIST_PENDING_APPROVAL', N'REJECTED_FOR_TAN', N'REJECT_SHORTLIST', 1),
    (N'SHORTLISTED', N'L1_SCHEDULING', N'START_L1', 0),
    (N'L1_SCHEDULING', N'L1_FEEDBACK_PENDING', N'L1_SCHEDULED', 0),
    (N'L1_FEEDBACK_PENDING', N'L1_OUTCOME_PENDING_APPROVAL', N'L1_FEEDBACK_SUBMITTED', 0),
    (N'L1_OUTCOME_PENDING_APPROVAL', N'L2_SCHEDULING', N'L1_PASS', 1),
    (N'L1_OUTCOME_PENDING_APPROVAL', N'REJECTED_FOR_TAN', N'L1_REJECT', 1),
    (N'L2_SCHEDULING', N'L2_FEEDBACK_PENDING', N'L2_SCHEDULED', 0),
    (N'L2_FEEDBACK_PENDING', N'L2_OUTCOME_PENDING_APPROVAL', N'L2_FEEDBACK_SUBMITTED', 0),
    (N'L2_OUTCOME_PENDING_APPROVAL', N'CLIENT_INTERVIEW_SCHEDULING', N'L2_PASS_TO_CLIENT', 1),
    (N'L2_OUTCOME_PENDING_APPROVAL', N'OFFER_DRAFT', N'L2_PASS_TO_OFFER', 1),
    (N'L2_OUTCOME_PENDING_APPROVAL', N'REJECTED_FOR_TAN', N'L2_REJECT', 1),
    (N'CLIENT_INTERVIEW_SCHEDULING', N'CLIENT_FEEDBACK_PENDING', N'CLIENT_SCHEDULED', 0),
    (N'CLIENT_FEEDBACK_PENDING', N'FINAL_SELECTION_PENDING_APPROVAL', N'CLIENT_FEEDBACK_SUBMITTED', 0),
    (N'FINAL_SELECTION_PENDING_APPROVAL', N'OFFER_DRAFT', N'APPROVE_FINAL_SELECTION', 1),
    (N'FINAL_SELECTION_PENDING_APPROVAL', N'REJECTED_FOR_TAN', N'REJECT_FINAL_SELECTION', 1),
    (N'OFFER_DRAFT', N'OFFER_PENDING_APPROVAL', N'SUBMIT_OFFER', 0),
    (N'OFFER_PENDING_APPROVAL', N'OFFER_SENT', N'APPROVE_AND_SEND_OFFER', 1),
    (N'OFFER_SENT', N'OFFER_ACCEPTANCE_PENDING', N'OFFER_VIEWED', 0),
    (N'OFFER_ACCEPTANCE_PENDING', N'GREEN_FORM_PENDING', N'OFFER_ACCEPTED', 0),
    (N'OFFER_ACCEPTANCE_PENDING', N'OFFER_DECLINED', N'OFFER_DECLINED_BY_CANDIDATE', 0),
    (N'GREEN_FORM_PENDING', N'GREEN_FORM_SUBMITTED', N'GREEN_FORM_SUBMIT', 0),
    (N'GREEN_FORM_SUBMITTED', N'DOCUMENT_VERIFICATION', N'START_VERIFICATION', 0),
    (N'DOCUMENT_VERIFICATION', N'DISCREPANCY_PENDING', N'DISCREPANCY_RAISED', 0),
    (N'DOCUMENT_VERIFICATION', N'EMPLOYEE_CONVERSION_PENDING_APPROVAL', N'VERIFICATION_CLEAN', 0),
    (N'DISCREPANCY_PENDING', N'DISCREPANCY_RESOLUTION_PENDING_APPROVAL', N'SUBMIT_DISCREPANCY_RESOLUTION', 0),
    (N'DISCREPANCY_RESOLUTION_PENDING_APPROVAL', N'DOCUMENT_VERIFICATION', N'DISCREPANCY_RESOLVED_CONTINUE_VERIFICATION', 1),
    (N'DISCREPANCY_RESOLUTION_PENDING_APPROVAL', N'EMPLOYEE_CONVERSION_PENDING_APPROVAL', N'DISCREPANCY_RESOLVED_PROCEED', 1),
    (N'EMPLOYEE_CONVERSION_PENDING_APPROVAL', N'EMPLOYEE_CREATED', N'APPROVE_CONVERSION_AND_CREATE_EMPLOYEE', 1),
    -- Escape routes usable from most in-flight states (hold/withdraw/close).
    (N'SHORTLISTED', N'ON_HOLD', N'PLACE_ON_HOLD', 0),
    (N'ON_HOLD', N'L1_SCHEDULING', N'RESUME_FROM_HOLD', 0),
    (N'L1_FEEDBACK_PENDING', N'WITHDRAWN', N'CANDIDATE_WITHDRAWS', 0),
    (N'GREEN_FORM_PENDING', N'WITHDRAWN', N'CANDIDATE_WITHDRAWS_POST_OFFER', 0),
    (N'REJECTED_FOR_TAN', N'CLOSED', N'CLOSE_REJECTED', 0),
    (N'OFFER_DECLINED', N'CLOSED', N'CLOSE_DECLINED', 0),
    (N'WITHDRAWN', N'CLOSED', N'CLOSE_WITHDRAWN', 0),
    (N'EMPLOYEE_CREATED', N'CLOSED', N'CLOSE_CONVERTED', 0);

    INSERT INTO ref.WorkflowTransitionDefinition (WorkflowDefinitionId, FromStateId, ToStateId, TransitionCode, RequiresApproval, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @WorkflowDefinitionId, fs.WorkflowStateDefinitionId, ts.WorkflowStateDefinitionId, t.TransitionCode, t.RequiresApproval, 1, @ExecutionUtc, @ActorUserId
    FROM @Transitions t
    JOIN ref.WorkflowStateDefinition fs ON fs.WorkflowDefinitionId = @WorkflowDefinitionId AND fs.StateCode = t.FromCode AND fs.IsDeleted = 0
    JOIN ref.WorkflowStateDefinition ts ON ts.WorkflowDefinitionId = @WorkflowDefinitionId AND ts.StateCode = t.ToCode AND ts.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM ref.WorkflowTransitionDefinition x
        WHERE x.WorkflowDefinitionId = @WorkflowDefinitionId AND x.FromStateId = fs.WorkflowStateDefinitionId AND x.ToStateId = ts.WorkflowStateDefinitionId AND x.IsDeleted = 0
    );

    -- ========================================================================
    -- Approval matrices (see header ASSUMPTION on OR-semantics)
    -- ========================================================================
    DECLARE @Matrices TABLE (MatrixCode nvarchar(200), MatrixName nvarchar(400), EntityType nvarchar(200));
    INSERT INTO @Matrices (MatrixCode, MatrixName, EntityType) VALUES
    (N'TAN_APPROVAL_STD', N'TAN Approval (Standard)', N'recruitment.JobRequisition'),
    (N'SHORTLIST_APPROVAL_STD', N'Candidate Shortlist Approval (Standard)', N'recruitment.CandidateShortlist'),
    (N'INTERVIEW_L1_OUTCOME_STD', N'L1 Interview Outcome Approval (Standard)', N'recruitment.InterviewOutcome'),
    (N'INTERVIEW_L2_OUTCOME_STD', N'L2 Interview Outcome Approval (Standard)', N'recruitment.InterviewOutcome'),
    (N'CLIENT_INTERVIEW_OUTCOME_STD', N'Client Interview Outcome Approval (Standard)', N'recruitment.InterviewOutcome'),
    (N'FINAL_SELECTION_STD', N'Final Selection Approval (Standard)', N'recruitment.CandidateApplication'),
    (N'OFFER_APPROVAL_STD', N'Offer Approval (Standard)', N'offer.Offer'),
    (N'DISCREPANCY_EXCEPTION_STD', N'High/Critical Discrepancy Exception Approval (Standard)', N'onboarding.Discrepancy'),
    (N'EMPLOYEE_CONVERSION_STD', N'Employee Conversion Approval (Standard)', N'employee.EmployeeConversion');

    INSERT INTO ref.ApprovalMatrix (TenantId, MatrixCode, MatrixName, EntityType, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, m.MatrixCode, m.MatrixName, m.EntityType, 1, @ExecutionUtc, @ActorUserId
    FROM @Matrices m
    WHERE NOT EXISTS (SELECT 1 FROM ref.ApprovalMatrix x WHERE x.TenantId = @TenantId AND x.MatrixCode = m.MatrixCode AND x.IsDeleted = 0);

    DECLARE @MatrixSteps TABLE (MatrixCode nvarchar(200), StepOrder int, ApproverRoleName nvarchar(200), ConditionExpression nvarchar(1000));
    INSERT INTO @MatrixSteps (MatrixCode, StepOrder, ApproverRoleName, ConditionExpression) VALUES
    (N'TAN_APPROVAL_STD', 1, N'TALENT_ACQUISITION_MANAGER', NULL),
    (N'SHORTLIST_APPROVAL_STD', 1, N'TALENT_ACQUISITION_MANAGER', N'Alternate approver: HIRING_MANAGER (OR semantics not enforced by this schema — see script header).'),
    (N'INTERVIEW_L1_OUTCOME_STD', 1, N'HIRING_MANAGER', NULL),
    (N'INTERVIEW_L2_OUTCOME_STD', 1, N'HIRING_MANAGER', NULL),
    (N'INTERVIEW_L2_OUTCOME_STD', 2, N'TALENT_ACQUISITION_MANAGER', NULL),
    (N'CLIENT_INTERVIEW_OUTCOME_STD', 1, N'HIRING_MANAGER', NULL),
    (N'FINAL_SELECTION_STD', 1, N'HIRING_MANAGER', NULL),
    (N'FINAL_SELECTION_STD', 2, N'TALENT_ACQUISITION_MANAGER', NULL),
    (N'OFFER_APPROVAL_STD', 1, N'OFFER_APPROVER', NULL),
    (N'OFFER_APPROVAL_STD', 2, N'HR_ADMIN', NULL),
    (N'DISCREPANCY_EXCEPTION_STD', 1, N'DOCUMENT_VERIFIER', N'Document Verifier lead review, per request section 9.'),
    (N'DISCREPANCY_EXCEPTION_STD', 2, N'HR_ADMIN', NULL),
    (N'EMPLOYEE_CONVERSION_STD', 1, N'HR_ADMIN', NULL),
    (N'EMPLOYEE_CONVERSION_STD', 2, N'EMPLOYEE_ONBOARDING_ADMIN', NULL);

    INSERT INTO ref.ApprovalMatrixRule (ApprovalMatrixId, StepOrder, ApproverRoleId, ConditionExpression, IsMandatory, CreatedAtUtc, CreatedByUserId)
    SELECT am.ApprovalMatrixId, ms.StepOrder, r.RoleId, ms.ConditionExpression, 1, @ExecutionUtc, @ActorUserId
    FROM @MatrixSteps ms
    JOIN ref.ApprovalMatrix am ON am.TenantId = @TenantId AND am.MatrixCode = ms.MatrixCode AND am.IsDeleted = 0
    JOIN iam.Role r ON r.TenantId IS NULL AND r.RoleName = ms.ApproverRoleName AND r.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM ref.ApprovalMatrixRule x
        WHERE x.ApprovalMatrixId = am.ApprovalMatrixId AND x.StepOrder = ms.StepOrder AND x.IsDeleted = 0
    );

    -- ========================================================================
    -- SLA policy (see header ASSUMPTION: business days modeled as N*24h)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM ref.SlaPolicy WHERE TenantId = @TenantId AND Code = N'RECRUITMENT_ONBOARDING_SLA_STD' AND IsDeleted = 0)
        INSERT INTO ref.SlaPolicy (TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'RECRUITMENT_ONBOARDING_SLA_STD', N'Recruitment & Onboarding SLA (Standard)', 1, @ExecutionUtc, @ActorUserId);

    DECLARE @SlaPolicyId UNIQUEIDENTIFIER = (SELECT SlaPolicyId FROM ref.SlaPolicy WHERE TenantId = @TenantId AND Code = N'RECRUITMENT_ONBOARDING_SLA_STD' AND IsDeleted = 0);

    DECLARE @SlaRules TABLE (EntityType nvarchar(200), StageCode nvarchar(200), BusinessDays int, EscalationRoleName nvarchar(200));
    INSERT INTO @SlaRules (EntityType, StageCode, BusinessDays, EscalationRoleName) VALUES
    (N'recruitment.JobRequisition', N'TAN_APPROVAL', 2, N'HR_ADMIN'),
    (N'recruitment.CandidateShortlist', N'SHORTLIST_REVIEW', 2, N'HR_ADMIN'),
    (N'recruitment.Interview', N'INTERVIEW_SCHEDULING', 1, N'RECRUITER'),
    (N'recruitment.InterviewFeedback', N'FEEDBACK_SUBMISSION', 1, N'HR_ADMIN'),
    (N'offer.Offer', N'OFFER_APPROVAL', 2, N'HR_ADMIN'),
    (N'offer.Offer', N'CANDIDATE_ACCEPTANCE', 5, N'RECRUITER'),
    (N'onboarding.GreenFormSubmission', N'GREEN_FORM_COMPLETION', 5, N'HR_OPERATIONS'),
    (N'onboarding.VerificationCase', N'DOCUMENT_VERIFICATION', 5, N'DOCUMENT_VERIFIER'),
    (N'onboarding.Discrepancy', N'DISCREPANCY_RESPONSE', 3, N'HR_ADMIN'),
    (N'employee.EmployeeConversion', N'CONVERSION_APPROVAL', 2, N'HR_ADMIN');

    INSERT INTO ref.SlaRule (SlaPolicyId, EntityType, StageCode, DueWithinHours, EscalationRoleId, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @SlaPolicyId, s.EntityType, s.StageCode, s.BusinessDays * 24, r.RoleId, 1, @ExecutionUtc, @ActorUserId
    FROM @SlaRules s
    JOIN iam.Role r ON r.TenantId IS NULL AND r.RoleName = s.EscalationRoleName AND r.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM ref.SlaRule x
        WHERE x.SlaPolicyId = @SlaPolicyId AND x.EntityType = s.EntityType AND x.StageCode = s.StageCode AND x.IsDeleted = 0
    );

    -- ========================================================================
    -- Notification templates (placeholders only — no legal/offer-letter content)
    -- ========================================================================
    DECLARE @EmailChannelId UNIQUEIDENTIFIER = (SELECT NotificationChannelId FROM ref.NotificationChannel WHERE Code = N'EMAIL' AND IsDeleted = 0);

    DECLARE @Templates TABLE (Code nvarchar(200), Name nvarchar(400), Subject nvarchar(1000), Body nvarchar(max));
    INSERT INTO @Templates (Code, Name, Subject, Body) VALUES
    (N'TAN_SUBMITTED_FOR_APPROVAL', N'TAN Submitted for Approval', N'TAN {{TanNumber}} submitted for your approval', N'{{ApproverName}}, TAN {{TanNumber}} ({{JobTitle}}) has been submitted for your approval. Please review in the platform.'),
    (N'TAN_DECISION', N'TAN Approved / Rejected / Changes Requested', N'TAN {{TanNumber}} — {{DecisionOutcome}}', N'{{RequesterName}}, TAN {{TanNumber}} has been {{DecisionOutcome}}. {{DecisionComments}}'),
    (N'SHORTLIST_APPROVAL_REQUEST', N'Candidate Shortlist Requires Approval', N'Shortlist approval needed for {{TanNumber}}', N'{{ApproverName}}, a candidate shortlist for {{TanNumber}} is awaiting your approval.'),
    (N'INTERVIEW_INVITATION', N'Interview Invitation', N'Interview scheduled — {{RoundName}}', N'{{CandidateName}}, your {{RoundName}} interview is scheduled for {{ScheduledDateTime}} ({{TimeZone}}). Details: {{LocationOrLink}}.'),
    (N'INTERVIEW_REMINDER', N'Interview Reminder', N'Reminder: {{RoundName}} interview {{ScheduledDateTime}}', N'This is a reminder for your upcoming {{RoundName}} interview on {{ScheduledDateTime}}.'),
    (N'INTERVIEW_RESCHEDULE_CANCEL', N'Interview Reschedule / Cancellation', N'Your interview has been {{ChangeType}}', N'Your {{RoundName}} interview has been {{ChangeType}}. {{NewScheduleDetails}}'),
    (N'FEEDBACK_REMINDER', N'Interview Feedback Reminder', N'Feedback pending for {{CandidateName}}', N'{{InterviewerName}}, feedback for {{CandidateName}}''s {{RoundName}} interview is still pending.'),
    (N'CANDIDATE_REJECTION', N'Candidate Rejection Communication', N'Update on your application for {{JobTitle}}', N'{{CandidateName}}, thank you for your interest in {{JobTitle}}. We will not be proceeding with your application for this role at this time.'),
    (N'OFFER_APPROVAL_REQUEST', N'Offer Approval Request', N'Offer approval needed for {{CandidateName}}', N'{{ApproverName}}, an offer for {{CandidateName}} ({{JobTitle}}) is awaiting your approval.'),
    (N'OFFER_SENT', N'Offer Sent', N'Your offer from {{OrganizationName}}', N'{{CandidateName}}, your offer for {{JobTitle}} has been sent. Please review it in the candidate portal.'),
    (N'OFFER_ACCEPTANCE_REMINDER', N'Offer Acceptance Reminder', N'Reminder: your offer is awaiting a response', N'{{CandidateName}}, your offer for {{JobTitle}} is awaiting your response by {{OfferExpiryDate}}.'),
    (N'GREEN_FORM_INVITATION', N'Green Form Invitation', N'Please complete your onboarding form', N'{{CandidateName}}, please complete your Green Form using the secure link provided.'),
    (N'GREEN_FORM_REMINDER', N'Green Form Reminder', N'Reminder: onboarding form incomplete', N'{{CandidateName}}, your Green Form is still incomplete. Please finish it at your earliest convenience.'),
    (N'DOCUMENT_REUPLOAD_REQUEST', N'Missing / Re-upload Document Request', N'Document re-upload needed: {{DocumentTypeName}}', N'{{CandidateName}}, a replacement upload is required because the submitted {{DocumentTypeName}} could not be processed. Please re-upload a clear copy.'),
    (N'DISCREPANCY_CLARIFICATION_REQUEST', N'Discrepancy Clarification Request', N'We need more information about your submission', N'{{CandidateName}}, we need additional information regarding {{DiscrepancyTypeName}}. Please respond via the candidate portal.'),
    (N'CONVERSION_APPROVAL_REQUEST', N'Employee Conversion Approval Request', N'Conversion approval needed for {{CandidateName}}', N'{{ApproverName}}, {{CandidateName}}''s conversion to employee is awaiting your approval.'),
    (N'EMPLOYEE_ID_CREATED_CONFIRMATION', N'Employee ID Created', N'Welcome — your Employee ID is ready', N'{{EmployeeName}}, your Employee ID {{EmployeeCode}} has been created. Welcome to {{OrganizationName}}.');

    INSERT INTO ref.NotificationTemplate (TenantId, Code, Name, NotificationChannelId, Locale, SubjectTemplate, BodyTemplate, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, t.Code, t.Name, @EmailChannelId, N'en-US', t.Subject, t.Body, 1, @ExecutionUtc, @ActorUserId
    FROM @Templates t
    WHERE NOT EXISTS (
        SELECT 1 FROM ref.NotificationTemplate x
        WHERE x.TenantId = @TenantId AND x.Code = t.Code AND x.NotificationChannelId = @EmailChannelId AND x.Locale = N'en-US' AND x.IsDeleted = 0
    );

    COMMIT TRAN;
    PRINT N'05-seed-workflow-approval-sla.sql complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
