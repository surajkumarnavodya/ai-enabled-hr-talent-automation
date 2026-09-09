namespace HrAutomation.Domain.Enums;

/// <summary>Fixed application role catalog used for RBAC/ABAC policy checks (spec section 4).</summary>
public enum RoleName
{
    HRRecruiter,
    HiringManager,
    HRAdmin,
    Interviewer,
    DocumentVerifier,
    CandidatePortal,
    SystemService
}
