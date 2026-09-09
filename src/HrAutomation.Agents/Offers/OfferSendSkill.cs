using System.Data;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Offers;

/// <summary>Moves an offer to Sent via offer.usp_MarkOfferSent, which itself refuses unless the
/// offer's current status is 'Approved' — see that procedure's header comment.</summary>
public sealed class OfferSendSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "offer_send_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        if (context.TanId is null || !Guid.TryParse(context.TanId, out var offerId))
        {
            throw new InvalidOperationException("OfferSendSkill requires a valid OfferId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "offer.usp_MarkOfferSent",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@OfferId", offerId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@SentByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                OfferId = offerId.ToString(),
                Summary = result.Message ?? "Offer send failed.",
                RisksOrExceptions = [result.ErrorCode ?? "OFFER_SEND_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            OfferId = offerId.ToString(),
            ProposedNextState = "Sent",
            DataUpdated = ["offer.Offer", "offer.OfferStatusHistory", "integration.OutboxMessage"],
            Summary = "Offer marked as sent."
        };
    }
}
