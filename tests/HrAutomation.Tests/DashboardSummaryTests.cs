using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace HrAutomation.Tests;

public class DashboardSummaryTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoHrAdminUserId = Guid.Parse("C3A025EE-42D8-4431-A10E-A7936C9555EF");

    [Fact]
    public async Task GetSummary_ReturnsRealNonNegativeCounts()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/dashboard/summary");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        // Seeded demo data guarantees at least one active TAN (Database/seed/09-*.sql) - a real
        // live count, not a static placeholder.
        Assert.True(body.GetProperty("active_tans").GetInt32() > 0);
        Assert.True(body.GetProperty("candidates_awaiting_review").GetInt32() >= 0);
        Assert.True(body.GetProperty("pending_approvals").GetInt32() >= 0);
        Assert.Equal(0, body.GetProperty("sla_breaches").GetInt32());
    }

    [Fact]
    public async Task GetSummary_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/dashboard/summary");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
