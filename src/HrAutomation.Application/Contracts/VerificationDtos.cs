namespace HrAutomation.Application.Contracts;

public sealed class VerificationQueueItemDto
{
    public Guid ApplicationId { get; init; }
    public string CandidateName { get; init; } = string.Empty;
    /// <summary>onboarding.VerificationCase.Status verbatim (Open, InProgress, Completed,
    /// Cancelled) — there is no separate pass/fail/needs-review outcome concept on the case
    /// itself; that granularity lives per-check on onboarding.VerificationCheck/VerificationResult,
    /// not surfaced here yet.</summary>
    public string Status { get; init; } = string.Empty;
    public DateTime OpenedAt { get; init; }
}
