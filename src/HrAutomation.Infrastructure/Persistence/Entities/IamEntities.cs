namespace HrAutomation.Infrastructure.Persistence.Entities;

// Persistence-layer records for HrAutomationDb (database-first, stored-procedure-backed).
// These are intentionally thin - the schema's own tables + stored procedures are the
// authority on state and validity (see ../../Database/scripts/07-create-stored-procedures.sql),
// not these POCOs. Kept out of HrAutomation.Domain.Entities to avoid colliding with the
// (soon to be retired) HrDbContext model of the same concepts.

public class IamUser
{
    public Guid UserId { get; set; }
    public Guid TenantId { get; set; }
    public string Email { get; set; } = null!;
    public string DisplayName { get; set; } = null!;
    public string UserStatus { get; set; } = null!;
    public bool IsSystemServiceAccount { get; set; }
    public DateTime? LastLoginAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public Guid? UpdatedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class IamUserProfile
{
    public Guid UserProfileId { get; set; }
    public Guid TenantId { get; set; }
    public Guid UserId { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? PhoneNumber { get; set; }
    public string? JobTitle { get; set; }
    public Guid? DepartmentId { get; set; }
    public Guid? LocationId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class IamUserAuthenticationProvider
{
    public Guid UserAuthenticationProviderId { get; set; }
    public Guid TenantId { get; set; }
    public Guid UserId { get; set; }
    public string ProviderName { get; set; } = null!;
    public string ProviderSubjectId { get; set; } = null!;
    public bool IsPrimary { get; set; }
    public DateTime LinkedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}

public class IamRole
{
    public Guid RoleId { get; set; }
    public Guid? TenantId { get; set; }
    public string RoleName { get; set; } = null!;
    public string? Description { get; set; }
    public bool IsSystemRole { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class IamPermission
{
    public Guid PermissionId { get; set; }
    public string PermissionKey { get; set; } = null!;
    public string? Description { get; set; }
    public string? ResourceCategory { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class IamUserRole
{
    public Guid UserRoleId { get; set; }
    public Guid TenantId { get; set; }
    public Guid UserId { get; set; }
    public Guid RoleId { get; set; }
    public DateTime AssignedAtUtc { get; set; }
    public Guid? AssignedByUserId { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
    public Guid? RevokedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class IamRolePermission
{
    public Guid RolePermissionId { get; set; }
    public Guid RoleId { get; set; }
    public Guid PermissionId { get; set; }
    public DateTime GrantedAtUtc { get; set; }
    public Guid? GrantedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}
