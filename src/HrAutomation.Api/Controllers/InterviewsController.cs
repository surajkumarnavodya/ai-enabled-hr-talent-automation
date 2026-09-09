using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using Microsoft.AspNetCore.Mvc;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/interviews")]
public sealed class InterviewsController(ISkillRegistry skillRegistry, IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CreateInterview(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("create_interview_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "create_interview", null, ct: ct);
        return Ok(response);
    }

    [HttpPost("{interviewId:guid}/feedback")]
    public async Task<IActionResult> SubmitFeedback(Guid interviewId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("interview_feedback_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "submit_interview_feedback", null, ct: ct);
        return Ok(response);
    }
}
