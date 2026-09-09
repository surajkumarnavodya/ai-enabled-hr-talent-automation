using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using Microsoft.AspNetCore.Mvc;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/offers")]
public sealed class OffersController(ISkillRegistry skillRegistry, IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CreateOffer(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("create_offer_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "create_offer", null, ct: ct);
        return Ok(response);
    }

    [HttpPost("{offerId:guid}/approve")]
    public async Task<IActionResult> ApproveOffer(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("offer_approval_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "approve_offer", null, ct: ct);
        return Ok(response);
    }

    [HttpPost("{offerId:guid}/send")]
    public async Task<IActionResult> SendOffer(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("offer_send_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "send_offer", null, ct: ct);
        return Ok(response);
    }

    [HttpPost("{offerId:guid}/acceptance")]
    public async Task<IActionResult> RecordAcceptance(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("offer_acceptance_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "record_offer_acceptance", null, ct: ct);
        return Ok(response);
    }
}
