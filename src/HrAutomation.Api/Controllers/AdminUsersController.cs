using System.Globalization;
using System.Text;
using HrAutomation.Application.Audit;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Security;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

/// <summary>
/// Real, SQL-Server-backed user administration (docs/09-quality-evaluation/master-management-gap-analysis.md
/// area #3/#4). Every action here is gated by IEffectivePermissionService against the real
/// iam.Permission catalog - not a role-string list - because this module manages the very
/// roles/permissions that role-string checks would otherwise hardcode. Permission keys used here
/// (user.read/create/update/deactivate) are the actual seeded iam.Permission.PermissionKey values
/// (see Database/seed/02-seed-iam-roles-permissions.sql), not the illustrative codes from any
/// external spec - adapted per that spec's own "adapt if actual permission codes differ" instruction.
/// </summary>
[Route("api/v1/admin/users")]
public sealed class AdminUsersController(
    HrAutomationDbContext db,
    IEffectivePermissionService permissions,
    IAuditLogger auditLogger) : HrControllerBase
{
    [HttpGet]
    public async Task<IActionResult> ListUsers(
        [FromQuery] string? search, [FromQuery] string? status,
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "user.read", ct);
        if (denied is not null) return denied;

        limit = Math.Clamp(limit, 1, 100);

        var query = db.Users.Where(u => u.TenantId == ctx.TenantId).AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(u => EF.Functions.Like(u.Email, $"%{term}%") || EF.Functions.Like(u.DisplayName, $"%{term}%"));
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            query = query.Where(u => u.UserStatus == status);
        }

        query = query.OrderByDescending(u => u.CreatedAtUtc).ThenByDescending(u => u.UserId);

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterCreatedAt, out var afterId))
        {
            query = query.Where(u =>
                u.CreatedAtUtc < afterCreatedAt ||
                (u.CreatedAtUtc == afterCreatedAt && u.UserId.CompareTo(afterId) < 0));
        }

        var items = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = items.Count > limit;
        var pageItems = items.Take(limit).ToList();

        var page = pageItems.Select(ToListItemDto).ToList();
        var nextCursor = hasMore ? EncodeCursor(pageItems[^1].CreatedAtUtc, pageItems[^1].UserId) : null;

        return Ok(new CursorPage<AdminUserListItemDto> { Items = page, NextCursor = nextCursor });
    }

    [HttpGet("{userId:guid}")]
    public async Task<IActionResult> GetUser(Guid userId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "user.read", ct);
        if (denied is not null) return denied;

        var user = await db.Users.FirstOrDefaultAsync(u => u.UserId == userId && u.TenantId == ctx.TenantId, ct);
        if (user is null)
        {
            return NotFound();
        }

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId && p.TenantId == ctx.TenantId, ct);

        string? departmentName = null;
        if (profile?.DepartmentId is { } departmentId)
        {
            departmentName = await db.Departments
                .Where(d => d.DepartmentId == departmentId)
                .Select(d => d.DepartmentName)
                .FirstOrDefaultAsync(ct);
        }

        string? locationName = null;
        if (profile?.LocationId is { } locationId)
        {
            locationName = await db.Locations
                .Where(l => l.LocationId == locationId)
                .Select(l => l.LocationName)
                .FirstOrDefaultAsync(ct);
        }

        var roles = await (
            from userRole in db.UserRoles
            where userRole.UserId == userId && userRole.TenantId == ctx.TenantId && userRole.RevokedAtUtc == null
            join role in db.Roles on userRole.RoleId equals role.RoleId
            select new AdminUserRoleDto
            {
                UserRoleId = userRole.UserRoleId,
                RoleId = role.RoleId,
                RoleName = role.RoleName,
                AssignedAtUtc = userRole.AssignedAtUtc
            }).ToListAsync(ct);

        var actorPermissions = await permissions.GetEffectivePermissionsAsync(ctx.TenantId, ctx.UserId, ct);
        var allowedActions = new List<string>();
        if (actorPermissions.Contains("user.update")) allowedActions.Add("update");
        if (actorPermissions.Contains("user.update")) allowedActions.Add("activate");
        if (actorPermissions.Contains("user.deactivate")) allowedActions.Add("deactivate");
        if (actorPermissions.Contains("role.manage")) allowedActions.Add("assign_role");
        if (actorPermissions.Contains("role.manage")) allowedActions.Add("revoke_role");

        return Ok(new AdminUserDetailDto
        {
            UserId = user.UserId,
            TenantId = user.TenantId,
            Email = user.Email,
            DisplayName = user.DisplayName,
            UserStatus = user.UserStatus,
            IsSystemServiceAccount = user.IsSystemServiceAccount,
            FirstName = profile?.FirstName,
            LastName = profile?.LastName,
            PhoneNumber = profile?.PhoneNumber,
            JobTitle = profile?.JobTitle,
            DepartmentName = departmentName,
            LocationName = locationName,
            LastLoginAtUtc = user.LastLoginAtUtc,
            CreatedAtUtc = user.CreatedAtUtc,
            Roles = roles,
            RowVersion = Convert.ToBase64String(user.RowVersion),
            AllowedActions = allowedActions
        });
    }

    private static AdminUserListItemDto ToListItemDto(IamUser u) => new()
    {
        UserId = u.UserId,
        Email = u.Email,
        DisplayName = u.DisplayName,
        UserStatus = u.UserStatus,
        IsSystemServiceAccount = u.IsSystemServiceAccount,
        LastLoginAtUtc = u.LastLoginAtUtc,
        CreatedAtUtc = u.CreatedAtUtc,
        RowVersion = Convert.ToBase64String(u.RowVersion)
    };

    private static string EncodeCursor(DateTime createdAtUtc, Guid id) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{createdAtUtc:O}|{id}"));

    private static bool TryDecodeCursor(string cursor, out DateTime createdAtUtc, out Guid id)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|');
            createdAtUtc = DateTime.Parse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
            id = Guid.Parse(parts[1]);
            return true;
        }
        catch (FormatException)
        {
            createdAtUtc = default;
            id = default;
            return false;
        }
    }
}
