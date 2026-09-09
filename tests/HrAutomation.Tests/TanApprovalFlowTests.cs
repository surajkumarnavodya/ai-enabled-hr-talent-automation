using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace HrAutomation.Tests;

public class TanApprovalFlowTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    // The seeded demo tenant/users (Database/seed/01-seed-tenant-organization.sql,
    // 03-seed-iam-users-access.sql) - freshly-minted random ids would fail HrAutomationDb's
    // org.Tenant/iam.User foreign-key constraints, unlike the old in-memory-database test
    // provider which didn't enforce them.
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");
    private static readonly Guid DemoHrAdminUserId = Guid.Parse("C3A025EE-42D8-4431-A10E-A7936C9555EF");

    [Fact]
    public async Task CreateThenApproveTan_TransitionsToApproved()
    {
        var client = factory.CreateClient();

        var (recruiterToken, tenantId) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", recruiterToken);

        var createResponse = await client.PostAsJsonAsync("/api/v1/tans", new
        {
            title = "Senior Backend Engineer",
            location = "Remote",
            grade = "L5",
            budget_min = 80000,
            budget_max = 120000,
            interview_stages_count = 2,
            client_interview_required = false,
            mandatory_criteria_json = "[]",
            preferred_criteria_json = "[]",
            raw_description = "Looking for a senior backend engineer with strong C#/.NET experience."
        });

        createResponse.EnsureSuccessStatusCode();
        var createBody = await createResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("completed", createBody.GetProperty("action_status").GetString());
        var tanId = createBody.GetProperty("tan_id").GetString();
        Assert.False(string.IsNullOrEmpty(tanId));

        // Approve with an HR_ADMIN token for the SAME tenant as the recruiter who created the TAN.
        var (adminToken, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", tenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);

        var approveResponse = await client.PostAsJsonAsync($"/api/v1/tans/{tanId}/approve", new
        {
            decision = "Approved",
            comments = "Looks good",
            source_version = 1
        });

        approveResponse.EnsureSuccessStatusCode();
        var approveBody = await approveResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(approveBody.GetProperty("action_status").GetString() == "completed", approveBody.ToString());
        Assert.Equal("Approved", approveBody.GetProperty("current_state").GetString());
    }

    [Fact]
    public async Task ApproveTan_WrongRole_Returns403()
    {
        var client = factory.CreateClient();

        var (recruiterToken, tenantId) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", recruiterToken);

        var createResponse = await client.PostAsJsonAsync("/api/v1/tans", new
        {
            title = "QA Engineer",
            location = "Remote",
            grade = "L3",
            budget_min = 40000,
            budget_max = 60000,
            interview_stages_count = 2,
            client_interview_required = false,
            mandatory_criteria_json = "[]",
            preferred_criteria_json = "[]",
            raw_description = "QA engineer role."
        });
        createResponse.EnsureSuccessStatusCode();
        var createBody = await createResponse.Content.ReadFromJsonAsync<JsonElement>();
        var tanId = createBody.GetProperty("tan_id").GetString();

        // A recruiter (not HRAdmin/HiringManager) is not permitted to approve a TAN.
        var approveResponse = await client.PostAsJsonAsync($"/api/v1/tans/{tanId}/approve", new
        {
            decision = "Approved",
            comments = "Trying to self-approve",
            source_version = 1
        });

        Assert.Equal(System.Net.HttpStatusCode.Forbidden, approveResponse.StatusCode);
    }
}
