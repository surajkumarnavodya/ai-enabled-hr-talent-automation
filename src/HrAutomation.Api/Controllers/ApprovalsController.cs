using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

/// <summary>
/// A real, cross-entity-type read of workflow.ApprovalRequest/ApprovalStep — the actual
/// generic work queue every approver-role page in the frontend expects. Decision dispatch
/// (POST .../decision) is real for the entity types with an already-built approval skill
/// (offer.Offer, onboarding.Discrepancy) and returns a clear, honest 422 - never a silent
/// no-op - for entity types not yet wired here (recruitment.JobRequisition/CandidateShortlist/
/// employee.EmployeeConversion each already have their own dedicated approve endpoints under
/// /tans, /applications; routing them through this generic endpoint too is follow-up work).
/// </summary>
[Route("api/v1/approvals")]
public sealed class ApprovalsController(
    HrAutomationDbContext db,
    ISkillRegistry skillRegistry,
    IGuardrailPipeline guardrails) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<PendingApprovalDto>>> ListPending(CancellationToken ct)
    {
        var ctx = BuildRequestContext();

        var pendingRequests = await db.ApprovalRequests
            .Where(r => r.TenantId == ctx.TenantId && r.Status == "Pending")
            .OrderByDescending(r => r.RequestedAtUtc)
            .Take(100)
            .ToListAsync(ct);

        var items = pendingRequests.Select(r => new PendingApprovalDto
        {
            Id = r.ApprovalRequestId,
            SubjectType = r.EntityType,
            SubjectLabel = $"{r.EntityType.Split('.').Last()} {r.EntityId.ToString()[..8]}",
            Action = "Approve",
            RequestedAt = r.RequestedAtUtc
        }).ToList();

        return Ok(new CursorPage<PendingApprovalDto> { Items = items, NextCursor = null });
    }

    [HttpPost("{approvalRequestId:guid}/decision")]
    public async Task<IActionResult> Decide(Guid approvalRequestId, [FromBody] ApprovalDecisionRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var approvalRequest = await db.ApprovalRequests
            .FirstOrDefaultAsync(r => r.ApprovalRequestId == approvalRequestId && r.TenantId == ctx.TenantId, ct);
        if (approvalRequest is null)
        {
            return NotFound();
        }

        (string SkillName, string TanIdOrAppId, bool UseTanId)? dispatch = approvalRequest.EntityType switch
        {
            "offer.Offer" when request.Decision == "approved" => ("offer_approval_skill", approvalRequest.EntityId.ToString(), true),
            "onboarding.Discrepancy" => ("discrepancy_resolve_skill", approvalRequest.EntityId.ToString(), false),
            _ => null
        };

        if (dispatch is null)
        {
            return UnprocessableEntity(Problem(
                statusCode: StatusCodes.Status422UnprocessableEntity,
                title: "Unsupported entity type",
                detail: $"Generic approval decisions are not yet wired for '{approvalRequest.EntityType}'. Use the entity-specific approval endpoint instead."));
        }

        var skill = skillRegistry.Get(dispatch.Value.SkillName);
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        object? input = approvalRequest.EntityType == "onboarding.Discrepancy"
            ? new ResolveDiscrepancyRequest { Decision = request.Decision }
            : null;

        var response = dispatch.Value.UseTanId
            ? await InvokeStandaloneAsync(guardrails, skill, ctx, "approvals_decision", input, tanId: dispatch.Value.TanIdOrAppId, ct: ct)
            : await InvokeStandaloneAsync(guardrails, skill, ctx, "approvals_decision", input, applicationId: dispatch.Value.TanIdOrAppId, ct: ct);

        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }
}

public sealed class PendingApprovalDto
{
    public Guid Id { get; init; }
    public string SubjectType { get; init; } = string.Empty;
    public string SubjectLabel { get; init; } = string.Empty;
    public string Action { get; init; } = string.Empty;
    public DateTime RequestedAt { get; init; }
}

public sealed class ApprovalDecisionRequest
{
    public required string Decision { get; init; }
}
