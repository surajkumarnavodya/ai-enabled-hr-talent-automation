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

/// <summary>Genuinely consulted at runtime by recruitment.usp_CreateTalentAcquisitionNumber
/// and employee.usp_GenerateEmployeeId (see 07-create-stored-procedures.sql) - editing
/// Prefix/Suffix/PaddingWidth here has real effect on future-generated numbers.</summary>
public class RefNumberingRule
{
    public Guid NumberingRuleId { get; set; }
    public Guid TenantId { get; set; }
    public string EntityType { get; set; } = null!; // TAN, EmployeeId, OfferNumber, ...
    public string? Prefix { get; set; }
    public string? Suffix { get; set; }
    public string NumberFormat { get; set; } = null!;
    public int PaddingWidth { get; set; }
    public string ResetPolicy { get; set; } = null!;
    public long CurrentSequence { get; set; }
    public bool IsActive { get; set; }
    public int VersionNumber { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

/// <summary>Genuinely consulted at runtime by every *_ApprovalMatrixCode-driven approval
/// procedure (see 07-create-stored-procedures.sql) - the number of non-deleted
/// ApprovalMatrixRule rows for the active matrix determines how many human approval
/// steps a real request requires.</summary>
public class RefApprovalMatrix
{
    public Guid ApprovalMatrixId { get; set; }
    public Guid TenantId { get; set; }
    public string MatrixCode { get; set; } = null!;
    public string MatrixName { get; set; } = null!;
    public string EntityType { get; set; } = null!;
    public bool IsActive { get; set; }
    public int VersionNumber { get; set; }
    public string ApprovalStatus { get; set; } = null!;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

public class RefApprovalMatrixRule
{
    public Guid ApprovalMatrixRuleId { get; set; }
    public Guid ApprovalMatrixId { get; set; }
    public int StepOrder { get; set; }
    public Guid? ApproverRoleId { get; set; }
    public bool IsMandatory { get; set; }
    public string? ConditionExpression { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public byte[] RowVersion { get; set; } = null!;
}

/// <summary>Reference/documentation only - NOT consulted by any runtime procedure (see
/// ADR-006: each entity's real transitions are hardcoded per-procedure, not driven by a
/// generic engine). Read-only in the API/UI for exactly that reason - editing these rows
/// would have zero effect on real workflow behavior.</summary>
public class RefWorkflowDefinition
{
    public Guid WorkflowDefinitionId { get; set; }
    public Guid? TenantId { get; set; }
    public string WorkflowCode { get; set; } = null!;
    public string WorkflowName { get; set; } = null!;
    public string? Description { get; set; }
    public string EntityType { get; set; } = null!;
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
}

public class RefWorkflowStateDefinition
{
    public Guid WorkflowStateDefinitionId { get; set; }
    public Guid WorkflowDefinitionId { get; set; }
    public string StateCode { get; set; } = null!;
    public string StateName { get; set; } = null!;
    public bool IsInitialState { get; set; }
    public bool IsTerminalState { get; set; }
    public bool RequiresApproval { get; set; }
    public int SortOrder { get; set; }
    public bool IsDeleted { get; set; }
}

public class RefWorkflowTransitionDefinition
{
    public Guid WorkflowTransitionDefinitionId { get; set; }
    public Guid WorkflowDefinitionId { get; set; }
    public Guid FromStateId { get; set; }
    public Guid ToStateId { get; set; }
    public string TransitionCode { get; set; } = null!;
    public bool RequiresApproval { get; set; }
    public string? RequiredPermissionKey { get; set; }
    public bool IsDeleted { get; set; }
}
