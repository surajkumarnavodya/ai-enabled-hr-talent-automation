# Data Dictionary

> Title: Data Dictionary | Version: 1.1 | Owner: [TENANT_CONFIGURATION_REQUIRED — Data Architecture] | Status: Draft (original target-state baseline; superseded in part by a real implementation — see notice below) | Last reviewed: 2026-09-08 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: DBA, Architecture, Security

> **Implementation reality notice (2026-09-08):** the entity names, field names, and the single-table `tan`/`approval`/`workflow_state_transition` shapes below are the *original target-state design* and do **not** match what was actually built. A real SQL Server database, `HrAutomationDb`, was implemented database-first with ~243 tables across schemas `org`/`iam`/`ref`/`recruitment`/`workflow`/`offer`/`onboarding`/`employee`/`integration`/`ai`/`audit` (PascalCase, schema-qualified, e.g. `recruitment.Candidate`, `recruitment.TalentAcquisitionNumber`). Key structural differences from the design below:
> - There is no single `tan` table — a TAN is split into `recruitment.TalentAcquisitionNumber` (the reserved number) and `recruitment.JobRequisition` (the approvable record that actually carries status, via `RequisitionStatusCode`).
> - There is no single `approval` table — approvals are three tables: `workflow.ApprovalRequest`, `workflow.ApprovalStep`, `workflow.ApprovalDecision`, keyed by `EntityType`/`EntityId` against whatever business entity they gate.
> - There is no generic `workflow_state_transition` table / workflow engine. Each business entity carries its own status column (e.g. `recruitment.JobRequisition.RequisitionStatusCode`), and the stored procedure that performs a transition (e.g. `recruitment.usp_ApproveJobRequisition`) enforces validity atomically with the write. See [ADR-006](../adr/ADR-006-database-first-stored-procedure-workflow.md).
> - The authoritative source for the real schema is the DDL itself: `src/HrAutomation.Infrastructure/Database/scripts/03-create-tables.sql` (tables), `04-create-keys-indexes-constraints.sql` (keys/FKs), `07-create-stored-procedures.sql` (the ~30 procedures that own workflow-critical writes). A markdown data dictionary generated from the real schema does not exist yet — `src/HrAutomation.Infrastructure/Database/docs/` is a placeholder folder, currently empty. Generating one is a `Planned` item, not done.
> - Only the tables backing CV ingestion (`recruitment.Candidate`/`CandidateContact`/`CandidateCv`/`CandidateCvVersion`/`CvParsingResult`/`CvExtractionField`) and TAN/JobRequisition creation-approval (`recruitment.TalentAcquisitionNumber`/`JobRequisition`/`JobDescription`/`JobDescriptionVersion`, `workflow.ApprovalRequest`/`ApprovalStep`/`ApprovalDecision`, `audit.AuditEvent`) are wired into live application code today (`HrAutomation.Infrastructure/Persistence/HrAutomationDbContext.cs`). The remaining ~230 tables exist in the database but have no application code reading/writing them yet.
>
> The rest of this document is preserved as the **original target-state design** — still useful as a simpler, engine-agnostic reference for entities not yet built (interviews, offers, Green Form, discrepancies, employee conversion), but do not treat its field names as authoritative for anything already implemented above.

## Table of contents

