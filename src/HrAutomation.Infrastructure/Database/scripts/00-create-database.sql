/* ============================================================================
   00-create-database.sql
   Purpose : Create the HR Automation database with safe, configurable defaults.
   Run as  : A login with CREATE DATABASE permission (never the application's
             least-privilege runtime login — see docs/security-model.md).
   Idempotent: Yes — safe to re-run.

   Configurable via sqlcmd variable. Example:
     sqlcmd -S "(localdb)\MSSQLLocalDB" -U sa -P "$env:HR_DB_SA_PASSWORD" -C ^
       -v DatabaseName="HrAutomationDb" -i 00-create-database.sql
   ============================================================================ */
:setvar DatabaseName "HrAutomationDb"

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DB_ID(N'$(DatabaseName)') IS NULL
BEGIN
    PRINT N'Creating database [$(DatabaseName)]...';

    DECLARE @sql nvarchar(max) = N'CREATE DATABASE ' + QUOTENAME(N'$(DatabaseName)');
    EXEC (@sql);
END
ELSE
BEGIN
    PRINT N'Database [$(DatabaseName)] already exists — skipping create.';
END
GO

/* Recommended baseline database options for an OLTP workload with optimistic
   concurrency (rowversion) and read-committed-snapshot to reduce blocking
   between the transactional write path and reporting reads. */
DECLARE @dbName sysname = N'$(DatabaseName)';
DECLARE @opt nvarchar(max) = N'
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET RECOVERY SIMPLE;
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET AUTO_CLOSE OFF;
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET AUTO_SHRINK OFF;
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET QUERY_STORE = ON;
ALTER DATABASE ' + QUOTENAME(@dbName) + N' SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
';
-- RECOVERY SIMPLE is the dev-friendly default for LocalDB (no log-backup management).
-- Staging/production MUST switch to RECOVERY FULL with a scheduled log-backup job before
-- go-live — point-in-time restore is not possible under SIMPLE. See docs/backup-recovery-and-dr.md.
EXEC (@opt);
GO

PRINT N'00-create-database.sql complete.';
