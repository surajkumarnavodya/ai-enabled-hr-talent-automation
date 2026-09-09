namespace HrAutomation.Infrastructure.Persistence.Entities;

public class AuditEvent
{
    public long AuditEventId { get; set; }
    public Guid EventId { get; set; }
    public Guid? TenantId { get; set; }
    public Guid? ActorUserId { get; set; }
    public string ActorType { get; set; } = null!; // User, System, AiAgent, ApiClient
    public string Action { get; set; } = null!;
    public string EntityType { get; set; } = null!;
    public Guid? EntityId { get; set; }
    public string? PreviousStatus { get; set; }
    public string? NewStatus { get; set; }
    public string Outcome { get; set; } = null!; // Success, Denied, Failed
    public string? MetadataJson { get; set; }
    public Guid? CorrelationId { get; set; }
    public DateTime OccurredAtUtc { get; set; }
}

public class IdempotencyKeyEntry
{
    public Guid IdempotencyKeyId { get; set; }
    public Guid TenantId { get; set; }
    public string IdempotencyKeyValue { get; set; } = null!;
    public string RequestPath { get; set; } = null!;
    public int? ResponseStatusCode { get; set; }
    public byte[]? ResponseBodyHash { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
}
