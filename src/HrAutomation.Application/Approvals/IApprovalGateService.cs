namespace HrAutomation.Application.Approvals;

public sealed record ApprovalGateCheck(bool IsApproved, Guid? ApprovalRequestId, string? Status);

/// <summary>
/// Enforces spec section 2's mandatory human approval gates. Reads the latest
/// workflow.ApprovalRequest for an entity - creation of the approval request itself now
/// happens inside the relevant stored procedure (e.g.
/// recruitment.usp_SubmitJobRequisitionForApproval), which enforces the gate atomically
/// with the state transition it guards. This service is the read-side check the
/// orchestrator/skills use to decide whether a gated action may proceed.
/// </summary>
public interface IApprovalGateService
{
    Task<ApprovalGateCheck> CheckAsync(string entityType, Guid entityId, CancellationToken ct = default);
}
