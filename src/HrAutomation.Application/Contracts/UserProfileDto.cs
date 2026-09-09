namespace HrAutomation.Application.Contracts;

/// <summary>The authenticated caller's identity/session context, as derived from their validated
/// token - never as supplied by the client. Backs `GET /api/v1/users/me`.</summary>
public sealed class UserProfileDto
{
    public required Guid UserId { get; init; }
    public required Guid TenantId { get; init; }
    public required string DisplayName { get; init; }
    public required string Role { get; init; }
    public string? DepartmentScope { get; init; }
}
