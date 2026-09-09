# Acceptance Criteria

> Title: Acceptance Criteria | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Product Owner] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Product, HR, QA

## Purpose and scope

Maps functional requirements from [product-requirements-document.md](../00-product/product-requirements-document.md) to concrete, testable acceptance criteria.

## Acceptance criteria by requirement

| Req ID | Acceptance criteria |
|---|---|
| FR-01/02 | Given a valid CV file, when uploaded, then it appears in the CV Bank with extraction status visible within the configured SLA, and duplicate candidates are flagged, not silently merged |
| FR-04/05 | Given a TAN with mandatory JD criteria, when submitted, then it cannot proceed to matching until an `hr_approver` records an approval decision |
| FR-06/07 | Given an approved TAN, when matching runs, then recommendations include a rationale citing specific JD criteria, and no candidate is shortlisted without a recorded human approval |
| FR-08/09 | Given a shortlisted candidate, when an interview is scheduled and completed, then structured feedback can be submitted and is immutable once recorded |
| FR-10 | Given an L1/L2/client rejection, when recorded, then the candidate's application for that TAN transitions to closed, and alternate recommendations are generated without requiring the candidate to be re-uploaded |
| FR-13/14 | Given a final selection approval, when an offer is drafted, then it cannot be sent until an `hr_approver` approves it, and compensation is sourced from a reference, never free text |
| FR-15/16 | Given an accepted offer, when the Green Form link is issued, then it is single-use, time-bound, and enforces the configured document checklist before submission is accepted |
| FR-17/18/19 | Given a submitted Green Form, when verification runs, then any mismatch produces a discrepancy record, and closing/exception requires a recorded `hr_approver` decision |
| FR-20/21 | Given an approved employee conversion, when executed, then an Employee ID is issued only if every gate-checklist item passes or has an approved exception, and downstream integration events fire exactly once (idempotent) |
| FR-22 | Given any workflow state transition, when it occurs, then a corresponding audit log entry exists in the same transaction |

## Non-functional acceptance criteria

Every NFR target in [non-functional-requirements.md](../01-architecture/non-functional-requirements.md) has a corresponding load/latency/availability test in [test-case-catalog.md](test-case-catalog.md).

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
