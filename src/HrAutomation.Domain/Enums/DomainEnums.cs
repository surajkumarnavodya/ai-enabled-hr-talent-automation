namespace HrAutomation.Domain.Enums;

public enum InterviewStage { L1, L2, Client }

public enum InterviewStatus { Scheduled, Rescheduled, Completed, Cancelled, NoShow }

public enum InterviewOutcome { Selected, Rejected, OnHold }

public enum OfferStatus { Draft, PendingApproval, Approved, Sent, Accepted, Declined, Withdrawn, Expired }

public enum GreenFormStatus { Issued, InProgress, Completed, Expired }

public enum DocumentVerificationStatus { Pending, Verified, Discrepant, ReuploadRequested }

public enum DiscrepancySeverity { Low, Medium, High, Critical }

public enum DiscrepancyStatus { Open, PendingHrApproval, Resolved, ExceptionApproved }

public enum ApprovalDecision { Approved, Rejected, ReturnedForInfo }

/// <summary>Mirrors spec section 2's mandatory human approval gates.</summary>
public enum ApprovalTaskType
{
    TanApproval,
    ShortlistApproval,
    L1OutcomeConfirmation,
    L2OutcomeConfirmation,
    ClientOutcomeConfirmation,
    RejectionConfirmation,
    OfferContentApproval,
    OfferWithdrawalApproval,
    DiscrepancyClosureApproval,
    PolicyExceptionApproval,
    EmployeeConversionApproval
}

public enum ApprovalTaskStatus { Pending, Approved, Rejected, Expired }

public enum NotificationChannel { Email, Sms, InApp }

public enum NotificationStatus { Queued, Sent, Failed }

public enum EmployeeStatus { Active, Inactive }

public enum IntegrationOutboxStatus { Pending, Sent, Failed, DeadLettered }

public enum SecurityEventSeverity { Info, Warning, Critical }

public enum ConsentType { DataProcessing, BackgroundVerification, Communication }

public enum DocumentClassification { Public, Internal, Confidential, Restricted }

public enum CandidateCvSource { Upload, Referral, AgencyPortal, CareerSite }

/// <summary>Separates mandatory-skill gaps from preferred-skill gaps per the Candidate Matching Agent spec.</summary>
public enum MatchGapType { Mandatory, Preferred }

public enum ActorType { human, agent, system }
