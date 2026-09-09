namespace HrAutomation.Application.Contracts;

public sealed class DiscrepancyDto
{
    public Guid Id { get; init; }
    public Guid CandidateApplicationId { get; init; }
    public string Type { get; init; } = string.Empty;
    public string Severity { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}

public sealed class ResolveDiscrepancyRequest
{
    /// <summary>approved -> ResolutionType "Cleared"; rejected -> "Confirmed". See
    /// CK_DiscrepancyResolution_Type / onboarding.usp_ResolveDiscrepancy.</summary>
    public required string Decision { get; init; }
}

public sealed class RequestReuploadRequest
{
    public string? Reason { get; init; }
}
