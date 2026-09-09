-- =============================================================================
-- SAMPLE RELATIONAL SCHEMA — TECHNICAL BASELINE ONLY
-- =============================================================================
-- This is a SAMPLE schema illustrating entities, relationships, keys, and
-- constraints described in data-dictionary.md and er-diagram.md.
-- IMPLEMENTATION REALITY NOTICE (2026-09-08): this sample does not match the
-- real, implemented database. The actual system runs on SQL Server as
-- HrAutomationDb (~243 tables, schema-qualified PascalCase), built database-
-- first at src/HrAutomation.Infrastructure/Database/scripts/. Treat this file
-- as an engine-agnostic conceptual reference only, never as a migration
-- source or a description of the real schema.
-- It is NOT production-ready. It REQUIRES DBA and security review before use:
--   - Confirm row-level security (RLS) policies per tenant_id on every table.
--   - Confirm column-level encryption approach for PII fields (encryption is
--     assumed to be applied at the application/column level; this DDL shows
--     placeholder column types only).
--   - Confirm index strategy against real query patterns and data volume.
--   - Confirm retention/legal-hold triggers before enabling automated purge.
-- Dialect: PostgreSQL (illustrative). For SQL Server, adapt UUID -> UNIQUEIDENTIFIER,
-- TIMESTAMPTZ -> DATETIMEOFFSET, JSONB -> NVARCHAR(MAX) with JSON constraints, etc.
-- All sample values in comments are FAKE/DEMO data only.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

-- =============================================================================
-- TENANCY AND ACCESS
-- =============================================================================

