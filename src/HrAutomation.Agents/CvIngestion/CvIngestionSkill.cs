using System.Data;
using System.Security.Cryptography;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Agents.CvIngestion;

public sealed class CvUploadInput
{
    public required string OriginalFileName { get; init; }
    public required string ContentType { get; init; }
    public required long FileSizeBytes { get; init; }
    public required byte[] Content { get; init; }
}

/// <summary>The CV Ingestion and Parsing Agent (spec 3.B): scan -> extract -> dedup-suggest -> persist.
/// Never advances a workflow by itself - just adds to the Master CV Bank. Candidate creation goes
/// through recruitment.usp_CreateCandidate (multi-entity, audited); CV/parsing metadata is plain EF
/// Core CRUD per Persistence/README.md. A suspected duplicate is never auto-merged - it is recorded
/// via recruitment.usp_CreateDuplicateReview for a human to confirm (spec: AI never autonomously
/// merges/rejects a candidate).</summary>
public sealed class CvIngestionSkill(HrAutomationDbContext db, IMalwareScanner malwareScanner, ICvFieldExtractor extractor) : ISkill
{
    public string SkillName => "parse_cv_skill";
    public string SkillVersion => "0.1.0";
    public IReadOnlyCollection<string> RequiredRoles { get; } = ["RECRUITER", "HR_ADMIN"];

