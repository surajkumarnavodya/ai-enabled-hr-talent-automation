using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Skills;

/// <summary>What a skill hands back to the orchestrator - enough to populate the response envelope
/// and to decide the next workflow state. A skill never returns a final HTTP response itself.</summary>
public sealed class SkillResult
{
    public required ActionStatus Status { get; init; }

    /// <summary>The resulting status code the skill's stored-procedure call applied (e.g.
    /// recruitment.JobRequisition.RequisitionStatusCode's new value) - not a fixed WorkflowState
    /// enum, since HrAutomationDb tracks status per entity, not via a generic state machine.</summary>
    public string? ProposedNextState { get; init; }
    public List<string> DataUpdated { get; init; } = [];
    public string Summary { get; init; } = string.Empty;
    public List<string> JobRelatedEvidence { get; init; } = [];
    public List<string> PolicySources { get; init; } = [];
    public decimal Confidence { get; init; }
    public List<string> RequiredApprovals { get; init; } = [];
    public List<string> RisksOrExceptions { get; init; } = [];
    public List<string> NextAllowedActions { get; init; } = [];

    /// <summary>Populated when the skill created/resolved these identities (e.g. new candidate/TAN).</summary>
    public string? CandidateId { get; init; }
    public string? TanId { get; init; }
    public string? ApplicationId { get; init; }
}
