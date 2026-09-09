using System.Data;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Offers;

/// <summary>Records candidate acceptance via offer.usp_RecordOfferAcceptance, which refuses
/// unless the offer's current status is 'Sent'.</summary>
public sealed class OfferAcceptanceSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "offer_acceptance_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["CANDIDATE_PORTAL_USER", "HR_ADMIN"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        if (context.TanId is null || !Guid.TryParse(context.TanId, out var offerId))
        {
            throw new InvalidOperationException("OfferAcceptanceSkill requires a valid OfferId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "offer.usp_RecordOfferAcceptance",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@OfferId", offerId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@RecordedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                OfferId = offerId.ToString(),
                Summary = result.Message ?? "Offer acceptance recording failed.",
                RisksOrExceptions = [result.ErrorCode ?? "OFFER_ACCEPTANCE_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            OfferId = offerId.ToString(),
            ProposedNextState = "Accepted",
            DataUpdated = ["offer.Offer", "offer.OfferAcceptance", "offer.OfferStatusHistory"],
            Summary = "Offer acceptance recorded."
        };
    }
}
