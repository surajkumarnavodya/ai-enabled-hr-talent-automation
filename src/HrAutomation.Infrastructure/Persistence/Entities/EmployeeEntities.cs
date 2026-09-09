namespace HrAutomation.Infrastructure.Persistence.Entities;

public class EmployeeConversion
{
    public Guid EmployeeConversionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateApplicationId { get; set; }
    public Guid OfferId { get; set; }
    public string Status { get; set; } = null!; // Pending, Eligible, Approved, Converted, Blocked
    public DateTime RequestedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}
