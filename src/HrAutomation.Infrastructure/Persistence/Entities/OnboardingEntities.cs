namespace HrAutomation.Infrastructure.Persistence.Entities;

public class OnboardingDiscrepancy
{
    public Guid DiscrepancyId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateApplicationId { get; set; }
    public Guid DiscrepancyTypeId { get; set; }
    public Guid DiscrepancySeverityId { get; set; }
    public Guid DiscrepancyStatusId { get; set; }
    public string Description { get; set; } = null!;
    public DateTime CreatedAtUtc { get; set; }
    public byte[] RowVersion { get; set; } = null!;
    public bool IsDeleted { get; set; }
}

public class OnboardingGreenFormSubmission
{
    public Guid GreenFormSubmissionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateApplicationId { get; set; }
    public string Status { get; set; } = null!; // InProgress, Submitted, UnderReview, Completed
    public bool IsDeleted { get; set; }
}

public class OnboardingVerificationCase
{
    public Guid VerificationCaseId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateApplicationId { get; set; }
    public string Status { get; set; } = null!; // Open, InProgress, Completed, Cancelled
    public DateTime OpenedAtUtc { get; set; }
    public DateTime? ClosedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}
