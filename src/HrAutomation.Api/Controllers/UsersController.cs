using HrAutomation.Application.Contracts;
using HrAutomation.Application.Security;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

/// <summary>Backs the frontend's "current user" auth-context call. Identity, tenant, and role
/// always come from the validated JWT (via BuildRequestContext -> RequestContextFactory), never
/// from a client-supplied value - this endpoint only enriches with a display name.</summary>
[Route("api/v1/users")]
public sealed class UsersController(HrAutomationDbContext db, IEffectivePermissionService permissions) : HrControllerBase
{
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser(CancellationToken ct)
    {
        var ctx = BuildRequestContext();

        var displayName = await db.Users
            .Where(u => u.UserId == ctx.UserId && u.TenantId == ctx.TenantId)
            .Select(u => u.DisplayName)
            .FirstOrDefaultAsync(ct);

        return Ok(new UserProfileDto
        {
            UserId = ctx.UserId,
            TenantId = ctx.TenantId,
            DisplayName = displayName ?? ctx.Role,
            Role = ctx.Role,
            DepartmentScope = ctx.DepartmentScope
        });
    }

    /// <summary>Real, database-backed effective permissions for the calling user - iam.UserRole
    /// (active) -&gt; iam.Role (active) -&gt; iam.RolePermission -&gt; iam.Permission (active). The
    /// frontend uses this to replace its former hardcoded ROLE_PERMISSIONS approximation; it is
    /// still UX-only (every mutating endpoint independently re-checks server-side).</summary>
    [HttpGet("me/permissions")]
    public async Task<IActionResult> GetCurrentUserPermissions(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var effective = await permissions.GetEffectivePermissionsAsync(ctx.TenantId, ctx.UserId, ct);
        return Ok(new EffectivePermissionsDto { Permissions = effective.OrderBy(p => p, StringComparer.Ordinal).ToList() });
    }
}
