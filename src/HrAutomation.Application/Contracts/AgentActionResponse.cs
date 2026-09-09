using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Contracts;

/// <summary>
/// The exact response envelope required by spec section 12. Returned by every action-style
/// endpoint (a POST that mutates workflow state). Serialized with snake_case property naming -
/// see Program.cs JSON options - so C# stays PascalCase while the wire format matches the spec
/// verbatim (request_id, action_status, guardrail_results.pii_check, etc.).
/// </summary>
public sealed class AgentActionResponse
{
    public required string RequestId { get; init; }
    public required string TraceId { get; init; }
    public required string TenantId { get; init; }
    public required string Action { get; init; }
    public required ActionStatus ActionStatus { get; init; }
    public required string WorkflowId { get; init; }
    public string? TanId { get; init; }
    public string? CandidateId { get; init; }
    public string? ApplicationId { get; init; }
    public string? InterviewRoundId { get; init; }
    public string? OfferId { get; init; }
    public string? GreenFormSubmissionId { get; init; }
    public string? EmployeeId { get; init; }
    public string? EmployeeNumber { get; init; }
    public required string CurrentState { get; init; }
    public string? ProposedNextState { get; init; }
    public List<string> DataUpdated { get; init; } = [];
    public required ExplanationDto Explanation { get; init; }
    public List<string> RequiredApprovals { get; init; } = [];
    public required GuardrailResultsDto GuardrailResults { get; init; }
    public List<string> RisksOrExceptions { get; init; } = [];
    public List<string> NextAllowedActions { get; init; } = [];
    public required AuditEventDto AuditEvent { get; init; }
}

public sealed class ExplanationDto
{
    public string Summary { get; init; } = string.Empty;
    public List<string> JobRelatedEvidence { get; init; } = [];
    public List<string> PolicySources { get; init; } = [];
    public decimal Confidence { get; init; }
}

public sealed class GuardrailResultsDto
{
    public required GuardrailResult Authorization { get; init; }
    public required GuardrailResult PiiCheck { get; init; }
    public required GuardrailResult PromptInjectionCheck { get; init; }
    public required GuardrailResult PolicyCheck { get; init; }
    public required GuardrailResult SchemaValidation { get; init; }

    public bool AllPass =>
        Authorization == GuardrailResult.pass &&
        PiiCheck == GuardrailResult.pass &&
        PromptInjectionCheck == GuardrailResult.pass &&
        PolicyCheck == GuardrailResult.pass &&
        SchemaValidation == GuardrailResult.pass;
}

public sealed class AuditEventDto
{
    public required string EventType { get; init; }
    public required DateTime TimestampUtc { get; init; }
    public required ActorType ActorType { get; init; }
    public required string ActorId { get; init; }
}
