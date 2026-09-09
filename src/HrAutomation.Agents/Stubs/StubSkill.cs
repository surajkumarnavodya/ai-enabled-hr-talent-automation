using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;

namespace HrAutomation.Agents.Stubs;

/// <summary>
/// Placeholder for the section-6 endpoints not yet implemented in this scaffold pass. Always
/// returns "blocked" with an explicit not-implemented risk - never a raw 404/500, and never
/// proposes a state transition, so the orchestrator leaves the workflow untouched (spec section 4:
/// fail closed).
/// </summary>
public sealed class StubSkill(string skillName, string skillVersion, IReadOnlyCollection<string> requiredRoles) : ISkill
{
    public string SkillName { get; } = skillName;
    public string SkillVersion { get; } = skillVersion;
    public IReadOnlyCollection<string> RequiredRoles { get; } = requiredRoles;

    public Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        return Task.FromResult(new SkillResult
        {
            Status = ActionStatus.blocked,
            Summary = $"Skill '{SkillName}' is not yet implemented in this scaffold.",
            RisksOrExceptions = [$"Skill '{SkillName}' v{SkillVersion} not yet implemented - requires human review before this capability can go live."]
        });
    }
}
