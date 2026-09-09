# Model Risk Register

> Title: Model Risk Register | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft (living document) | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: AI Governance, Security, Legal

## Purpose and scope

Tracks each model/skill combination in production, its risk tier, known limitations, and mitigations — the AI-governance equivalent of the security threat register.

## Register

| Skill | Model tier (`model_version.risk_tier`) | Known limitations | Mitigations | Owner |
|---|---|---|---|---|
| CV Extraction | Standard | May mis-extract poorly formatted/scanned CVs | Confidence threshold + manual review queue | [TENANT_CONFIGURATION_REQUIRED] |
| Candidate Matching | Elevated (influences human decisions at scale) | Potential proxy bias if JD criteria are loosely worded | Fairness testing ([fairness-and-bias-governance.md](../05-security-governance/fairness-and-bias-governance.md)), mandatory human approval | [TENANT_CONFIGURATION_REQUIRED] |
| Offer Drafting | Standard | Template misapplication if wrong template version selected | Template version validation, mandatory human approval before send | [TENANT_CONFIGURATION_REQUIRED] |
| Document Verification Assist | Elevated (touches identity documents) | OCR errors on low-quality scans | Confidence threshold, `needs_review` fallback, never auto-pass | [TENANT_CONFIGURATION_REQUIRED] |
| Policy Q&A (RAG) | Standard | Hallucination risk if grounding fails silently | Citation enforcement, no-answer fallback | [TENANT_CONFIGURATION_REQUIRED] |

## Risk tier definitions

| Tier | Definition | Review cadence |
|---|---|---|
| Standard | Low potential impact if wrong; always reviewed by a human before consequential action | Quarterly |
| Elevated | Higher potential impact (identity, fairness-sensitive); stricter thresholds and mandatory sampling | Monthly |
| Restricted | Not currently used in this platform — reserved for any future fully-autonomous capability, which would require a new ADR and explicit organizational sign-off | N/A |

## Review process

Each entry is reviewed on its cadence for: continued accuracy of "known limitations," whether mitigations remain effective, and whether production incidents (see [incident-response-runbook.md](../05-security-governance/incident-response-runbook.md)) or evaluation drift (see [ai-evaluation-strategy.md](ai-evaluation-strategy.md)) require a tier change.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
