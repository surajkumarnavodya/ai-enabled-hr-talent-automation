using HrAutomation.Domain.Enums;

namespace HrAutomation.Domain;

/// <summary>
/// Deterministic transition rules for both workflow types. This is the single source of truth
/// the Orchestrator Agent consults before invoking a skill - business logic and the LLM never
/// decide state movement directly (spec section 1/3.A).
/// </summary>
public static class WorkflowStateMachine
{
    private static readonly Dictionary<WorkflowState, WorkflowState[]> Transitions = new()
    {
        [WorkflowState.TanDraft] = [WorkflowState.TanApproved, WorkflowState.TanCancelled],
        [WorkflowState.TanApproved] = [WorkflowState.TanOnHold, WorkflowState.TanClosed, WorkflowState.MatchingInProgress],
        [WorkflowState.TanOnHold] = [WorkflowState.TanApproved, WorkflowState.TanCancelled],

        [WorkflowState.MatchingInProgress] = [WorkflowState.CandidatesRecommended],
        [WorkflowState.CandidatesRecommended] = [WorkflowState.ShortlistPendingApproval],
        [WorkflowState.ShortlistPendingApproval] = [WorkflowState.Shortlisted, WorkflowState.ApplicationClosed],
        [WorkflowState.Shortlisted] = [WorkflowState.L1Scheduled],

        [WorkflowState.L1Scheduled] = [WorkflowState.L1FeedbackCaptured],
        [WorkflowState.L1FeedbackCaptured] = [WorkflowState.L1Selected, WorkflowState.L1Rejected],
        [WorkflowState.L1Rejected] = [WorkflowState.ApplicationClosed],
        [WorkflowState.L1Selected] = [WorkflowState.L2Scheduled],

        [WorkflowState.L2Scheduled] = [WorkflowState.L2FeedbackCaptured],
        [WorkflowState.L2FeedbackCaptured] = [WorkflowState.L2Selected, WorkflowState.L2Rejected],
        [WorkflowState.L2Rejected] = [WorkflowState.ApplicationClosed],
        [WorkflowState.L2Selected] = [WorkflowState.ClientInterviewScheduled, WorkflowState.FinalSelectionPendingApproval],

        [WorkflowState.ClientInterviewScheduled] = [WorkflowState.ClientFeedbackCaptured],
        [WorkflowState.ClientFeedbackCaptured] = [WorkflowState.ClientSelected, WorkflowState.ClientRejected],
        [WorkflowState.ClientRejected] = [WorkflowState.ApplicationClosed],
        [WorkflowState.ClientSelected] = [WorkflowState.FinalSelectionPendingApproval],

        [WorkflowState.FinalSelectionPendingApproval] = [WorkflowState.FinalSelectionApproved, WorkflowState.ApplicationClosed],
        [WorkflowState.FinalSelectionApproved] = [WorkflowState.OfferInputsCollected],

        [WorkflowState.OfferInputsCollected] = [WorkflowState.OfferDrafted],
        [WorkflowState.OfferDrafted] = [WorkflowState.OfferPendingApproval],
        [WorkflowState.OfferPendingApproval] = [WorkflowState.OfferApproved, WorkflowState.ApplicationClosed],
        [WorkflowState.OfferApproved] = [WorkflowState.OfferSent],
        [WorkflowState.OfferSent] = [WorkflowState.OfferAccepted, WorkflowState.OfferDeclined, WorkflowState.OfferWithdrawn],
        [WorkflowState.OfferAccepted] = [WorkflowState.GreenFormIssued],
        [WorkflowState.OfferDeclined] = [WorkflowState.ApplicationClosed],
        [WorkflowState.OfferWithdrawn] = [WorkflowState.ApplicationClosed],

        [WorkflowState.GreenFormIssued] = [WorkflowState.GreenFormSubmitted],
        [WorkflowState.GreenFormSubmitted] = [WorkflowState.DocumentVerificationInProgress],

        [WorkflowState.DocumentVerificationInProgress] = [WorkflowState.DiscrepancyRaised, WorkflowState.EmployeeConversionPendingApproval],
        [WorkflowState.DiscrepancyRaised] = [WorkflowState.DiscrepancyResolutionPendingApproval],
        [WorkflowState.DiscrepancyResolutionPendingApproval] = [WorkflowState.DiscrepancyResolved, WorkflowState.ApplicationClosed],
        [WorkflowState.DiscrepancyResolved] = [WorkflowState.DocumentVerificationInProgress, WorkflowState.EmployeeConversionPendingApproval],

        [WorkflowState.EmployeeConversionPendingApproval] = [WorkflowState.EmployeeCreated, WorkflowState.ApplicationClosed],
        [WorkflowState.EmployeeCreated] = [],
        [WorkflowState.ApplicationClosed] = [],
        [WorkflowState.TanClosed] = [],
        [WorkflowState.TanCancelled] = []
    };

    public static bool CanTransition(WorkflowState from, WorkflowState to)
        => Transitions.TryGetValue(from, out var allowed) && allowed.Contains(to);

    public static IReadOnlyList<WorkflowState> AllowedNextStates(WorkflowState from)
        => Transitions.TryGetValue(from, out var allowed) ? allowed : [];
}
