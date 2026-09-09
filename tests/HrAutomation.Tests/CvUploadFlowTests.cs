using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

namespace HrAutomation.Tests;

public class CvUploadFlowTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    // The seeded demo tenant (Database/seed/01-seed-tenant-organization.sql) - a freshly-minted
    // random tenant_id would fail HrAutomationDb's org.Tenant foreign-key constraints, unlike the
    // old in-memory-database test provider which didn't enforce them.
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");

    [Fact]
    public async Task UploadCv_NewCandidate_ReturnsCompletedWithCandidateId()
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, "RECRUITER", DemoTenantId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        var fileBytes = Encoding.UTF8.GetBytes(
            "Jane Doe\njane.doe@example.com\n+1 555 123 4567\nSkills: C#, .NET, Azure");
        var fileContent = new ByteArrayContent(fileBytes);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("text/plain");
        content.Add(fileContent, "file", "resume.txt");

        var response = await client.PostAsync("/api/v1/candidates/cvs", content);
        var debugBody = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, debugBody);

        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("completed", body.GetProperty("action_status").GetString());
        Assert.False(string.IsNullOrEmpty(body.GetProperty("candidate_id").GetString()));
        Assert.Equal("pass", body.GetProperty("guardrail_results").GetProperty("authorization").GetString());
    }

    [Fact]
    public async Task UploadCv_WithoutAuthorization_Returns401()
    {
        var client = factory.CreateClient();

        using var content = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent(Encoding.UTF8.GetBytes("no auth header"));
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("text/plain");
        content.Add(fileContent, "file", "resume.txt");

        var response = await client.PostAsync("/api/v1/candidates/cvs", content);

        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
