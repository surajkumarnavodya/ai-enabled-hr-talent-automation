using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace HrAutomation.Tests;

/// <summary>
/// Covers the first real vertical slice of the Administration/Master-Management module:
/// GET /api/v1/users/me/permissions (database-backed effective permissions, replacing the
/// frontend's former hardcoded ROLE_PERMISSIONS approximation) and GET /api/v1/admin/users
/// (list/detail), which is the first endpoint gated by IEffectivePermissionService rather than a
/// role-string list. Uses the same seeded demo tenant/user pattern as TanApprovalFlowTests.
/// </summary>
public class AdminUsersAndPermissionsTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");
    private static readonly Guid DemoHrAdminUserId = Guid.Parse("C3A025EE-42D8-4431-A10E-A7936C9555EF");

    [Fact]
    public async Task GetEffectivePermissions_ForHrAdmin_IncludesUserRead()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/users/me/permissions");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        var permissions = body.GetProperty("permissions").EnumerateArray().Select(p => p.GetString()).ToList();
        Assert.Contains("user.read", permissions);
    }

    [Fact]
    public async Task GetEffectivePermissions_ForRecruiter_DoesNotIncludeUserRead()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/users/me/permissions");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        var permissions = body.GetProperty("permissions").EnumerateArray().Select(p => p.GetString()).ToList();
        Assert.DoesNotContain("user.read", permissions);
        // A real permission the seed does grant RECRUITER, so this proves the query isn't just
        // returning an empty set for every role.
        Assert.Contains("tan.read", permissions);
    }

    [Fact]
    public async Task GetEffectivePermissions_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/users/me/permissions");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ListUsers_AsHrAdmin_ReturnsSeededDemoUsers()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/admin/users?limit=100");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        var items = body.GetProperty("items").EnumerateArray().ToList();
        Assert.Contains(items, item => item.GetProperty("user_id").GetString()!.Equals(DemoHrAdminUserId.ToString(), StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task ListUsers_AsRecruiter_WithoutUserReadPermission_Returns403AndAudits()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/admin/users");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        // Denied attempts must be audited too (.claude/rules/security.md), not just successful
        // sensitive actions - confirm via the existing real audit-log read endpoint.
        var adminToken = (await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId)).AccessToken;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);
        var auditResponse = await client.GetAsync("/api/v1/audit-logs?limit=50");
        auditResponse.EnsureSuccessStatusCode();
        var auditBody = await auditResponse.Content.ReadFromJsonAsync<JsonElement>();
        var auditItems = auditBody.GetProperty("items").EnumerateArray().ToList();
        Assert.Contains(auditItems, item =>
            item.TryGetProperty("event_type", out var eventType) && eventType.GetString() == "authorization.denied");
    }

    [Fact]
    public async Task GetUserDetail_AsHrAdmin_ReturnsRolesAndAllowedActions()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/v1/admin/users/{DemoRecruiterUserId}");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(DemoRecruiterUserId.ToString(), body.GetProperty("user_id").GetString(), ignoreCase: true);
        var roles = body.GetProperty("roles").EnumerateArray().ToList();
        Assert.Contains(roles, r => r.GetProperty("role_name").GetString() == "RECRUITER");
        Assert.False(string.IsNullOrEmpty(body.GetProperty("row_version").GetString()));
        var allowedActions = body.GetProperty("allowed_actions").EnumerateArray().Select(a => a.GetString()).ToList();
        // HR_ADMIN's seeded grant is user.read only (see Database/seed/02-seed-iam-roles-permissions.sql)
        // - update/deactivate/assign_role/revoke_role require user.update/user.deactivate/role.manage,
        // none of which HR_ADMIN holds. Only PLATFORM_ADMIN/TENANT_ADMIN get those.
        Assert.DoesNotContain("update", allowedActions);
        Assert.DoesNotContain("deactivate", allowedActions);
        Assert.DoesNotContain("assign_role", allowedActions);
    }

    [Fact]
    public async Task ListUsers_TenantIsolation_DoesNotReturnOrExposeOtherTenantUsers()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<HrAutomationDbContext>();

        var uniqueSuffix = Guid.NewGuid().ToString("N");
        var otherTenantCode = $"TEST-ISO-{uniqueSuffix}"[..24];
        var otherEmail = $"isolation.{uniqueSuffix}@example.test";
        var otherSubjectId = $"isolation-test-subject-{uniqueSuffix}";
        var otherTenantId = Guid.Empty;
        try
        {
            Guid otherUserId;
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"EXEC iam.usp_CreateTenant @TenantCode={otherTenantCode}, @TenantName={"Isolation Test Tenant"}");
            otherTenantId = await db.Database.SqlQuery<Guid>(
                $"SELECT TenantId AS Value FROM org.Tenant WHERE TenantCode = {otherTenantCode}").FirstAsync();

            await db.Database.ExecuteSqlInterpolatedAsync(
                $"""
                 EXEC iam.usp_CreateUser @TenantId={otherTenantId}, @Email={otherEmail},
                     @DisplayName={"Isolation Test User"}, @ProviderName={"DEMO_OIDC"},
                     @ProviderSubjectId={otherSubjectId}
                 """);
            otherUserId = await db.Database.SqlQuery<Guid>(
                $"SELECT UserId AS Value FROM iam.[User] WHERE TenantId = {otherTenantId} AND Email = {otherEmail}").FirstAsync();

            var client = factory.CreateClient();
            var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

            var listResponse = await client.GetAsync("/api/v1/admin/users?limit=200");
            listResponse.EnsureSuccessStatusCode();
            var listBody = await listResponse.Content.ReadFromJsonAsync<JsonElement>();
            var items = listBody.GetProperty("items").EnumerateArray().ToList();
            Assert.DoesNotContain(items, item =>
                item.GetProperty("user_id").GetString()!.Equals(otherUserId.ToString(), StringComparison.OrdinalIgnoreCase));

            // Not merely absent from the list - a direct, ID-guessed lookup must also 404, not
            // leak the other tenant's record.
            var detailResponse = await client.GetAsync($"/api/v1/admin/users/{otherUserId}");
            Assert.Equal(HttpStatusCode.NotFound, detailResponse.StatusCode);
        }
        finally
        {
            if (otherTenantId != Guid.Empty)
            {
                await db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM iam.UserAuthenticationProvider WHERE TenantId = {otherTenantId}");
                await db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM iam.[User] WHERE TenantId = {otherTenantId}");
                await db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM org.Tenant WHERE TenantId = {otherTenantId}");
            }
        }
    }

    [Fact]
    public async Task GetUserDetail_ForNonexistentUser_Returns404()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/v1/admin/users/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
