using System.Data;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Agents.Applications;

/// <summary>Approves the AI-recommended shortlist for a candidate application via
/// recruitment.usp_ApproveCandidateShortlist. This is the human decision CandidateMatchesPage's
/// "Approve for shortlist" button records - the AI match score/recommendation never decides on
/// its own. See CLAUDE.md "AI may ... never autonomously ... select a candidate."</summary>
public sealed class ShortlistApprovalSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "shortlist_approval_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN", "TALENT_ACQUISITION_MANAGER"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        if (context.ApplicationId is null || !Guid.TryParse(context.ApplicationId, out var applicationId))
        {
            throw new InvalidOperationException("ShortlistApprovalSkill requires a valid CandidateApplicationId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var shortlistId = await db.Database.SqlQuery<Guid>(
            $"SELECT CandidateShortlistId AS [Value] FROM recruitment.CandidateShortlist WHERE CandidateApplicationId = {applicationId} AND TenantId = {tenantId} AND IsDeleted = 0")
            .FirstOrDefaultAsync(ct);

        if (shortlistId == Guid.Empty)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                ApplicationId = applicationId.ToString(),
                Summary = "No shortlist entry found for this application.",
                RisksOrExceptions = ["NOT_FOUND"]
            };
        }

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_ApproveCandidateShortlist",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CandidateShortlistId", shortlistId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApproverUserId", userId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@Comments", (string?)null, SqlDbType.NVarChar)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                ApplicationId = applicationId.ToString(),
                Summary = result.Message ?? "Shortlist approval failed.",
                RisksOrExceptions = [result.ErrorCode ?? "SHORTLIST_APPROVAL_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            ApplicationId = applicationId.ToString(),
            DataUpdated = ["recruitment.CandidateShortlistApproval"],
            Summary = "Shortlist approved."
        };
    }
}
