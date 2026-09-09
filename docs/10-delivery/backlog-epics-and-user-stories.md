# Backlog: Epics and User Stories

> Title: Backlog: Epics and User Stories | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, Engineering leads

## Purpose and scope

High-level epic breakdown derived from [product-requirements-document.md](../00-product/product-requirements-document.md), for initial delivery planning. Detailed story-level backlog is maintained in the team's tracking tool — [TENANT_CONFIGURATION_REQUIRED — e.g. Jira/Azure Boards project].

## Epics

| Epic | Summary | Key requirements covered |
|---|---|---|
| E1: CV Bank Ingestion | Upload, parse, dedupe, secure storage | FR-01–03 |
| E2: TAN Lifecycle | Create, approve, version JD | FR-04–05 |
| E3: AI Candidate Matching | Explainable scoring against approved TAN | FR-06 |
| E4: Shortlist & Approval | Human-gated shortlist workflow | FR-07 |
| E5: Interview Lifecycle | Scheduling, feedback, L1/L2/client progression, rejection loop | FR-08–12 |
| E6: Offer Lifecycle | Draft, approve, send, accept/decline | FR-13–14 |
| E7: Green Form & Verification | Secure link issuance, document/history collection, verification | FR-15–17 |
| E8: Discrepancy Management | Reporting, re-upload loop, HR-approved closure | FR-18–19 |
| E9: Employee Conversion | Gate checklist, Employee ID issuance | FR-20 |
| E10: Downstream Integrations | HRMS/payroll/IT/access/induction triggers | FR-21 |
| E11: Audit & Governance | Full audit trail, approval matrix enforcement | FR-22 |
| E12: Platform Configuration | Tenant/workflow/RAG/model configuration surfaces | Configuration-first non-negotiable |
| E13: Security & AI Governance Foundations | Guardrails, RBAC/ABAC, threat mitigations | Non-negotiables 1–3 |

## Sample user stories (illustrative — fake/demo context)

- As a Recruiter, I want to upload a batch of CVs so that they are parsed and added to the CV Bank without manual re-entry.
- As an HR Approver, I want to review AI-generated shortlist recommendations with rationale so that I can approve or reject with confidence.
- As a Candidate, I want a secure, time-bound Green Form link so that I can submit my documents without creating a full account.
- As an HR Operations user, I want a clear discrepancy report so that I can request the right clarification from the candidate.
- As a Compliance Reviewer, I want to query the audit log by subject so that I can verify every approval gate was honored.

## Risk register (delivery-specific)

| Risk | Mitigation |
|---|---|
| Scope creep into compensation-policy logic | Explicitly out of scope per [scope-assumptions-open-questions.md](../00-product/scope-assumptions-open-questions.md) |
| Underestimating MCP server build effort | Treat each MCP server as its own epic-sized effort per [mcp-tool-governance.md](../07-mcp-integrations/mcp-tool-governance.md) onboarding process |
| AI evaluation infrastructure built too late | Sequence [ai-evaluation-strategy.md](../06-ai-agents-rag/ai-evaluation-strategy.md) infrastructure alongside first skill, not after |

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
