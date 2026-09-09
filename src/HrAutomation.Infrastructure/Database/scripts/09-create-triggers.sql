/* ============================================================================
   09-create-triggers.sql
   Purpose : The essential trigger categories from section 12 of the design
             spec. Triggers are deliberately minimal — business logic belongs
             in stored procedures/the Application layer, not here. Every
             trigger below is set-based (works correctly for multi-row
             INSERT/UPDATE/DELETE), uses no cursors, and calls no external
             system.
   Idempotent: Yes (CREATE OR ALTER TRIGGER).
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ----------------------------------------------------------------------------
   Category 1 — Append-only protection for audit tables. Applied to every
   table in the audit schema. Even db_owner/sysadmin cannot UPDATE or DELETE
   through this trigger (INSTEAD OF triggers fire before any permission-level
   exemption would apply); the only sanctioned path around it is the
   documented retention/legal-hold purge process (maintenance.usp_
   ExecuteRetentionPolicy), which is intentionally NOT exempted either — that
   procedure works by archiving to a separate, non-audit-schema table before
   any deletion, never by deleting from audit.* directly. See
   docs/trigger-catalog.md and docs/data-retention-and-privacy.md.
   ---------------------------------------------------------------------------- */

CREATE OR ALTER TRIGGER audit.trg_AuditEvent_PreventModify
ON audit.AuditEvent
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, 'audit.AuditEvent is append-only. UPDATE/DELETE is not permitted — see docs/data-retention-and-privacy.md for the legal-hold/retention purge process.', 1;
END
GO

CREATE OR ALTER TRIGGER audit.trg_SecurityEvent_PreventModify
ON audit.SecurityEvent
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, 'audit.SecurityEvent is append-only.', 1;
END
GO

CREATE OR ALTER TRIGGER audit.trg_DataAccessEvent_PreventModify
ON audit.DataAccessEvent
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, 'audit.DataAccessEvent is append-only.', 1;
END
GO

CREATE OR ALTER TRIGGER audit.trg_PrivilegedActionEvent_PreventModify
ON audit.PrivilegedActionEvent
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, 'audit.PrivilegedActionEvent is append-only.', 1;
END
GO

CREATE OR ALTER TRIGGER audit.trg_ErrorEvent_PreventModify
ON audit.ErrorEvent
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, 'audit.ErrorEvent is append-only.', 1;
END
GO

CREATE OR ALTER TRIGGER audit.trg_RetentionExecutionLog_PreventModify
ON audit.RetentionExecutionLog
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, 'audit.RetentionExecutionLog is append-only.', 1;
END
GO

/* ----------------------------------------------------------------------------
   Category 2 — Block direct invalid updates/deletes for critical immutable
   records. offer.OfferCompensation is never edited after creation — a
   compensation change is a NEW offer.OfferVersion + offer.OfferCompensation
   row per non-negotiable "never calculate or approve compensation... without
   approved business workflow." Set-based, multi-row safe.
   ---------------------------------------------------------------------------- */

CREATE OR ALTER TRIGGER offer.trg_OfferCompensation_PreventModify
ON offer.OfferCompensation
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, 'offer.OfferCompensation is immutable once created — create a new OfferVersion + OfferCompensation row instead. See offer.usp_AddOfferCompensationComponent.', 1;
END
GO

PRINT N'09-create-triggers.sql complete (audit append-only protection + OfferCompensation immutability).';
