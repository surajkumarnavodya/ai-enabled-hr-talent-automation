using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Interviews;

/// <summary>
/// Schedules the next InterviewRound for a candidate's application via
/// recruitment.usp_ScheduleInterview - creates the parent recruitment.Interview row on first
/// call, appends subsequent rounds (L1, L2, Client, ...) on later calls. See ADR-006: the
/// stored procedure is the sole write path for this workflow-adjacent state.
/// </summary>
public sealed class CreateInterviewSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "create_interview_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["RECRUITER", "HR_ADMIN"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as ScheduleInterviewRequest
            ?? throw new InvalidOperationException("CreateInterviewSkill requires ScheduleInterviewRequest.");

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_ScheduleInterview",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CandidateApplicationId", input.CandidateApplicationId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@InterviewRoundDefinitionId", input.InterviewRoundDefinitionId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ScheduledStartUtc", input.ScheduledStartUtc, SqlDbType.DateTime2),
                StoredProcedureExecutor.Param("@ScheduledEndUtc", input.ScheduledEndUtc, SqlDbType.DateTime2),
                StoredProcedureExecutor.Param("@TimeZoneId", input.TimeZoneId, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@LocationOrLink", input.LocationOrLink, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@PanelUserId", input.PanelUserId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CreatedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!result.Success || result.EntityId is not { } interviewRoundId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = result.Message ?? "Interview scheduling failed.",
                RisksOrExceptions = [result.ErrorCode ?? "SCHEDULE_INTERVIEW_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            InterviewRoundId = interviewRoundId.ToString(),
            ApplicationId = input.CandidateApplicationId.ToString(),
            ProposedNextState = "Scheduled",
            DataUpdated = ["recruitment.Interview", "recruitment.InterviewRound", "recruitment.InterviewScheduleSlot"],
            Summary = "Interview scheduled.",
            NextAllowedActions = [$"POST /api/v1/interviews/{interviewRoundId}/feedback"]
        };
    }
}
