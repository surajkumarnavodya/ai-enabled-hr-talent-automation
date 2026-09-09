using System.Data;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;

namespace HrAutomation.Agents.Employees;

/// <summary>
/// Runs the two separately-gated human actions employee.usp_ApproveEmployeeConversion (records
/// the HR approval decision) and employee.usp_CreateEmployeeFromCandidate (creates the real
/// Employee ID) back to back, behind the single "Create Employee ID" confirmation the frontend
/// exposes. Both procedures independently re-validate the eligibility checklist server-side -
/// this skill never short-circuits that; it just chains two already-gated writes triggered by
/// the same human confirmation. See CLAUDE.md "AI may ... never autonomously create an Employee
/// ID" - this skill only executes after RequirePermissionAsync-equivalent role authorization
/// AND an explicit human confirmation dialog on the frontend.
/// </summary>
public sealed class EmployeeConversionSkill(HrAutomationDbContext db) : ISkill
{
    public string SkillName => "employee_conversion_skill";
    public string SkillVersion => "1.0.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["EMPLOYEE_ONBOARDING_ADMIN", "HR_ADMIN"];

    private const string ApprovalMatrixCode = "EMPLOYEE_CONVERSION_STD";

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        if (context.ApplicationId is null || !Guid.TryParse(context.ApplicationId, out var employeeConversionId))
        {
            // Reusing the generic ApplicationId slot for EmployeeConversionId - see
            // ApplicationsController.ConvertToEmployee, the only caller.
            throw new InvalidOperationException("EmployeeConversionSkill requires a valid EmployeeConversionId in the skill context.");
        }

        var tenantId = context.RequestContext.TenantId;
        var userId = context.RequestContext.UserId;

        var approveResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "employee.usp_ApproveEmployeeConversion",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@EmployeeConversionId", employeeConversionId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApproverUserId", userId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@ApprovalMatrixCode", ApprovalMatrixCode, SqlDbType.NVarChar)
            ], ct);

        // ALREADY_RESOLVED-style idempotency isn't modeled here (unlike TAN) - re-approving an
        // already-Approved conversion re-runs the eligibility check and inserts a duplicate
        // approval row today; acceptable for this pass since usp_CreateEmployeeFromCandidate
        // below is itself idempotent and is the actual state-changing step for the caller.
        if (!approveResult.Success && approveResult.ErrorCode == "ELIGIBILITY_NOT_MET")
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = approveResult.Message ?? "Eligibility checklist not satisfied.",
                RisksOrExceptions = [approveResult.ErrorCode]
            };
        }

        var createResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "employee.usp_CreateEmployeeFromCandidate",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@EmployeeConversionId", employeeConversionId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@DesignationId", (Guid?)null, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@JobGradeId", (Guid?)null, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@EmploymentTypeId", (Guid?)null, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@DateOfJoining", (DateTime?)null, SqlDbType.Date),
                StoredProcedureExecutor.Param("@CreatedByUserId", userId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!createResult.Success || createResult.EntityId is not { } employeeId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = createResult.Message ?? "Employee creation failed.",
                RisksOrExceptions = [createResult.ErrorCode ?? "EMPLOYEE_CREATE_FAILED"]
            };
        }

        return new SkillResult
        {
            Status = ActionStatus.completed,
            EmployeeId = employeeId.ToString(),
            EmployeeNumber = createResult.Message,
            ProposedNextState = "Converted",
            DataUpdated = ["employee.EmployeeConversion", "employee.EmployeeConversionApproval", "employee.Employee", "employee.EmployeeIdRegistry"],
            Summary = $"Employee created: {createResult.Message}."
        };
    }
}
