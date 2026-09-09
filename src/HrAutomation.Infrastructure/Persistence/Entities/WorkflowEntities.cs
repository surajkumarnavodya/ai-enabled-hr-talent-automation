namespace HrAutomation.Infrastructure.Persistence.Entities;

public class WorkflowApprovalRequest
{
    public Guid ApprovalRequestId { get; set; }
    public Guid TenantId { get; set; }
    public Guid? WorkflowInstanceId { get; set; }
    public Guid ApprovalMatrixId { get; set; }
    public string EntityType { get; set; } = null!;
    public Guid EntityId { get; set; }
    public string Status { get; set; } = null!; // Pending, Approved, Rejected, Cancelled
    public Guid? RequestedByUserId { get; set; }
    public DateTime RequestedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public Guid? CorrelationId { get; set; }
    public bool IsDeleted { get; set; }
}

public class WorkflowApprovalStep
{
    public Guid ApprovalStepId { get; set; }
    public Guid TenantId { get; set; }
    public Guid ApprovalRequestId { get; set; }
    public Guid ApprovalMatrixRuleId { get; set; }
    public int StepOrder { get; set; }
    public Guid? AssignedApproverUserId { get; set; }
    public string Status { get; set; } = null!; // Pending, Approved, Rejected, Delegated, Skipped
}

public class WorkflowApprovalDecision
{
    public Guid ApprovalDecisionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid ApprovalStepId { get; set; }
    public Guid DecidedByUserId { get; set; }
    public string Decision { get; set; } = null!; // Approved, Rejected
    public string? Comments { get; set; }
    public DateTime DecidedAtUtc { get; set; }
    public Guid? CorrelationId { get; set; }
}
