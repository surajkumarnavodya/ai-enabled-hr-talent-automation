using HrAutomation.Infrastructure.Persistence;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace HrAutomation.Api.HealthChecks;

/// <summary>Verifies HrAutomationDb is reachable without exposing server name, connection
/// string, or any other database detail in the response - see docs/05-security-governance/.</summary>
public sealed class DatabaseHealthCheck(HrAutomationDbContext db) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var canConnect = await db.Database.CanConnectAsync(cancellationToken);
            return canConnect
                ? HealthCheckResult.Healthy("Database reachable.")
                : HealthCheckResult.Unhealthy("Database unreachable.");
        }
        catch
        {
            // Never surface the underlying exception (connection string, server name, driver
            // error text) to a caller - see .claude/rules/security.md.
            return HealthCheckResult.Unhealthy("Database unreachable.");
        }
    }
}
