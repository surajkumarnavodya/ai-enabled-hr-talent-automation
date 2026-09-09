namespace HrAutomation.Application.Security;

/// <summary>
/// Resolves the real, database-backed permission grant for a user: iam.UserRole (active) -&gt;
/// iam.Role (active) -&gt; iam.RolePermission -&gt; iam.Permission (active). This is the single
/// source of truth for "can this user do X" across the Administration module and any other
/// endpoint that needs finer-grained authorization than a role-string check - deny-by-default,
/// nothing is granted unless an explicit row chain exists.
/// </summary>
public interface IEffectivePermissionService
{
    Task<IReadOnlySet<string>> GetEffectivePermissionsAsync(Guid tenantId, Guid userId, CancellationToken ct);

    Task<bool> HasPermissionAsync(Guid tenantId, Guid userId, string permissionKey, CancellationToken ct);
}
