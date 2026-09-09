namespace HrAutomation.Application.Skills;

/// <summary>Looks up a registered skill by its stable SkillName - lets controllers resolve the right
/// capability without depending on concrete skill types from HrAutomation.Agents.</summary>
public interface ISkillRegistry
{
    ISkill Get(string skillName);
}
