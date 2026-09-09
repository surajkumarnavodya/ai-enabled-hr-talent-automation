namespace HrAutomation.Infrastructure.Persistence.Entities;

public class RecruitmentCandidate
{
    public Guid CandidateId { get; set; }
    public Guid TenantId { get; set; }
    public string FirstName { get; set; } = null!;
    public string? MiddleName { get; set; }
    public string LastName { get; set; } = null!;
    public Guid CandidateStatusId { get; set; }
    public Guid? PrimaryCandidateSourceId { get; set; }
    public string? HeadlineSummary { get; set; }
    public decimal? TotalExperienceYears { get; set; }
    public Guid? CurrentLocationId { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public Guid? UpdatedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class RecruitmentCandidateContact
{
    public Guid CandidateContactId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateId { get; set; }
    public string ContactType { get; set; } = null!; // Email, Phone, LinkedIn, Other
    public string ContactValue { get; set; } = null!;
    public string? NormalizedValue { get; set; }
    public bool IsPrimary { get; set; }
    public bool IsVerified { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentCandidateCv
{
    public Guid CandidateCvId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateId { get; set; }
    public bool IsPrimary { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentCandidateCvVersion
{
    public Guid CandidateCvVersionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateCvId { get; set; }
    public int VersionNumber { get; set; }
    public string ObjectStorageUri { get; set; } = null!;
    public string FileName { get; set; } = null!;
    public string MimeType { get; set; } = null!;
    public long FileSizeBytes { get; set; }
    public byte[] ContentHash { get; set; } = null!;
    public string MalwareScanStatus { get; set; } = null!; // Pending, Clean, Infected, Failed
    public Guid? UploadedByUserId { get; set; }
    public DateTime UploadedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentCvParsingResult
{
    public Guid CvParsingResultId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateCvVersionId { get; set; }
    public string ParseStatus { get; set; } = null!; // Pending, Succeeded, Failed, LowConfidence
    public decimal? ConfidenceScore { get; set; }
    public string? RawOutputObjectStorageUri { get; set; }
    public bool RequiresHumanReview { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentCvExtractionField
{
    public Guid CvExtractionFieldId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CvParsingResultId { get; set; }
    public string FieldName { get; set; } = null!;
    public string? FieldValue { get; set; }
    public decimal? ConfidenceScore { get; set; }
    public bool IsAcceptedByHuman { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentTalentAcquisitionNumber
{
    public Guid TalentAcquisitionNumberId { get; set; }
    public Guid TenantId { get; set; }
    public string TanNumber { get; set; } = null!;
    public Guid? DepartmentId { get; set; }
    public Guid? BusinessUnitId { get; set; }
    public Guid? RequestedByUserId { get; set; }
    public DateTime IssuedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentJobRequisition
{
    public Guid JobRequisitionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid TalentAcquisitionNumberId { get; set; }
    public string Title { get; set; } = null!;
    public int HeadcountRequested { get; set; }
    public string RequisitionStatusCode { get; set; } = null!;
    // Draft, PendingApproval, Approved, ActiveSourcing, OnHold, ClosedFilled, Cancelled
    public string Priority { get; set; } = null!;
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public byte[] RowVersion { get; set; } = null!;
    public bool IsDeleted { get; set; }
}

public class RecruitmentJobDescription
{
    public Guid JobDescriptionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid JobRequisitionId { get; set; }
    public Guid? CurrentVersionId { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentJobDescriptionVersion
{
    public Guid JobDescriptionVersionId { get; set; }
    public Guid TenantId { get; set; }
    public Guid JobDescriptionId { get; set; }
    public int VersionNumber { get; set; }
    public string? Summary { get; set; }
    public string? ResponsibilitiesText { get; set; }
    public string ApprovalStatus { get; set; } = null!; // Draft, PendingApproval, Approved, Retired
    public bool IsDeleted { get; set; }
}

public class RecruitmentCandidateApplication
{
    public Guid CandidateApplicationId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateId { get; set; }
    public Guid JobRequisitionId { get; set; }
    public string ApplicationStatusCode { get; set; } = null!;
    public DateTime AppliedAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public byte[] RowVersion { get; set; } = null!;
    public bool IsDeleted { get; set; }
}

public class RecruitmentInterview
{
    public Guid InterviewId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateApplicationId { get; set; }
    public string Status { get; set; } = null!; // Scheduled, Completed, Cancelled, NoShow
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentInterviewRound
{
    public Guid InterviewRoundId { get; set; }
    public Guid TenantId { get; set; }
    public Guid InterviewId { get; set; }
    public Guid InterviewRoundDefinitionId { get; set; }
    public int SequenceNumber { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentInterviewPanelMember
{
    public Guid InterviewPanelMemberId { get; set; }
    public Guid TenantId { get; set; }
    public Guid InterviewRoundId { get; set; }
    public Guid UserId { get; set; }
    public bool IsLeadInterviewer { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentInterviewScheduleSlot
{
    public Guid InterviewScheduleSlotId { get; set; }
    public Guid TenantId { get; set; }
    public Guid InterviewRoundId { get; set; }
    public DateTime ScheduledStartUtc { get; set; }
    public DateTime ScheduledEndUtc { get; set; }
    public string? TimeZoneId { get; set; }
    public string? LocationOrLink { get; set; }
    public bool IsCurrent { get; set; }
}

public class RecruitmentInterviewFeedback
{
    public Guid InterviewFeedbackId { get; set; }
    public Guid TenantId { get; set; }
    public Guid InterviewRoundId { get; set; }
    public Guid SubmittedByUserId { get; set; }
    public int VersionNumber { get; set; }
    public string? OverallRecommendation { get; set; }
    public DateTime SubmittedAtUtc { get; set; }
    public bool IsFinal { get; set; }
    public bool IsDeleted { get; set; }
}

public class RecruitmentInterviewOutcome
{
    public Guid InterviewOutcomeId { get; set; }
    public Guid TenantId { get; set; }
    public Guid InterviewRoundId { get; set; }
    public string OutcomeStatus { get; set; } = null!; // Progressed, Rejected, OnHold
    public Guid DecidedByUserId { get; set; }
    public DateTime DecidedAtUtc { get; set; }
}
