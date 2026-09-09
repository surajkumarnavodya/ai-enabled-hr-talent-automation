namespace HrAutomation.Infrastructure.Persistence.Entities;

public class RefCandidateSource
{
    public Guid CandidateSourceId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
}

public class RefInterviewRoundDefinition
{
    public Guid InterviewRoundDefinitionId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
}

public class RefOfferStatus
{
    public Guid OfferStatusId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public bool IsTerminal { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
}

public class RefDiscrepancyType
{
    public Guid DiscrepancyTypeId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public bool IsDeleted { get; set; }
}

public class RefDiscrepancySeverity
{
    public Guid DiscrepancySeverityId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public bool IsDeleted { get; set; }
}

public class RefDiscrepancyStatus
{
    public Guid DiscrepancyStatusId { get; set; }
    public Guid? TenantId { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public bool IsDeleted { get; set; }
}
