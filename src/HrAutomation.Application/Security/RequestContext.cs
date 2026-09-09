namespace HrAutomation.Application.Security;

/// <summary>
/// The minimum authenticated identity every request must carry (spec section 4: "Identity and
/// access"). Built once by API middleware from validated JWT claims and threaded explicitly
/// through controllers -> orchestrator -> skills. Never reconstructed from user-supplied input.
/// Role is the iam.Role.RoleName code from HrAutomationDb (e.g. "RECRUITER", "HR_ADMIN") -
/// config-driven per the platform's non-negotiable "never hardcode roles" rule, not a fixed
/// C# enum.
/// </summary>
public sealed record RequestContext(
    Guid TenantId,
    Guid UserId,
    string Role,
    string? DepartmentScope,
    string PurposeOfUse,
    string CorrelationId,
    string TraceId);
