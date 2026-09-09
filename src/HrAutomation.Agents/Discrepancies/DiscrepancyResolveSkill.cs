using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Discrepancies;

/// <summary>Records the HR resolution decision for a discrepancy via onboarding.usp_ResolveDiscrepancy
/// (DISCREPANCY_EXCEPTION_STD approval matrix). Always a human decision — see CLAUDE.md "AI may
/// parse/summarize/route - never autonomously ... resolve a discrepancy."</summary>
public sealed class DiscrepancyResolveSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "discrepancy_resolve_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN"];

    private const string ApprovalMatrixCode = "DISCREPANCY_EXCEPTION_STD";

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as ResolveDiscrepancyRequest
            ?? throw new InvalidOperationException("DiscrepancyResolveSkill requires ResolveDiscrepancyRequest.");

        if (context.ApplicationId is null || !Guid.TryParse(context.ApplicationId, out var discrepancyId))
        {
            // Reusing the generic ApplicationId slot on SkillContext for the discrepancy id -
            // see DiscrepanciesController.Resolve, the only caller.
            throw new InvalidOperationException("DiscrepancyResolveSkill requires a valid DiscrepancyId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;
        var resolutionType = input.Decision == "approved" ? "Cleared" : "Confirmed";

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "onboarding.usp_ResolveDiscrepancy",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@DiscrepancyId", discrepancyId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ResolutionType", resolutionType, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@CorrectiveAction", (string?)null, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@HrDecisionNotes", (string?)null, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@ResolvedByUserId", userId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApprovalMatrixCode", ApprovalMatrixCode, SqlDbType.NVarChar)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = result.Message ?? "Discrepancy resolution failed.",
                RisksOrExceptions = [result.ErrorCode ?? "DISCREPANCY_RESOLVE_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            ApplicationId = discrepancyId.ToString(),
            ProposedNextState = "Closed",
            DataUpdated = ["onboarding.Discrepancy", "onboarding.DiscrepancyApproval", "onboarding.DiscrepancyResolution", "onboarding.DiscrepancyStatusHistory"],
            Summary = $"Discrepancy resolution recorded: {resolutionType}."
        };
    }
}
