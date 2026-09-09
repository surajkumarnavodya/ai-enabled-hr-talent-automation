using System.Data;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Offers;

/// <summary>Records one approval step against a pending offer.OfferApproval via offer.usp_ApproveOffer.</summary>
public sealed class OfferApprovalSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "offer_approval_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["OFFER_APPROVER"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        if (context.TanId is null || !Guid.TryParse(context.TanId, out var offerId))
        {
            throw new InvalidOperationException("OfferApprovalSkill requires a valid OfferId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "offer.usp_ApproveOffer",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@OfferId", offerId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApproverUserId", userId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@Comments", (string?)null, SqlDbType.NVarChar)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                OfferId = offerId.ToString(),
                Summary = result.Message ?? "Offer approval failed.",
                RisksOrExceptions = [result.ErrorCode ?? "OFFER_APPROVAL_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            OfferId = offerId.ToString(),
            DataUpdated = ["offer.Offer", "offer.OfferApproval", "workflow.ApprovalStep", "workflow.ApprovalDecision"],
            Summary = "Offer approval step recorded.",
            NextAllowedActions = [$"POST /api/v1/offers/{offerId}/send"]
        };
    }
}
