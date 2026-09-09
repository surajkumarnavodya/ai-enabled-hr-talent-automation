using System.Text.Json;
using HrAutomation.Api.Security;
using HrAutomation.Application.Audit;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Security;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HrAutomation.Api.Controllers;

[ApiController]
[Authorize]
public abstract class HrControllerBase : ControllerBase
{
    protected RequestContext BuildRequestContext() => RequestContextFactory.FromHttpContext(HttpContext);

    protected static bool IsAuthorizedForSkill(ISkill skill, RequestContext ctx) =>
        skill.RequiredRoles.Count == 0 || skill.RequiredRoles.Contains(ctx.Role);

    protected IActionResult ForbiddenForSkill(ISkill skill, RequestContext ctx) =>
        Problem(
            statusCode: StatusCodes.Status403Forbidden,
            title: "Forbidden",
            detail: $"Role '{ctx.Role}' is not permitted to invoke '{skill.SkillName}'.");

    /// <summary>
    /// Deny-by-default permission gate backed by iam.RolePermission (see
    /// IEffectivePermissionService), for the Administration/Master-Management module where a
    /// role-string list is too coarse. Returns null when allowed; otherwise a 403 Problem Details
    /// result, after writing a "Denied" audit event - every denied attempt is audited per
    /// .claude/rules/security.md, not just successful sensitive actions.
    /// </summary>
    protected async Task<IActionResult?> RequirePermissionAsync(
        IEffectivePermissionService permissions,
        IAuditLogger auditLogger,
        RequestContext ctx,
        string permissionKey,
        CancellationToken ct)
    {
        if (await permissions.HasPermissionAsync(ctx.TenantId, ctx.UserId, permissionKey, ct))
        {
            return null;
        }

        await auditLogger.LogAsync(new AuditLogEntry
        {
            TenantId = ctx.TenantId,
            EventType = "authorization.denied",
            ActorType = ActorType.human,
            ActorId = ctx.UserId.ToString(),
            EntityType = "iam.Permission",
            CorrelationId = ctx.CorrelationId,
            NewStatus = "Denied",
            DetailsJson = JsonSerializer.Serialize(new { requiredPermission = permissionKey, actorRole = ctx.Role })
        }, ct);

        return Problem(
            statusCode: StatusCodes.Status403Forbidden,
            title: "Forbidden",
            detail: $"Missing required permission '{permissionKey}'.");
    }

    /// <summary>422 Problem Details for "valid JSON, invalid business input" per spec section 6.</summary>
    protected IActionResult ValidationProblemFrom(FluentValidation.Results.ValidationResult validation)
    {
        foreach (var error in validation.Errors)
        {
            ModelState.AddModelError(error.PropertyName, error.ErrorMessage);
        }

        var problemDetails = ProblemDetailsFactory.CreateValidationProblemDetails(
            HttpContext, ModelState, statusCode: StatusCodes.Status422UnprocessableEntity);

        return new UnprocessableEntityObjectResult(problemDetails);
    }

    /// <summary>
    /// Runs a skill outside the workflow engine, for section-6 routes whose upstream workflow
    /// instance doesn't exist yet in this scaffold pass (e.g. applications/interviews/offers that
    /// depend on the still-stubbed match_candidates_skill). Always produces a valid envelope with
    /// workflow_id "n/a" - it never touches WorkflowInstance/WorkflowStateTransition.
    /// </summary>
    protected async Task<AgentActionResponse> InvokeStandaloneAsync(
        IGuardrailPipeline guardrails,
        ISkill skill,
        RequestContext ctx,
        string action,
        object? input,
        string? tanId = null,
        string? candidateId = null,
        string? applicationId = null,
        CancellationToken ct = default)
    {
        var guardrailResults = guardrails.Evaluate(new GuardrailCheckInput
        {
            RequestContext = ctx,
            RequiredRoles = skill.RequiredRoles
        });

        var skillResult = await skill.ExecuteAsync(new SkillContext
        {
            RequestContext = ctx,
            WorkflowInstanceId = Guid.Empty,
            TanId = tanId,
            CandidateId = candidateId,
            ApplicationId = applicationId,
            Input = input
        }, ct);

        return AgentActionResponseFactory.Build(ctx, action, "n/a", "N/A", null, skillResult, guardrailResults, actorId: skill.SkillName);
    }
}
