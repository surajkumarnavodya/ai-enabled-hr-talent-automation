using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Audit;

public sealed class AuditLogEntry
{
    public required Guid TenantId { get; init; }
    public required string EventType { get; init; }
    public required ActorType ActorType { get; init; }
    public required string ActorId { get; init; }
    public string? WorkflowId { get; init; }
    public string? TanId { get; init; }
    public string? CandidateId { get; init; }
    public string? ApplicationId { get; init; }
    /// <summary>Generic entity reference for areas with no dedicated Id property above (e.g.
    /// Administration/Master-Management: "iam.User", "iam.Role", "org.Department", ...). Takes
    /// priority over Tan/Application/Candidate/Workflow in AuditLogger.ResolvePrimaryEntity.</summary>
    public string? EntityType { get; init; }
    public string? EntityId { get; init; }
    public required string CorrelationId { get; init; }
    public string? PriorStatus { get; init; }
    public string? NewStatus { get; init; }
    public string DetailsJson { get; init; } = "{}";
}

/// <summary>Writes immutable audit_log rows. Never place secrets, PII, or document text in DetailsJson.</summary>
public interface IAuditLogger
{
    Task LogAsync(AuditLogEntry entry, CancellationToken ct = default);
}
