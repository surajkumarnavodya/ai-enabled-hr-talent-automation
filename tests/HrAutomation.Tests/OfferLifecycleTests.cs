using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace HrAutomation.Tests;

public class OfferLifecycleTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");
    private static readonly Guid DemoHrAdminUserId = Guid.Parse("C3A025EE-42D8-4431-A10E-A7936C9555EF");

    private async Task<Guid> GetSeededApplicationIdAsync()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<HrAutomationDbContext>();
        await db.Database.OpenConnectionAsync();
        await db.Database.ExecuteSqlInterpolatedAsync($"EXEC sp_set_session_context 'TenantId', {DemoTenantId}");
        return await db.CandidateApplications.Where(a => a.TenantId == DemoTenantId)
            .Select(a => a.CandidateApplicationId).FirstAsync();
    }

    [Fact]
    public async Task CreateApproveAndSendOffer_TransitionsThroughRealStates()
    {
        var applicationId = await GetSeededApplicationIdAsync();
        var client = factory.CreateClient();
        var (hrAdminToken, tenantId) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", hrAdminToken);

        var createResponse = await client.PostAsJsonAsync("/api/v1/offers", new
        {
            candidate_application_id = applicationId
        });
        createResponse.EnsureSuccessStatusCode();
        var createBody = await createResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("completed", createBody.GetProperty("action_status").GetString());
        var offerId = createBody.GetProperty("offer_id").GetString();
        Assert.False(string.IsNullOrEmpty(offerId));

        var afterCreate = await client.GetAsync($"/api/v1/offers/{offerId}");
        afterCreate.EnsureSuccessStatusCode();
        Assert.Equal("PendingApproval", (await afterCreate.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        // OFFER_APPROVAL_STD is a 2-step matrix (ref.ApprovalMatrixRule) — the offer only reaches
        // "Approved" once every step has a recorded decision; call approve once per step.
        var (approverToken, _) = await DevTokenHelper.IssueTokenAsync(client, "OFFER_APPROVER", tenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", approverToken);

        var firstApprove = await client.PostAsync($"/api/v1/offers/{offerId}/approve", null);
        firstApprove.EnsureSuccessStatusCode();
        Assert.Equal("completed", (await firstApprove.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("action_status").GetString());
        Assert.Equal("PendingApproval", (await (await client.GetAsync($"/api/v1/offers/{offerId}")).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        var secondApprove = await client.PostAsync($"/api/v1/offers/{offerId}/approve", null);
        secondApprove.EnsureSuccessStatusCode();
        Assert.Equal("completed", (await secondApprove.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("action_status").GetString());

        var afterApprove = await client.GetAsync($"/api/v1/offers/{offerId}");
        Assert.Equal("Approved", (await afterApprove.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", hrAdminToken);
        var sendResponse = await client.PostAsync($"/api/v1/offers/{offerId}/send", null);
        sendResponse.EnsureSuccessStatusCode();
        Assert.Equal("completed", (await sendResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("action_status").GetString());

        var afterSend = await client.GetAsync($"/api/v1/offers/{offerId}");
        Assert.Equal("Sent", (await afterSend.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        var acceptResponse = await client.PostAsync($"/api/v1/offers/{offerId}/acceptance", null);
        acceptResponse.EnsureSuccessStatusCode();
        Assert.Equal("completed", (await acceptResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("action_status").GetString());

        var afterAccept = await client.GetAsync($"/api/v1/offers/{offerId}");
        Assert.Equal("Accepted", (await afterAccept.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        var listResponse = await client.GetAsync("/api/v1/offers?limit=200");
        listResponse.EnsureSuccessStatusCode();
        var items = (await listResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items").EnumerateArray().ToList();
        Assert.Contains(items, item => item.GetProperty("offer_id").GetString() == offerId);
    }

    [Fact]
    public async Task SendOffer_BeforeApproval_ReturnsUnprocessable()
    {
        var applicationId = await GetSeededApplicationIdAsync();
        var client = factory.CreateClient();
        var (hrAdminToken, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", hrAdminToken);

        var createResponse = await client.PostAsJsonAsync("/api/v1/offers", new { candidate_application_id = applicationId });
        createResponse.EnsureSuccessStatusCode();
        var offerId = (await createResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("offer_id").GetString();

        // Still PendingApproval — usp_MarkOfferSent must refuse (APPROVAL_REQUIRED), not silently succeed.
        var sendResponse = await client.PostAsync($"/api/v1/offers/{offerId}/send", null);

        Assert.Equal(HttpStatusCode.UnprocessableEntity, sendResponse.StatusCode);
    }

    [Fact]
    public async Task CreateOffer_WrongRole_Returns403()
    {
        var applicationId = await GetSeededApplicationIdAsync();
        var client = factory.CreateClient();
        var (recruiterToken, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", recruiterToken);

        // create_offer_skill requires HR_ADMIN, not RECRUITER.
        var response = await client.PostAsJsonAsync("/api/v1/offers", new { candidate_application_id = applicationId });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetOffer_NotFound_Returns404()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "HR_ADMIN", DemoTenantId, DemoHrAdminUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/v1/offers/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
