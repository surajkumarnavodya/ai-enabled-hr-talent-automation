namespace HrAutomation.Application.Contracts;

public sealed class DashboardSummaryDto
{
    public int ActiveTans { get; init; }
    public int CandidatesAwaitingReview { get; init; }
    public int InterviewsScheduledToday { get; init; }
    public int PendingInterviewFeedback { get; init; }
    public int PendingApprovals { get; init; }
    public int OffersPendingAcceptance { get; init; }
    public int GreenFormsPending { get; init; }
    public int HighSeverityDiscrepancies { get; init; }
    public int EmployeeConversionsPending { get; init; }
    /// <summary>Always 0 — no SLA policy/tracking mechanism exists in this schema yet. Returned
    /// honestly as 0, not fabricated, so the tile doesn't imply monitoring that isn't there.</summary>
    public int SlaBreaches { get; init; }
}
