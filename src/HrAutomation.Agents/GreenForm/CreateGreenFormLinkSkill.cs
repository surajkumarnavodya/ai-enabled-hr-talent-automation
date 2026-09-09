using System.Data;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.GreenForm;

/// <summary>
/// Issues (or returns the existing) Green Form link for a candidate application via
/// onboarding.usp_IssueGreenFormLink. The returned GreenFormSubmissionId IS the single-use
/// token the candidate URL carries — see that procedure's header comment for why no separate
/// token table exists.
/// </summary>
public sealed class CreateGreenFormLinkSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "green_form_issue_link_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN", "RECRUITER"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        if (context.ApplicationId is null || !Guid.TryParse(context.ApplicationId, out var applicationId))
        {
            throw new InvalidOperationException("CreateGreenFormLinkSkill requires a valid CandidateApplicationId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "onboarding.usp_IssueGreenFormLink",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CandidateApplicationId", applicationId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CreatedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!result.Success || result.EntityId is not { } submissionId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = result.Message ?? "Green Form link issuance failed.",
                RisksOrExceptions = [result.ErrorCode ?? "GREEN_FORM_ISSUE_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            GreenFormSubmissionId = submissionId.ToString(),
            ApplicationId = applicationId.ToString(),
            ProposedNextState = "InProgress",
            DataUpdated = ["onboarding.GreenForm", "onboarding.GreenFormVersion", "onboarding.GreenFormSubmission"],
            Summary = $"Green Form link issued: /green-form/{submissionId}"
        };
    }
}
