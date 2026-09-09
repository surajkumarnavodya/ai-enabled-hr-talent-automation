/* ============================================================================
   07-seed-onboarding-offer-configuration.sql
   Purpose : Seed offer templates, the remaining numbering rules (Candidate
             reference, Offer, Employee ID, Discrepancy report — TAN is
             seeded in 06), Green Form sections/field definitions, and the
             standard document checklist.
   Depends on: 01, 02, 03, 04 (document types), 06 (TAN numbering rule note).
   Idempotent: Yes.

   Verification-provider configuration (section 11F of the request) and
   discrepancy severity/status/escalation defaults (section 11G) are NOT
   re-seeded here — they already exist from 04-seed-reference-master-data.sql
   (ref.VerificationType, ref.DiscrepancySeverity, ref.DiscrepancyStatus),
   05-seed-workflow-approval-sla.sql (SLA rule + re-upload/clarification
   notification templates), and 08-seed-ai-rag-integration-configuration.sql
   (BACKGROUND_VERIFICATION_PROVIDER integration metadata). Re-inserting them
   here would either duplicate or conflict with those scripts' ownership.

   SCHEMA NOTE (M15): onboarding.GreenFormFieldDefinition has no dedicated
   "restricted/sensitive" classification column — sensitivity is documented
   in FieldLabel text only. onboarding.GreenFormFieldValue.ValueText is a
   single nvarchar(4000) column with no per-field encryption-at-rest marker
   beyond the table's own general protections — bank/tax/statutory fields are
   marked conditional (IsRequired = 0) and their sensitivity is called out in
   the field label for reviewer visibility.
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @TenantCode nvarchar(50) = N'DEMO-HR';
DECLARE @TenantId UNIQUEIDENTIFIER;
DECLARE @ActorUserId UNIQUEIDENTIFIER;
DECLARE @CorrelationId UNIQUEIDENTIFIER = NEWID();
DECLARE @ExecutionUtc datetime2(7) = SYSUTCDATETIME();

SELECT @TenantId = TenantId FROM org.Tenant WHERE TenantCode = @TenantCode AND IsDeleted = 0;
IF @TenantId IS NULL
    THROW 50001, 'Seed execution failed: tenant was not found. Run 01-seed-tenant-organization.sql first.', 1;

SELECT @ActorUserId = UserId FROM iam.[User] WHERE TenantId = @TenantId AND Email = N'demo.hr.admin@example.test' AND IsDeleted = 0;
IF @ActorUserId IS NULL
    THROW 50002, 'Seed execution failed: seed administrator user was not found. Run 03-seed-iam-users-access.sql first.', 1;

IF NOT EXISTS (SELECT 1 FROM ref.DocumentType WHERE TenantId = @TenantId AND IsDeleted = 0)
    THROW 50003, 'Seed execution failed: reference document types were not found. Run 04-seed-reference-master-data.sql first.', 1;

EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
EXEC sys.sp_set_session_context @key = N'UserId', @value = @ActorUserId;
EXEC sys.sp_set_session_context @key = N'CorrelationId', @value = @CorrelationId;

BEGIN TRY
    BEGIN TRAN;

    -- ========================================================================
    -- A. Offer templates (placeholders only — no legal/offer-letter content)
    -- ========================================================================
    DECLARE @OfferTemplates TABLE (Code nvarchar(200), Name nvarchar(400));
    INSERT INTO @OfferTemplates (Code, Name) VALUES
    (N'DEMO_STANDARD_OFFER', N'Demo Standard Offer'), (N'DEMO_CONTRACT_OFFER', N'Demo Contract Offer'),
    (N'DEMO_INTERNSHIP_OFFER', N'Demo Internship Offer');

    INSERT INTO ref.OfferTemplate (TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, t.Code, t.Name, 1, @ExecutionUtc, @ActorUserId
    FROM @OfferTemplates t
    WHERE NOT EXISTS (SELECT 1 FROM ref.OfferTemplate x WHERE x.TenantId = @TenantId AND x.Code = t.Code AND x.IsDeleted = 0);

    DECLARE @OfferTemplateBody nvarchar(max) = N'Dear {{CandidateName}}, we are pleased to offer you the position of {{JobTitle}} (Grade {{Grade}}) in {{Department}}, based at {{Location}}, reporting to {{ReportingManager}}, with a proposed joining date of {{JoiningDate}}. Compensation summary: {{CompensationSummary}}. This offer is valid until {{OfferExpiryDate}}. Authorized by {{AuthorizedSignatory}}. [LEGAL_REVIEW_REQUIRED: this is a placeholder template only, not approved offer-letter legal content.]';

    INSERT INTO ref.OfferTemplateVersion (OfferTemplateId, VersionNumber, BodyTemplate, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
    SELECT ot.OfferTemplateId, 1, @OfferTemplateBody, N'Approved', @ExecutionUtc, @ActorUserId
    FROM ref.OfferTemplate ot
    WHERE ot.TenantId = @TenantId AND ot.Code IN (SELECT Code FROM @OfferTemplates)
      AND NOT EXISTS (SELECT 1 FROM ref.OfferTemplateVersion x WHERE x.OfferTemplateId = ot.OfferTemplateId AND x.VersionNumber = 1 AND x.IsDeleted = 0);

    -- ========================================================================
    -- B. Numbering rules (TAN already seeded in 06)
    -- ========================================================================
    DECLARE @NumberingRules TABLE (EntityType nvarchar(200), Prefix nvarchar(40), PaddingWidth int, NumberFormat nvarchar(200));
    INSERT INTO @NumberingRules (EntityType, Prefix, PaddingWidth, NumberFormat) VALUES
    (N'CandidateReference', N'CAN-', 6, N'CAN-{YYYY}-{SEQ:6}'),
    (N'OfferNumber', N'OFF-', 6, N'OFF-{YYYY}-{SEQ:6}'),
    (N'EmployeeId', N'EMP-', 6, N'EMP-{TENANT}-{YYYY}-{SEQ:6}'),
    (N'DiscrepancyReport', N'DSR-', 6, N'DSR-{YYYY}-{SEQ:6}');

    INSERT INTO ref.NumberingRule (TenantId, EntityType, Prefix, NumberFormat, PaddingWidth, ResetPolicy, IsActive, CreatedAtUtc, CreatedByUserId)
    SELECT @TenantId, n.EntityType, n.Prefix, n.NumberFormat, n.PaddingWidth, N'Yearly', 1, @ExecutionUtc, @ActorUserId
    FROM @NumberingRules n
    WHERE NOT EXISTS (SELECT 1 FROM ref.NumberingRule x WHERE x.TenantId = @TenantId AND x.EntityType = n.EntityType AND x.IsDeleted = 0);
    -- NOTE (see final report M6): as with TAN, EmployeeId/OfferNumber
    -- generation procedures only apply Prefix + zero-padded sequence + Suffix
    -- — {YYYY}/{TENANT}/{SEQ:n} tokens in NumberFormat are descriptive only.
    -- CandidateReference and DiscrepancyReport have no consuming procedure at
    -- all today (see M5): recruitment.Candidate has no business-code column.

    -- ========================================================================
    -- C. Green Form sections
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM onboarding.GreenForm WHERE TenantId = @TenantId AND Code = N'DEMO_STANDARD_GREEN_FORM' AND IsDeleted = 0)
        INSERT INTO onboarding.GreenForm (TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'DEMO_STANDARD_GREEN_FORM', N'Demo Standard Green Form', 1, @ExecutionUtc, @ActorUserId);

    DECLARE @GreenFormId UNIQUEIDENTIFIER = (SELECT GreenFormId FROM onboarding.GreenForm WHERE TenantId = @TenantId AND Code = N'DEMO_STANDARD_GREEN_FORM' AND IsDeleted = 0);

    IF NOT EXISTS (SELECT 1 FROM onboarding.GreenFormVersion WHERE GreenFormId = @GreenFormId AND VersionNumber = 1)
        INSERT INTO onboarding.GreenFormVersion (TenantId, GreenFormId, VersionNumber, ApprovalStatus, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, @GreenFormId, 1, N'Approved', @ExecutionUtc, @ActorUserId);

    DECLARE @GreenFormVersionId UNIQUEIDENTIFIER = (SELECT GreenFormVersionId FROM onboarding.GreenFormVersion WHERE GreenFormId = @GreenFormId AND VersionNumber = 1);

    IF NOT EXISTS (SELECT 1 FROM onboarding.GreenForm WHERE GreenFormId = @GreenFormId AND CurrentVersionId = @GreenFormVersionId)
        UPDATE onboarding.GreenForm SET CurrentVersionId = @GreenFormVersionId WHERE GreenFormId = @GreenFormId;

    DECLARE @Sections TABLE (Code nvarchar(100), Title nvarchar(400), SortOrder int);
    INSERT INTO @Sections (Code, Title, SortOrder) VALUES
    (N'PERSONAL_DETAILS', N'Personal Details', 10), (N'CONTACT_DETAILS', N'Contact Details', 20),
    (N'ADDRESS_DETAILS', N'Address Details', 30), (N'EMERGENCY_CONTACT', N'Emergency Contact', 40),
    (N'EDUCATION_DETAILS', N'Education Details', 50), (N'EMPLOYMENT_DETAILS', N'Employment Details', 60),
    (N'DECLARATION', N'Declaration', 70), (N'DOCUMENT_UPLOADS', N'Document Uploads', 80);

    INSERT INTO onboarding.GreenFormSection (TenantId, GreenFormVersionId, SectionCode, SectionTitle, SortOrder)
    SELECT @TenantId, @GreenFormVersionId, s.Code, s.Title, s.SortOrder
    FROM @Sections s
    WHERE NOT EXISTS (SELECT 1 FROM onboarding.GreenFormSection x WHERE x.GreenFormVersionId = @GreenFormVersionId AND x.SectionCode = s.Code);

    -- ========================================================================
    -- D. Default Green Form field definitions
    -- ========================================================================
    DECLARE @Fields TABLE (SectionCode nvarchar(100), FieldCode nvarchar(200), FieldLabel nvarchar(400), FieldType nvarchar(60), IsRequired bit, SortOrder int);
    INSERT INTO @Fields (SectionCode, FieldCode, FieldLabel, FieldType, IsRequired, SortOrder) VALUES
    (N'PERSONAL_DETAILS', N'FULL_NAME', N'Full Name', N'Text', 1, 10),
    (N'PERSONAL_DETAILS', N'DATE_OF_BIRTH', N'Date of Birth [LEGAL_REVIEW_REQUIRED: confirm policy/legal basis before collecting]', N'Date', 0, 20),
    (N'CONTACT_DETAILS', N'PERSONAL_EMAIL', N'Personal Email', N'Text', 1, 10),
    (N'CONTACT_DETAILS', N'MOBILE_NUMBER', N'Mobile Number', N'Text', 1, 20),
    (N'ADDRESS_DETAILS', N'CURRENT_ADDRESS', N'Current Address', N'Text', 1, 10),
    (N'ADDRESS_DETAILS', N'PERMANENT_ADDRESS', N'Permanent Address', N'Text', 1, 20),
    (N'EMERGENCY_CONTACT', N'EMERGENCY_CONTACT_DETAILS', N'Emergency Contact (name, relationship, phone)', N'Text', 1, 10),
    (N'EDUCATION_DETAILS', N'EDUCATION_HISTORY', N'Education History', N'Text', 1, 10),
    (N'EMPLOYMENT_DETAILS', N'EMPLOYMENT_HISTORY', N'Employment History', N'Text', 0, 10),
    (N'EMPLOYMENT_DETAILS', N'EMPLOYMENT_GAP_EXPLANATION', N'Employment Gap Explanation (if applicable)', N'Text', 0, 20),
    (N'EMPLOYMENT_DETAILS', N'BANK_ACCOUNT_REFERENCE', N'Bank Account Reference — restricted, conditional (statutory/payroll setup only)', N'Text', 0, 30),
    (N'EMPLOYMENT_DETAILS', N'TAX_IDENTIFIER_REFERENCE', N'Tax Identifier Reference — restricted, conditional (statutory/payroll setup only)', N'Text', 0, 40),
    (N'DECLARATION', N'DECLARATION_ACKNOWLEDGEMENT', N'Declaration Acknowledgement', N'Boolean', 1, 10);

    INSERT INTO onboarding.GreenFormFieldDefinition (TenantId, GreenFormSectionId, FieldCode, FieldLabel, FieldType, IsRequired, SortOrder)
    SELECT @TenantId, gfs.GreenFormSectionId, f.FieldCode, f.FieldLabel, f.FieldType, f.IsRequired, f.SortOrder
    FROM @Fields f
    JOIN onboarding.GreenFormSection gfs ON gfs.GreenFormVersionId = @GreenFormVersionId AND gfs.SectionCode = f.SectionCode
    WHERE NOT EXISTS (
        SELECT 1 FROM onboarding.GreenFormFieldDefinition x
        WHERE x.GreenFormSectionId = gfs.GreenFormSectionId AND x.FieldCode = f.FieldCode
    );

    -- ========================================================================
    -- E. Document checklist (all employees)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM ref.DocumentChecklist WHERE TenantId = @TenantId AND Code = N'DEMO_STANDARD_CHECKLIST' AND IsDeleted = 0)
        INSERT INTO ref.DocumentChecklist (TenantId, Code, Name, IsActive, CreatedAtUtc, CreatedByUserId)
        VALUES (@TenantId, N'DEMO_STANDARD_CHECKLIST', N'Demo Standard Onboarding Document Checklist', 1, @ExecutionUtc, @ActorUserId);

    DECLARE @ChecklistId UNIQUEIDENTIFIER = (SELECT DocumentChecklistId FROM ref.DocumentChecklist WHERE TenantId = @TenantId AND Code = N'DEMO_STANDARD_CHECKLIST' AND IsDeleted = 0);

    DECLARE @ChecklistItems TABLE (DocumentTypeCode nvarchar(100), IsMandatory bit, SortOrder int);
    INSERT INTO @ChecklistItems (DocumentTypeCode, IsMandatory, SortOrder) VALUES
    (N'RESUME', 1, 10), (N'GOVERNMENT_ID', 1, 20), (N'ADDRESS_PROOF', 1, 30),
    (N'EDUCATION_CERTIFICATE', 1, 40), (N'EXPERIENCE_LETTER', 0, 50),
    (N'RELIEVING_LETTER', 0, 60), (N'SIGNED_OFFER_LETTER', 1, 70);
    -- ExperienceLetter/RelievingLetter are IsMandatory = 0 (conditional on
    -- prior employment) per section 11E; the checklist-evaluation procedure
    -- that would apply this condition automatically is not yet implemented
    -- (see docs/stored-procedure-catalog.md) — HR applies the condition
    -- manually today.

    INSERT INTO ref.DocumentChecklistItem (DocumentChecklistId, DocumentTypeId, IsMandatory, SortOrder, CreatedAtUtc, CreatedByUserId)
    SELECT @ChecklistId, dt.DocumentTypeId, ci.IsMandatory, ci.SortOrder, @ExecutionUtc, @ActorUserId
    FROM @ChecklistItems ci
    JOIN ref.DocumentType dt ON dt.TenantId = @TenantId AND dt.Code = ci.DocumentTypeCode AND dt.IsDeleted = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM ref.DocumentChecklistItem x
        WHERE x.DocumentChecklistId = @ChecklistId AND x.DocumentTypeId = dt.DocumentTypeId AND x.IsDeleted = 0
    );

    COMMIT TRAN;
    PRINT N'07-seed-onboarding-offer-configuration.sql complete.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
