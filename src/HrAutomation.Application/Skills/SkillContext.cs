using HrAutomation.Application.Security;

namespace HrAutomation.Application.Skills;

/// <summary>
/// The minimal-context envelope passed into a skill (spec section 8): current workflow state,
/// least-required structured fields, and the requesting user - never the full DB, chat history,
/// or raw sensitive documents.
/// </summary>
public sealed class SkillContext
{
    public required RequestContext RequestContext { get; init; }
    public required Guid WorkflowInstanceId { get; init; }
    public string? TanId { get; init; }
    public string? CandidateId { get; init; }
    public string? ApplicationId { get; init; }

    /// <summary>The skill-specific input DTO (e.g. CreateTanRequest, CV upload metadata) - the skill casts this itself.</summary>
    public object? Input { get; init; }
}
