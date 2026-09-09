namespace HrAutomation.Application.Contracts;

public sealed class CandidateDto
{
    public Guid CandidateId { get; init; }
    public string FullName { get; init; } = string.Empty;
    public string? CurrentLocation { get; init; }
    public int TotalExperienceMonths { get; init; }
    public string Source { get; init; } = string.Empty;
    public bool IsActive { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public string RowVersion { get; init; } = string.Empty;
}

public sealed class PatchCandidateRequest
{
    public string? FullName { get; init; }
    public string? CurrentLocation { get; init; }
    public int? TotalExperienceMonths { get; init; }
}
