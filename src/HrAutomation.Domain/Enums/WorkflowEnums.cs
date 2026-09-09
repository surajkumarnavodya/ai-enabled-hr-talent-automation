namespace HrAutomation.Domain.Enums;

/// <summary>Distinguishes the TAN approval workflow from the per-candidate application workflow -
/// both run through the same generic WorkflowInstance/WorkflowStateTransition engine.</summary>
public enum WorkflowType
{
    Tan,
    CandidateApplication
}

/// <summary>
/// Unified state space for both workflow types (spec section 1, steps 3-22). Not every state
/// applies to every WorkflowType; WorkflowStateMachine.CanTransition enforces the valid edges.
/// </summary>
public enum WorkflowState
{
    TanDraft,
    TanApproved,
    TanOnHold,
    TanClosed,
    TanCancelled,

    MatchingInProgress,
    CandidatesRecommended,
    ShortlistPendingApproval,
    Shortlisted,

    L1Scheduled,
    L1FeedbackCaptured,
    L1Rejected,
    L1Selected,

    L2Scheduled,
    L2FeedbackCaptured,
    L2Rejected,
    L2Selected,

    ClientInterviewScheduled,
    ClientFeedbackCaptured,
    ClientRejected,
    ClientSelected,

    FinalSelectionPendingApproval,
    FinalSelectionApproved,

    OfferInputsCollected,
    OfferDrafted,
    OfferPendingApproval,
    OfferApproved,
    OfferSent,
    OfferAccepted,
    OfferDeclined,
    OfferWithdrawn,

    GreenFormIssued,
    GreenFormSubmitted,

    DocumentVerificationInProgress,
    DiscrepancyRaised,
    DiscrepancyResolutionPendingApproval,
    DiscrepancyResolved,

    EmployeeConversionPendingApproval,
    EmployeeCreated,

    ApplicationClosed
}

/// <summary>
/// Exact wire-format values required by the response contract (spec section 12):
/// "completed | pending_approval | blocked | failed | needs_human_review".
/// Members are intentionally lower_snake_case so JsonStringEnumConverter serializes them verbatim.
/// </summary>
public enum ActionStatus
{
    completed,
    pending_approval,
    blocked,
    failed,
    needs_human_review
}

/// <summary>Exact wire-format values for guardrail_results.* fields: "pass | fail".</summary>
public enum GuardrailResult
{
    pass,
    fail
}
