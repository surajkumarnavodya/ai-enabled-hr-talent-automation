using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace HrAutomation.Infrastructure.Persistence;

/// <summary>Design-time factory for tooling that needs an HrAutomationDbContext instance
/// outside the running API host. Table shape is owned by ../Database/scripts/, not by
/// migrations generated from this context - see HrAutomationDbContext's class comment.</summary>
public sealed class HrAutomationDbContextFactory : IDesignTimeDbContextFactory<HrAutomationDbContext>
{
    // Matches <UserSecretsId> in src/HrAutomation.Api/HrAutomation.Api.csproj.
    private const string ApiUserSecretsId = "ee90fcc8-70e7-49be-9f6f-5b830ba33368";

    public HrAutomationDbContext CreateDbContext(string[] args)
    {
        var configuration = new ConfigurationBuilder()
            .AddUserSecrets(ApiUserSecretsId, reloadOnChange: false)
            .AddEnvironmentVariables()
            .Build();

        var connectionString = configuration.GetConnectionString("HrAutomationDb")
            ?? "Server=(localdb)\\mssqllocaldb;Database=HrAutomationDb;Trusted_Connection=True;MultipleActiveResultSets=true";

        var optionsBuilder = new DbContextOptionsBuilder<HrAutomationDbContext>();
        optionsBuilder.UseSqlServer(connectionString);
        return new HrAutomationDbContext(optionsBuilder.Options);
    }
}
