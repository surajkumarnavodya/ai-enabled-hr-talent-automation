namespace HrAutomation.Application.Contracts;

public sealed class AuditLogDto
{
    public Guid Id { get; init; }
    public string EventType { get; init; } = string.Empty;
    public string ActorType { get; init; } = string.Empty;
    public string ActorId { get; init; } = string.Empty;
    public string? WorkflowId { get; init; }
    public string? TanId { get; init; }
    public string? CandidateId { get; init; }
    public string? ApplicationId { get; init; }
    public string CorrelationId { get; init; } = string.Empty;
    public string? PriorStatus { get; init; }
    public string? NewStatus { get; init; }
    public DateTime CreatedAtUtc { get; init; }
}

public sealed class WorkflowDto
{
    public Guid WorkflowId { get; init; }
    public string WorkflowType { get; init; } = string.Empty;
    public string CurrentState { get; init; } = string.Empty;
    public Guid SubjectId { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public DateTime UpdatedAtUtc { get; init; }
}
