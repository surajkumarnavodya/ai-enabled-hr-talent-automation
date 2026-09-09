# Human Approval Matrix

> Title: Human Approval Matrix | Version: 1.1 | Owner: [TENANT_CONFIGURATION_REQUIRED — HR Process Owner] | Status: Draft (target-state; only TAN approval is enforced in code today — see notice) | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: HR, Security, Compliance

> **Implementation reality notice (2026-09-08):** "enforced in code by the workflow engine" below is true only for **TAN approval** today — `recruitment.usp_ApproveJobRequisition`/`usp_RejectJobRequisition` plus `workflow.ApprovalRequest`/`ApprovalStep`/`ApprovalDecision`, gated server-side and independently re-checked (never trusting a client-supplied role claim), per `.claude/rules/api.md`. Every other row (shortlist, interview outcome, final selection, offer content/send, discrepancy closure, employee conversion, Employee ID creation) describes a gate for a workflow stage that has no backing implementation yet (see [agent-skill-catalog.md](../06-ai-agents-rag/agent-skill-catalog.md) for what's actually built). Do not assume any gate below is enforced until its corresponding skill/endpoint is marked `Implemented`.

## Purpose and scope

Enumerates every sensitive action in the workflow, the required approver role(s), whether AI may propose the action, and the auditable evidence required. This matrix is enforced in code by the workflow engine (not just convention) and is configurable per tenant via [approval-matrix.schema.json](../../config/schemas/approval-matrix.schema.json) — **the set of gated actions itself is fixed**; only approver role mapping, quorum, and delegation are tenant-configurable.

## Matrix

| Action | AI may propose? | Required approver role(s) | Minimum approvers | Can be delegated? | Audit evidence required |
|---|---|---|---|---|---|
| TAN approval | Yes (JD summary draft) | `hr_approver` | 1 | Yes, to another `hr_approver` | Approval record + JD version hash |
| Shortlist approval | Yes (ranked recommendations) | `hr_approver` or `hiring_manager` (config) | 1 | Yes | Approval record + match-score snapshot |
| Interview scheduling | Yes (slot suggestions) | N/A (operational, not a decision gate) | 0 | — | Scheduling event log |
| Interview outcome (reject/select) | No — AI may summarize feedback only | `interviewer` (submits), reviewed by `recruiter` | 1 | No | Structured feedback record, signed by submitter identity |
| Final selection approval | No | `hr_approver` | 1 (2 if configured for senior grades) | Yes | Approval record referencing all round feedback |
| Offer content approval | Yes (draft from template) | `hr_approver` | 1 | Yes | Approval record + offer document hash |
| Offer send | No (system action after approval) | Triggered automatically post-approval | — | — | Send event with offer document hash |
| Discrepancy closure / exception | Yes (draft rationale) | `hr_approver` | 1 | Yes | Approval record + discrepancy evidence bundle |
| Employee conversion | No | `hr_approver` | 1 | Yes | Approval record + gate-checklist snapshot |
| Employee ID creation | No (system action after approval) | Triggered automatically post-approval | — | — | Creation event with approval reference |
| Compensation figure entry | No — AI must never propose figures | `hr_approver` (from HRMS/comp reference) | 1 | Yes | Reference to comp system record, not free text |
| Configuration change (workflow/approval matrix) | No | `platform_admin` + `hr_approver` co-sign | 2 | No | Change-control record with diff |

## Non-negotiable rule

No workflow path may reach `OfferSent`, `Resolved` (discrepancy), or `EmployeeIdIssued` without a corresponding approval record satisfying the row above. This is enforced by the workflow engine rejecting the transition, not by UI convention. See [ADR-002](../adr/ADR-002-agent-orchestration-pattern.md) and [ai-guardrails-policy.md](../05-security-governance/ai-guardrails-policy.md).

## Delegation and escalation

Delegation rules (who can act as backup approver, maximum delegation duration, whether delegation itself requires logging) are [TENANT_CONFIGURATION_REQUIRED]. All delegated approvals must record both the delegate and the delegator in the audit log.

## Assumptions and open questions

- Quorum size for senior-grade approvals is [TENANT_CONFIGURATION_REQUIRED].
- Whether hiring managers can co-approve shortlists alongside HR, or only HR — [TENANT_CONFIGURATION_REQUIRED].

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
