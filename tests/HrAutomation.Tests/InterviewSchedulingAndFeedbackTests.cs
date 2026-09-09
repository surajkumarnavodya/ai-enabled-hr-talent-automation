using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace HrAutomation.Tests;

public class InterviewSchedulingAndFeedbackTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");

    // recruitment.usp_ScheduleInterview requires a real recruitment.CandidateApplication row (no
    // API creates one yet - that's the still-stubbed match_candidates_skill/shortlist flow) - read
    // one from the seeded demo transaction data (Database/seed/09-*.sql) rather than fabricate an
    // id that would fail the FK constraint.
    private async Task<(Guid ApplicationId, Guid RoundDefinitionId)> GetSeededFixturesAsync()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<HrAutomationDbContext>();

        // Row-level security predicates key off SESSION_CONTEXT('TenantId'), which
        // TenantSessionContextMiddleware normally sets per HTTP request (see
        // .claude/rules/data.md) — a raw DbContext scope like this one has none set, so every
        // RLS-protected query below would silently return zero rows without this. The connection
        // must stay open across both calls (EF Core otherwise pools/reopens a fresh connection
        // per command, which would lose the session-scoped context set here).
        await db.Database.OpenConnectionAsync();
        await db.Database.ExecuteSqlInterpolatedAsync($"EXEC sp_set_session_context 'TenantId', {DemoTenantId}");

        var applicationId = await db.CandidateApplications
            .Where(a => a.TenantId == DemoTenantId)
            .Select(a => a.CandidateApplicationId)
            .FirstAsync();

        var roundDefinitionId = await db.InterviewRoundDefinitions
            .Where(d => d.TenantId == DemoTenantId && d.Code == "L1_TECHNICAL")
            .Select(d => d.InterviewRoundDefinitionId)
            .FirstAsync();

        return (applicationId, roundDefinitionId);
    }

    [Fact]
    public async Task ScheduleInterview_ThenListAndGet_ReturnsRealPersistedRound()
    {
        var (applicationId, roundDefinitionId) = await GetSeededFixturesAsync();
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var start = DateTime.UtcNow.AddDays(3);
        var createResponse = await client.PostAsJsonAsync("/api/v1/interviews", new
        {
            candidate_application_id = applicationId,
            interview_round_definition_id = roundDefinitionId,
            scheduled_start_utc = start,
            scheduled_end_utc = start.AddMinutes(45),
            time_zone_id = "Asia/Kolkata",
            location_or_link = "Test Meeting Room"
        });

        createResponse.EnsureSuccessStatusCode();
        var createBody = await createResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("completed", createBody.GetProperty("action_status").GetString());
        var interviewRoundId = createBody.GetProperty("interview_round_id").GetString();
        Assert.False(string.IsNullOrEmpty(interviewRoundId));

        var listResponse = await client.GetAsync("/api/v1/interviews?limit=200");
        listResponse.EnsureSuccessStatusCode();
        var listBody = await listResponse.Content.ReadFromJsonAsync<JsonElement>();
        var items = listBody.GetProperty("items").EnumerateArray().ToList();
        Assert.Contains(items, item => item.GetProperty("interview_round_id").GetString() == interviewRoundId);

        var getResponse = await client.GetAsync($"/api/v1/interviews/{interviewRoundId}");
        getResponse.EnsureSuccessStatusCode();
        var getBody = await getResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Scheduled", getBody.GetProperty("status").GetString());
        Assert.False(string.IsNullOrEmpty(getBody.GetProperty("candidate_name").GetString()));
    }

    [Fact]
    public async Task SubmitFeedback_ThenInterviewShowsCompleted()
    {
        var (applicationId, roundDefinitionId) = await GetSeededFixturesAsync();
        var client = factory.CreateClient();
        var (recruiterToken, tenantId) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", recruiterToken);

        var start = DateTime.UtcNow.AddDays(-1);
        var createResponse = await client.PostAsJsonAsync("/api/v1/interviews", new
        {
            candidate_application_id = applicationId,
            interview_round_definition_id = roundDefinitionId,
            scheduled_start_utc = start,
            scheduled_end_utc = start.AddMinutes(45)
        });
        createResponse.EnsureSuccessStatusCode();
        var interviewRoundId = (await createResponse.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("interview_round_id").GetString();

        var (interviewerToken, _) = await DevTokenHelper.IssueTokenAsync(client, "INTERVIEWER", tenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", interviewerToken);

        var feedbackResponse = await client.PostAsJsonAsync($"/api/v1/interviews/{interviewRoundId}/feedback", new
        {
            outcome = "select",
            communication_score = 4,
            technical_score = 5,
            notes = "Strong technical depth, clear communicator."
        });

        feedbackResponse.EnsureSuccessStatusCode();
        var feedbackBody = await feedbackResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("completed", feedbackBody.GetProperty("action_status").GetString());

        var getResponse = await client.GetAsync($"/api/v1/interviews/{interviewRoundId}");
        getResponse.EnsureSuccessStatusCode();
        var getBody = await getResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Completed", getBody.GetProperty("status").GetString());
    }

    [Fact]
    public async Task SubmitFeedback_WrongRole_Returns403()
    {
        var (applicationId, roundDefinitionId) = await GetSeededFixturesAsync();
        var client = factory.CreateClient();
        var (recruiterToken, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", recruiterToken);

        var start = DateTime.UtcNow.AddDays(2);
        var createResponse = await client.PostAsJsonAsync("/api/v1/interviews", new
        {
            candidate_application_id = applicationId,
            interview_round_definition_id = roundDefinitionId,
            scheduled_start_utc = start,
            scheduled_end_utc = start.AddMinutes(45)
        });
        createResponse.EnsureSuccessStatusCode();
        var interviewRoundId = (await createResponse.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("interview_round_id").GetString();

        // A recruiter (not an assigned INTERVIEWER) may not submit interview feedback.
        var feedbackResponse = await client.PostAsJsonAsync($"/api/v1/interviews/{interviewRoundId}/feedback", new
        {
            outcome = "select",
            communication_score = 4,
            technical_score = 4,
            notes = "Attempting to self-submit feedback."
        });

        Assert.Equal(HttpStatusCode.Forbidden, feedbackResponse.StatusCode);
    }

    [Fact]
    public async Task GetInterview_NotFound_Returns404()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId, DemoRecruiterUserId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/v1/interviews/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task ListInterviews_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/interviews");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
