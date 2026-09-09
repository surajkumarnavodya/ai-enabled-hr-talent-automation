/* ============================================================================
   02-seed-iam-roles-permissions.sql
   Purpose : Seed the 20 platform/tenant roles, the full permission catalog,
             the least-privilege role-to-permission matrix, and the
             authorization policy placeholders referenced by section 6.
   Depends on: 01-seed-tenant-organization.sql.
   Idempotent: Yes.

   SCHEMA NOTE: iam.Role.TenantId is NULLable (NULL = system-wide baseline,
   reusable across tenants — see the unique index UQ_iam_Role_Global vs.
   UQ_iam_Role_Tenant in Database/scripts/03-create-tables.sql). iam.Permission
   has no TenantId column at all — permissions are always global. These 20
   roles are seeded as global, reusable system roles (TenantId = NULL,
   IsSystemRole = 1) rather than duplicated per tenant, matching the schema's
   own design for a shared role catalog; DEMO-HR's users are attached to them
   via iam.UserRole (tenant-scoped) in 03-seed-iam-users-access.sql. Because
   these are not tenant-scoped rows, they are NOT deleted by
   11-seed-cleanup-demo-data.sql (see that script's header).
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

SELECT @TenantId = TenantId FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0;
IF @TenantId IS NULL
    THROW 50001, 'Seed execution failed: tenant was not found. Run 01-seed-tenant-organization.sql first.', 1;

-- Plain (non-read-only) context — see 01-seed-tenant-organization.sql header
-- note on why iam.usp_SetSessionSecurityContext (read-only) is not used here.
EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

BEGIN TRY
    BEGIN TRAN;

    -- ========================================================================
    -- Permission catalog (global — domain.resource.action)
    -- ========================================================================
    DECLARE @Permissions TABLE (PermissionKey nvarchar(300), ResourceCategory nvarchar(200), Description nvarchar(1000));
    INSERT INTO @Permissions (PermissionKey, ResourceCategory, Description) VALUES
    (N'tenant.read', N'tenant', N'View tenant configuration'),
    (N'tenant.manage', N'tenant', N'Manage tenant configuration'),
    (N'organization.read', N'organization', N'View organization/department/location master data'),
    (N'organization.manage', N'organization', N'Manage organization/department/location master data'),
    (N'user.read', N'iam', N'View users'),
    (N'user.create', N'iam', N'Create users'),
    (N'user.update', N'iam', N'Update users'),
    (N'user.deactivate', N'iam', N'Deactivate users'),
    (N'role.read', N'iam', N'View roles'),
    (N'role.manage', N'iam', N'Manage roles'),
    (N'permission.read', N'iam', N'View permissions'),
    (N'permission.manage', N'iam', N'Manage permissions'),
    (N'candidate.read', N'recruitment', N'View candidate profiles'),
    (N'candidate.create', N'recruitment', N'Create candidate profiles'),
    (N'candidate.update', N'recruitment', N'Update candidate profiles'),
    (N'candidate.upload_cv', N'recruitment', N'Upload a candidate CV'),
    (N'candidate.merge', N'recruitment', N'Merge duplicate candidate records'),
    (N'candidate.view_sensitive', N'recruitment', N'View sensitive candidate fields'),
    (N'candidate.export', N'recruitment', N'Export candidate data'),
    (N'cv_bank.read', N'recruitment', N'Search/browse the CV Bank'),
    (N'cv_bank.manage', N'recruitment', N'Manage CV Bank configuration'),
    (N'tan.read', N'recruitment', N'View TAN/job requisitions'),
    (N'tan.create', N'recruitment', N'Create TAN/job requisitions'),
    (N'tan.update', N'recruitment', N'Update TAN/job requisitions'),
    (N'tan.submit', N'recruitment', N'Submit a TAN for approval'),
    (N'tan.approve', N'recruitment', N'Approve a TAN'),
    (N'tan.close', N'recruitment', N'Close a TAN/job requisition'),
    (N'job_description.read', N'recruitment', N'View job descriptions'),
    (N'job_description.create', N'recruitment', N'Create job description versions'),
    (N'job_description.update', N'recruitment', N'Update job description versions'),
    (N'job_description.approve', N'recruitment', N'Approve a job description version'),
    (N'candidate_match.run', N'recruitment', N'Run AI candidate matching'),
    (N'candidate_match.read', N'recruitment', N'View AI candidate match results'),
    (N'candidate_match.approve_shortlist', N'recruitment', N'Approve a candidate shortlist'),
    (N'interview.read', N'recruitment', N'View interviews'),
    (N'interview.schedule', N'recruitment', N'Schedule interviews'),
    (N'interview.reschedule', N'recruitment', N'Reschedule interviews'),
    (N'interview.cancel', N'recruitment', N'Cancel interviews'),
    (N'interview.submit_feedback', N'recruitment', N'Submit interview feedback'),
    (N'interview.approve_outcome', N'recruitment', N'Approve an interview outcome'),
    (N'offer.read', N'offer', N'View offers'),
    (N'offer.create', N'offer', N'Create offer drafts'),
    (N'offer.update', N'offer', N'Update offer drafts'),
    (N'offer.view_compensation', N'offer', N'View offer compensation detail'),
    (N'offer.approve', N'offer', N'Approve an offer'),
    (N'offer.send', N'offer', N'Send an approved offer'),
    (N'offer.withdraw', N'offer', N'Withdraw an offer'),
    (N'offer.record_acceptance', N'offer', N'Record an offer acceptance/decline'),
    (N'green_form.read', N'onboarding', N'View Green Form submissions'),
    (N'green_form.issue_link', N'onboarding', N'Issue a Green Form upload/submission link'),
    (N'green_form.submit', N'onboarding', N'Submit a Green Form (candidate action)'),
    (N'green_form.review', N'onboarding', N'Review a submitted Green Form'),
    (N'document.read', N'onboarding', N'View document metadata'),
    (N'document.upload', N'onboarding', N'Upload a document'),
    (N'document.verify', N'onboarding', N'Verify a document'),
    (N'document.request_reupload', N'onboarding', N'Request a document re-upload'),
    (N'document.view_sensitive', N'onboarding', N'View restricted/sensitive document classes'),
    (N'verification.read', N'onboarding', N'View verification cases/checks'),
    (N'verification.create', N'onboarding', N'Create a verification case/check'),
    (N'verification.update', N'onboarding', N'Update a verification case/check'),
    (N'verification.approve', N'onboarding', N'Approve a verification result'),
    (N'discrepancy.read', N'onboarding', N'View discrepancies'),
    (N'discrepancy.create', N'onboarding', N'Create a discrepancy'),
    (N'discrepancy.resolve', N'onboarding', N'Resolve a discrepancy'),
    (N'discrepancy.approve_exception', N'onboarding', N'Approve a discrepancy exception'),
    (N'employee.read', N'employee', N'View employee records'),
    (N'employee.convert', N'employee', N'Convert a candidate to employee'),
    (N'employee.create_id', N'employee', N'Create an Employee ID (system-service only)'),
    (N'employee.provision', N'employee', N'Coordinate employee IT/payroll provisioning'),
    (N'workflow.read', N'workflow', N'View workflow instances/state'),
    (N'workflow.manage', N'workflow', N'Manage workflow definitions'),
    (N'approval.read', N'workflow', N'View approval requests'),
    (N'approval.request', N'workflow', N'Request an approval'),
    (N'approval.decide', N'workflow', N'Decide (approve/reject) an approval step'),
    (N'audit.read', N'audit', N'View audit events'),
    (N'audit.export', N'audit', N'Export audit events'),
    (N'reporting.read', N'reporting', N'View reporting views'),
    (N'reporting.export', N'reporting', N'Export reporting data'),
    (N'configuration.read', N'ref', N'View configuration/reference data'),
    (N'configuration.manage', N'ref', N'Manage configuration/reference data'),
    (N'feature_flag.read', N'ref', N'View feature flags'),
    (N'feature_flag.manage', N'ref', N'Manage feature flags'),
    (N'integration.read', N'integration', N'View integration configuration/status'),
    (N'integration.manage', N'integration', N'Manage integration configuration'),
    (N'integration.execute', N'integration', N'Execute integration operations (service-only)'),
    (N'ai.run', N'ai', N'Trigger an AI skill run'),
    (N'ai.review', N'ai', N'Review/override an AI recommendation'),
    (N'ai.view_evaluation', N'ai', N'View AI evaluation results'),
    (N'rag.read', N'ai', N'Query the RAG policy assistant'),
    (N'rag.manage', N'ai', N'Manage RAG corpus configuration'),
    (N'mcp.execute_read', N'mcp', N'Execute a read-tier MCP tool call'),
    (N'mcp.execute_propose', N'mcp', N'Execute a propose-tier MCP tool call'),
    (N'mcp.execute_sensitive_write', N'mcp', N'Execute an approval-required sensitive-write MCP tool call');

    INSERT INTO iam.Permission (PermissionKey, ResourceCategory, Description, IsActive, CreatedAtUtc)
    SELECT p.PermissionKey, p.ResourceCategory, p.Description, 1, @ExecutionUtc
    FROM @Permissions p
    WHERE NOT EXISTS (SELECT 1 FROM iam.Permission x WHERE x.PermissionKey = p.PermissionKey AND x.IsDeleted = 0);

    -- ========================================================================
    -- Roles (global system roles)
    -- ========================================================================
    DECLARE @Roles TABLE (RoleName nvarchar(200), Description nvarchar(1000));
    INSERT INTO @Roles (RoleName, Description) VALUES
    (N'PLATFORM_ADMIN', N'Platform-level configuration administrator. Does not automatically receive tenant HR operational access.'),
    (N'TENANT_ADMIN', N'Tenant configuration, users, roles, workflow configuration, reporting, integration monitoring. Cannot bypass HR approval workflow.'),
    (N'HR_ADMIN', N'Full tenant HR workflow visibility and authorized HR approvals, excluding platform administration.'),
    (N'RECRUITER', N'Candidate/CV Bank/TAN read-create-update, matching, interview coordination. Cannot approve offers, close high-severity discrepancies, or create Employee IDs.'),
    (N'TALENT_ACQUISITION_MANAGER', N'Approves TANs, shortlist decisions, and candidate progression as configured.'),
    (N'HIRING_MANAGER', N'Views assigned TANs, reviews candidate recommendations, submits/approves interview outcomes for assigned requisitions.'),
    (N'INTERVIEWER', N'Views assigned candidate interview details and submits assigned feedback only.'),
    (N'CLIENT_INTERVIEWER', N'Client-limited interviewer scope. No CV Bank search, compensation, offer, or internal audit access.'),
    (N'OFFER_APPROVER', N'Reviews approved candidate information required for offer review, views compensation, approves/declines offers.'),
    (N'HR_OPERATIONS', N'Green Form review, document collection, onboarding coordination. No unrestricted compensation access.'),
    (N'DOCUMENT_VERIFIER', N'Document verification and discrepancy work only.'),
    (N'EMPLOYEE_ONBOARDING_ADMIN', N'Employee conversion/provisioning coordination after all workflow gates are approved.'),
    (N'PAYROLL_INTEGRATION_USER', N'Narrow integration permissions only. No interactive UI access.'),
    (N'IT_PROVISIONING_USER', N'Narrow provisioning request/status permissions only. No HR/candidate browsing.'),
    (N'AUDITOR', N'Read audit/reporting views only, with sensitive-data restrictions.'),
    (N'REPORTING_USER', N'Read approved reporting views only. No direct base-table access.'),
    (N'SUPPORT_READONLY', N'Restricted, masked, read-only support scope.'),
    (N'CANDIDATE_PORTAL_USER', N'Own Green Form, own documents, own offer acceptance actions, approved candidate-facing communication only.'),
    (N'AI_REVIEWER', N'Views AI runs, recommendations, evaluation results; approves/overrides AI recommendation workflows where policy allows. No autonomous employment decisions.'),
    (N'INTEGRATION_SERVICE', N'Non-human service permissions only, limited to required API/MCP/integration actions.');

    INSERT INTO iam.Role (TenantId, RoleName, Description, IsSystemRole, IsActive, CreatedAtUtc)
    SELECT NULL, r.RoleName, r.Description, 1, 1, @ExecutionUtc
    FROM @Roles r
    WHERE NOT EXISTS (SELECT 1 FROM iam.Role x WHERE x.TenantId IS NULL AND x.RoleName = r.RoleName AND x.IsDeleted = 0);

    -- ========================================================================
    -- Role -> permission matrix (least privilege — see role descriptions
    -- above and section 6 of the request for the rationale behind each row).
    -- ========================================================================
    DECLARE @RolePermissions TABLE (RoleName nvarchar(200), PermissionKey nvarchar(300));
    INSERT INTO @RolePermissions (RoleName, PermissionKey) VALUES
    -- PLATFORM_ADMIN: platform-level only — tenant/config/role/permission/feature-flag/integration/audit, no candidate/HR data.
    (N'PLATFORM_ADMIN', N'tenant.read'), (N'PLATFORM_ADMIN', N'tenant.manage'),
    (N'PLATFORM_ADMIN', N'organization.read'), (N'PLATFORM_ADMIN', N'organization.manage'),
    (N'PLATFORM_ADMIN', N'user.read'), (N'PLATFORM_ADMIN', N'user.create'), (N'PLATFORM_ADMIN', N'user.update'), (N'PLATFORM_ADMIN', N'user.deactivate'),
    (N'PLATFORM_ADMIN', N'role.read'), (N'PLATFORM_ADMIN', N'role.manage'),
    (N'PLATFORM_ADMIN', N'permission.read'), (N'PLATFORM_ADMIN', N'permission.manage'),
    (N'PLATFORM_ADMIN', N'configuration.read'), (N'PLATFORM_ADMIN', N'configuration.manage'),
    (N'PLATFORM_ADMIN', N'feature_flag.read'), (N'PLATFORM_ADMIN', N'feature_flag.manage'),
    (N'PLATFORM_ADMIN', N'integration.read'), (N'PLATFORM_ADMIN', N'integration.manage'),
    (N'PLATFORM_ADMIN', N'audit.read'), (N'PLATFORM_ADMIN', N'audit.export'),
    (N'PLATFORM_ADMIN', N'reporting.read'),
    -- TENANT_ADMIN
    (N'TENANT_ADMIN', N'tenant.read'), (N'TENANT_ADMIN', N'organization.read'), (N'TENANT_ADMIN', N'organization.manage'),
    (N'TENANT_ADMIN', N'user.read'), (N'TENANT_ADMIN', N'user.create'), (N'TENANT_ADMIN', N'user.update'), (N'TENANT_ADMIN', N'user.deactivate'),
    (N'TENANT_ADMIN', N'role.read'), (N'TENANT_ADMIN', N'role.manage'), (N'TENANT_ADMIN', N'permission.read'),
    (N'TENANT_ADMIN', N'workflow.read'), (N'TENANT_ADMIN', N'workflow.manage'),
    (N'TENANT_ADMIN', N'configuration.read'), (N'TENANT_ADMIN', N'configuration.manage'),
    (N'TENANT_ADMIN', N'feature_flag.read'), (N'TENANT_ADMIN', N'feature_flag.manage'),
    (N'TENANT_ADMIN', N'integration.read'), (N'TENANT_ADMIN', N'reporting.read'), (N'TENANT_ADMIN', N'reporting.export'),
    (N'TENANT_ADMIN', N'audit.read'), (N'TENANT_ADMIN', N'tan.read'), (N'TENANT_ADMIN', N'candidate.read'),
    -- HR_ADMIN: full HR workflow authority
    (N'HR_ADMIN', N'organization.read'), (N'HR_ADMIN', N'user.read'),
    (N'HR_ADMIN', N'candidate.read'), (N'HR_ADMIN', N'candidate.create'), (N'HR_ADMIN', N'candidate.update'), (N'HR_ADMIN', N'candidate.view_sensitive'), (N'HR_ADMIN', N'candidate.merge'), (N'HR_ADMIN', N'candidate.export'),
    (N'HR_ADMIN', N'cv_bank.read'), (N'HR_ADMIN', N'cv_bank.manage'),
    (N'HR_ADMIN', N'tan.read'), (N'HR_ADMIN', N'tan.create'), (N'HR_ADMIN', N'tan.update'), (N'HR_ADMIN', N'tan.submit'), (N'HR_ADMIN', N'tan.approve'), (N'HR_ADMIN', N'tan.close'),
    (N'HR_ADMIN', N'job_description.read'), (N'HR_ADMIN', N'job_description.create'), (N'HR_ADMIN', N'job_description.update'), (N'HR_ADMIN', N'job_description.approve'),
    (N'HR_ADMIN', N'candidate_match.read'), (N'HR_ADMIN', N'candidate_match.approve_shortlist'),
    (N'HR_ADMIN', N'interview.read'), (N'HR_ADMIN', N'interview.approve_outcome'),
    (N'HR_ADMIN', N'offer.read'), (N'HR_ADMIN', N'offer.view_compensation'), (N'HR_ADMIN', N'offer.approve'),
    (N'HR_ADMIN', N'green_form.read'), (N'HR_ADMIN', N'green_form.review'),
    (N'HR_ADMIN', N'document.read'), (N'HR_ADMIN', N'document.view_sensitive'),
    (N'HR_ADMIN', N'verification.read'), (N'HR_ADMIN', N'verification.approve'),
    (N'HR_ADMIN', N'discrepancy.read'), (N'HR_ADMIN', N'discrepancy.resolve'), (N'HR_ADMIN', N'discrepancy.approve_exception'),
    (N'HR_ADMIN', N'employee.read'), (N'HR_ADMIN', N'employee.convert'),
    (N'HR_ADMIN', N'workflow.read'), (N'HR_ADMIN', N'approval.read'), (N'HR_ADMIN', N'approval.request'), (N'HR_ADMIN', N'approval.decide'),
    (N'HR_ADMIN', N'reporting.read'), (N'HR_ADMIN', N'reporting.export'), (N'HR_ADMIN', N'configuration.read'),
    (N'HR_ADMIN', N'ai.review'), (N'HR_ADMIN', N'ai.view_evaluation'), (N'HR_ADMIN', N'rag.read'),
    -- RECRUITER: no offer approval, no high-severity discrepancy closure, no employee ID creation
    (N'RECRUITER', N'candidate.read'), (N'RECRUITER', N'candidate.create'), (N'RECRUITER', N'candidate.update'), (N'RECRUITER', N'candidate.upload_cv'),
    (N'RECRUITER', N'cv_bank.read'), (N'RECRUITER', N'tan.read'), (N'RECRUITER', N'tan.create'), (N'RECRUITER', N'tan.update'), (N'RECRUITER', N'tan.submit'),
    (N'RECRUITER', N'job_description.read'), (N'RECRUITER', N'job_description.create'), (N'RECRUITER', N'job_description.update'),
    (N'RECRUITER', N'candidate_match.run'), (N'RECRUITER', N'candidate_match.read'),
    (N'RECRUITER', N'interview.read'), (N'RECRUITER', N'interview.schedule'), (N'RECRUITER', N'interview.reschedule'), (N'RECRUITER', N'interview.cancel'),
    (N'RECRUITER', N'offer.read'), (N'RECRUITER', N'green_form.read'), (N'RECRUITER', N'document.read'),
    (N'RECRUITER', N'workflow.read'), (N'RECRUITER', N'approval.read'), (N'RECRUITER', N'approval.request'),
    (N'RECRUITER', N'ai.run'), (N'RECRUITER', N'ai.view_evaluation'),
    -- TALENT_ACQUISITION_MANAGER
    (N'TALENT_ACQUISITION_MANAGER', N'candidate.read'), (N'TALENT_ACQUISITION_MANAGER', N'cv_bank.read'),
    (N'TALENT_ACQUISITION_MANAGER', N'tan.read'), (N'TALENT_ACQUISITION_MANAGER', N'tan.approve'), (N'TALENT_ACQUISITION_MANAGER', N'tan.close'),
    (N'TALENT_ACQUISITION_MANAGER', N'job_description.read'), (N'TALENT_ACQUISITION_MANAGER', N'job_description.approve'),
    (N'TALENT_ACQUISITION_MANAGER', N'candidate_match.read'), (N'TALENT_ACQUISITION_MANAGER', N'candidate_match.approve_shortlist'),
    (N'TALENT_ACQUISITION_MANAGER', N'interview.read'), (N'TALENT_ACQUISITION_MANAGER', N'interview.approve_outcome'),
    (N'TALENT_ACQUISITION_MANAGER', N'offer.read'), (N'TALENT_ACQUISITION_MANAGER', N'workflow.read'),
    (N'TALENT_ACQUISITION_MANAGER', N'approval.read'), (N'TALENT_ACQUISITION_MANAGER', N'approval.decide'),
    (N'TALENT_ACQUISITION_MANAGER', N'reporting.read'), (N'TALENT_ACQUISITION_MANAGER', N'ai.review'),
    -- HIRING_MANAGER: assigned-scope only (enforced by iam.AuthorizationPolicy below, not the permission grant alone)
    (N'HIRING_MANAGER', N'tan.read'), (N'HIRING_MANAGER', N'candidate.read'), (N'HIRING_MANAGER', N'candidate_match.read'),
    (N'HIRING_MANAGER', N'interview.read'), (N'HIRING_MANAGER', N'interview.submit_feedback'), (N'HIRING_MANAGER', N'interview.approve_outcome'),
    (N'HIRING_MANAGER', N'candidate_match.approve_shortlist'),
    (N'HIRING_MANAGER', N'workflow.read'), (N'HIRING_MANAGER', N'approval.read'), (N'HIRING_MANAGER', N'approval.decide'),
    -- INTERVIEWER: assigned interview only
    (N'INTERVIEWER', N'interview.read'), (N'INTERVIEWER', N'interview.submit_feedback'),
    -- CLIENT_INTERVIEWER: same as interviewer, no CV Bank/compensation/offer/audit
    (N'CLIENT_INTERVIEWER', N'interview.read'), (N'CLIENT_INTERVIEWER', N'interview.submit_feedback'),
    -- OFFER_APPROVER
    (N'OFFER_APPROVER', N'candidate.read'), (N'OFFER_APPROVER', N'offer.read'), (N'OFFER_APPROVER', N'offer.view_compensation'),
    (N'OFFER_APPROVER', N'offer.approve'), (N'OFFER_APPROVER', N'workflow.read'), (N'OFFER_APPROVER', N'approval.read'), (N'OFFER_APPROVER', N'approval.decide'),
    -- HR_OPERATIONS: no unrestricted compensation
    (N'HR_OPERATIONS', N'candidate.read'), (N'HR_OPERATIONS', N'green_form.read'), (N'HR_OPERATIONS', N'green_form.issue_link'), (N'HR_OPERATIONS', N'green_form.review'),
    (N'HR_OPERATIONS', N'document.read'), (N'HR_OPERATIONS', N'document.upload'), (N'HR_OPERATIONS', N'document.request_reupload'),
    (N'HR_OPERATIONS', N'verification.read'), (N'HR_OPERATIONS', N'discrepancy.read'), (N'HR_OPERATIONS', N'discrepancy.create'),
    (N'HR_OPERATIONS', N'offer.read'), (N'HR_OPERATIONS', N'workflow.read'), (N'HR_OPERATIONS', N'approval.read'),
    -- DOCUMENT_VERIFIER: verification/discrepancy only, restricted offer/interview
    (N'DOCUMENT_VERIFIER', N'document.read'), (N'DOCUMENT_VERIFIER', N'document.verify'), (N'DOCUMENT_VERIFIER', N'document.request_reupload'), (N'DOCUMENT_VERIFIER', N'document.view_sensitive'),
    (N'DOCUMENT_VERIFIER', N'verification.read'), (N'DOCUMENT_VERIFIER', N'verification.create'), (N'DOCUMENT_VERIFIER', N'verification.update'), (N'DOCUMENT_VERIFIER', N'verification.approve'),
    (N'DOCUMENT_VERIFIER', N'discrepancy.read'), (N'DOCUMENT_VERIFIER', N'discrepancy.create'), (N'DOCUMENT_VERIFIER', N'discrepancy.resolve'),
    -- EMPLOYEE_ONBOARDING_ADMIN
    (N'EMPLOYEE_ONBOARDING_ADMIN', N'candidate.read'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'green_form.read'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'document.read'),
    (N'EMPLOYEE_ONBOARDING_ADMIN', N'verification.read'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'discrepancy.read'),
    (N'EMPLOYEE_ONBOARDING_ADMIN', N'employee.read'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'employee.convert'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'employee.provision'),
    (N'EMPLOYEE_ONBOARDING_ADMIN', N'workflow.read'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'approval.read'), (N'EMPLOYEE_ONBOARDING_ADMIN', N'approval.request'),
    -- PAYROLL_INTEGRATION_USER: narrow, non-interactive
    (N'PAYROLL_INTEGRATION_USER', N'integration.read'), (N'PAYROLL_INTEGRATION_USER', N'integration.execute'), (N'PAYROLL_INTEGRATION_USER', N'employee.read'),
    -- IT_PROVISIONING_USER: narrow, no HR/candidate browsing
    (N'IT_PROVISIONING_USER', N'integration.read'), (N'IT_PROVISIONING_USER', N'integration.execute'), (N'IT_PROVISIONING_USER', N'employee.provision'),
    -- AUDITOR: audit/reporting read only
    (N'AUDITOR', N'audit.read'), (N'AUDITOR', N'audit.export'), (N'AUDITOR', N'reporting.read'),
    -- REPORTING_USER: reporting only
    (N'REPORTING_USER', N'reporting.read'), (N'REPORTING_USER', N'reporting.export'),
    -- SUPPORT_READONLY: masked, restricted
    (N'SUPPORT_READONLY', N'candidate.read'), (N'SUPPORT_READONLY', N'tan.read'), (N'SUPPORT_READONLY', N'offer.read'), (N'SUPPORT_READONLY', N'reporting.read'),
    -- CANDIDATE_PORTAL_USER: own-record only (enforced by iam.AuthorizationPolicy below)
    (N'CANDIDATE_PORTAL_USER', N'green_form.submit'), (N'CANDIDATE_PORTAL_USER', N'document.upload'), (N'CANDIDATE_PORTAL_USER', N'offer.record_acceptance'),
    -- AI_REVIEWER: view + override, never autonomous decision permissions
    (N'AI_REVIEWER', N'ai.run'), (N'AI_REVIEWER', N'ai.review'), (N'AI_REVIEWER', N'ai.view_evaluation'),
    (N'AI_REVIEWER', N'candidate_match.read'), (N'AI_REVIEWER', N'discrepancy.read'), (N'AI_REVIEWER', N'rag.read'),
    -- INTEGRATION_SERVICE: service-scope only
    (N'INTEGRATION_SERVICE', N'integration.execute'), (N'INTEGRATION_SERVICE', N'mcp.execute_read'), (N'INTEGRATION_SERVICE', N'mcp.execute_propose');

    INSERT INTO iam.RolePermission (RoleId, PermissionId, GrantedAtUtc, CreatedAtUtc)
    SELECT r.RoleId, p.PermissionId, @ExecutionUtc, @ExecutionUtc
    FROM @RolePermissions rp
    JOIN iam.Role r ON r.TenantId IS NULL AND r.RoleName = rp.RoleName AND r.IsDeleted = 0
    JOIN iam.Permission p ON p.PermissionKey = rp.PermissionKey AND p.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM iam.RolePermission x
        WHERE x.RoleId = r.RoleId AND x.PermissionId = p.PermissionId AND x.IsDeleted = 0
    );

    -- ========================================================================
    -- Authorization policies (documented ABAC expressions evaluated by the
    -- Application layer — see iam.AuthorizationPolicyRule's own design note
    -- in Database/scripts/03-create-tables.sql: these are configuration
    -- metadata, not an active SQL-Server-enforced control).
    -- ========================================================================
    DECLARE @Policies TABLE (PolicyName nvarchar(300), Description nvarchar(1000), RuleExpression nvarchar(2000));
    INSERT INTO @Policies (PolicyName, Description, RuleExpression) VALUES
    (N'CandidatePortal.OwnRecordOnly', N'A CANDIDATE_PORTAL_USER may only access Green Form, documents, and offer-acceptance actions tied to their own CandidateApplicationId.', N'resource.CandidateApplicationId == actor.CandidateApplicationId'),
    (N'Interviewer.AssignedInterviewOnly', N'An INTERVIEWER/CLIENT_INTERVIEWER may only read/submit feedback for InterviewRound rows where they are a recruitment.InterviewPanelMember.', N'EXISTS(recruitment.InterviewPanelMember WHERE InterviewRoundId == resource.InterviewRoundId AND UserId == actor.UserId)'),
    (N'HiringManager.AssignedTanOnly', N'A HIRING_MANAGER may only read/act on JobRequisition rows where they appear in recruitment.JobRequisitionHiringManager.', N'EXISTS(recruitment.JobRequisitionHiringManager WHERE JobRequisitionId == resource.JobRequisitionId AND UserId == actor.UserId)'),
    (N'DocumentVerifier.AssignedCaseOnly', N'A DOCUMENT_VERIFIER may act on onboarding.VerificationCheck rows within their assigned VerificationCase queue only, per configured queue assignment.', N'resource.VerificationCaseId IN actor.AssignedVerificationCaseIds'),
    (N'OfferApprover.PendingOfferOnly', N'An OFFER_APPROVER may decide only offer.OfferApproval rows currently Status = Pending and addressed to their ApprovalStep.', N'resource.Status == "Pending" AND resource.AssignedApproverUserId == actor.UserId'),
    (N'Auditor.ReadOnlyNoMutation', N'An AUDITOR has no INSERT/UPDATE/DELETE permission on any business table — audit.read/audit.export/reporting.read only.', N'action IN ("read","export")'),
    (N'IntegrationService.RestrictedScope', N'An INTEGRATION_SERVICE principal may call only the specific MCP tools declared in its ai.AiSkill.ToolAllowlistJson for the given integration; no interactive-UI-only permission is ever granted to this role.', N'actor.IsSystemServiceAccount == true AND tool.Name IN actor.AllowedToolNames');

    INSERT INTO iam.AuthorizationPolicy (TenantId, PolicyName, Description, IsActive, CreatedAtUtc)
    SELECT NULL, p.PolicyName, p.Description, 1, @ExecutionUtc
    FROM @Policies p
    WHERE NOT EXISTS (SELECT 1 FROM iam.AuthorizationPolicy x WHERE x.TenantId IS NULL AND x.PolicyName = p.PolicyName AND x.IsDeleted = 0);

    INSERT INTO iam.AuthorizationPolicyRule (AuthorizationPolicyId, RuleExpression, Effect, SortOrder, CreatedAtUtc)
    SELECT ap.AuthorizationPolicyId, p.RuleExpression, N'Allow', 1, @ExecutionUtc
    FROM @Policies p
    JOIN iam.AuthorizationPolicy ap ON ap.TenantId IS NULL AND ap.PolicyName = p.PolicyName AND ap.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM iam.AuthorizationPolicyRule x
        WHERE x.AuthorizationPolicyId = ap.AuthorizationPolicyId AND x.RuleExpression = p.RuleExpression AND x.IsDeleted = 0
    );

    COMMIT TRAN;
    PRINT N'02-seed-iam-roles-permissions.sql complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
