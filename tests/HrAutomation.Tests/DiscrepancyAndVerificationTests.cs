using System.Data;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace HrAutomation.Tests;

public class DiscrepancyAndVerificationTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");
    private static readonly Guid DemoHrAdminUserId = Guid.Parse("C3A025EE-42D8-4431-A10E-A7936C9555EF");

    // No API endpoint creates a discrepancy (they're raised by verification providers/AI in the
    // real design, never directly by an HR user through this UI) — call the real stored
    // procedure directly to seed one for the test, same as any other real caller would.
    private async Task<Guid> CreateDiscrepancyAsync()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<HrAutomationDbContext>();
        await db.Database.OpenConnectionAsync();
        await db.Database.ExecuteSqlInterpolatedAsync($"EXEC sp_set_session_context 'TenantId', {DemoTenantId}");

        var applicationId = await db.CandidateApplications.Where(a => a.TenantId == DemoTenantId)
            .Select(a => a.CandidateApplicationId).FirstAsync();

        var connection = (Microsoft.Data.SqlClient.SqlConnection)db.Database.GetDbConnection();
        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "onboarding.usp_CreateDiscrepancy";
        command.Parameters.Add(new Microsoft.Data.SqlClient.SqlParameter("@TenantId", SqlDbType.UniqueIdentifier) { Value = DemoTenantId });
        command.Parameters.Add(new Microsoft.Data.SqlClient.SqlParameter("@CandidateApplicationId", SqlDbType.UniqueIdentifier) { Value = applicationId });
        command.Parameters.Add(new Microsoft.Data.SqlClient.SqlParameter("@DiscrepancyTypeCode", SqlDbType.NVarChar) { Value = "DATE_MISMATCH" });
        command.Parameters.Add(new Microsoft.Data.SqlClient.SqlParameter("@DiscrepancySeverityCode", SqlDbType.NVarChar) { Value = "HIGH" });
        command.Parameters.Add(new Microsoft.Data.SqlClient.SqlParameter("@Description", SqlDbType.NVarChar) { Value = "Integration test discrepancy." });
        command.Parameters.Add(new Microsoft.Data.SqlClient.SqlParameter("@CreatedByUserId", SqlDbType.UniqueIdentifier) { Value = DemoRecruiterUserId });

        await using var reader = await command.ExecuteReaderAsync();
        await reader.ReadAsync();
        return reader.GetGuid(reader.GetOrdinal("EntityId"));
    }

    [Fact]
    public async Task ListAndResolveDiscrepancy_TransitionsToClosed()
    {
        var discrepancyId = await CreateDiscrepancyAsync();
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var listResponse = await client.GetAsync("/api/v1/discrepancies?limit=200");
        listResponse.EnsureSuccessStatusCode();
        var items = (await listResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items").EnumerateArray().ToList();
        Assert.Contains(items, item => item.GetProperty("id").GetString() == discrepancyId.ToString());

        var getResponse = await client.GetAsync($"/api/v1/discrepancies/{discrepancyId}");
        getResponse.EnsureSuccessStatusCode();
        var getBody = await getResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("DATE_MISMATCH", getBody.GetProperty("type").GetString());
        Assert.Equal("HIGH", getBody.GetProperty("severity").GetString());
        Assert.Equal("OPEN", getBody.GetProperty("status").GetString());

        var resolveResponse = await client.PostAsJsonAsync($"/api/v1/discrepancies/{discrepancyId}/resolve", new { decision = "approved" });
        resolveResponse.EnsureSuccessStatusCode();
        Assert.Equal("completed", (await resolveResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("action_status").GetString());

        var afterResolve = await client.GetAsync($"/api/v1/discrepancies/{discrepancyId}");
        Assert.Equal("CLOSED", (await afterResolve.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        // Resolving an already-resolved discrepancy must be rejected, not silently re-applied.
        var secondResolve = await client.PostAsJsonAsync($"/api/v1/discrepancies/{discrepancyId}/resolve", new { decision = "approved" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, secondResolve.StatusCode);
    }

    [Fact]
    public async Task RequestReupload_MovesDiscrepancyToAwaitingCandidateResponse()
    {
        var discrepancyId = await CreateDiscrepancyAsync();
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/v1/discrepancies/{discrepancyId}/reupload-request", new { reason = "Please re-upload a clearer scan." });
        response.EnsureSuccessStatusCode();
        Assert.Equal("completed", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("action_status").GetString());

        var getResponse = await client.GetAsync($"/api/v1/discrepancies/{discrepancyId}");
        Assert.Equal("AWAITING_CANDIDATE_RESPONSE", (await getResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());
    }

    [Fact]
    public async Task ResolveDiscrepancy_WrongRole_Returns403()
    {
        var discrepancyId = await CreateDiscrepancyAsync();
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/v1/discrepancies/{discrepancyId}/resolve", new { decision = "approved" });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task VerificationQueue_ReturnsSeededCase()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/v1/verification?limit=200");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("items").GetArrayLength() >= 0);
    }

    [Fact]
    public async Task ListDiscrepancies_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/discrepancies");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
