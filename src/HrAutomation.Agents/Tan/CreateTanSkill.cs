using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;

namespace HrAutomation.Agents.Tan;

/// <summary>
/// Bootstraps a new TAN number, its JobRequisition, and its first JD version, then immediately
/// submits the requisition for approval - HrAutomationDb splits what the old app called a single
/// "TAN" into recruitment.TalentAcquisitionNumber (the reserved number) and
/// recruitment.JobRequisition (the approvable draft that actually carries status/version); this
/// skill treats JobRequisitionId as the "tanId" the rest of the API surfaces, since that's the
/// entity with an approval-gated lifecycle. Invoked directly by the controller (not through
/// IWorkflowOrchestrator) because there is no pre-existing approval request to gate against yet.
/// </summary>
public sealed class CreateTanSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "create_tan_skill";
    public string SkillVersion => "0.1.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["RECRUITER", "HR_ADMIN", "HIRING_MANAGER"];

    private const string ApprovalMatrixCode = "TAN_APPROVAL_STD";

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as CreateTanRequest
            ?? throw new InvalidOperationException("CreateTanSkill requires CreateTanRequest.");

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var tanResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_CreateTalentAcquisitionNumber",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@RequestedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!tanResult.Success || tanResult.EntityId is not { } talentAcquisitionNumberId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = $"TAN number reservation failed: {tanResult.Message}",
                RisksOrExceptions = [tanResult.ErrorCode ?? "TAN_CREATE_FAILED"]
            };
        }
        var tanNumber = tanResult.Message!;

        var requisitionResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_CreateJobRequisition",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@TalentAcquisitionNumberId", talentAcquisitionNumberId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@Title", input.Title, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@HeadcountRequested", 1, SqlDbType.Int),
                StoredProcedureExecutor.Param("@CreatedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!requisitionResult.Success || requisitionResult.EntityId is not { } jobRequisitionId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                TanId = talentAcquisitionNumberId.ToString(),
                Summary = $"Job requisition creation failed: {requisitionResult.Message}",
                RisksOrExceptions = [requisitionResult.ErrorCode ?? "REQUISITION_CREATE_FAILED"]
            };
        }

        // JD/criteria authoring is plain CRUD per Persistence/README.md - no dedicated procedure.
        // NOTE (documented gap): CreateTanRequest.Location/Grade/BudgetMin/BudgetMax/
        // InterviewStagesCount/ClientInterviewRequired/MandatoryCriteriaJson/PreferredCriteriaJson
        // have no corresponding columns on recruitment.JobRequisition/JobDescriptionVersion in
        // HrAutomationDb (Location/Grade there are FK lookups into org.Location/org.JobGrade, not
        // free text) - not persisted pending a schema/contract decision. Only Title/RawDescription
        // carry through today.
        var jobDescriptionId = Guid.NewGuid();
        db.JobDescriptions.Add(new RecruitmentJobDescription
        {
            JobDescriptionId = jobDescriptionId,
            TenantId = tenantId,
            JobRequisitionId = jobRequisitionId
        });
        db.JobDescriptionVersions.Add(new RecruitmentJobDescriptionVersion
        {
            JobDescriptionVersionId = Guid.NewGuid(),
            TenantId = tenantId,
            JobDescriptionId = jobDescriptionId,
            VersionNumber = 1,
            ResponsibilitiesText = input.RawDescription,
            ApprovalStatus = "Draft"
        });
        await db.SaveChangesAsync(ct);

        var submitResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_SubmitJobRequisitionForApproval",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@JobRequisitionId", jobRequisitionId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApprovalMatrixCode", ApprovalMatrixCode, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@RequestedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!submitResult.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                TanId = jobRequisitionId.ToString(),
                Summary = $"TAN {tanNumber} created but could not be submitted for approval: {submitResult.Message}",
                RisksOrExceptions = [submitResult.ErrorCode ?? "SUBMIT_FOR_APPROVAL_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            TanId = jobRequisitionId.ToString(),
            ProposedNextState = "PendingApproval",
            DataUpdated = ["recruitment.TalentAcquisitionNumber", "recruitment.JobRequisition", "recruitment.JobDescriptionVersion"],
            Summary = $"TAN {tanNumber} created and submitted for approval.",
            RequiredApprovals = [ApprovalMatrixCode],
            NextAllowedActions = [$"POST /api/v1/tans/{jobRequisitionId}/approve"]
        };
    }
}