CREATE TABLE tenant (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(200) NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active','suspended','archived')),
    branding_config_ref VARCHAR(500),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    version             INTEGER NOT NULL DEFAULT 1,
    is_deleted          BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE user_account (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id                   UUID NOT NULL REFERENCES tenant(id),
    email                       VARCHAR(320) NOT NULL,
    identity_provider_subject   VARCHAR(200) NOT NULL,
    display_name                VARCHAR(200) NOT NULL,
    status                      VARCHAR(20) NOT NULL DEFAULT 'active'
                                    CHECK (status IN ('active','disabled')),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID,
    updated_by                  UUID,
    version                     INTEGER NOT NULL DEFAULT 1,
    is_deleted                  BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_user_tenant_email UNIQUE (tenant_id, email),
    CONSTRAINT uq_user_idp_subject UNIQUE (tenant_id, identity_provider_subject)
);
CREATE INDEX ix_user_account_tenant ON user_account(tenant_id) WHERE is_deleted = false;

CREATE TABLE role (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    name            VARCHAR(100) NOT NULL, -- e.g. 'recruiter','hr_approver'
    permissions     JSONB NOT NULL DEFAULT '[]',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    version         INTEGER NOT NULL DEFAULT 1,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_role_tenant_name UNIQUE (tenant_id, name)
);

CREATE TABLE user_role_assignment (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    user_id         UUID NOT NULL REFERENCES user_account(id),
    role_id         UUID NOT NULL REFERENCES role(id),
    scope           JSONB DEFAULT '{}', -- e.g. {"department":"Engineering","location":"BLR"}
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_role_scope UNIQUE (user_id, role_id, scope)
);
CREATE INDEX ix_user_role_user ON user_role_assignment(user_id);

-- =============================================================================
-- CANDIDATE AND CV
-- =============================================================================

CREATE TABLE candidate (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenant(id),
    full_name               VARCHAR(200) NOT NULL,
    primary_email_encrypted BYTEA NOT NULL,   -- application-layer encrypted
    primary_phone_encrypted BYTEA,
    dedup_hash              VARCHAR(128) NOT NULL, -- deterministic hash of normalized email/phone
    source                  VARCHAR(50), -- e.g. 'manual_upload','bulk_import','referral'
    status                  VARCHAR(30) NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active','withdrawn','blocked')),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID,
    updated_by              UUID,
    version                 INTEGER NOT NULL DEFAULT 1,
    is_deleted              BOOLEAN NOT NULL DEFAULT false
);
CREATE INDEX ix_candidate_tenant_dedup ON candidate(tenant_id, dedup_hash) WHERE is_deleted = false;

CREATE TABLE cv_document (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenant(id),
    candidate_id        UUID NOT NULL REFERENCES candidate(id),
    blob_ref            VARCHAR(1000) NOT NULL, -- object storage reference, never raw bytes here
    file_hash           VARCHAR(128) NOT NULL,
    mime_type           VARCHAR(100) NOT NULL,
    uploaded_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    extraction_status   VARCHAR(30) NOT NULL DEFAULT 'pending'
                            CHECK (extraction_status IN ('pending','in_progress','completed','needs_review','failed')),
    scan_status         VARCHAR(30) NOT NULL DEFAULT 'pending'
                            CHECK (scan_status IN ('pending','clean','quarantined','failed')),
    version             INTEGER NOT NULL DEFAULT 1,
    is_deleted          BOOLEAN NOT NULL DEFAULT false
);
CREATE INDEX ix_cv_document_candidate ON cv_document(candidate_id) WHERE is_deleted = false;

CREATE TABLE cv_extracted_field (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cv_document_id      UUID NOT NULL REFERENCES cv_document(id),
    field_name          VARCHAR(100) NOT NULL,
    field_value         TEXT,
    confidence_score    NUMERIC(4,3) CHECK (confidence_score BETWEEN 0 AND 1),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_cv_extracted_field_doc ON cv_extracted_field(cv_document_id);

CREATE TABLE candidate_history (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id        UUID NOT NULL REFERENCES candidate(id),
    event_type          VARCHAR(100) NOT NULL,
    event_payload       JSONB NOT NULL DEFAULT '{}',
    occurred_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_candidate_history_candidate ON candidate_history(candidate_id);

-- =============================================================================
-- TAN AND JD
-- =============================================================================

CREATE TABLE tan (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenant(id),
    tan_number          VARCHAR(50) NOT NULL, -- format per config/defaults/workflow.default.yaml, e.g. TAN-2026-000123
    title               VARCHAR(200) NOT NULL,
    department          VARCHAR(100),
    location            VARCHAR(100),
    grade               VARCHAR(50),
    status              VARCHAR(30) NOT NULL DEFAULT 'draft'
                            CHECK (status IN ('draft','pending_approval','approved','on_hold','closed')),
    requested_by        UUID NOT NULL REFERENCES user_account(id),
    hiring_manager_id   UUID REFERENCES user_account(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    version             INTEGER NOT NULL DEFAULT 1,
    is_deleted          BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_tan_tenant_number UNIQUE (tenant_id, tan_number)
);
CREATE INDEX ix_tan_tenant_status ON tan(tenant_id, status) WHERE is_deleted = false;

CREATE TABLE jd_version (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tan_id                  UUID NOT NULL REFERENCES tan(id),
    version_number          INTEGER NOT NULL,
    content_ref             VARCHAR(1000) NOT NULL, -- object storage or content table reference
    mandatory_criteria      JSONB NOT NULL DEFAULT '[]',
    preferred_criteria      JSONB NOT NULL DEFAULT '[]',
    approved_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_jd_version UNIQUE (tan_id, version_number)
);

-- =============================================================================
-- APPLICATION, MATCHING, INTERVIEWS
-- =============================================================================

CREATE TABLE application (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    tan_id          UUID NOT NULL REFERENCES tan(id),
    candidate_id    UUID NOT NULL REFERENCES candidate(id),
    status          VARCHAR(40) NOT NULL DEFAULT 'recommended',
    closed_reason   VARCHAR(200),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    version         INTEGER NOT NULL DEFAULT 1,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_application_tan_candidate UNIQUE (tan_id, candidate_id)
);
CREATE INDEX ix_application_tan ON application(tan_id) WHERE is_deleted = false;
CREATE INDEX ix_application_candidate ON application(candidate_id) WHERE is_deleted = false;

CREATE TABLE match_score (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id      UUID NOT NULL REFERENCES application(id),
    score               NUMERIC(5,2) NOT NULL CHECK (score BETWEEN 0 AND 100),
    rationale           JSONB NOT NULL DEFAULT '{}', -- explainability: matched criteria, weights
    model_version_id    UUID, -- references model_version(id)
    prompt_version_id   UUID, -- references prompt_version(id)
    scored_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_match_score_application ON match_score(application_id);

CREATE TABLE interview (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id  UUID NOT NULL REFERENCES application(id),
    stage           VARCHAR(20) NOT NULL CHECK (stage IN ('L1','L2','client')),
    scheduled_at    TIMESTAMPTZ,
    status          VARCHAR(30) NOT NULL DEFAULT 'scheduled'
                        CHECK (status IN ('scheduled','rescheduled','completed','cancelled','no_show')),
    panelist_ids    JSONB NOT NULL DEFAULT '[]',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    version         INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX ix_interview_application ON interview(application_id);

CREATE TABLE interview_feedback (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    interview_id                UUID NOT NULL REFERENCES interview(id),
    submitted_by                UUID NOT NULL REFERENCES user_account(id),
    outcome                     VARCHAR(20) NOT NULL CHECK (outcome IN ('select','reject')),
    structured_feedback         JSONB NOT NULL DEFAULT '{}',
    ai_summary_draft            TEXT, -- optional AI-assisted summary; never authoritative for outcome
    submitted_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_feedback_per_interview_submitter UNIQUE (interview_id, submitted_by)
);

-- =============================================================================
-- OFFER AND GREEN FORM
-- =============================================================================

CREATE TABLE offer (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenant(id),
    application_id      UUID NOT NULL REFERENCES application(id),
    status              VARCHAR(30) NOT NULL DEFAULT 'drafted'
                            CHECK (status IN ('drafted','pending_approval','approved','sent','accepted','declined','expired')),
    compensation_ref    VARCHAR(200) NOT NULL, -- reference into external comp system, never free-text figure
    template_version    VARCHAR(50) NOT NULL,
    document_blob_ref   VARCHAR(1000),
    sent_at             TIMESTAMPTZ,
    responded_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    version             INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_offer_application UNIQUE (application_id)
);

CREATE TABLE green_form (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenant(id),
    offer_id            UUID NOT NULL REFERENCES offer(id),
    access_token_hash   VARCHAR(256) NOT NULL, -- token stored hashed, never plaintext
    issued_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'issued'
                            CHECK (status IN ('issued','submitted','expired','revoked')),
    CONSTRAINT uq_green_form_offer UNIQUE (offer_id)
);

CREATE TABLE employment_history_entry (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    green_form_id       UUID NOT NULL REFERENCES green_form(id),
    employer_name       VARCHAR(200) NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE,
    verification_status VARCHAR(30) NOT NULL DEFAULT 'pending'
                            CHECK (verification_status IN ('pending','verified','discrepancy'))
);

CREATE TABLE education_entry (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    green_form_id       UUID NOT NULL REFERENCES green_form(id),
    institution         VARCHAR(200) NOT NULL,
    qualification       VARCHAR(200) NOT NULL,
    year                INTEGER,
    verification_status VARCHAR(30) NOT NULL DEFAULT 'pending'
                            CHECK (verification_status IN ('pending','verified','discrepancy'))
);

-- =============================================================================
-- DOCUMENTS, VERIFICATION, DISCREPANCY
-- =============================================================================

CREATE TABLE candidate_document (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    green_form_id       UUID NOT NULL REFERENCES green_form(id),
    document_type       VARCHAR(100) NOT NULL, -- from configurable checklist
    blob_ref            VARCHAR(1000) NOT NULL,
    classification      VARCHAR(30) NOT NULL DEFAULT 'restricted'
                            CHECK (classification IN ('internal','confidential','restricted')),
    retention_tag       VARCHAR(50),
    uploaded_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    scan_status         VARCHAR(30) NOT NULL DEFAULT 'pending'
                            CHECK (scan_status IN ('pending','clean','quarantined','failed'))
);
CREATE INDEX ix_candidate_document_green_form ON candidate_document(green_form_id);

CREATE TABLE verification_result (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_document_id   UUID NOT NULL REFERENCES candidate_document(id),
    verified_by             VARCHAR(100) NOT NULL, -- 'system' or user_account.id as text
    outcome                 VARCHAR(20) NOT NULL CHECK (outcome IN ('pass','fail','needs_review')),
    confidence_score        NUMERIC(4,3) CHECK (confidence_score BETWEEN 0 AND 1),
    verified_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE discrepancy (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenant(id),
    application_id      UUID NOT NULL REFERENCES application(id),
    type                VARCHAR(100) NOT NULL, -- from configurable discrepancy taxonomy
    severity            VARCHAR(20) NOT NULL CHECK (severity IN ('low','medium','high','critical')),
    description         TEXT NOT NULL,
    evidence_ref        JSONB NOT NULL DEFAULT '{}',
    status              VARCHAR(30) NOT NULL DEFAULT 'raised'
                            CHECK (status IN ('raised','reupload_requested','pending_hr_approval','resolved')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_discrepancy_application ON discrepancy(application_id);

-- =============================================================================
-- APPROVALS AND WORKFLOW TRANSITIONS
-- =============================================================================

CREATE TABLE approval (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenant(id),
    subject_type        VARCHAR(50) NOT NULL, -- 'tan','application_shortlist','application_final','offer','discrepancy','employee_conversion'
    subject_id          UUID NOT NULL,
    action              VARCHAR(100) NOT NULL,
    approver_user_id    UUID NOT NULL REFERENCES user_account(id),
    delegated_by        UUID REFERENCES user_account(id),
    decision            VARCHAR(20) NOT NULL CHECK (decision IN ('approved','rejected')),
    decided_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    evidence_ref        JSONB NOT NULL DEFAULT '{}'
);
CREATE INDEX ix_approval_subject ON approval(subject_type, subject_id);

CREATE TABLE workflow_state_transition (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenant(id),
    subject_type            VARCHAR(50) NOT NULL,
    subject_id              UUID NOT NULL,
    from_state              VARCHAR(50),
    to_state                VARCHAR(50) NOT NULL,
    triggered_by            VARCHAR(100) NOT NULL, -- user_account.id, 'system', or agent skill name
    approval_id             UUID REFERENCES approval(id),
    occurred_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    workflow_config_version VARCHAR(50) NOT NULL
);
CREATE INDEX ix_wst_subject ON workflow_state_transition(subject_type, subject_id);

-- =============================================================================
-- EMPLOYEE
-- =============================================================================

CREATE TABLE employee (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    application_id  UUID NOT NULL REFERENCES application(id),
    employee_number VARCHAR(50) NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive')),
    converted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_employee_application UNIQUE (application_id),
    CONSTRAINT uq_employee_tenant_number UNIQUE (tenant_id, employee_number)
);

CREATE TABLE employee_id_registry (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    employee_number VARCHAR(50) NOT NULL,
    format_version  VARCHAR(20) NOT NULL,
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_registry_tenant_number UNIQUE (tenant_id, employee_number)
);

-- =============================================================================
-- INTEGRATION, AUDIT, EVALUATION, RAG
-- =============================================================================

CREATE TABLE integration_outbox (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    event_type      VARCHAR(100) NOT NULL,
    payload         JSONB NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','delivered','failed','dead_letter')),
    attempt_count   INTEGER NOT NULL DEFAULT 0,
    available_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_outbox_status_available ON integration_outbox(status, available_at);

CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor_type      VARCHAR(20) NOT NULL CHECK (actor_type IN ('human','agent','system')),
    actor_id        VARCHAR(200) NOT NULL,
    action          VARCHAR(150) NOT NULL,
    subject_type    VARCHAR(50) NOT NULL,
    subject_id      UUID,
    approval_id     UUID REFERENCES approval(id),
    outcome         VARCHAR(20) NOT NULL CHECK (outcome IN ('success','denied','error')),
    metadata        JSONB NOT NULL DEFAULT '{}', -- must already be redacted before insert
    correlation_id  VARCHAR(100)
);
CREATE INDEX ix_audit_log_tenant_time ON audit_log(tenant_id, occurred_at);
CREATE INDEX ix_audit_log_subject ON audit_log(subject_type, subject_id);
-- Append-only: revoke UPDATE/DELETE grants on this table for all application roles except a
-- narrowly-scoped retention/legal-hold purge role.

CREATE TABLE model_version (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider        VARCHAR(100) NOT NULL,
    model_name      VARCHAR(100) NOT NULL,
    version_tag     VARCHAR(50) NOT NULL,
    risk_tier       VARCHAR(20) NOT NULL DEFAULT 'standard'
                        CHECK (risk_tier IN ('standard','elevated','restricted')),
    active          BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT uq_model_version UNIQUE (provider, model_name, version_tag)
);

CREATE TABLE prompt_version (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    skill_name      VARCHAR(100) NOT NULL,
    version_tag     VARCHAR(50) NOT NULL,
    content_ref     VARCHAR(1000) NOT NULL,
    approved_by     UUID REFERENCES user_account(id),
    approved_at     TIMESTAMPTZ,
    CONSTRAINT uq_prompt_version UNIQUE (skill_name, version_tag)
);

CREATE TABLE evaluation_record (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_type    VARCHAR(50) NOT NULL,
    subject_id      UUID,
    dataset_ref     VARCHAR(500) NOT NULL,
    score           JSONB NOT NULL DEFAULT '{}',
    evaluated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE rag_document (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    source_type     VARCHAR(50) NOT NULL, -- 'policy','process','jd_reference'
    classification  VARCHAR(30) NOT NULL DEFAULT 'internal',
    access_policy   JSONB NOT NULL DEFAULT '{}',
    effective_date  DATE,
    expiry_date     DATE,
    content_hash    VARCHAR(128) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE rag_chunk (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rag_document_id     UUID NOT NULL REFERENCES rag_document(id),
    heading_path        VARCHAR(500),
    page_or_clause_ref  VARCHAR(100),
    embedding_version   VARCHAR(50) NOT NULL,
    chunk_hash          VARCHAR(128) NOT NULL
    -- The embedding vector itself lives in the configured vector store, keyed by this row's id.
    -- See docs/adr/ADR-003-rag-and-vector-store-boundary.md.
);
CREATE INDEX ix_rag_chunk_document ON rag_chunk(rag_document_id);

CREATE TABLE idempotency_key_record (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_value           VARCHAR(200) NOT NULL UNIQUE,
    request_hash        VARCHAR(128) NOT NULL,
    response_snapshot_ref VARCHAR(1000),
    expires_at          TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_idempotency_expires ON idempotency_key_record(expires_at);

-- =============================================================================
-- ROW-LEVEL SECURITY (illustrative — enable and author policies per tenant model)
-- =============================================================================
-- Example pattern (repeat per tenant-scoped table):
-- ALTER TABLE candidate ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY tenant_isolation_candidate ON candidate
--     USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
-- Application connection must SET app.current_tenant_id per request/session.
-- [DBA/SECURITY REVIEW REQUIRED before enabling in production.]
