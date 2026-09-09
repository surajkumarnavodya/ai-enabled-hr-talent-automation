using HrAutomation.Application.Approvals;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Infrastructure.Approvals;

public sealed class ApprovalGateService(HrAutomationDbContext db) : IApprovalGateService
{
    public async Task<ApprovalGateCheck> CheckAsync(string entityType, Guid entityId, CancellationToken ct = default)
    {
        var request = await db.ApprovalRequests
            .Where(a => a.EntityType == entityType && a.EntityId == entityId)
            .OrderByDescending(a => a.RequestedAtUtc)
            .FirstOrDefaultAsync(ct);

        if (request is null)
        {
            return new ApprovalGateCheck(false, null, null);
        }

        return new ApprovalGateCheck(request.Status == "Approved", request.ApprovalRequestId, request.Status);
    }
}
