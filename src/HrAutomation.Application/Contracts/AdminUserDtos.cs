namespace HrAutomation.Application.Contracts;

/// <summary>Row shape for GET /api/v1/admin/users. Deliberately excludes anything from
/// iam.UserAuthenticationProvider (no subject IDs) - see user_authentication_mapping permission
/// for that detail view.</summary>
public sealed class AdminUserListItemDto
{
    public required Guid UserId { get; init; }
    public required string Email { get; init; }
    public required string DisplayName { get; init; }
    public required string UserStatus { get; init; }
    public required bool IsSystemServiceAccount { get; init; }
    public DateTime? LastLoginAtUtc { get; init; }
    public required DateTime CreatedAtUtc { get; init; }
    public required string RowVersion { get; init; }
}

public sealed class AdminUserRoleDto
{
    public required Guid UserRoleId { get; init; }
    public required Guid RoleId { get; init; }
    public required string RoleName { get; init; }
    public required DateTime AssignedAtUtc { get; init; }
}

public sealed class AdminUserDetailDto
{
    public required Guid UserId { get; init; }
    public required Guid TenantId { get; init; }
    public required string Email { get; init; }
    public required string DisplayName { get; init; }
    public required string UserStatus { get; init; }
    public required bool IsSystemServiceAccount { get; init; }
    public string? FirstName { get; init; }
    public string? LastName { get; init; }
    public string? PhoneNumber { get; init; }
    public string? JobTitle { get; init; }
    public string? DepartmentName { get; init; }
    public string? LocationName { get; init; }
    public DateTime? LastLoginAtUtc { get; init; }
    public required DateTime CreatedAtUtc { get; init; }
    public required IReadOnlyList<AdminUserRoleDto> Roles { get; init; }
    public required string RowVersion { get; init; }
    /// <summary>What this actor is currently allowed to do to this specific user record, computed
    /// server-side (deny-by-default) - the UI must disable actions based on this list, not guess.</summary>
    public required IReadOnlyList<string> AllowedActions { get; init; }
}

/// <summary>Response for GET /api/v1/users/me/permissions - the real, database-backed
/// replacement for the frontend's former hardcoded ROLE_PERMISSIONS approximation.</summary>
public sealed class EffectivePermissionsDto
{
    public required IReadOnlyList<string> Permissions { get; init; }
}
