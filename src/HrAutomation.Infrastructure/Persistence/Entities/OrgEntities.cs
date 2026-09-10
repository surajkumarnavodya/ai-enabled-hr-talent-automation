namespace HrAutomation.Infrastructure.Persistence.Entities;

// Thin org.* master-data entities - see IamEntities.cs header comment for the
// database-first convention these follow. Only the columns needed by the
// Administration/Master-Management module so far are mapped; extend as more
// org.* screens are built (docs/09-quality-evaluation/master-management-gap-analysis.md).

public class OrgDepartment
{
    public Guid DepartmentId { get; set; }
    public Guid TenantId { get; set; }
    public Guid? BusinessUnitId { get; set; }
    public string DepartmentCode { get; set; } = null!;
    public string DepartmentName { get; set; } = null!;
    public Guid? ParentDepartmentId { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class OrgLocation
{
    public Guid LocationId { get; set; }
    public Guid TenantId { get; set; }
    public string LocationCode { get; set; } = null!;
    public string LocationName { get; set; } = null!;
    public string? City { get; set; }
    public string? CountryCode { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class OrgTenant
{
    public Guid TenantId { get; set; }
    public string TenantCode { get; set; } = null!;
    public string TenantName { get; set; } = null!;
    public string? LegalName { get; set; }
    public string? PrimaryDomain { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}
