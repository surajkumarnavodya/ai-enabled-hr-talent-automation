using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Offers;

/// <summary>
/// Creates an offer.Offer draft via offer.usp_CreateOfferDraft, then immediately submits it for
/// approval via offer.usp_SubmitOfferForApproval (OFFER_APPROVAL_STD matrix) - mirrors
/// CreateTanSkill's create-then-submit pattern. Compensation is intentionally not set here: no
/// procedure exists yet for writing offer.OfferCompensation (a RESTRICTED TABLE per
/// 03-create-tables.sql), so a compensation figure is never accepted from this or any other
/// untrusted input path - see CLAUDE.md "Never store a compensation figure as free text."
/// </summary>
public sealed class CreateOfferSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "create_offer_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN"];

    private const string ApprovalMatrixCode = "OFFER_APPROVAL_STD";

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as CreateOfferRequest
            ?? throw new InvalidOperationException("CreateOfferSkill requires CreateOfferRequest.");

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var draftResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "offer.usp_CreateOfferDraft",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CandidateApplicationId", input.CandidateApplicationId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@OfferTemplateId", input.OfferTemplateId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@CreatedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!draftResult.Success || draftResult.EntityId is not { } offerId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = $"Offer draft creation failed: {draftResult.Message}",
                RisksOrExceptions = [draftResult.ErrorCode ?? "OFFER_DRAFT_CREATE_FAILED"]
            };
        }
        var offerNumber = draftResult.Message!;

        var submitResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "offer.usp_SubmitOfferForApproval",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@OfferId", offerId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApprovalMatrixCode", ApprovalMatrixCode, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@RequestedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!submitResult.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                OfferId = offerId.ToString(),
                Summary = $"Offer {offerNumber} created but could not be submitted for approval: {submitResult.Message}",
                RisksOrExceptions = [submitResult.ErrorCode ?? "SUBMIT_FOR_APPROVAL_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            OfferId = offerId.ToString(),
            ApplicationId = input.CandidateApplicationId.ToString(),
            ProposedNextState = "PendingApproval",
            DataUpdated = ["offer.Offer", "offer.OfferVersion", "workflow.ApprovalRequest"],
            Summary = $"Offer {offerNumber} created and submitted for approval.",
            RequiredApprovals = [ApprovalMatrixCode],
            NextAllowedActions = [$"POST /api/v1/offers/{offerId}/approve"]
        };
    }
}
