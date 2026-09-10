namespace HrAutomation.Application.Contracts;

/// <summary>DTOs for GET/PATCH /api/v1/admin/tenant-profile, /numbering-rules,
/// /approval-matrices, /workflow-definitions. See AdminConfigurationController and
/// 07-create-stored-procedures.sql "ADMINISTRATION" section for which of these are
/// genuinely enforced at runtime (tenant profile, numbering rules, approval matrix
/// rules) versus read-only reference documentation (workflow definitions - see
/// ADR-006; editing them would have zero effect on real behavior, so no write DTO
/// exists for them).</summary>
public sealed class TenantProfileDto
{
    public required Guid TenantId { get; init; }
    public required string TenantCode { get; init; }
    public required string TenantName { get; init; }
    public string? LegalName { get; init; }
    public string? PrimaryDomain { get; init; }
    public required string RowVersion { get; init; }
}

public sealed class UpdateTenantProfileRequest
{
    public required string TenantName { get; init; }
    public string? LegalName { get; init; }
    public string? PrimaryDomain { get; init; }
    public required string RowVersion { get; init; }
}

public sealed class NumberingRuleDto
{
    public required Guid NumberingRuleId { get; init; }
    public required string EntityType { get; init; }
    public string? Prefix { get; init; }
    public string? Suffix { get; init; }
    public required string NumberFormat { get; init; }
    public required int PaddingWidth { get; init; }
    public required string ResetPolicy { get; init; }
    public required long CurrentSequence { get; init; }
    public required bool IsActive { get; init; }
    /// <summary>Preview of the next number this rule would issue with its current
    /// settings - computed server-side, never a value the client should compute itself.</summary>
    public required string NextPreview { get; init; }
    public required string RowVersion { get; init; }
}

public sealed class UpdateNumberingRuleRequest
{
    public string? Prefix { get; init; }
    public string? Suffix { get; init; }
    public required int PaddingWidth { get; init; }
    public required string RowVersion { get; init; }
}

public sealed class ApprovalMatrixRuleDto
{
    public required Guid ApprovalMatrixRuleId { get; init; }
    public required int StepOrder { get; init; }
    public Guid? ApproverRoleId { get; init; }
    public string? ApproverRoleName { get; init; }
    public required bool IsMandatory { get; init; }
    public string? ConditionExpression { get; init; }
    public required string RowVersion { get; init; }
}

public sealed class ApprovalMatrixDto
{
    public required Guid ApprovalMatrixId { get; init; }
    public required string MatrixCode { get; init; }
    public required string MatrixName { get; init; }
    public required string EntityType { get; init; }
    public required bool IsActive { get; init; }
    public required IReadOnlyList<ApprovalMatrixRuleDto> Rules { get; init; }
}

public sealed class AddApprovalMatrixRuleRequest
{
    public required int StepOrder { get; init; }
    public Guid? ApproverRoleId { get; init; }
    public bool IsMandatory { get; init; } = true;
    public string? ConditionExpression { get; init; }
}

public sealed class UpdateApprovalMatrixRuleRequest
{
    public required int StepOrder { get; init; }
    public Guid? ApproverRoleId { get; init; }
    public required bool IsMandatory { get; init; }
    public string? ConditionExpression { get; init; }
    public required string RowVersion { get; init; }
}

/// <summary>Reference/documentation view only (ADR-006: no generic workflow engine
/// consults these rows at runtime - each entity's real transitions are hardcoded per
/// stored procedure). No write DTO exists for this on purpose.</summary>
public sealed class WorkflowDefinitionDto
{
    public required Guid WorkflowDefinitionId { get; init; }
    public required string WorkflowCode { get; init; }
    public required string WorkflowName { get; init; }
    public string? Description { get; init; }
    public required string EntityType { get; init; }
    public required IReadOnlyList<WorkflowStateDto> States { get; init; }
    public required IReadOnlyList<WorkflowTransitionDto> Transitions { get; init; }
}

public sealed class WorkflowStateDto
{
    public required Guid WorkflowStateDefinitionId { get; init; }
    public required string StateCode { get; init; }
    public required string StateName { get; init; }
    public required bool IsInitialState { get; init; }
    public required bool IsTerminalState { get; init; }
    public required bool RequiresApproval { get; init; }
    public required int SortOrder { get; init; }
}

public sealed class WorkflowTransitionDto
{
    public required Guid WorkflowTransitionDefinitionId { get; init; }
    public required Guid FromStateId { get; init; }
    public required Guid ToStateId { get; init; }
    public required string TransitionCode { get; init; }
    public required bool RequiresApproval { get; init; }
}

public sealed class RoleOptionDto
{
    public required Guid RoleId { get; init; }
    public required string RoleName { get; init; }
}

public sealed class AdminOperationResultDto
{
    public required bool Success { get; init; }
    public string? Message { get; init; }
    public Guid? EntityId { get; init; }
    public string? ErrorCode { get; init; }
}
