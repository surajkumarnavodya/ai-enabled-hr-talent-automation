using System.Globalization;
using System.Text;
using HrAutomation.Agents.CvIngestion;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence.Entities;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/candidates")]
public sealed class CandidatesController(HrAutomationDbContext db, ISkillRegistry skillRegistry, IGuardrailPipeline guardrails)
    : HrControllerBase
{
    [HttpPost("cvs")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10_485_760)]
    public async Task<IActionResult> UploadCv(IFormFile file, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("parse_cv_skill");

        if (!IsAuthorizedForSkill(skill, ctx))
        {
            return ForbiddenForSkill(skill, ctx);
        }

        if (file is null || file.Length == 0)
        {
            return Problem(statusCode: StatusCodes.Status422UnprocessableEntity, title: "Invalid input", detail: "A non-empty file is required.");
        }

        await using var memoryStream = new MemoryStream();
        await file.CopyToAsync(memoryStream, ct);

        var input = new CvUploadInput
        {
            OriginalFileName = file.FileName,
            ContentType = file.ContentType,
            FileSizeBytes = file.Length,
            Content = memoryStream.ToArray()
        };

        var guardrailResults = guardrails.Evaluate(new GuardrailCheckInput
        {
            RequestContext = ctx,
            RequiredRoles = skill.RequiredRoles,
            UntrustedTextToScan = file.FileName
        });

        if (!guardrailResults.AllPass)
        {
            var blocked = new SkillResult
            {
                Status = ActionStatus.blocked,
                Summary = "Blocked by guardrail check.",
                RisksOrExceptions = ["One or more guardrail checks failed - see guardrail_results."]
            };
            return Ok(AgentActionResponseFactory.Build(ctx, "upload_cv", "n/a", "N/A", null, blocked, guardrailResults, actorId: skill.SkillName));
        }

        var skillResult = await skill.ExecuteAsync(new SkillContext
        {
            RequestContext = ctx,
            WorkflowInstanceId = Guid.Empty,
            Input = input
        }, ct);

        var response = AgentActionResponseFactory.Build(ctx, "upload_cv", "n/a", "N/A", null, skillResult, guardrailResults, actorId: skill.SkillName);
        return skillResult.Status == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    [HttpGet]
    public async Task<ActionResult<CursorPage<CandidateDto>>> ListCandidates(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.Candidates
            .Where(c => c.TenantId == ctx.TenantId)
            .OrderByDescending(c => c.CreatedAtUtc)
            .ThenByDescending(c => c.CandidateId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterCreatedAt, out var afterId))
        {
            query = query.Where(c =>
                c.CreatedAtUtc < afterCreatedAt ||
                (c.CreatedAtUtc == afterCreatedAt && c.CandidateId.CompareTo(afterId) < 0));
        }

        var items = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = items.Count > limit;
        var pageItems = items.Take(limit).ToList();
        var sourceCodes = await ResolveSourceCodesAsync(pageItems, ct);
        var page = pageItems.Select(c => ToDto(c, sourceCodes.GetValueOrDefault(c.PrimaryCandidateSourceId ?? Guid.Empty))).ToList();
        var nextCursor = hasMore ? EncodeCursor(pageItems[^1].CreatedAtUtc, pageItems[^1].CandidateId) : null;

        return Ok(new CursorPage<CandidateDto> { Items = page, NextCursor = nextCursor });
    }

    [HttpGet("{candidateId:guid}")]
    public async Task<IActionResult> GetCandidate(Guid candidateId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var candidate = await db.Candidates.FirstOrDefaultAsync(c => c.CandidateId == candidateId && c.TenantId == ctx.TenantId, ct);
        if (candidate is null)
        {
            return NotFound();
        }

        var sourceCode = candidate.PrimaryCandidateSourceId is null
            ? null
            : await db.CandidateSources.Where(s => s.CandidateSourceId == candidate.PrimaryCandidateSourceId).Select(s => s.Code).FirstOrDefaultAsync(ct);
        return Ok(ToDto(candidate, sourceCode));
    }

    [HttpPatch("{candidateId:guid}")]
    public async Task<IActionResult> PatchCandidate(
        Guid candidateId,
        [FromBody] PatchCandidateRequest request,
        [FromHeader(Name = "If-Match")] string? ifMatch,
        CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var candidate = await db.Candidates.FirstOrDefaultAsync(c => c.CandidateId == candidateId && c.TenantId == ctx.TenantId, ct);
        if (candidate is null)
        {
            return NotFound();
        }

        if (!string.IsNullOrEmpty(ifMatch) && ifMatch.Trim('"') != Convert.ToBase64String(candidate.RowVersion))
        {
            return Problem(statusCode: StatusCodes.Status409Conflict, title: "Version conflict",
                detail: "The candidate record has been modified since it was last read.");
        }

        if (request.FullName is not null)
        {
            (candidate.FirstName, candidate.LastName) = SplitName(request.FullName);
        }
        // NOTE (documented gap): request.CurrentLocation is free text; recruitment.Candidate stores
        // CurrentLocationId as an FK into org.Location, so it is accepted but not persisted pending
        // a name-to-location-id resolution decision (same gap as CreateTanSkill's Location/Grade).
        if (request.TotalExperienceMonths is not null)
        {
            candidate.TotalExperienceYears = Math.Round(request.TotalExperienceMonths.Value / 12m, 1);
        }
        candidate.UpdatedByUserId = ctx.UserId;
        candidate.UpdatedAtUtc = DateTime.UtcNow;

        await db.SaveChangesAsync(ct);

        var sourceCode = candidate.PrimaryCandidateSourceId is null
            ? null
            : await db.CandidateSources.Where(s => s.CandidateSourceId == candidate.PrimaryCandidateSourceId).Select(s => s.Code).FirstOrDefaultAsync(ct);
        return Ok(ToDto(candidate, sourceCode));
    }

    private async Task<Dictionary<Guid, string>> ResolveSourceCodesAsync(List<RecruitmentCandidate> candidates, CancellationToken ct)
    {
        var sourceIds = candidates.Where(c => c.PrimaryCandidateSourceId is not null)
            .Select(c => c.PrimaryCandidateSourceId!.Value).Distinct().ToList();
        if (sourceIds.Count == 0)
        {
            return [];
        }

        return await db.CandidateSources
            .Where(s => sourceIds.Contains(s.CandidateSourceId))
            .ToDictionaryAsync(s => s.CandidateSourceId, s => s.Code, ct);
    }

    private static CandidateDto ToDto(RecruitmentCandidate c, string? sourceCode) => new()
    {
        CandidateId = c.CandidateId,
        FullName = $"{c.FirstName} {c.LastName}".Trim(),
        CurrentLocation = null, // see PatchCandidate's documented gap note
        TotalExperienceMonths = c.TotalExperienceYears is { } years ? (int)Math.Round(years * 12) : 0,
        Source = sourceCode ?? "Unknown",
        IsActive = c.IsActive,
        CreatedAtUtc = c.CreatedAtUtc,
        RowVersion = Convert.ToBase64String(c.RowVersion)
    };

    private static (string FirstName, string LastName) SplitName(string fullName)
    {
        var parts = fullName.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Length > 1 ? (parts[0], parts[1]) : (fullName, "-");
    }

    private static string EncodeCursor(DateTime createdAtUtc, Guid id) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{createdAtUtc:O}|{id}"));

    private static bool TryDecodeCursor(string cursor, out DateTime createdAtUtc, out Guid id)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|');
            createdAtUtc = DateTime.Parse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
            id = Guid.Parse(parts[1]);
            return true;
        }
        catch (FormatException)
        {
            createdAtUtc = default;
            id = default;
            return false;
        }
    }
}
