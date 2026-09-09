using HrAutomation.Application.Contracts;
using HrAutomation.Application.Security;
using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Guardrails;

public sealed class GuardrailCheckInput
{
    public required RequestContext RequestContext { get; init; }
    public required IReadOnlyCollection<string> RequiredRoles { get; init; }

    /// <summary>Untrusted text pulled from a CV, JD, retrieved policy chunk, or tool output - scanned for
    /// injection phrases. Never treated as instructions, only as data (spec section 4).</summary>
    public string? UntrustedTextToScan { get; init; }

    public bool SchemaValid { get; init; } = true;
    public bool PolicyOk { get; init; } = true;
}

/// <summary>
/// Runs before any tool/skill execution and fails closed: any single "fail" blocks the action
/// (spec section 4). Populates guardrail_results on every response.
/// </summary>
public interface IGuardrailPipeline
{
    GuardrailResultsDto Evaluate(GuardrailCheckInput input);
}
