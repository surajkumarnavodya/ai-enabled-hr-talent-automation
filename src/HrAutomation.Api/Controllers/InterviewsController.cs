using System.Globalization;
using System.Text;
using FluentValidation;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

// "interviewId" throughout this controller is recruitment.InterviewRoundId — the granularity
// the frontend list/detail/feedback pages operate at (one row per stage: L1, L2, Client, ...),
// not the parent recruitment.Interview. See InterviewDtos.cs.
[Route("api/v1/interviews")]
public sealed class InterviewsController(
    HrAutomationDbContext db,
    ISkillRegistry skillRegistry,
    IGuardrailPipeline guardrails,
    IValidator<ScheduleInterviewRequest> scheduleValidator,
    IValidator<SubmitInterviewFeedbackRequest> feedbackValidator) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<InterviewDto>>> ListInterviews(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.InterviewRounds
            .Where(r => r.TenantId == ctx.TenantId)
            .OrderByDescending(r => r.CreatedAtUtc)
            .ThenByDescending(r => r.InterviewRoundId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterCreatedAt, out var afterId))
        {
            query = query.Where(r =>
                r.CreatedAtUtc < afterCreatedAt ||
                (r.CreatedAtUtc == afterCreatedAt && r.InterviewRoundId.CompareTo(afterId) < 0));
        }

        var rounds = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = rounds.Count > limit;
        var pageRounds = rounds.Take(limit).ToList();

        var dtos = await ToDtosAsync(pageRounds, ctx.TenantId, ct);
        var nextCursor = hasMore ? EncodeCursor(pageRounds[^1].CreatedAtUtc, pageRounds[^1].InterviewRoundId) : null;

        return Ok(new CursorPage<InterviewDto> { Items = dtos, NextCursor = nextCursor });
    }

    [HttpGet("{interviewId:guid}")]
    public async Task<IActionResult> GetInterview(Guid interviewId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var round = await db.InterviewRounds.FirstOrDefaultAsync(r => r.InterviewRoundId == interviewId && r.TenantId == ctx.TenantId, ct);
        if (round is null)
        {
            return NotFound();
        }

        var dtos = await ToDtosAsync([round], ctx.TenantId, ct);
        return Ok(dtos[0]);
    }

    [HttpPost]
    public async Task<IActionResult> ScheduleInterview([FromBody] ScheduleInterviewRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("create_interview_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var validation = await scheduleValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "schedule_interview", request,
            applicationId: request.CandidateApplicationId.ToString(), ct: ct);

        if (response.ActionStatus != ActionStatus.completed || response.InterviewRoundId is not { } roundIdText)
        {
            return UnprocessableEntity(response);
        }

        return CreatedAtAction(nameof(GetInterview), new { interviewId = Guid.Parse(roundIdText) }, response);
    }

    [HttpPost("{interviewId:guid}/feedback")]
    public async Task<IActionResult> SubmitFeedback(Guid interviewId, [FromBody] SubmitInterviewFeedbackRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("interview_feedback_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var validation = await feedbackValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        if (!await db.InterviewRounds.AnyAsync(r => r.InterviewRoundId == interviewId && r.TenantId == ctx.TenantId, ct))
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "submit_interview_feedback", request,
            tanId: interviewId.ToString(), ct: ct);

        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    private async Task<List<InterviewDto>> ToDtosAsync(List<RecruitmentInterviewRound> rounds, Guid tenantId, CancellationToken ct)
    {
        if (rounds.Count == 0) return [];

        var interviewIds = rounds.Select(r => r.InterviewId).Distinct().ToList();
        var interviews = await db.Interviews
            .Where(i => interviewIds.Contains(i.InterviewId))
            .ToDictionaryAsync(i => i.InterviewId, ct);

        var roundDefIds = rounds.Select(r => r.InterviewRoundDefinitionId).Distinct().ToList();
        var roundDefs = await db.InterviewRoundDefinitions
            .Where(d => roundDefIds.Contains(d.InterviewRoundDefinitionId))
            .ToDictionaryAsync(d => d.InterviewRoundDefinitionId, ct);

        var roundIds = rounds.Select(r => r.InterviewRoundId).ToList();
        var currentSlots = await db.InterviewScheduleSlots
            .Where(s => roundIds.Contains(s.InterviewRoundId) && s.IsCurrent)
            .ToDictionaryAsync(s => s.InterviewRoundId, ct);

        var applicationIds = interviews.Values.Select(i => i.CandidateApplicationId).Distinct().ToList();
        var applications = await db.CandidateApplications
            .Where(a => applicationIds.Contains(a.CandidateApplicationId))
            .ToDictionaryAsync(a => a.CandidateApplicationId, ct);

        var candidateIds = applications.Values.Select(a => a.CandidateId).Distinct().ToList();
        var candidates = await db.Candidates
            .Where(c => candidateIds.Contains(c.CandidateId))
            .ToDictionaryAsync(c => c.CandidateId, ct);

        var result = new List<InterviewDto>(rounds.Count);
        foreach (var round in rounds)
        {
            interviews.TryGetValue(round.InterviewId, out var interview);
            roundDefs.TryGetValue(round.InterviewRoundDefinitionId, out var roundDef);
            currentSlots.TryGetValue(round.InterviewRoundId, out var slot);

            RecruitmentCandidateApplication? application = null;
            RecruitmentCandidate? candidate = null;
            if (interview is not null && applications.TryGetValue(interview.CandidateApplicationId, out application))
            {
                candidates.TryGetValue(application.CandidateId, out candidate);
            }

            result.Add(new InterviewDto
            {
                InterviewRoundId = round.InterviewRoundId,
                CandidateApplicationId = interview?.CandidateApplicationId ?? Guid.Empty,
                CandidateName = candidate is null ? string.Empty : $"{candidate.FirstName} {candidate.LastName}",
                Stage = roundDef?.Name ?? string.Empty,
                Status = interview?.Status ?? string.Empty,
                ScheduledAt = slot?.ScheduledStartUtc
            });
        }
        return result;
    }

    private static string EncodeCursor(DateTime createdAtUtc, Guid id) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{createdAtUtc:O}|{id}"));

    private static bool TryDecodeCursor(string cursor, out DateTime createdAtUtc, out Guid id)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|');
            createdAtUtc = DateTime.Parse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
            id = Guid.Parse(parts[1]);
            return true;
        }
        catch (FormatException)
        {
            createdAtUtc = default;
            id = default;
            return false;
        }
    }
}
