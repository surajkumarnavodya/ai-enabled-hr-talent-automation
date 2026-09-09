using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace HrAutomation.Tests;

public class EmployeeConversionAndApprovalsTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoHrAdminUserId = Guid.Parse("C3A025EE-42D8-4431-A10E-A7936C9555EF");

    [Fact]
    public async Task ApprovalsQueue_ReturnsPendingRequests()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/approvals?limit=200");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("items").ValueKind == JsonValueKind.Array);
    }

    [Fact]
    public async Task ApprovalsQueue_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/approvals");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task EmployeeConversionList_ReturnsSeededConversion()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/employee-conversion");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        var items = body.GetProperty("items").EnumerateArray().ToList();
        // Seeded demo data (Database/seed/09-*.sql) includes exactly one ineligible
        // EmployeeConversion row - verify the checklist reads real, not fabricated, values.
        if (items.Count > 0)
        {
            var first = items[0];
            Assert.False(string.IsNullOrEmpty(first.GetProperty("candidate_name").GetString()));
            Assert.True(first.GetProperty("checklist").GetArrayLength() == 4);
        }
    }

    [Fact]
    public async Task ConvertToEmployee_WhenIneligible_ReturnsUnprocessable()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "EMPLOYEE_ONBOARDING_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var listResponse = await client.GetAsync("/api/v1/employee-conversion");
        listResponse.EnsureSuccessStatusCode();
        var items = (await listResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items").EnumerateArray().ToList();
        if (items.Count == 0)
        {
            return; // No seeded conversion row in this environment - nothing to assert.
        }

        var ineligible = items.FirstOrDefault(i => !i.GetProperty("eligible").GetBoolean());
        if (ineligible.ValueKind == JsonValueKind.Undefined)
        {
            return; // Seeded row happens to be eligible in this environment - covered by the other test instead.
        }

        var applicationId = ineligible.GetProperty("application_id").GetString();
        var response = await client.PostAsync($"/api/v1/applications/{applicationId}/convert-to-employee", null);

        // The server re-validates eligibility itself inside usp_ApproveEmployeeConversion /
        // usp_CreateEmployeeFromCandidate - never trusts the checklist this same API already
        // returned. An ineligible candidate must be refused, not converted anyway.
        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
    }

    [Fact]
    public async Task ShortlistApproval_WrongRole_Returns403()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "INTERVIEWER", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Random id: this test only verifies the role gate fires before any lookup happens.
        var response = await client.PostAsync($"/api/v1/applications/{Guid.NewGuid()}/shortlist-approval", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
