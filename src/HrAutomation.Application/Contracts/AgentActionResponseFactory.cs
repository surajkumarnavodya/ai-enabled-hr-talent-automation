using HrAutomation.Application.Security;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Contracts;

/// <summary>
/// Assembles the section-12 response envelope from a skill result. Used directly by controllers
/// for bootstrap actions that have no prior workflow instance (CV upload, TAN creation), and by
/// IWorkflowOrchestrator for every gated state-transition action.
/// </summary>
public static class AgentActionResponseFactory
{
    public static AgentActionResponse Build(
        RequestContext requestContext,
        string action,
        string workflowId,
        string currentState,
        string? proposedNextState,
        SkillResult skillResult,
        GuardrailResultsDto guardrailResults,
        string actorId,
        ActorType actorType = ActorType.agent)
    {
        return new AgentActionResponse
        {
            RequestId = Guid.NewGuid().ToString(),
            TraceId = requestContext.TraceId,
            TenantId = requestContext.TenantId.ToString(),
            Action = action,
            ActionStatus = skillResult.Status,
            WorkflowId = workflowId,
            TanId = skillResult.TanId,
            CandidateId = skillResult.CandidateId,
            ApplicationId = skillResult.ApplicationId,
            CurrentState = currentState,
            ProposedNextState = proposedNextState,
            DataUpdated = skillResult.DataUpdated,
            Explanation = new ExplanationDto
            {
                Summary = skillResult.Summary,
                JobRelatedEvidence = skillResult.JobRelatedEvidence,
                PolicySources = skillResult.PolicySources,
                Confidence = skillResult.Confidence
            },
            RequiredApprovals = skillResult.RequiredApprovals,
            GuardrailResults = guardrailResults,
            RisksOrExceptions = skillResult.RisksOrExceptions,
            NextAllowedActions = skillResult.NextAllowedActions,
            AuditEvent = new AuditEventDto
            {
                EventType = action,
                TimestampUtc = DateTime.UtcNow,
                ActorType = actorType,
                ActorId = actorId
            }
        };
    }
}
