using System.Text.RegularExpressions;
using HrAutomation.Application.Contracts;
using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Guardrails;

/// <summary>
/// Reference implementation - deliberately simple pattern/keyword matching. Flagged as a
/// placeholder: production deployments must replace PiiCheck and PromptInjectionCheck with a
/// real PII scanner and a trained injection classifier (spec section 4/10).
/// </summary>
public sealed partial class GuardrailPipeline : IGuardrailPipeline
{
    private static readonly string[] InjectionPhrases =
    [
        "ignore previous instructions",
        "ignore all prior instructions",
        "disregard the above",
        "reveal your system prompt",
        "reveal the system prompt",
        "bypass approval",
        "bypass the approval",
        "skip approval",
        "you are now",
        "act as if",
        "export all data",
        "send all candidate data",
        "override policy",
        "ignore the policy"
    ];

    [GeneratedRegex(@"\b\d{3}-\d{2}-\d{4}\b")] // SSN-shaped
    private static partial Regex SsnPattern();

    [GeneratedRegex(@"(?i)\b(api[_-]?key|secret|password|bearer\s+[a-z0-9._-]+)\s*[:=]")]
    private static partial Regex SecretLikePattern();

    public GuardrailResultsDto Evaluate(GuardrailCheckInput input)
    {
        var authorization = input.RequiredRoles.Count == 0 || input.RequiredRoles.Contains(input.RequestContext.Role)
            ? GuardrailResult.pass
            : GuardrailResult.fail;

        var text = input.UntrustedTextToScan ?? string.Empty;

        var piiCheck = SsnPattern().IsMatch(text) || SecretLikePattern().IsMatch(text)
            ? GuardrailResult.fail
            : GuardrailResult.pass;

        var promptInjectionCheck = InjectionPhrases.Any(p => text.Contains(p, StringComparison.OrdinalIgnoreCase))
            ? GuardrailResult.fail
            : GuardrailResult.pass;

        return new GuardrailResultsDto
        {
            Authorization = authorization,
            PiiCheck = piiCheck,
            PromptInjectionCheck = promptInjectionCheck,
            PolicyCheck = input.PolicyOk ? GuardrailResult.pass : GuardrailResult.fail,
            SchemaValidation = input.SchemaValid ? GuardrailResult.pass : GuardrailResult.fail
        };
    }
}
