using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using Microsoft.AspNetCore.Mvc;

namespace HrAutomation.Api.Controllers;

/// <summary>
/// Shortlist approval, progression approval (L1/L2/client outcome confirmation), and employee
/// conversion all depend on candidate_tan_application rows that only match_candidates_skill would
/// create - and that skill is still a stub in this pass. These routes are therefore wired directly
/// to their skills (not through the workflow engine) and always return "blocked" (spec section 6).
/// </summary>
[Route("api/v1/applications")]
public sealed class ApplicationsController(ISkillRegistry skillRegistry, IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpPost("{applicationId:guid}/shortlist-approval")]
    public async Task<IActionResult> ShortlistApproval(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("shortlist_approval_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "shortlist_approval", null,
            applicationId: applicationId.ToString(), ct: ct);
        return Ok(response);
    }

    [HttpPost("{applicationId:guid}/progression-approval")]
    public async Task<IActionResult> ProgressionApproval(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("progression_approval_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "progression_approval", null,
            applicationId: applicationId.ToString(), ct: ct);
        return Ok(response);
    }

    [HttpPost("{applicationId:guid}/convert-to-employee")]
    public async Task<IActionResult> ConvertToEmployee(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("employee_conversion_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "convert_to_employee", null,
            applicationId: applicationId.ToString(), ct: ct);
        return Ok(response);
    }
}
