using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Infrastructure.Persistence;

/// <summary>Database-first context over the hand-built HrAutomationDb schema
/// (../Database/scripts/03-create-tables.sql). No migrations are generated from this
/// context - table shape is owned by the SQL scripts; this only maps to what already
/// exists. See Persistence/README.md "When to use EF Core vs. a stored procedure":
/// simple CRUD goes through the DbSets below, multi-entity/workflow-critical actions
/// go through Database.ExecuteSqlInterpolatedAsync/SqlQuery calling the procedures in
/// ../Database/scripts/07-create-stored-procedures.sql.</summary>
public class HrAutomationDbContext(DbContextOptions<HrAutomationDbContext> options) : DbContext(options)
{
    public DbSet<IamUser> Users => Set<IamUser>();
    public DbSet<IamUserProfile> UserProfiles => Set<IamUserProfile>();
    public DbSet<IamUserAuthenticationProvider> UserAuthenticationProviders => Set<IamUserAuthenticationProvider>();
    public DbSet<IamRole> Roles => Set<IamRole>();
    public DbSet<IamPermission> Permissions => Set<IamPermission>();
    public DbSet<IamUserRole> UserRoles => Set<IamUserRole>();
    public DbSet<IamRolePermission> RolePermissions => Set<IamRolePermission>();

    public DbSet<OrgDepartment> Departments => Set<OrgDepartment>();
    public DbSet<OrgLocation> Locations => Set<OrgLocation>();

    public DbSet<RecruitmentCandidate> Candidates => Set<RecruitmentCandidate>();
    public DbSet<RecruitmentCandidateContact> CandidateContacts => Set<RecruitmentCandidateContact>();
    public DbSet<RecruitmentCandidateCv> CandidateCvs => Set<RecruitmentCandidateCv>();
    public DbSet<RecruitmentCandidateCvVersion> CandidateCvVersions => Set<RecruitmentCandidateCvVersion>();
    public DbSet<RecruitmentCvParsingResult> CvParsingResults => Set<RecruitmentCvParsingResult>();
    public DbSet<RecruitmentCvExtractionField> CvExtractionFields => Set<RecruitmentCvExtractionField>();
    public DbSet<RecruitmentTalentAcquisitionNumber> TalentAcquisitionNumbers => Set<RecruitmentTalentAcquisitionNumber>();
    public DbSet<RecruitmentJobRequisition> JobRequisitions => Set<RecruitmentJobRequisition>();
    public DbSet<RecruitmentJobDescription> JobDescriptions => Set<RecruitmentJobDescription>();
    public DbSet<RecruitmentJobDescriptionVersion> JobDescriptionVersions => Set<RecruitmentJobDescriptionVersion>();

    public DbSet<WorkflowApprovalRequest> ApprovalRequests => Set<WorkflowApprovalRequest>();
    public DbSet<WorkflowApprovalStep> ApprovalSteps => Set<WorkflowApprovalStep>();
    public DbSet<WorkflowApprovalDecision> ApprovalDecisions => Set<WorkflowApprovalDecision>();

    public DbSet<AuditEvent> AuditEvents => Set<AuditEvent>();
    public DbSet<IdempotencyKeyEntry> IdempotencyKeys => Set<IdempotencyKeyEntry>();