    private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "application/pdf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "image/jpeg", "image/png", "image/tiff",
        "text/plain" // demo-only path handled by SimpleCvExtractor
    };

    private const long MaxFileSizeBytes = 10 * 1024 * 1024;

    public async Task<SkillResult> ExecuteAsync(SkillContext context, CancellationToken ct = default)
    {
        var input = context.Input as CvUploadInput
            ?? throw new InvalidOperationException("CvIngestionSkill requires CvUploadInput.");

        if (!AllowedContentTypes.Contains(input.ContentType) || input.FileSizeBytes is 0 or > MaxFileSizeBytes)
        {
            return new SkillResult
            {
                Status = ActionStatus.blocked,
                Summary = "CV rejected: unsupported file type or file size out of allowed range.",
                RisksOrExceptions = ["Unsupported content type or file size"]
            };
        }

        var scanPassed = await malwareScanner.ScanAsync(input.Content, ct);
        if (!scanPassed)
        {
            return new SkillResult
            {
                Status = ActionStatus.blocked,
                Summary = "CV rejected: malware scan failed.",
                RisksOrExceptions = ["Malware scan failed"]
            };
        }

        var extraction = extractor.Extract(input.Content, input.ContentType, input.OriginalFileName);
        var tenantId = context.RequestContext.TenantId;

        var normalizedEmail = extraction.Email?.Trim().ToLowerInvariant();
        var normalizedPhone = extraction.Phone is null
            ? null
            : new string(extraction.Phone.Where(char.IsDigit).ToArray());

        var suspectedDuplicateId = normalizedEmail is null && normalizedPhone is null
            ? null
            : await db.CandidateContacts
                .Where(c => c.TenantId == tenantId
                    && ((normalizedEmail != null && c.ContactType == "Email" && c.NormalizedValue == normalizedEmail)
                        || (normalizedPhone != null && c.ContactType == "Phone" && c.NormalizedValue == normalizedPhone)))
                .Select(c => (Guid?)c.CandidateId)
                .FirstOrDefaultAsync(ct);

        var nameParts = extraction.FullName.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var firstName = nameParts.Length > 0 ? nameParts[0] : extraction.FullName;
        var lastName = nameParts.Length > 1 ? nameParts[1] : "-";

        var createResult = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "recruitment.usp_CreateCandidate",
            [
                StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@FirstName", firstName, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@LastName", lastName, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@Email", extraction.Email, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@Phone", extraction.Phone, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@CandidateSourceCode", "OTHER", SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@CreatedByUserId", context.RequestContext.UserId, SqlDbType.UniqueIdentifier)
            ], ct);

        if (!createResult.Success || createResult.EntityId is not { } candidateId)
        {
            return new SkillResult
            {
                Status = ActionStatus.failed,
                Summary = $"Candidate creation failed: {createResult.Message}",
                RisksOrExceptions = [createResult.ErrorCode ?? "CANDIDATE_CREATE_FAILED"]
            };
        }

        if (suspectedDuplicateId is { } duplicateOfId)
        {
            await StoredProcedureExecutor.ExecuteAsync(
                db.Database, "recruitment.usp_CreateDuplicateReview",
                [
                    StoredProcedureExecutor.Param("@TenantId", tenantId, SqlDbType.UniqueIdentifier),
                    StoredProcedureExecutor.Param("@PrimaryCandidateId", duplicateOfId, SqlDbType.UniqueIdentifier),
                    StoredProcedureExecutor.Param("@SuspectedDuplicateCandidateId", candidateId, SqlDbType.UniqueIdentifier),
                    StoredProcedureExecutor.Param("@MatchReason", "Email/phone match on CV upload", SqlDbType.NVarChar),
                    StoredProcedureExecutor.Param("@CreatedByUserId", context.RequestContext.UserId, SqlDbType.UniqueIdentifier)
                ], ct);
        }

        var cv = new RecruitmentCandidateCv
        {
            CandidateCvId = Guid.NewGuid(),
            TenantId = tenantId,
            CandidateId = candidateId,
            IsPrimary = true,
            CreatedAtUtc = DateTime.UtcNow
        };
        db.CandidateCvs.Add(cv);

        var contentHash = SHA256.HashData(input.Content);
        var cvVersion = new RecruitmentCandidateCvVersion
        {
            CandidateCvVersionId = Guid.NewGuid(),
            TenantId = tenantId,
            CandidateCvId = cv.CandidateCvId,
            VersionNumber = 1,
            ObjectStorageUri = $"cvs/{tenantId}/{cv.CandidateCvId}",
            FileName = input.OriginalFileName,
            MimeType = input.ContentType,
            FileSizeBytes = input.FileSizeBytes,
            ContentHash = contentHash,
            MalwareScanStatus = "Clean",
            UploadedByUserId = context.RequestContext.UserId,
            UploadedAtUtc = DateTime.UtcNow
        };
        db.CandidateCvVersions.Add(cvVersion);

        var parsingResult = new RecruitmentCvParsingResult
        {
            CvParsingResultId = Guid.NewGuid(),
            TenantId = tenantId,
            CandidateCvVersionId = cvVersion.CandidateCvVersionId,
            ParseStatus = extraction.RequiresHumanReview ? "LowConfidence" : "Succeeded",
            ConfidenceScore = extraction.ConfidenceScore,
            RequiresHumanReview = extraction.RequiresHumanReview
        };
        db.CvParsingResults.Add(parsingResult);

        foreach (var skillName in extraction.Skills)
        {
            db.CvExtractionFields.Add(new RecruitmentCvExtractionField
            {
                CvExtractionFieldId = Guid.NewGuid(),
                TenantId = tenantId,
                CvParsingResultId = parsingResult.CvParsingResultId,
                FieldName = "Skill",
                FieldValue = skillName,
                ConfidenceScore = extraction.ConfidenceScore
            });
        }

        await db.SaveChangesAsync(ct);

        return new SkillResult
        {
            Status = ActionStatus.completed,
            CandidateId = candidateId.ToString(),
            DataUpdated = ["recruitment.Candidate", "recruitment.CandidateCv", "recruitment.CvParsingResult"],
            Summary = suspectedDuplicateId is null
                ? "New candidate created in the Master CV Bank from uploaded CV."
                : "Candidate created; a suspected duplicate was flagged for human review (not auto-merged).",
            JobRelatedEvidence = [.. extraction.Skills],
            Confidence = extraction.ConfidenceScore,
            RisksOrExceptions = extraction.RequiresHumanReview
                ? ["Low-confidence extraction - route to HR review before use in candidate matching."]
                : []
        };
    }
}
