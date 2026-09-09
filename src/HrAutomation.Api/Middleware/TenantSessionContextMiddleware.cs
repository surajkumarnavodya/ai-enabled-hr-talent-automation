using System.Data;
using System.Security.Claims;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Middleware;

/// <summary>
/// Sets SESSION_CONTEXT('TenantId') on the request's HrAutomationDbContext connection right after
/// authentication, before any controller/middleware queries a row-level-security-protected table.
/// Without this, every RLS filter predicate (security.fn_tenant_access_predicate, see
/// ../../HrAutomation.Infrastructure/Database/scripts/05-create-security.sql) evaluates
/// `SESSION_CONTEXT('TenantId') IS NULL` and silently filters every row - a query with a perfectly
/// correct WHERE TenantId = @tenantId clause still returns zero rows.
///
/// Deliberately uses the plain `sp_set_session_context` form (not the read-only
/// iam.usp_SetSessionSecurityContext variant) - a read-only session context key cannot be reset,
/// and several stored procedures this request may go on to call set it again themselves (each is
/// independently callable outside the API, so each sets its own context defensively). Both set it
/// to the same value, so re-setting it here first is harmless.
/// </summary>
public sealed class TenantSessionContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, HrAutomationDbContext db)
    {
        if (Guid.TryParse(context.User.FindFirstValue("tenant_id"), out var tenantId))
        {
            var connection = (SqlConnection)db.Database.GetDbConnection();
            if (connection.State != ConnectionState.Open)
            {
                await connection.OpenAsync(context.RequestAborted);
            }

            await using var command = connection.CreateCommand();
            command.CommandText = "EXEC sp_set_session_context @key = N'TenantId', @value = @TenantId;";
            command.Parameters.Add(new SqlParameter("@TenantId", SqlDbType.UniqueIdentifier) { Value = tenantId });
            await command.ExecuteNonQueryAsync(context.RequestAborted);
        }

        await next(context);
    }
}
