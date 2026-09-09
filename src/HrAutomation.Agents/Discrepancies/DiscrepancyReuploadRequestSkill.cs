using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Discrepancies;

/// <summary>Raises a document re-upload request tied to a discrepancy via
/// onboarding.usp_RequestDocumentReupload.</summary>
public sealed class DiscrepancyReuploadRequestSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "discrepancy_reupload_request_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["HR_ADMIN", "DOCUMENT_VERIFIER"];

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as RequestReuploadRequest
            ?? throw new InvalidOperationException("DiscrepancyReuploadRequestSkill requires RequestReuploadRequest.");

        if (context.ApplicationId is null || !Guid.TryParse(context.ApplicationId, out var discrepancyId))
        {
            throw new InvalidOperationException("DiscrepancyReuploadRequestSkill requires a valid DiscrepancyId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "onboarding.usp_RequestDocumentReupload",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@DiscrepancyId", discrepancyId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@Reason", input.Reason, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@RequestedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!result.Success)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = result.Message ?? "Re-upload request failed.",
                RisksOrExceptions = [result.ErrorCode ?? "REUPLOAD_REQUEST_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            ApplicationId = discrepancyId.ToString(),
            DataUpdated = ["onboarding.DocumentUploadRequest", "onboarding.Discrepancy", "onboarding.DiscrepancyStatusHistory"],
            Summary = "Document re-upload requested."
        };
    }
}
