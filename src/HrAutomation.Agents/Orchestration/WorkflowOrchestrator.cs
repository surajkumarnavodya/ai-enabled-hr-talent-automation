using HrAutomation.Application.Approvals;
using HrAutomation.Application.Audit;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Orchestration;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;

namespace HrAutomation.Agents.Orchestration;

/// <summary>
/// The HR Workflow Orchestrator Agent (spec 3.A): guardrails -> approval-gate pre-check -> skill
/// execution -> audit. Unlike the original scaffold, it does not load or mutate a WorkflowInstance
/// row itself - HrAutomationDb has no generic workflow-engine table for these flows; each skill's
/// stored-procedure call (see ../../HrAutomation.Infrastructure/Database/scripts/07-create-stored-
/// procedures.sql) applies its own state transition atomically and reports the result back via
/// SkillResult.ProposedNextState. A skill can only ever propose/report a next state - the
/// orchestrator is still the only component that decides whether execution is allowed to happen.
/// </summary>
public sealed class WorkflowOrchestrator(
    IApprovalGateService approvalGate,
    IAuditLogger auditLogger,
    IGuardrailPipeline guardrails) : IWorkflowOrchestrator
{
    public async Task<AgentActionResponse> ExecuteAsync(OrchestratorRequest request, CancellationToken ct = default)
    {
        var guardrailResults = guardrails.Evaluate(new GuardrailCheckInput
        {
            RequestContext = request.RequestContext,
            RequiredRoles = request.Skill.RequiredRoles,
            UntrustedTextToScan = request.UntrustedTextToScan
        });

        if (!guardrailResults.AllPass)
        {
            return AgentActionResponseFactory.Build(
                request.RequestContext, request.Action, request.EntityId.ToString(), "Unknown", null,
                new SkillResult
                {
                    Status = ActionStatus.blocked,
                    Summary = "Blocked by guardrail check.",
                    RisksOrExceptions = ["One or more guardrail checks failed - see guardrail_results."]
                },
                guardrailResults, actorId: request.Skill.SkillName);
        }

        if (request.RequiresPriorApproval)
        {
            var check = await approvalGate.CheckAsync(request.EntityType, request.EntityId, ct);
            if (!check.IsApproved)
            {
                return AgentActionResponseFactory.Build(
                    request.RequestContext, request.Action, request.EntityId.ToString(), check.Status ?? "Unknown", null,
                    new SkillResult
                    {
                        Status = ActionStatus.pending_approval,
                        Summary = "Human approval required before this action can proceed.",
                        RequiredApprovals = check.ApprovalRequestId is { } id
                            ? [$"{request.EntityType}:{id}"]
                            : [$"{request.EntityType}:none-pending - submit for approval first"]
                    },
                    guardrailResults, actorId: request.Skill.SkillName);
            }
        }

        var skillResult = await request.Skill.ExecuteAsync(new SkillContext
        {
            RequestContext = request.RequestContext,
            WorkflowInstanceId = request.EntityId,
            TanId = request.TanId,
            CandidateId = request.CandidateId,
            ApplicationId = request.ApplicationId,
            Input = request.SkillInput
        }, ct);

        var applied = skillResult.Status == ActionStatus.completed && skillResult.ProposedNextState is not null;

        // Skills persist via the stored procedures above, which already write their own
        // audit.usp_WriteAuditEvent row; this is the orchestrator-level record of the action as a
        // whole (guardrail/approval-gate outcome included), a coarser sibling entry, not a duplicate.
        await auditLogger.LogAsync(new AuditLogEntry
        {
            TenantId = request.RequestContext.TenantId,
            EventType = request.Action,
            ActorType = ActorType.agent,
            ActorId = request.Skill.SkillName,
            TanId = skillResult.TanId ?? request.TanId,
            CandidateId = skillResult.CandidateId ?? request.CandidateId,
            ApplicationId = skillResult.ApplicationId ?? request.ApplicationId,
            CorrelationId = request.RequestContext.CorrelationId,
            NewStatus = skillResult.ProposedNextState,
            DetailsJson = "{}"
        }, ct);

        return AgentActionResponseFactory.Build(
            request.RequestContext, request.Action, request.EntityId.ToString(),
            applied ? skillResult.ProposedNextState! : "Unknown",
            applied ? null : skillResult.ProposedNextState,
            skillResult, guardrailResults, actorId: request.Skill.SkillName);
    }
}
