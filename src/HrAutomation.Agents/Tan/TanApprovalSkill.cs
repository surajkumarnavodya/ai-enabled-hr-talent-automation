using System.Data;
using HrAutomation.Application.Audit;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Tan;

/// <summary>
/// Records the mandatory TAN (recruitment.JobRequisition) approval decision (spec section 2) via
/// recruitment.usp_ApproveJobRequisition/usp_RejectJobRequisition, which apply the transition
/// atomically with the approval-step/decision rows. "ReturnedForInfo" has no state transition or
/// backing procedure - it is recorded as an audit-only comment, matching the original scaffold's
/// "nothing for the state machine to validate" handling.
///
/// NOTE (documented gap): the old app compared ApproveTanRequest.SourceVersion against an integer
/// version counter for optimistic concurrency. recruitment.JobRequisition uses a SQL `rowversion`
/// column instead, and the stored procedures above don't take a version parameter - they use the
/// approval request's Status = 'Pending' as their own concurrency guard (a second decision on an
/// already-decided request returns NOT_FOUND). SourceVersion is accepted for API-contract
/// compatibility but is not currently enforced here.
/// </summary>
public sealed class TanApprovalSkill(HrAutomationDbContext db, IAuditLogger auditLogger) : ISkill
{
    public string SkillName => "tan_approval_skill";
    public string SkillVersion => "0.1.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN", "TALENT_ACQUISITION_MANAGER", "HIRING_MANAGER"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as ApproveTanRequest
            ?? throw new InvalidOperationException("TanApprovalSkill requires ApproveTanRequest.");

        if (context.TanId is null || !Guid.TryParse(context.TanId, out var jobRequisitionId))
        {
            throw new InvalidOperationException("TanApprovalSkill requires a valid TanId (JobRequisitionId) in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        if (input.Decision == ApprovalDecision.ReturnedForInfo)
        {
            await auditLogger.LogAsync(new AuditLogEntry
            {
                TenantId = tenantId,
                EventType = "TAN.ReturnedForInfo",
                ActorType = ActorType.human,
                ActorId = userId.ToString(),
                TanId = jobRequisitionId.ToString(),
                CorrelationId = context.RequestContext.CorrelationId,
                DetailsJson = $"{{\"comments\":{System.Text.Json.JsonSerializer.Serialize(input.Comments)}}}"
            }, ct);

            return new SkillResult
            {
                Status = ActionStatus.needs_human_review,
                TanId = jobRequisitionId.ToString(),
                Summary = "Additional information requested - no status change applied.",
                NextAllowedActions = [$"POST /api/v1/tans/{jobRequisitionId}/approve"]
            };
        }

        var procedureName = input.Decision == ApprovalDecision.Approved
            ? "recruitment.usp_ApproveJobRequisition"
            : "recruitment.usp_RejectJobRequisition";

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, procedureName,
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@JobRequisitionId", jobRequisitionId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApproverUserId", userId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@Comments", input.Comments, SqlDbType.NVarChar)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                TanId = jobRequisitionId.ToString(),
                Summary = result.Message ?? "TAN approval decision failed.",
                RisksOrExceptions = [result.ErrorCode ?? "TAN_APPROVAL_FAILED"]
            };
        }

        var newStatus = input.Decision == ApprovalDecision.Approved ? "Approved" : "Cancelled";
        return new SkillResult
        {
            Status = ActionStatus.completed,
            TanId = jobRequisitionId.ToString(),
            ProposedNextState = newStatus,
            DataUpdated = ["recruitment.JobRequisition", "workflow.ApprovalRequest", "workflow.ApprovalStep", "workflow.ApprovalDecision"],
            Summary = $"TAN approval recorded: {input.Decision}.",
            NextAllowedActions = newStatus == "Approved"
                ? [$"POST /api/v1/tans/{jobRequisitionId}/match-candidates"]
                : []
        };
    }
}
