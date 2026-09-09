namespace HrAutomation.Application.Skills;

/// <summary>
/// A versioned, least-privilege capability module (spec section 8). Concrete skills live in
/// HrAutomation.Agents. The orchestrator - never the skill itself - decides whether the proposed
/// state transition and required approvals allow execution to actually happen.
/// </summary>
public interface ISkill
{
    string SkillName { get; }
    string SkillVersion { get; }

    /// <summary>iam.Role.RoleName codes (e.g. "RECRUITER") - see RequestContext.Role.</summary>
    IReadOnlyCollection<string> RequiredRoles { get; }

    Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default);
}
