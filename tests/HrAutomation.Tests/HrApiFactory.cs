using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace HrAutomation.Tests;

/// <summary>
/// Forces the Development environment so /api/v1/dev/token is reachable in tests, and points
/// HrAutomationDbContext at the real HrAutomationDb LocalDB instance.
///
/// NOTE (documented gap): the original scaffold swapped in EF Core's UseInMemoryDatabase for
/// per-factory test isolation. That's no longer viable - CvIngestionSkill/CreateTanSkill/
/// TanApprovalSkill/AuditLogger call HrAutomationDb's stored procedures via raw ADO.NET
/// (StoredProcedureExecutor), and RLS/computed columns/triggers only exist in the real SQL
/// Server engine, not the in-memory provider. Tests now run against the same LocalDB
/// HrAutomationDb instance as local dev rather than a hermetically isolated database per run;
/// each test should create its own tenant/data (e.g. via iam.usp_CreateTenant) rather than
/// assuming a clean database, and a dedicated per-test-run database is a follow-up worth doing
/// before this suite runs in shared CI.
/// </summary>
public sealed class HrApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");

        builder.ConfigureAppConfiguration((context, configBuilder) =>
        {
            configBuilder.AddUserSecrets<HrApiFactory>(optional: true);
        });

        builder.ConfigureServices((context, services) =>
        {
            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<HrAutomationDbContext>));
            if (descriptor is not null)
            {
                services.Remove(descriptor);
            }

            var connectionString = context.Configuration.GetConnectionString("HrAutomationDb")
                ?? "Server=(localdb)\\MSSQLLocalDB;Database=HrAutomationDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true";
            services.AddDbContext<HrAutomationDbContext>(options => options.UseSqlServer(connectionString));
        });
    }
}
