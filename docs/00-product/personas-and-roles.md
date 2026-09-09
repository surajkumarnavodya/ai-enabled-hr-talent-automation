# Personas and Roles

> Title: Personas and Roles | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, HR, Security

## Purpose and scope

Defines the human and system personas that interact with the platform, and maps each to the role-based access control (RBAC) roles used throughout [identity-access-control.md](../05-security-governance/identity-access-control.md) and the [human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md). Configurable per tenant: role names, department scoping, and delegation rules — [TENANT_CONFIGURATION_REQUIRED].

## Personas

| Persona | Description | Primary goals | System role(s) |
|---|---|---|---|
| Recruiter | Sources and manages candidates against TANs | Fast, high-quality shortlists | `recruiter` |
| Hiring Manager | Owns the job requisition and final selection call | Hire the right candidate quickly | `hiring_manager` |
| HR Approver | Approves TANs, shortlists, offers, discrepancy closure, employee conversion | Governance and compliance of every gate | `hr_approver` |
| Interview Panelist | Conducts and scores interviews | Structured, fair feedback | `interviewer` |
| HR Operations (Onboarding) | Manages Green Form, document verification, employee conversion | Clean, complete onboarding data | `hr_ops` |
| Candidate | Applies, interviews, accepts offer, submits Green Form/documents | Transparent, fast process | `candidate` (external, scoped identity) |
| Compliance / Security Reviewer | Audits AI decisions, approvals, and access | Policy adherence, fairness, security | `compliance_reviewer` |
| Platform Administrator | Configures tenants, workflow, roles, integrations | Safe, correct configuration | `platform_admin` |
| System Integrator / Developer | Builds and maintains integrations, MCP servers, agents | Reliable, secure automation | `integration_engineer` |
| AI Agent (non-human actor) | Executes skills: extract, match, draft, route, alert | Assist without deciding | `agent_service_principal` (least privilege, no approval rights) |

## Role responsibility summary

| Role | Can request | Can approve | Cannot do |
|---|---|---|---|
| `recruiter` | TAN creation, shortlist request, interview scheduling | — | Approve own TAN, approve own shortlist, approve offers |
| `hiring_manager` | Final-selection request | Final selection (subject to HR approval matrix) | Release offer letter, create Employee ID |
| `hr_approver` | — | TAN, shortlist, offer, discrepancy closure, employee conversion | Perform recruiter/candidate-facing data entry as a substitute for approval review |
| `interviewer` | — | Interview feedback submission (self) | Approve shortlist/offer |
| `hr_ops` | Document re-upload requests | Verification pass/fail (not discrepancy *closure*) | Discrepancy closure/exception approval |
| `candidate` | Offer acceptance, Green Form/document submission | Own acceptance only | Any internal workflow action |
| `compliance_reviewer` | Audit queries | — (read-only + flag) | Any workflow state change |
| `platform_admin` | Configuration changes (via change control) | Configuration promotion to prod (per CI/CD gate) | Bypass approval-matrix enforcement in code |
| `agent_service_principal` | Draft outputs, recommendations, tool calls (scoped) | Nothing listed in Section 5 of CLAUDE.md | Any action reserved for a human approver |

## Assumptions and dependencies

Exact role names, department/business-unit scoping, and delegation/backup-approver rules are [TENANT_CONFIGURATION_REQUIRED] and configured in `config/tenants/sample-tenant.yaml`.

## Risks and open questions

- Cross-tenant panelists (e.g., shared interview pool) — access model TBD: [TENANT_CONFIGURATION_REQUIRED].
- Candidate identity proofing method for Green Form access — [LEGAL_REVIEW_REQUIRED].

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
