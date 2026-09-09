using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

/// <summary>
/// progression-approval (L1/L2/client outcome confirmation) depends on a generic
/// workflow-transition concept this build doesn't have yet and stays wired to its stub - see
/// docs/09-quality-evaluation/production-readiness-report.md. shortlist-approval and
/// convert-to-employee are real.
/// </summary>
[Route("api/v1/applications")]
public sealed class ApplicationsController(HrAutomationDbContext db, ISkillRegistry skillRegistry, IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpPost("{applicationId:guid}/shortlist-approval")]
    public async Task<IActionResult> ShortlistApproval(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("shortlist_approval_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "shortlist_approval", null,
            applicationId: applicationId.ToString(), ct: ct);
        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
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

        // The route/frontend key on CandidateApplicationId; the underlying procedures key on
        // EmployeeConversionId - resolve it here so the skill stays focused on the id shape the
        // stored procedures actually expect.
        var employeeConversionId = await db.EmployeeConversions
            .Where(ec => ec.CandidateApplicationId == applicationId && ec.TenantId == ctx.TenantId)
            .Select(ec => ec.EmployeeConversionId)
            .FirstOrDefaultAsync(ct);
        if (employeeConversionId == Guid.Empty)
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "convert_to_employee", null,
            applicationId: employeeConversionId.ToString(), ct: ct);
        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }
}
