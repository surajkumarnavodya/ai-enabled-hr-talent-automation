# Compliance Review Checklist

> Title: Compliance Review Checklist | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Compliance] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Legal, Compliance, Security, HR

## Purpose and scope

Checklist to be completed by Legal/Compliance before go-live in any new tenant/jurisdiction. Every item marked [LEGAL_REVIEW_REQUIRED] must be resolved and recorded before production launch in that jurisdiction.

## Checklist

| # | Item | Status | Owner |
|---|---|---|---|
| 1 | Data residency requirements confirmed and mapped to deployment region | [LEGAL_REVIEW_REQUIRED] | Legal |
| 2 | Retention periods finalized per [data-classification-and-retention.md](../03-data/data-classification-and-retention.md) | [LEGAL_REVIEW_REQUIRED] | Legal/HR |
| 3 | Candidate privacy notice/consent content drafted and approved | [LEGAL_REVIEW_REQUIRED] | Legal |
| 4 | Right-to-erasure process defined and testable | [LEGAL_REVIEW_REQUIRED] | Legal/Privacy |
| 5 | Protected-characteristic definitions confirmed per jurisdiction ([fairness-and-bias-governance.md](fairness-and-bias-governance.md)) | [LEGAL_REVIEW_REQUIRED] | Legal |
| 6 | Background verification scope/vendor compliant with local law | [LEGAL_REVIEW_REQUIRED] | Legal/HR |
| 7 | E-signature legal enforceability confirmed for offer letters | [LEGAL_REVIEW_REQUIRED] | Legal |
| 8 | Breach notification obligations and timelines documented | [LEGAL_REVIEW_REQUIRED] | Legal/Security |
| 9 | Employment record retention law mapped to [master-data-management.md](../03-data/master-data-management.md) | [LEGAL_REVIEW_REQUIRED] | Legal/HR |
| 10 | AI use disclosure to candidates (where legally required) drafted | [LEGAL_REVIEW_REQUIRED] | Legal/AI Governance |
| 11 | Cross-border data transfer mechanism (if applicable) documented | [LEGAL_REVIEW_REQUIRED] | Legal |
| 12 | Accessibility compliance target confirmed (e.g., WCAG level) | [TENANT_CONFIGURATION_REQUIRED] | Product/Legal |
| 13 | Security architecture reviewed and signed off | Pending | Security |
| 14 | Threat model reviewed and residual risks accepted | Pending | Security/Legal |
| 15 | DBA review of sample schema completed | Pending | DBA |

## Process

This checklist is completed once per tenant/jurisdiction before go-live and re-reviewed on a configurable cadence (default: annually) or upon material regulatory change.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
