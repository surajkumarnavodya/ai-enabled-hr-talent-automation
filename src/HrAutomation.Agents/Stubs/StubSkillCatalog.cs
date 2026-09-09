using HrAutomation.Application.Skills;

namespace HrAutomation.Agents.Stubs;

/// <summary>Central list of the not-yet-implemented skills backing the remaining section-6 routes,
/// so Program.cs can register them in one loop instead of one DI line per skill. Role codes are
/// iam.Role.RoleName values from HrAutomationDb (see Database/seed/02-seed-iam-roles-permissions.sql).</summary>
public static class StubSkillCatalog
{
    public static IReadOnlyList<ISkill> CreateAll() =>
    [
        new StubSkill("match_candidates_skill", "0.1.0", ["RECRUITER", "HR_ADMIN"]),
        new StubSkill("progression_approval_skill", "0.1.0", ["HR_ADMIN", "HIRING_MANAGER"]),
        new StubSkill("document_verify_skill", "0.1.0", ["DOCUMENT_VERIFIER"])
    ];
}
