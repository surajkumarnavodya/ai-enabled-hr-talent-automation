using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace HrAutomation.Tests;

public class TanListAndUserProfileTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");

    [Fact]
    public async Task Health_ReturnsHealthyWithoutAuth()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Healthy", body.GetProperty("status").GetString());
        Assert.Contains(body.GetProperty("checks").EnumerateArray(), c => c.GetProperty("name").GetString() == "database");
    }

    [Fact]
    public async Task GetCurrentUser_ReturnsProfileFromValidatedToken()
    {
        var client = factory.CreateClient();
        var (token, tenantId) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/users/me");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(DemoRecruiterUserId.ToString(), body.GetProperty("user_id").GetString(), ignoreCase: true);
        Assert.Equal(tenantId.ToString(), body.GetProperty("tenant_id").GetString(), ignoreCase: true);
        Assert.Equal("RECRUITER", body.GetProperty("role").GetString());
        Assert.False(string.IsNullOrEmpty(body.GetProperty("display_name").GetString()));
    }

    [Fact]
    public async Task GetCurrentUser_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/users/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ListTans_ReturnsCreatedTanInCursorPage()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var createResponse = await client.PostAsJsonAsync("/api/v1/tans", new
        {
            title = "List Endpoint Test Engineer",
            location = "Remote",
            grade = "L4",
            budget_min = 50000,
            budget_max = 90000,
            interview_stages_count = 2,
            client_interview_required = false,
            mandatory_criteria_json = "[]",
            preferred_criteria_json = "[]",
            raw_description = "Created to verify GET /api/v1/tans lists real persisted rows."
        });
        createResponse.EnsureSuccessStatusCode();
        var createBody = await createResponse.Content.ReadFromJsonAsync<JsonElement>();
        var tanId = createBody.GetProperty("tan_id").GetString();

        var listResponse = await client.GetAsync("/api/v1/tans?limit=100");

        listResponse.EnsureSuccessStatusCode();
        var listBody = await listResponse.Content.ReadFromJsonAsync<JsonElement>();
        var items = listBody.GetProperty("items").EnumerateArray().ToList();
        Assert.Contains(items, item => item.GetProperty("tan_id").GetString() == tanId);
    }

    [Fact]
    public async Task ListTans_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/tans");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
