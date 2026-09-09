# Product Requirements Document — HR Recruitment & Onboarding Automation Platform

> Title: Product Requirements Document | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, HR, Architecture, Security

## Table of contents

1. [Purpose and scope](#purpose-and-scope)
2. [Goals and success metrics](#goals-and-success-metrics)
3. [Personas](#personas)
4. [Functional requirements](#functional-requirements)
5. [Non-functional requirements](#non-functional-requirements-summary)
6. [Human-in-the-loop requirements](#human-in-the-loop-requirements)
7. [Configurability requirements](#configurability-requirements)
8. [Assumptions and dependencies](#assumptions-and-dependencies)
9. [Risks and open questions](#risks-and-open-questions)
10. [Acceptance criteria](#acceptance-criteria)
11. [Change control](#change-control)

## Purpose and scope

Define product requirements for a platform automating recruitment-to-onboarding: CV intake through Employee ID creation, with AI assistance bounded by mandatory human approval on material decisions. Scope covers the workflow in [end-to-end-recruitment-onboarding-workflow.md](../02-business-workflows/end-to-end-recruitment-onboarding-workflow.md). Out of scope: compensation-band policy authorship, legal contract text, final vendor selection (see [scope-assumptions-open-questions.md](scope-assumptions-open-questions.md)).

## Goals and success metrics

| Goal | Metric | Target (illustrative — [TENANT_CONFIGURATION_REQUIRED]) |
|---|---|---|
| Faster shortlisting | Median time from TAN approval to shortlist | ≤ 5 business days |
| Higher recruiter throughput | TANs actively managed per recruiter | +30% vs. baseline |
| Consistent, explainable matching | % of AI recommendations with recorded rationale | 100% |
| Reduced data-entry errors | Green Form discrepancy rate | ≤ configurable threshold |
| Governed AI use | % of sensitive actions with recorded human approval | 100% (non-negotiable) |
| Faster onboarding | Median time from acceptance to Employee ID | ≤ configurable SLA |

## Personas

See [personas-and-roles.md](personas-and-roles.md) for full detail: Recruiter, Hiring Manager, HR Approver, Candidate, Interview Panelist, HR Operations (Green Form/verification), Compliance/Security Reviewer, Platform Administrator, System Integrator.

## Functional requirements

| ID | Requirement | Workflow step | Priority |
|---|---|---|---|
| FR-01 | Upload one or more CVs into a Master CV Bank, in configurable accepted formats | 1 | Must |
| FR-02 | Parse, normalize, and deduplicate candidate data on ingestion | 2 | Must |
| FR-03 | Store candidate data securely with tenant isolation and encryption | 2 | Must |
| FR-04 | Create a TAN (Talent Acquisition Number) with an attached JD | 3 | Must |
| FR-05 | Require approval of TAN/JD before matching begins | 3 | Must |
| FR-06 | AI-generate explainable candidate recommendations against an approved TAN | 4–5 | Must |
| FR-07 | Require human approval before shortlisting any candidate | 6 | Must |
| FR-08 | Schedule/reschedule L1 interviews via calendar integration | 7 | Must |
| FR-09 | Capture structured L1 feedback | 8 | Must |
| FR-10 | On L1 reject, close candidate for the current TAN only and recommend alternates | 9 | Must |
| FR-11 | On L1 select, schedule L2 interview | 10 | Must |
| FR-12 | Schedule client interview when configured as required | 11 | Should |
| FR-13 | Generate an approved offer letter after final selection approval | 12 | Must |
| FR-14 | Capture candidate acceptance/decline | 13 | Must |
| FR-15 | Issue a secure, time-bound Green Form link on acceptance | 14 | Must |
| FR-16 | Collect employment history, education, and required documents via Green Form | 15 | Must |
| FR-17 | Verify submitted data/documents against configurable rules | 16 | Must |
| FR-18 | Generate discrepancy reports for verification failures | 17 | Must |
| FR-19 | Support re-upload/clarification requests, HR-approval gated | 18–19 | Must |
| FR-20 | Convert an approved candidate to an employee and issue an Employee ID | 20 | Must |
| FR-21 | Trigger configured downstream integrations on employee creation | 21 | Must |
| FR-22 | Provide full audit trail for every state transition and approval | Cross-cutting | Must |

## Non-functional requirements summary

See [non-functional-requirements.md](../01-architecture/non-functional-requirements.md) for full detail on availability, latency, scalability, security, accessibility, and cost targets.

## Human-in-the-loop requirements

AI may recommend, extract, classify, summarize, draft, route, alert. AI must never autonomously reject/select candidates, release offers, set compensation, close discrepancies/exceptions, or create Employee IDs. See [human-approval-matrix.md](../02-business-workflows/human-approval-matrix.md) and [ai-guardrails-policy.md](../05-security-governance/ai-guardrails-policy.md).

## Configurability requirements

Workflow stages, approval matrices, TAN/Employee-ID numbering, document checklists, scoring weights, retention periods, SLAs, templates, model routing, prompts, and RAG parameters must be tenant-configurable per [Section 4 of CLAUDE.md](../../CLAUDE.md). No code deployment should be required to change these values.

## Assumptions and dependencies

- Identity provider, e-signature vendor, calendar/email platform, and HRMS/payroll targets are tenant-specific — see `.env.example` and `config/tenants/sample-tenant.yaml`.
- Background verification and compensation-band logic are external policy inputs: [TENANT_POLICY_REQUIRED].

## Risks and open questions

See [scope-assumptions-open-questions.md](scope-assumptions-open-questions.md) for the live register.

## Acceptance criteria

- Every functional requirement above is traceable to at least one API endpoint, event, database entity, and test case (see [GENERATED_FILES.md](../../GENERATED_FILES.md) traceability map).
- No functional requirement permits an AI action listed as forbidden in Section 5 of CLAUDE.md.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
