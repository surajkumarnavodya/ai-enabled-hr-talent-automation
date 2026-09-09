using System.Security.Claims;
using HrAutomation.Application.Security;

namespace HrAutomation.Api.Security;

/// <summary>Builds the RequestContext every controller threads through to skills/orchestrator, from
/// validated JWT claims only - never from user-supplied body/query values (spec section 4).</summary>
public static class RequestContextFactory
{
    public static RequestContext FromHttpContext(HttpContext httpContext)
    {
        var user = httpContext.User;

        var tenantIdClaim = user.FindFirstValue("tenant_id")
            ?? throw new InvalidOperationException("Authenticated principal is missing the tenant_id claim.");
        var userIdClaim = user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new InvalidOperationException("Authenticated principal is missing the sub claim.");
        var roleClaim = user.FindFirstValue(ClaimTypes.Role)
            ?? throw new InvalidOperationException("Authenticated principal is missing the role claim.");

        var departmentScope = user.FindFirstValue("department_scope");
        var purposeOfUse = httpContext.Request.Headers["X-Purpose-Of-Use"].FirstOrDefault() ?? "hr_workflow_operation";
        var correlationId = httpContext.Items.TryGetValue(CorrelationIdItemKey, out var cid) && cid is string s
            ? s
            : httpContext.TraceIdentifier;
        var traceId = System.Diagnostics.Activity.Current?.Id ?? httpContext.TraceIdentifier;

        return new RequestContext(
            TenantId: Guid.Parse(tenantIdClaim),
            UserId: Guid.Parse(userIdClaim),
            Role: roleClaim,
            DepartmentScope: departmentScope,
            PurposeOfUse: purposeOfUse,
            CorrelationId: correlationId,
            TraceId: traceId);
    }

    public const string CorrelationIdItemKey = "CorrelationId";
}
