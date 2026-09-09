using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace HrAutomation.Tests;

public class GreenFormLifecycleTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");

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
    public async Task IssueLink_ThenAnonymousGetAndSubmit_WorksEndToEnd()
    {
        var applicationId = await GetSeededApplicationIdAsync();
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var issueResponse = await client.PostAsync($"/api/v1/green-forms/{applicationId}/issue-link", null);
        issueResponse.EnsureSuccessStatusCode();
        var issueBody = await issueResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("completed", issueBody.GetProperty("action_status").GetString());
        var greenFormToken = issueBody.GetProperty("green_form_submission_id").GetString();
        Assert.False(string.IsNullOrEmpty(greenFormToken));

        // The candidate has no session at all — a client with no Authorization header must
        // still be able to read and submit via the token alone (RLS bypass verified for real,
        // not just compiled: onboarding.usp_GetGreenFormSubmissionStatus/usp_SubmitGreenForm
        // both run WITH EXECUTE AS 'db_hr_green_form_token_resolver' specifically for this).
        var anonymousClient = factory.CreateClient();

        var byTokenResponse = await anonymousClient.GetAsync($"/api/v1/green-forms/by-token/{greenFormToken}");
        byTokenResponse.EnsureSuccessStatusCode();
        var byTokenBody = await byTokenResponse.Content.ReadFromJsonAsync<JsonElement>();
        var initialStatus = byTokenBody.GetProperty("status").GetString();
        // usp_IssueGreenFormLink is idempotent (unique constraint on
        // CandidateApplicationId+GreenFormVersionId) and this suite has no per-run database
        // isolation (DEC-007, see .claude/rules/testing.md) — a prior run against the same
        // seeded application may have already submitted this exact token. Both starting states
        // are valid; only assert the one guaranteed real-world invariant either way: an
        // already-submitted form must reject a second submission (see below), never silently
        // accept it twice.
        Assert.True(initialStatus is "InProgress" or "Submitted", $"Unexpected status: {initialStatus}");

        if (initialStatus == "InProgress")
        {
            var submitResponse = await anonymousClient.PostAsJsonAsync($"/api/v1/green-forms/by-token/{greenFormToken}/submissions", new
            {
                employment_history = new[]
                {
                    new { employer_name = "Acme Test Corp", start_date = "2020-01-01", end_date = (string?)null }
                },
                education = new[]
                {
                    new { institution = "Test University", qualification = "B.Sc. Computer Science", year = 2019 }
                }
            });
            submitResponse.EnsureSuccessStatusCode();
        }

        var statusResponse = await anonymousClient.GetAsync($"/api/v1/green-forms/submission/{greenFormToken}");
        statusResponse.EnsureSuccessStatusCode();
        var statusBody = await statusResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Submitted", statusBody.GetProperty("status").GetString());

        // Resubmitting an already-submitted form must be rejected, not silently accepted twice.
        var resubmitResponse = await anonymousClient.PostAsJsonAsync($"/api/v1/green-forms/by-token/{greenFormToken}/submissions", new
        {
            employment_history = Array.Empty<object>(),
            education = Array.Empty<object>()
        });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, resubmitResponse.StatusCode);
    }

    [Fact]
    public async Task GetByToken_UnknownToken_Returns404()
    {
        var anonymousClient = factory.CreateClient();

        var response = await anonymousClient.GetAsync($"/api/v1/green-forms/by-token/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task IssueLink_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.PostAsync($"/api/v1/green-forms/{Guid.NewGuid()}/issue-link", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
