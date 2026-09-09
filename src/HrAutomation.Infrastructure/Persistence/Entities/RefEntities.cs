namespace HrAutomation.Infrastructure.Persistence.Entities;

public class RefCandidateSource
{
    public Guid CandidateSourceId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
}
