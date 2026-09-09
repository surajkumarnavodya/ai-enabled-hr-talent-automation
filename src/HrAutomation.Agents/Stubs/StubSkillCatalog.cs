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
        new StubSkill("shortlist_approval_skill", "0.1.0", ["HR_ADMIN", "TALENT_ACQUISITION_MANAGER"]),
        new StubSkill("create_interview_skill", "0.1.0", ["RECRUITER", "HR_ADMIN"]),
        new StubSkill("interview_feedback_skill", "0.1.0", ["INTERVIEWER"]),
        new StubSkill("progression_approval_skill", "0.1.0", ["HR_ADMIN", "HIRING_MANAGER"]),
        new StubSkill("create_offer_skill", "0.1.0", ["HR_ADMIN"]),
        new StubSkill("offer_approval_skill", "0.1.0", ["OFFER_APPROVER"]),
        new StubSkill("offer_send_skill", "0.1.0", ["HR_ADMIN"]),
        new StubSkill("offer_acceptance_skill", "0.1.0", ["CANDIDATE_PORTAL_USER"]),
        new StubSkill("green_form_issue_link_skill", "0.1.0", ["HR_ADMIN", "RECRUITER"]),
        new StubSkill("document_verify_skill", "0.1.0", ["DOCUMENT_VERIFIER"]),
        new StubSkill("discrepancy_resolve_skill", "0.1.0", ["HR_ADMIN"]),
        new StubSkill("employee_conversion_skill", "0.1.0", ["EMPLOYEE_ONBOARDING_ADMIN"])
    ];
}
