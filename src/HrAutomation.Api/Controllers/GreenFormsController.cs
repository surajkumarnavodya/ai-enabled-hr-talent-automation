using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using Microsoft.AspNetCore.Mvc;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/green-forms")]
public sealed class GreenFormsController(ISkillRegistry skillRegistry, IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpPost("{applicationId:guid}/issue-link")]
    public async Task<IActionResult> IssueLink(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("green_form_issue_link_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "issue_green_form_link", null,
            applicationId: applicationId.ToString(), ct: ct);
        return Ok(response);
    }
}
