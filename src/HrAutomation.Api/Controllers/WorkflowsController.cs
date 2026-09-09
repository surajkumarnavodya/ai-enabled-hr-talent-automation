using HrAutomation.Application.Contracts;
using HrAutomation.Infrastructure.Persistence.Entities;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

// "Workflow" here maps onto workflow.ApprovalRequest: HrAutomationDb has no generic
// WorkflowInstance table backing this concept (see Agents/Orchestration/WorkflowOrchestrator.cs
// class comment) - each business action's own status column (e.g.
// recruitment.JobRequisition.RequisitionStatusCode) tracks state, and ApprovalRequest is the
// closest analog to a pollable "workflow instance": one row per approval cycle for an entity.
[Route("api/v1/workflows")]
public sealed class WorkflowsController(HrAutomationDbContext db) : HrControllerBase
{
    [HttpGet("{workflowId:guid}")]
    public async Task<IActionResult> GetWorkflow(Guid workflowId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var request = await db.ApprovalRequests
            .FirstOrDefaultAsync(a => a.ApprovalRequestId == workflowId && a.TenantId == ctx.TenantId, ct);

        if (request is null)
        {
            return NotFound();
        }

        return Ok(ToDto(request));
    }

    private static WorkflowDto ToDto(WorkflowApprovalRequest a) => new()
    {
        WorkflowId = a.ApprovalRequestId,
        WorkflowType = a.EntityType,
        CurrentState = a.Status,
        SubjectId = a.EntityId,
        CreatedAtUtc = a.RequestedAtUtc,
        UpdatedAtUtc = a.CompletedAtUtc ?? a.RequestedAtUtc
    };
}
