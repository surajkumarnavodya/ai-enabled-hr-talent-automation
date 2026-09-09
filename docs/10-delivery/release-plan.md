# Release Plan

> Title: Release Plan | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner / Delivery Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, Architecture, Security

## Purpose and scope

Illustrative phased release plan sequencing the epics in [backlog-epics-and-user-stories.md](backlog-epics-and-user-stories.md). Actual dates are [TENANT_CONFIGURATION_REQUIRED].

## Phased approach

| Phase | Scope | Rationale |
|---|---|---|
| Phase 0 — Foundations | E12 (config), E13 (security/guardrails foundations), core data model, CI/CD gates | Nothing else is safe to build without these in place |
| Phase 1 — CV Bank & TAN | E1, E2 | Establishes the data entering the pipeline |
| Phase 2 — Matching & Shortlist | E3, E4 | First AI-assisted capability, with human gate |
| Phase 3 — Interview Lifecycle | E5 | Core recruiter/HR workflow loop |
| Phase 4 — Offer & Acceptance | E6 | Requires E3–E5 stable |
| Phase 5 — Green Form & Verification | E7, E8 | Onboarding data collection |
| Phase 6 — Employee Conversion & Integrations | E9, E10 | Final workflow leg, requires downstream integration partners ready |
| Phase 7 — Hardening | E11 depth, full [security-test-plan.md](../05-security-governance/security-test-plan.md), [ai-evaluation-strategy.md](../06-ai-agents-rag/ai-evaluation-strategy.md) maturity | Pre-general-availability hardening |

## Go/no-go criteria per phase

Each phase gate requires: [definition-of-done.md](definition-of-done.md) satisfied for all included stories, no open Critical/High security findings, and sign-off per [compliance-review-checklist.md](../05-security-governance/compliance-review-checklist.md) items relevant to that phase's data handling.

## Assumptions and dependencies

Actual timeline, team sizing, and parallelization strategy are [TENANT_CONFIGURATION_REQUIRED] and depend on organizational capacity, not fixed here.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
