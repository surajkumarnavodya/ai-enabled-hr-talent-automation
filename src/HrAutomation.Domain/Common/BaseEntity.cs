namespace HrAutomation.Domain.Common;

/// <summary>
/// Base for all persisted entities. TenantId is nullable only for the small set of
/// global catalog entities (Role, Permission) that are not tenant-scoped.
/// </summary>
public abstract class BaseEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? TenantId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }

    /// <summary>SQL Server rowversion column - backs optimistic concurrency and API ETag/If-Match.</summary>
    public byte[] RowVersion { get; set; } = Array.Empty<byte>();

    public bool IsDeleted { get; set; }
}