    public DbSet<RefCandidateSource> CandidateSources => Set<RefCandidateSource>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<IamUser>(b =>
        {
            b.ToTable("User", "iam");
            b.HasKey(e => e.UserId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<IamUserProfile>(b =>
        {
            b.ToTable("UserProfile", "iam");
            b.HasKey(e => e.UserProfileId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<IamUserAuthenticationProvider>(b =>
        {
            b.ToTable("UserAuthenticationProvider", "iam");
            b.HasKey(e => e.UserAuthenticationProviderId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<IamRole>(b =>
        {
            b.ToTable("Role", "iam");
            b.HasKey(e => e.RoleId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<IamPermission>(b =>
        {
            b.ToTable("Permission", "iam");
            b.HasKey(e => e.PermissionId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<IamUserRole>(b =>
        {
            b.ToTable("UserRole", "iam");
            b.HasKey(e => e.UserRoleId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<IamRolePermission>(b =>
        {
            b.ToTable("RolePermission", "iam");
            b.HasKey(e => e.RolePermissionId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<OrgDepartment>(b =>
        {
            b.ToTable("Department", "org");
            b.HasKey(e => e.DepartmentId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<OrgLocation>(b =>
        {
            b.ToTable("Location", "org");
            b.HasKey(e => e.LocationId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentCandidate>(b =>
        {
            b.ToTable("Candidate", "recruitment");
            b.HasKey(e => e.CandidateId);
            b.Property(e => e.TotalExperienceYears).HasPrecision(4, 1);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentCandidateContact>(b =>
        {
            b.ToTable("CandidateContact", "recruitment");
            b.HasKey(e => e.CandidateContactId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentCandidateCv>(b =>
        {
            b.ToTable("CandidateCv", "recruitment");
            b.HasKey(e => e.CandidateCvId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentCandidateCvVersion>(b =>
        {
            b.ToTable("CandidateCvVersion", "recruitment");
            b.HasKey(e => e.CandidateCvVersionId);
            b.HasQueryFilter(e => !e.IsDeleted);
            // Explicit FK relationships (even without navigation properties) so EF Core's
            // SaveChanges batching knows the correct insert order for multi-entity adds in one
            // call (e.g. CvIngestionSkill) - without this it can batch a child insert before its
            // parent and the FK constraint rejects it.
            b.HasOne<RecruitmentCandidateCv>().WithMany().HasForeignKey(e => e.CandidateCvId);
        });

        modelBuilder.Entity<RecruitmentCvParsingResult>(b =>
        {
            b.ToTable("CvParsingResult", "recruitment");
            b.HasKey(e => e.CvParsingResultId);
            b.Property(e => e.ConfidenceScore).HasPrecision(5, 4);
            b.HasQueryFilter(e => !e.IsDeleted);
            b.HasOne<RecruitmentCandidateCvVersion>().WithMany().HasForeignKey(e => e.CandidateCvVersionId);
        });

        modelBuilder.Entity<RecruitmentCvExtractionField>(b =>
        {
            b.ToTable("CvExtractionField", "recruitment");
            b.HasKey(e => e.CvExtractionFieldId);
            b.Property(e => e.ConfidenceScore).HasPrecision(5, 4);
            b.HasQueryFilter(e => !e.IsDeleted);
            b.HasOne<RecruitmentCvParsingResult>().WithMany().HasForeignKey(e => e.CvParsingResultId);
        });

        modelBuilder.Entity<RecruitmentTalentAcquisitionNumber>(b =>
        {
            b.ToTable("TalentAcquisitionNumber", "recruitment");
            b.HasKey(e => e.TalentAcquisitionNumberId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentJobRequisition>(b =>
        {
            b.ToTable("JobRequisition", "recruitment");
            b.HasKey(e => e.JobRequisitionId);
            b.Property(e => e.RowVersion).IsRowVersion();
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentJobDescription>(b =>
        {
            b.ToTable("JobDescription", "recruitment");
            b.HasKey(e => e.JobDescriptionId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<RecruitmentJobDescriptionVersion>(b =>
        {
            b.ToTable("JobDescriptionVersion", "recruitment");
            b.HasKey(e => e.JobDescriptionVersionId);
            b.HasQueryFilter(e => !e.IsDeleted);
            b.HasOne<RecruitmentJobDescription>().WithMany().HasForeignKey(e => e.JobDescriptionId);
        });

        modelBuilder.Entity<WorkflowApprovalRequest>(b =>
        {
            b.ToTable("ApprovalRequest", "workflow");
            b.HasKey(e => e.ApprovalRequestId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });

        modelBuilder.Entity<WorkflowApprovalStep>(b =>
        {
            b.ToTable("ApprovalStep", "workflow");
            b.HasKey(e => e.ApprovalStepId);
        });

        modelBuilder.Entity<WorkflowApprovalDecision>(b =>
        {
            b.ToTable("ApprovalDecision", "workflow");
            b.HasKey(e => e.ApprovalDecisionId);
        });

        modelBuilder.Entity<AuditEvent>(b =>
        {
            b.ToTable("AuditEvent", "audit");
            b.HasKey(e => e.AuditEventId);
            b.Property(e => e.AuditEventId).ValueGeneratedOnAdd();
        });

        modelBuilder.Entity<IdempotencyKeyEntry>(b =>
        {
            b.ToTable("IdempotencyKey", "integration");
            b.HasKey(e => e.IdempotencyKeyId);
            b.HasIndex(e => new { e.TenantId, e.RequestPath, e.IdempotencyKeyValue }).IsUnique();
        });

        modelBuilder.Entity<RefCandidateSource>(b =>
        {
            b.ToTable("CandidateSource", "ref");
            b.HasKey(e => e.CandidateSourceId);
            b.HasQueryFilter(e => !e.IsDeleted);
        });
    }
}
