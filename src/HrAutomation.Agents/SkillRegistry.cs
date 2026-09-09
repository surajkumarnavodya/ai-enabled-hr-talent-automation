using HrAutomation.Application.Skills;

namespace HrAutomation.Agents;

public sealed class SkillRegistry : ISkillRegistry
{
    private readonly Dictionary<string, ISkill> _skills;

    public SkillRegistry(IEnumerable<ISkill> skills)
    {
        _skills = skills.ToDictionary(s => s.SkillName, StringComparer.OrdinalIgnoreCase);
    }

    public ISkill Get(string skillName)
    {
        if (!_skills.TryGetValue(skillName, out var skill))
        {
            throw new InvalidOperationException($"Skill '{skillName}' is not registered.");
        }

        return skill;
    }
}
