using HrAutomation.Application.Security;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Infrastructure.Security;

public sealed class EffectivePermissionService(HrAutomationDbContext db) : IEffectivePermissionService
{
    public async Task<IReadOnlySet<string>> GetEffectivePermissionsAsync(Guid tenantId, Guid userId, CancellationToken ct)
    {
        var keys = await (
            from userRole in db.UserRoles
            where userRole.TenantId == tenantId && userRole.UserId == userId && userRole.RevokedAtUtc == null
            join role in db.Roles on userRole.RoleId equals role.RoleId
            where role.IsActive
            join rolePermission in db.RolePermissions on role.RoleId equals rolePermission.RoleId
            join permission in db.Permissions on rolePermission.PermissionId equals permission.PermissionId
            where permission.IsActive
            select permission.PermissionKey
        ).Distinct().ToListAsync(ct);

        return keys.ToHashSet(StringComparer.Ordinal);
    }

    public async Task<bool> HasPermissionAsync(Guid tenantId, Guid userId, string permissionKey, CancellationToken ct)
    {
        var permissions = await GetEffectivePermissionsAsync(tenantId, userId, ct);
        return permissions.Contains(permissionKey);
    }
}
