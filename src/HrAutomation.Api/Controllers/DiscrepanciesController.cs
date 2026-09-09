using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using Microsoft.AspNetCore.Mvc;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/discrepancies")]
public sealed class DiscrepanciesController(ISkillRegistry skillRegistry, IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpPost("{discrepancyId:guid}/resolve")]
    public async Task<IActionResult> ResolveDiscrepancy(Guid discrepancyId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("discrepancy_resolve_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "resolve_discrepancy", null, ct: ct);
        return Ok(response);
    }
}
