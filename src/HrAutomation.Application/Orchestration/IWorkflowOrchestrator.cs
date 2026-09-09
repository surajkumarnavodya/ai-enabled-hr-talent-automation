using HrAutomation.Application.Contracts;
using HrAutomation.Application.Security;
using HrAutomation.Application.Skills;

namespace HrAutomation.Application.Orchestration;

public sealed class OrchestratorRequest
{
    public required RequestContext RequestContext { get; init; }

    /// <summary>Short verb-style action name for the response envelope, e.g. "create_tan", "upload_cv".</summary>
    public required string Action { get; init; }

    /// <summary>Entity type + id the skill acts on (e.g. "recruitment.JobRequisition"), used to look
    /// up the current approval-gate status. See ApprovalGateService.</summary>
    public required string EntityType { get; init; }
    public required Guid EntityId { get; init; }

    public required ISkill Skill { get; init; }
    public object? SkillInput { get; init; }
    public string? TanId { get; init; }
    public string? CandidateId { get; init; }
    public string? ApplicationId { get; init; }

    /// <summary>Set when this action requires a prior human-approved workflow.ApprovalRequest for
    /// EntityType/EntityId before the skill may run (spec section 2).</summary>
    public bool RequiresPriorApproval { get; init; }

    /// <summary>Untrusted free text (CV/JD content etc.) to run through the prompt-injection guardrail.</summary>
    public string? UntrustedTextToScan { get; init; }
}

/// <summary>
/// The HR Workflow Orchestrator Agent (spec section 3.A): the single place guardrails and the
/// approval-gate pre-check run before a skill executes. Unlike the original scaffold, it does not
/// own state-transition validity itself - each stored procedure a skill calls
/// (../../HrAutomation.Infrastructure/Database/scripts/07-create-stored-procedures.sql) enforces its
/// own transition rules atomically with the write, since HrAutomationDb has no generic
/// WorkflowInstance/state-machine table backing these flows. The orchestrator still never lets a
/// skill decide on its own whether it's allowed to run, and always returns the standard
/// AgentActionResponse envelope.
/// </summary>
public interface IWorkflowOrchestrator
{
    Task<AgentActionResponse> ExecuteAsync(OrchestratorRequest request, CancellationToken ct = default);
}
