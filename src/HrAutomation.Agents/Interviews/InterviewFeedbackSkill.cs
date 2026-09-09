using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Interviews;

/// <summary>
/// Records the panelist's feedback + outcome decision for one InterviewRound via
/// recruitment.usp_SubmitInterviewFeedback. This is a real, audited human decision (the
/// submitting interviewer) - it does not itself advance the candidate through the TAN/offer
/// pipeline; that stays gated behind its own separate approval action. See
/// docs/02-business-workflows and CLAUDE.md "AI may parse/summarize/route - never
/// autonomously reject/select a candidate" (not applicable here: this is a human decision,
/// not an AI one, but the skill still never bypasses the stored-procedure write path).
/// </summary>
public sealed class InterviewFeedbackSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "interview_feedback_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["INTERVIEWER"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as SubmitInterviewFeedbackRequest
            ?? throw new InvalidOperationException("InterviewFeedbackSkill requires SubmitInterviewFeedbackRequest.");

        if (context.TanId is null || !Guid.TryParse(context.TanId, out var interviewRoundId))
        {
            // Reusing the generic TanId slot on SkillContext for the round id - see
            // InterviewsController.SubmitFeedback, which is the only caller.
            throw new InvalidOperationException("InterviewFeedbackSkill requires a valid InterviewRoundId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var (overallRecommendation, outcomeStatus) = input.Outcome == "select"
            ? ("Yes", "Progressed")
            : ("No", "Rejected");

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_SubmitInterviewFeedback",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@InterviewRoundId", interviewRoundId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@SubmittedByUserId", userId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@OverallRecommendation", overallRecommendation, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@OutcomeStatus", outcomeStatus, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@CommunicationScore", input.CommunicationScore, SqlDbType.Decimal),
                StoredProcedureExecutor.Param("@TechnicalScore", input.TechnicalScore, SqlDbType.Decimal),
                StoredProcedureExecutor.Param("@Notes", input.Notes, SqlDbType.NVarChar)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                InterviewRoundId = interviewRoundId.ToString(),
                Summary = result.Message ?? "Interview feedback submission failed.",
                RisksOrExceptions = [result.ErrorCode ?? "INTERVIEW_FEEDBACK_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            InterviewRoundId = interviewRoundId.ToString(),
            ProposedNextState = "Completed",
            DataUpdated = ["recruitment.InterviewFeedback", "recruitment.InterviewFeedbackScore", "recruitment.InterviewOutcome", "recruitment.Interview"],
            Summary = $"Interview feedback recorded: {outcomeStatus}.",
        };
    }
}
