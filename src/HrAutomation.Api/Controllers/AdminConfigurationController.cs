using HrAutomation.Application.Contracts;
using HrAutomation.Application.Security;
using HrAutomation.Application.Audit;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace HrAutomation.Api.Controllers;

/// <summary>
/// Real, SQL-Server-backed admin configuration: tenant profile, numbering rules, and
/// approval matrix rules - the three genuinely-enforced-at-runtime pieces of
/// configuration this platform has (see 07-create-stored-procedures.sql "ADMINISTRATION"
/// section for exactly how each is consulted). Workflow definitions are exposed
/// read-only, honestly labeled as reference documentation per ADR-006 - editing them
/// would have zero effect on real transition behavior, so no write path exists for
/// them (see design precedent: AdminFeatureFlagsPage/AdminRolesPage are also
/// deliberately read-only for the same "don't fake a control that does nothing" reason).
/// </summary>
[Route("api/v1/admin")]
public sealed class AdminConfigurationController(
    HrAutomationDbContext db,
    IEffectivePermissionService permissions,
    IAuditLogger auditLogger) : HrControllerBase
{
    [HttpGet("tenant-profile")]
    public async Task<IActionResult> GetTenantProfile(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "tenant.read", ct);
        if (denied is not null) return denied;

        var tenant = await db.Tenants.FirstOrDefaultAsync(t => t.TenantId == ctx.TenantId, ct);
        if (tenant is null) return NotFound();

        return Ok(new TenantProfileDto
        {
            TenantId = tenant.TenantId,
            TenantCode = tenant.TenantCode,
            TenantName = tenant.TenantName,
            LegalName = tenant.LegalName,
            PrimaryDomain = tenant.PrimaryDomain,
            RowVersion = Convert.ToBase64String(tenant.RowVersion)
        });
    }

    [HttpPatch("tenant-profile")]
    public async Task<IActionResult> UpdateTenantProfile([FromBody] UpdateTenantProfileRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "tenant.manage", ct);
        if (denied is not null) return denied;

        var result = await StoredProcedureExecutor.ExecuteAsync(db.Database, "org.usp_UpdateTenantProfile",
        [
            StoredProcedureExecutor.Param("@TenantId", ctx.TenantId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@TenantName", request.TenantName, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@LegalName", request.LegalName, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@PrimaryDomain", request.PrimaryDomain, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@UpdatedByUserId", ctx.UserId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@RowVersion", Convert.FromBase64String(request.RowVersion), SqlDbType.Binary),
        ], ct);

        return ToActionResult(result);
    }

    [HttpGet("numbering-rules")]
    public async Task<IActionResult> ListNumberingRules(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "configuration.read", ct);
        if (denied is not null) return denied;

        var rules = await db.NumberingRules
            .Where(r => r.TenantId == ctx.TenantId)
            .OrderBy(r => r.EntityType)
            .ToListAsync(ct);

        return Ok(rules.Select(ToDto).ToList());
    }

    [HttpPatch("numbering-rules/{numberingRuleId:guid}")]
    public async Task<IActionResult> UpdateNumberingRule(Guid numberingRuleId, [FromBody] UpdateNumberingRuleRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "configuration.manage", ct);
        if (denied is not null) return denied;

        var result = await StoredProcedureExecutor.ExecuteAsync(db.Database, "ref.usp_UpdateNumberingRule",
        [
            StoredProcedureExecutor.Param("@TenantId", ctx.TenantId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@NumberingRuleId", numberingRuleId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@Prefix", request.Prefix, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@Suffix", request.Suffix, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@PaddingWidth", request.PaddingWidth, SqlDbType.Int),
            StoredProcedureExecutor.Param("@UpdatedByUserId", ctx.UserId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@RowVersion", Convert.FromBase64String(request.RowVersion), SqlDbType.Binary),
        ], ct);

        return ToActionResult(result);
    }

    [HttpGet("approval-matrices")]
    public async Task<IActionResult> ListApprovalMatrices(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "workflow.read", ct);
        if (denied is not null) return denied;

        var matrices = await db.ApprovalMatrices
            .Where(m => m.TenantId == ctx.TenantId)
            .OrderBy(m => m.EntityType).ThenBy(m => m.MatrixCode)
            .ToListAsync(ct);

        var matrixIds = matrices.Select(m => m.ApprovalMatrixId).ToList();

        var rules = await (
            from rule in db.ApprovalMatrixRules
            where matrixIds.Contains(rule.ApprovalMatrixId)
            join role in db.Roles on rule.ApproverRoleId equals role.RoleId into roleJoin
            from role in roleJoin.DefaultIfEmpty()
            orderby rule.StepOrder
            select new { rule, RoleName = role != null ? role.RoleName : null }
        ).ToListAsync(ct);

        var dtos = matrices.Select(m => new ApprovalMatrixDto
        {
            ApprovalMatrixId = m.ApprovalMatrixId,
            MatrixCode = m.MatrixCode,
            MatrixName = m.MatrixName,
            EntityType = m.EntityType,
            IsActive = m.IsActive,
            Rules = rules.Where(r => r.rule.ApprovalMatrixId == m.ApprovalMatrixId)
                .Select(r => new ApprovalMatrixRuleDto
                {
                    ApprovalMatrixRuleId = r.rule.ApprovalMatrixRuleId,
                    StepOrder = r.rule.StepOrder,
                    ApproverRoleId = r.rule.ApproverRoleId,
                    ApproverRoleName = r.RoleName,
                    IsMandatory = r.rule.IsMandatory,
                    ConditionExpression = r.rule.ConditionExpression,
                    RowVersion = Convert.ToBase64String(r.rule.RowVersion)
                }).ToList()
        }).ToList();

        return Ok(dtos);
    }

    [HttpGet("approval-matrices/roles")]
    public async Task<IActionResult> ListApproverRoleOptions(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "workflow.read", ct);
        if (denied is not null) return denied;

        var roles = await db.Roles
            .Where(r => (r.TenantId == null || r.TenantId == ctx.TenantId) && r.IsActive)
            .OrderBy(r => r.RoleName)
            .Select(r => new RoleOptionDto { RoleId = r.RoleId, RoleName = r.RoleName })
            .ToListAsync(ct);

        return Ok(roles);
    }

    [HttpPost("approval-matrices/{matrixId:guid}/rules")]
    public async Task<IActionResult> AddApprovalMatrixRule(Guid matrixId, [FromBody] AddApprovalMatrixRuleRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "workflow.manage", ct);
        if (denied is not null) return denied;

        var result = await StoredProcedureExecutor.ExecuteAsync(db.Database, "ref.usp_AddApprovalMatrixRule",
        [
            StoredProcedureExecutor.Param("@TenantId", ctx.TenantId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@ApprovalMatrixId", matrixId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@StepOrder", request.StepOrder, SqlDbType.Int),
            StoredProcedureExecutor.Param("@ApproverRoleId", request.ApproverRoleId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@IsMandatory", request.IsMandatory, SqlDbType.Bit),
            StoredProcedureExecutor.Param("@ConditionExpression", request.ConditionExpression, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@CreatedByUserId", ctx.UserId, SqlDbType.UniqueIdentifier),
        ], ct);

        return ToActionResult(result);
    }

    [HttpPatch("approval-matrices/{matrixId:guid}/rules/{ruleId:guid}")]
    public async Task<IActionResult> UpdateApprovalMatrixRule(Guid matrixId, Guid ruleId, [FromBody] UpdateApprovalMatrixRuleRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "workflow.manage", ct);
        if (denied is not null) return denied;

        var result = await StoredProcedureExecutor.ExecuteAsync(db.Database, "ref.usp_UpdateApprovalMatrixRule",
        [
            StoredProcedureExecutor.Param("@TenantId", ctx.TenantId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@ApprovalMatrixRuleId", ruleId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@StepOrder", request.StepOrder, SqlDbType.Int),
            StoredProcedureExecutor.Param("@ApproverRoleId", request.ApproverRoleId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@IsMandatory", request.IsMandatory, SqlDbType.Bit),
            StoredProcedureExecutor.Param("@ConditionExpression", request.ConditionExpression, SqlDbType.NVarChar),
            StoredProcedureExecutor.Param("@UpdatedByUserId", ctx.UserId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@RowVersion", Convert.FromBase64String(request.RowVersion), SqlDbType.Binary),
        ], ct);

        return ToActionResult(result);
    }

    [HttpDelete("approval-matrices/{matrixId:guid}/rules/{ruleId:guid}")]
    public async Task<IActionResult> DeleteApprovalMatrixRule(Guid matrixId, Guid ruleId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "workflow.manage", ct);
        if (denied is not null) return denied;

        var result = await StoredProcedureExecutor.ExecuteAsync(db.Database, "ref.usp_DeleteApprovalMatrixRule",
        [
            StoredProcedureExecutor.Param("@TenantId", ctx.TenantId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@ApprovalMatrixRuleId", ruleId, SqlDbType.UniqueIdentifier),
            StoredProcedureExecutor.Param("@DeletedByUserId", ctx.UserId, SqlDbType.UniqueIdentifier),
        ], ct);

        return ToActionResult(result);
    }

    /// <summary>Read-only reference/documentation view - see class header comment and
    /// ADR-006. Deliberately has no corresponding write endpoint.</summary>
    [HttpGet("workflow-definitions")]
    public async Task<IActionResult> ListWorkflowDefinitions(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var denied = await RequirePermissionAsync(permissions, auditLogger, ctx, "workflow.read", ct);
        if (denied is not null) return denied;

        var definitions = await db.WorkflowDefinitions
            .Where(w => w.TenantId == null || w.TenantId == ctx.TenantId)
            .OrderBy(w => w.WorkflowCode)
            .ToListAsync(ct);

        var defIds = definitions.Select(d => d.WorkflowDefinitionId).ToList();

        var states = await db.WorkflowStateDefinitions
            .Where(s => defIds.Contains(s.WorkflowDefinitionId))
            .OrderBy(s => s.SortOrder)
            .ToListAsync(ct);

        var transitions = await db.WorkflowTransitionDefinitions
            .Where(t => defIds.Contains(t.WorkflowDefinitionId))
            .ToListAsync(ct);

        var dtos = definitions.Select(d => new WorkflowDefinitionDto
        {
            WorkflowDefinitionId = d.WorkflowDefinitionId,
            WorkflowCode = d.WorkflowCode,
            WorkflowName = d.WorkflowName,
            Description = d.Description,
            EntityType = d.EntityType,
            States = states.Where(s => s.WorkflowDefinitionId == d.WorkflowDefinitionId)
                .Select(s => new WorkflowStateDto
                {
                    WorkflowStateDefinitionId = s.WorkflowStateDefinitionId,
                    StateCode = s.StateCode,
                    StateName = s.StateName,
                    IsInitialState = s.IsInitialState,
                    IsTerminalState = s.IsTerminalState,
                    RequiresApproval = s.RequiresApproval,
                    SortOrder = s.SortOrder
                }).ToList(),
            Transitions = transitions.Where(t => t.WorkflowDefinitionId == d.WorkflowDefinitionId)
                .Select(t => new WorkflowTransitionDto
                {
                    WorkflowTransitionDefinitionId = t.WorkflowTransitionDefinitionId,
                    FromStateId = t.FromStateId,
                    ToStateId = t.ToStateId,
                    TransitionCode = t.TransitionCode,
                    RequiresApproval = t.RequiresApproval
                }).ToList()
        }).ToList();

        return Ok(dtos);
    }

    private static NumberingRuleDto ToDto(Infrastructure.Persistence.Entities.RefNumberingRule r) => new()
    {
        NumberingRuleId = r.NumberingRuleId,
        EntityType = r.EntityType,
        Prefix = r.Prefix,
        Suffix = r.Suffix,
        NumberFormat = r.NumberFormat,
        PaddingWidth = r.PaddingWidth,
        ResetPolicy = r.ResetPolicy,
        CurrentSequence = r.CurrentSequence,
        IsActive = r.IsActive,
        NextPreview = (r.Prefix ?? "") + (r.CurrentSequence + 1).ToString().PadLeft(r.PaddingWidth, '0') + (r.Suffix ?? ""),
        RowVersion = Convert.ToBase64String(r.RowVersion)
    };

    /// <summary>Uniform mapping from the ADR-006 ProcResult shape to an HTTP response -
    /// NOT_FOUND -> 404, CONCURRENCY_CONFLICT -> 409, every other failure -> 422 (business
    /// validation, e.g. MIN_APPROVAL_STEPS_REQUIRED/DUPLICATE_STEP_ORDER/INVALID_PADDING_WIDTH).</summary>
    /// <summary>Maps the ADR-006 ProcResult shape to an HTTP response. Failures are RFC 7807
    /// Problem Details (not the AdminOperationResultDto envelope) specifically so the crafted,
    /// user-safe `result.Message` (e.g. "This matrix must keep at least one mandatory approval
    /// step...") reaches the UI — HrAutomation.Web's response interceptor reads `detail`/`title`
    /// off Problem Details responses, not an arbitrary custom shape (see
    /// api/client/requestInterceptors.ts onResponseError).</summary>
    private IActionResult ToActionResult(ProcResult result)
    {
        if (result.Success)
        {
            return Ok(new AdminOperationResultDto
            {
                Success = true,
                Message = result.Message,
                EntityId = result.EntityId,
                ErrorCode = null
            });
        }

        var statusCode = result.ErrorCode switch
        {
            "NOT_FOUND" => StatusCodes.Status404NotFound,
            "CONCURRENCY_CONFLICT" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status422UnprocessableEntity
        };

        return Problem(statusCode: statusCode, title: result.ErrorCode ?? "Request failed", detail: result.Message);
    }
}