1. [Common fields (all entities)](#common-fields-all-entities)
2. [Tenancy and access](#tenancy-and-access)
3. [Candidate and CV](#candidate-and-cv)
4. [TAN and JD](#tan-and-jd)
5. [Application, matching, interviews](#application-matching-interviews)
6. [Offer and Green Form](#offer-and-green-form)
7. [Documents, verification, discrepancy](#documents-verification-discrepancy)
8. [Approvals and workflow transitions](#approvals-and-workflow-transitions)
9. [Employee](#employee)
10. [Integration, audit, evaluation, RAG](#integration-audit-evaluation-rag)
11. [Change control](#change-control)

## Common fields (all entities)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Primary key |
| `tenant_id` | UUID | Foreign key to `tenant`; required on every table for isolation |
| `created_at` / `updated_at` | timestamptz | UTC |
| `created_by` / `updated_by` | UUID | References `user_account.id` or a system principal |
| `version` | integer | Optimistic concurrency token |
| `is_deleted` | boolean | Soft delete flag; hard delete only via retention/legal-hold workflow |

## Tenancy and access

| Entity | Key fields | Notes |
|---|---|---|
| `tenant` | `id`, `name`, `status`, `branding_config_ref` | One row per tenant/legal entity |
| `user_account` | `id`, `tenant_id`, `email`, `identity_provider_subject`, `status` | Internal users (recruiters, HR, panelists, admins) |
| `role` | `id`, `tenant_id`, `name`, `permissions_json` | See [identity-access-control.md](../05-security-governance/identity-access-control.md) |
| `user_role_assignment` | `user_id`, `role_id`, `scope_json` | ABAC scope (department/location/business unit) |

## Candidate and CV

| Entity | Key fields | Notes |
|---|---|---|
| `candidate` | `id`, `tenant_id`, `full_name`, `primary_email_encrypted`, `primary_phone_encrypted`, `dedup_hash`, `source`, `status` | PII fields encrypted at column level; see [privacy-and-pii-handling.md](../05-security-governance/privacy-and-pii-handling.md) |
| `cv_document` | `id`, `candidate_id`, `blob_ref`, `file_hash`, `mime_type`, `uploaded_at`, `extraction_status` | `blob_ref` points to object storage, never raw bytes in RDBMS |
| `cv_extracted_field` | `id`, `cv_document_id`, `field_name`, `field_value`, `confidence_score` | Structured extraction result, reviewable |
| `candidate_history` | `id`, `candidate_id`, `event_type`, `event_payload_json`, `occurred_at` | Append-only change history |

## TAN and JD

| Entity | Key fields | Notes |
|---|---|---|
| `tan` | `id`, `tenant_id`, `tan_number`, `title`, `department`, `location`, `grade`, `status`, `requested_by`, `hiring_manager_id` | `tan_number` format per `config/defaults/workflow.default.yaml` |
| `jd_version` | `id`, `tan_id`, `version_number`, `content_ref`, `mandatory_criteria_json`, `preferred_criteria_json`, `approved_at` | Versioned JD content; mandatory vs. preferred criteria drive matching |

## Application, matching, interviews

| Entity | Key fields | Notes |
|---|---|---|
| `application` | `id`, `tenant_id`, `tan_id`, `candidate_id`, `status`, `closed_reason` | One row per candidate-per-TAN attempt |
| `match_score` | `id`, `application_id`, `score`, `rationale_json`, `model_version_id`, `prompt_version_id`, `scored_at` | `rationale_json` supports explainability |
| `interview` | `id`, `application_id`, `stage` (`L1`/`L2`/`client`), `scheduled_at`, `status`, `panelist_ids_json` | |
| `interview_feedback` | `id`, `interview_id`, `submitted_by`, `outcome` (`select`/`reject`), `structured_feedback_json`, `submitted_at` | Never AI-authored outcome, only optional AI-drafted summary field kept separate |

## Offer and Green Form

| Entity | Key fields | Notes |
|---|---|---|
| `offer` | `id`, `application_id`, `status`, `compensation_ref` (external reference, not free text), `template_version`, `document_blob_ref`, `sent_at`, `responded_at` | Compensation figures sourced from HRMS/comp system reference, never AI-generated |
| `green_form` | `id`, `offer_id`, `access_token_hash`, `issued_at`, `expires_at`, `status` | Single-use, time-bound secure link; token stored hashed |
| `employment_history_entry` | `id`, `green_form_id`, `employer_name`, `start_date`, `end_date`, `verification_status` | |
| `education_entry` | `id`, `green_form_id`, `institution`, `qualification`, `year`, `verification_status` | |

## Documents, verification, discrepancy

| Entity | Key fields | Notes |
|---|---|---|
| `candidate_document` | `id`, `green_form_id`, `document_type`, `blob_ref`, `classification`, `retention_tag` | Document type per configurable checklist |
| `verification_result` | `id`, `candidate_document_id`, `verified_by` (`system`/`user_id`), `outcome`, `confidence_score`, `verified_at` | |
| `discrepancy` | `id`, `application_id`, `type`, `severity`, `description`, `evidence_ref_json`, `status` | Status per [workflow-state-machine.md](../02-business-workflows/workflow-state-machine.md) |

## Approvals and workflow transitions

| Entity | Key fields | Notes |
|---|---|---|
| `approval` | `id`, `subject_type`, `subject_id`, `action`, `approver_user_id`, `delegated_by`, `decision`, `decided_at`, `evidence_ref_json` | Single table for all approval types (TAN, shortlist, offer, discrepancy closure, employee conversion) |
| `workflow_state_transition` | `id`, `subject_type`, `subject_id`, `from_state`, `to_state`, `triggered_by`, `approval_id` (nullable), `occurred_at`, `workflow_config_version` | Append-only |

## Employee

| Entity | Key fields | Notes |
|---|---|---|
| `employee` | `id`, `tenant_id`, `application_id`, `employee_number`, `status`, `converted_at` | |
| `employee_id_registry` | `id`, `tenant_id`, `employee_number`, `format_version`, `issued_at` | Enforces uniqueness/format per `config/defaults/workflow.default.yaml` |

## Integration, audit, evaluation, RAG

| Entity | Key fields | Notes |
|---|---|---|
| `integration_outbox` | `id`, `tenant_id`, `event_type`, `payload_json`, `status`, `attempt_count`, `available_at` | Transactional outbox — see [ADR-001](../adr/ADR-001-transactional-system-of-record.md) |
| `audit_log` | `id`, `tenant_id`, `actor_type`, `actor_id`, `action`, `subject_type`, `subject_id`, `occurred_at`, `metadata_json` (redacted) | See [audit-log-specification.md](audit-log-specification.md) |
| `model_version` | `id`, `provider`, `model_name`, `version_tag`, `risk_tier`, `active` | See [model-risk-register.md](../06-ai-agents-rag/model-risk-register.md) |
| `prompt_version` | `id`, `skill_name`, `version_tag`, `content_ref`, `approved_by`, `approved_at` | See [prompt-management.md](../06-ai-agents-rag/prompt-management.md) |
| `evaluation_record` | `id`, `subject_type`, `subject_id`, `dataset_ref`, `score_json`, `evaluated_at` | De-identified where possible |
| `rag_document` | `id`, `tenant_id`, `source_type`, `classification`, `access_policy_json`, `effective_date`, `expiry_date`, `content_hash` | See [rag-ingestion-and-chunking.md](../06-ai-agents-rag/rag-ingestion-and-chunking.md) |
| `rag_chunk` | `id`, `rag_document_id`, `heading_path`, `page_or_clause_ref`, `embedding_version`, `chunk_hash` | Embedding vector lives in the vector store, keyed by `id` |
| `idempotency_key_record` | `id`, `key_value`, `request_hash`, `response_snapshot_ref`, `expires_at` | Backs API idempotency ([api-standards.md](../04-api/api-standards.md)) |

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
