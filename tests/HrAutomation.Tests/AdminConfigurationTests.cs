using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace HrAutomation.Tests;

/// <summary>
/// Covers the genuinely-enforced-at-runtime admin configuration endpoints (tenant profile,
/// numbering rules, approval matrix rules — see 07-create-stored-procedures.sql
/// "ADMINISTRATION" section) plus the read-only workflow-definitions reference view.
/// Uses the real seeded demo tenant/users, not fabricated data — DEC-007 applies (no
/// per-test-run database isolation), so tests read back actual state rather than assuming
/// a pristine starting point.
/// </summary>
public class AdminConfigurationTests(HrApiFactory factory) : IClassFixture<HrApiFactory>
{
    private static readonly Guid DemoTenantId = Guid.Parse("5B7EA628-5EE4-4680-865D-71CABB8463D7");
    private static readonly Guid DemoTenantAdminUserId = Guid.Parse("7EC3629F-F533-4067-B4D0-A842549E4B5B");
    private static readonly Guid DemoPlatformAdminUserId = Guid.Parse("F10B311D-AF1E-4638-B30A-886DF1619439");
    private static readonly Guid DemoRecruiterUserId = Guid.Parse("708CEBD9-7BFA-4E87-9B10-FCE57092C46C");

    private static async Task<HttpClient> AuthedClientAsync(HrApiFactory factory, string role, Guid userId)
    {
        var client = factory.CreateClient();
        var (token, _) = await DevTokenHelper.IssueTokenAsync(client, role, DemoTenantId, userId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    [Fact]
    public async Task GetTenantProfile_AsTenantAdmin_ReturnsRealTenant()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);

        var response = await client.GetAsync("/api/v1/admin/tenant-profile");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(DemoTenantId.ToString(), body.GetProperty("tenant_id").GetString(), ignoreCase: true);
        Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("tenant_name").GetString()));
        Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("row_version").GetString()));
    }

    [Fact]
    public async Task UpdateTenantProfile_AsPlatformAdmin_ActuallyPersistsAndReturnsNewRowVersion()
    {
        // tenant.manage is seeded to PLATFORM_ADMIN only, not TENANT_ADMIN (which only has
        // tenant.read) — see Database/seed/02-seed-iam-roles-permissions.sql @RolePermissions.
        var client = await AuthedClientAsync(factory, "PLATFORM_ADMIN", DemoPlatformAdminUserId);

        var before = await (await client.GetAsync("/api/v1/admin/tenant-profile")).Content.ReadFromJsonAsync<JsonElement>();
        var originalName = before.GetProperty("tenant_name").GetString()!;
        var rowVersion = before.GetProperty("row_version").GetString()!;
        var newName = $"{originalName} (test-{Guid.NewGuid():N})";

        var patchResponse = await client.PatchAsJsonAsync("/api/v1/admin/tenant-profile", new
        {
            tenant_name = newName,
            legal_name = before.GetProperty("legal_name").GetString(),
            primary_domain = before.GetProperty("primary_domain").GetString(),
            row_version = rowVersion
        });
        patchResponse.EnsureSuccessStatusCode();

        var after = await (await client.GetAsync("/api/v1/admin/tenant-profile")).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(newName, after.GetProperty("tenant_name").GetString());
        Assert.NotEqual(rowVersion, after.GetProperty("row_version").GetString());

        // Restore original name so this test is repeatable against the shared demo DB (DEC-007).
        var restoreResponse = await client.PatchAsJsonAsync("/api/v1/admin/tenant-profile", new
        {
            tenant_name = originalName,
            legal_name = before.GetProperty("legal_name").GetString(),
            primary_domain = before.GetProperty("primary_domain").GetString(),
            row_version = after.GetProperty("row_version").GetString()
        });
        restoreResponse.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task UpdateTenantProfile_WithStaleRowVersion_Returns409()
    {
        var client = await AuthedClientAsync(factory, "PLATFORM_ADMIN", DemoPlatformAdminUserId);
        var before = await (await client.GetAsync("/api/v1/admin/tenant-profile")).Content.ReadFromJsonAsync<JsonElement>();

        var staleRowVersion = Convert.ToBase64String(new byte[] { 0, 0, 0, 0, 0, 0, 0, 1 });

        var response = await client.PatchAsJsonAsync("/api/v1/admin/tenant-profile", new
        {
            tenant_name = before.GetProperty("tenant_name").GetString(),
            legal_name = before.GetProperty("legal_name").GetString(),
            primary_domain = before.GetProperty("primary_domain").GetString(),
            row_version = staleRowVersion
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task UpdateTenantProfile_AsRecruiter_Returns403()
    {
        var client = await AuthedClientAsync(factory, "RECRUITER", DemoRecruiterUserId);

        var response = await client.PatchAsJsonAsync("/api/v1/admin/tenant-profile", new
        {
            tenant_name = "Should not be allowed",
            row_version = Convert.ToBase64String(new byte[8])
        });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ListNumberingRules_AsTenantAdmin_IncludesRealSeededTanRule()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);

        var response = await client.GetAsync("/api/v1/admin/numbering-rules");

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        var rules = body.EnumerateArray().ToList();
        Assert.Contains(rules, r => r.GetProperty("entity_type").GetString() == "TAN");
        var tanRule = rules.First(r => r.GetProperty("entity_type").GetString() == "TAN");
        Assert.False(string.IsNullOrEmpty(tanRule.GetProperty("next_preview").GetString()));
    }

    [Fact]
    public async Task UpdateNumberingRule_ChangesPrefixAndNextPreviewReflectsIt()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);
        var rules = (await (await client.GetAsync("/api/v1/admin/numbering-rules")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        var tanRule = rules.First(r => r.GetProperty("entity_type").GetString() == "TAN");
        var ruleId = tanRule.GetProperty("numbering_rule_id").GetString();
        var originalPrefix = tanRule.GetProperty("prefix").GetString();
        var originalPadding = tanRule.GetProperty("padding_width").GetInt32();
        var rowVersion = tanRule.GetProperty("row_version").GetString();

        var newPrefix = $"T{DateTime.UtcNow.Ticks % 100}-";
        var patchResponse = await client.PatchAsJsonAsync($"/api/v1/admin/numbering-rules/{ruleId}", new
        {
            prefix = newPrefix,
            suffix = (string?)null,
            padding_width = originalPadding,
            row_version = rowVersion
        });
        patchResponse.EnsureSuccessStatusCode();

        var afterRules = (await (await client.GetAsync("/api/v1/admin/numbering-rules")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        var afterTanRule = afterRules.First(r => r.GetProperty("numbering_rule_id").GetString() == ruleId);
        Assert.Equal(newPrefix, afterTanRule.GetProperty("prefix").GetString());
        Assert.StartsWith(newPrefix, afterTanRule.GetProperty("next_preview").GetString());

        // Restore.
        var restoreResponse = await client.PatchAsJsonAsync($"/api/v1/admin/numbering-rules/{ruleId}", new
        {
            prefix = originalPrefix,
            suffix = (string?)null,
            padding_width = originalPadding,
            row_version = afterTanRule.GetProperty("row_version").GetString()
        });
        restoreResponse.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task UpdateNumberingRule_InvalidPaddingWidth_Returns422()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);
        var rules = (await (await client.GetAsync("/api/v1/admin/numbering-rules")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        var tanRule = rules.First(r => r.GetProperty("entity_type").GetString() == "TAN");

        var response = await client.PatchAsJsonAsync($"/api/v1/admin/numbering-rules/{tanRule.GetProperty("numbering_rule_id").GetString()}", new
        {
            prefix = tanRule.GetProperty("prefix").GetString(),
            suffix = (string?)null,
            padding_width = 999,
            row_version = tanRule.GetProperty("row_version").GetString()
        });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
    }

    [Fact]
    public async Task ListApprovalMatrices_ReturnsRealSeededMatricesWithRules()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);

        var response = await client.GetAsync("/api/v1/admin/approval-matrices");

        response.EnsureSuccessStatusCode();
        var matrices = (await response.Content.ReadFromJsonAsync<JsonElement>()).EnumerateArray().ToList();
        var offerMatrix = matrices.First(m => m.GetProperty("matrix_code").GetString() == "OFFER_APPROVAL_STD");
        var rules = offerMatrix.GetProperty("rules").EnumerateArray().ToList();
        Assert.Equal(2, rules.Count); // seeded: 2 mandatory steps (Database/seed/05-seed-workflow-approval-sla.sql)
    }

    [Fact]
    public async Task AddThenDeleteApprovalMatrixRule_OnMultiStepMatrix_Succeeds()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);
        var matrices = (await (await client.GetAsync("/api/v1/admin/approval-matrices")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        var offerMatrix = matrices.First(m => m.GetProperty("matrix_code").GetString() == "OFFER_APPROVAL_STD");
        var matrixId = offerMatrix.GetProperty("approval_matrix_id").GetString();
        var maxStepOrder = offerMatrix.GetProperty("rules").EnumerateArray().Max(r => r.GetProperty("step_order").GetInt32());

        var addResponse = await client.PostAsJsonAsync($"/api/v1/admin/approval-matrices/{matrixId}/rules", new
        {
            step_order = maxStepOrder + 1,
            approver_role_id = (string?)null,
            is_mandatory = false,
            condition_expression = "test-only step, safe to add/remove (not mandatory)"
        });
        addResponse.EnsureSuccessStatusCode();
        var addBody = await addResponse.Content.ReadFromJsonAsync<JsonElement>();
        var newRuleId = addBody.GetProperty("entity_id").GetString();

        var deleteResponse = await client.DeleteAsync($"/api/v1/admin/approval-matrices/{matrixId}/rules/{newRuleId}");
        deleteResponse.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task DeleteApprovalMatrixRule_LastMandatoryStepOnSingleStepMatrix_Returns422()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);
        var matrices = (await (await client.GetAsync("/api/v1/admin/approval-matrices")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        // Seeded with exactly one mandatory rule (Database/seed/05-seed-workflow-approval-sla.sql) -
        // removing it would leave zero human approval steps for TAN approval.
        var tanMatrix = matrices.First(m => m.GetProperty("matrix_code").GetString() == "TAN_APPROVAL_STD");
        var matrixId = tanMatrix.GetProperty("approval_matrix_id").GetString();
        var onlyRule = tanMatrix.GetProperty("rules").EnumerateArray().Single();

        var response = await client.DeleteAsync(
            $"/api/v1/admin/approval-matrices/{matrixId}/rules/{onlyRule.GetProperty("approval_matrix_rule_id").GetString()}");

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);

        // Confirm the rule genuinely still exists (the reject was not a no-op success).
        var afterMatrices = (await (await client.GetAsync("/api/v1/admin/approval-matrices")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        var afterTanMatrix = afterMatrices.First(m => m.GetProperty("matrix_code").GetString() == "TAN_APPROVAL_STD");
        Assert.Single(afterTanMatrix.GetProperty("rules").EnumerateArray());
    }

    [Fact]
    public async Task AddApprovalMatrixRule_AsRecruiter_Returns403()
    {
        var client = await AuthedClientAsync(factory, "RECRUITER", DemoRecruiterUserId);
        var matrices = (await (await client.GetAsync("/api/v1/admin/approval-matrices")).Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().ToList();
        var offerMatrix = matrices.First(m => m.GetProperty("matrix_code").GetString() == "OFFER_APPROVAL_STD");

        var response = await client.PostAsJsonAsync(
            $"/api/v1/admin/approval-matrices/{offerMatrix.GetProperty("approval_matrix_id").GetString()}/rules",
            new { step_order = 99, is_mandatory = false });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ListWorkflowDefinitions_ReturnsReferenceDataReadOnly()
    {
        var client = await AuthedClientAsync(factory, "TENANT_ADMIN", DemoTenantAdminUserId);

        var response = await client.GetAsync("/api/v1/admin/workflow-definitions");

        response.EnsureSuccessStatusCode();
        var definitions = (await response.Content.ReadFromJsonAsync<JsonElement>()).EnumerateArray().ToList();
        Assert.NotEmpty(definitions);
        Assert.All(definitions, d =>
        {
            Assert.False(string.IsNullOrWhiteSpace(d.GetProperty("workflow_code").GetString()));
        });
    }

    [Fact]
    public async Task GetTenantProfile_WithoutToken_Returns401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/v1/admin/tenant-profile");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
