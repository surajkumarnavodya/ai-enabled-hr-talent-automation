using System.Globalization;
using System.Text;
using HrAutomation.Application.Contracts;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

/// <summary>Read-only queue over onboarding.VerificationCase. The verify-a-document write action
/// lives on DocumentsController (still a stub — no onboarding.VerificationCheck/VerificationResult
/// write path exists yet; see docs/09-quality-evaluation/production-readiness-report.md).</summary>
[Route("api/v1/verification")]
public sealed class VerificationController(HrAutomationDbContext db) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<VerificationQueueItemDto>>> ListQueue(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.VerificationCases
            .Where(v => v.TenantId == ctx.TenantId)
            .OrderByDescending(v => v.OpenedAtUtc)
            .ThenByDescending(v => v.VerificationCaseId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterOpenedAt, out var afterId))
        {
            query = query.Where(v =>
                v.OpenedAtUtc < afterOpenedAt ||
                (v.OpenedAtUtc == afterOpenedAt && v.VerificationCaseId.CompareTo(afterId) < 0));
        }

        var cases = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = cases.Count > limit;
        var pageCases = cases.Take(limit).ToList();

        var dtos = await ToDtosAsync(pageCases, ct);
        var nextCursor = hasMore ? EncodeCursor(pageCases[^1].OpenedAtUtc, pageCases[^1].VerificationCaseId) : null;

        return Ok(new CursorPage<VerificationQueueItemDto> { Items = dtos, NextCursor = nextCursor });
    }

    [HttpGet("{applicationId:guid}")]
    public async Task<IActionResult> GetByApplication(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var verificationCase = await db.VerificationCases
            .FirstOrDefaultAsync(v => v.CandidateApplicationId == applicationId && v.TenantId == ctx.TenantId, ct);
        if (verificationCase is null)
        {
            return NotFound();
        }

        var dtos = await ToDtosAsync([verificationCase], ct);
        return Ok(dtos[0]);
    }

    private async Task<List<VerificationQueueItemDto>> ToDtosAsync(List<OnboardingVerificationCase> cases, CancellationToken ct)
    {
        if (cases.Count == 0) return [];

        var applicationIds = cases.Select(c => c.CandidateApplicationId).Distinct().ToList();
        var applications = await db.CandidateApplications
            .Where(a => applicationIds.Contains(a.CandidateApplicationId))
            .ToDictionaryAsync(a => a.CandidateApplicationId, ct);

        var candidateIds = applications.Values.Select(a => a.CandidateId).Distinct().ToList();
        var candidates = await db.Candidates
            .Where(c => candidateIds.Contains(c.CandidateId))
            .ToDictionaryAsync(c => c.CandidateId, ct);

        return cases.Select(c =>
        {
            applications.TryGetValue(c.CandidateApplicationId, out var application);
            var candidateName = application is not null && candidates.TryGetValue(application.CandidateId, out var candidate)
                ? $"{candidate.FirstName} {candidate.LastName}"
                : string.Empty;

            return new VerificationQueueItemDto
            {
                ApplicationId = c.CandidateApplicationId,
                CandidateName = candidateName,
                Status = c.Status,
                OpenedAt = c.OpenedAtUtc
            };
        }).ToList();
    }

    private static string EncodeCursor(DateTime openedAtUtc, Guid id) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{openedAtUtc:O}|{id}"));

    private static bool TryDecodeCursor(string cursor, out DateTime openedAtUtc, out Guid id)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|');
            openedAtUtc = DateTime.Parse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
            id = Guid.Parse(parts[1]);
            return true;
        }
        catch (FormatException)
        {
            openedAtUtc = default;
            id = default;
            return false;
        }
    }
}
