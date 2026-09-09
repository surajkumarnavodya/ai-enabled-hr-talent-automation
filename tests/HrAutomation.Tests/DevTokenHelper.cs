using System.Net.Http.Json;
using System.Text.Json;

namespace HrAutomation.Tests;

internal static class DevTokenHelper
{
    public static async Task<(string AccessToken, Guid TenantId)> IssueTokenAsync(
        HttpClient client, string role, Guid? tenantId = null, Guid? userId = null)
    {
        var response = await client.PostAsJsonAsync("/api/v1/dev/token", new
        {
            role,
            tenant_id = tenantId,
            user_id = userId
        });

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();

        return (
            body.GetProperty("access_token").GetString()!,
            Guid.Parse(body.GetProperty("tenant_id").GetString()!));
    }
}
