namespace HrAutomation.Application.Contracts;

/// <summary>
/// One row = one recruitment.InterviewRound (the granularity the frontend list/detail/feedback
/// pages operate at - "L1", "L2", "Client" etc. are separate rounds of the same
/// recruitment.Interview). InterviewRoundId is the "id" this API surface uses throughout.
/// </summary>
public sealed class InterviewDto
{
    public Guid InterviewRoundId { get; init; }
    public Guid CandidateApplicationId { get; init; }
    public string CandidateName { get; init; } = string.Empty;
    public string Stage { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public DateTime? ScheduledAt { get; init; }
}

public sealed class ScheduleInterviewRequest
{
    public required Guid CandidateApplicationId { get; init; }
    public required Guid InterviewRoundDefinitionId { get; init; }
    public required DateTime ScheduledStartUtc { get; init; }
    public required DateTime ScheduledEndUtc { get; init; }
    public string? TimeZoneId { get; init; }
    public string? LocationOrLink { get; init; }
    public Guid? PanelUserId { get; init; }
}

public sealed class SubmitInterviewFeedbackRequest
{
    /// <summary>select -> InterviewOutcome "Progressed" + InterviewFeedback.OverallRecommendation "Yes";
    /// reject -> "Rejected" / "No". See CK_InterviewFeedback_Recommendation / CK_InterviewOutcome_Status.</summary>
    public required string Outcome { get; init; }
    public decimal? CommunicationScore { get; init; }
    public decimal? TechnicalScore { get; init; }
    public string? Notes { get; init; }
}
