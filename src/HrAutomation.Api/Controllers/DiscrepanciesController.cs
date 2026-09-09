using System.Globalization;
using System.Text;
using FluentValidation;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/discrepancies")]
public sealed class DiscrepanciesController(
    HrAutomationDbContext db,
    ISkillRegistry skillRegistry,
    IGuardrailPipeline guardrails,
    IValidator<ResolveDiscrepancyRequest> resolveValidator,
    IValidator<RequestReuploadRequest> reuploadValidator) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<DiscrepancyDto>>> ListDiscrepancies(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.Discrepancies
            .Where(d => d.TenantId == ctx.TenantId)
            .OrderByDescending(d => d.CreatedAtUtc)
            .ThenByDescending(d => d.DiscrepancyId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterCreatedAt, out var afterId))
        {
            query = query.Where(d =>
                d.CreatedAtUtc < afterCreatedAt ||
                (d.CreatedAtUtc == afterCreatedAt && d.DiscrepancyId.CompareTo(afterId) < 0));
        }

        var rows = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = rows.Count > limit;
        var pageRows = rows.Take(limit).ToList();

        var dtos = await ToDtosAsync(pageRows, ct);
        var nextCursor = hasMore ? EncodeCursor(pageRows[^1].CreatedAtUtc, pageRows[^1].DiscrepancyId) : null;

        return Ok(new CursorPage<DiscrepancyDto> { Items = dtos, NextCursor = nextCursor });
    }

    [HttpGet("{discrepancyId:guid}")]
    public async Task<IActionResult> GetDiscrepancy(Guid discrepancyId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var discrepancy = await db.Discrepancies.FirstOrDefaultAsync(d => d.DiscrepancyId == discrepancyId && d.TenantId == ctx.TenantId, ct);
        if (discrepancy is null)
        {
            return NotFound();
        }

        var dtos = await ToDtosAsync([discrepancy], ct);
        return Ok(dtos[0]);
    }

    [HttpPost("{discrepancyId:guid}/resolve")]
    public async Task<IActionResult> Resolve(Guid discrepancyId, [FromBody] ResolveDiscrepancyRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("discrepancy_resolve_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var validation = await resolveValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        if (!await db.Discrepancies.AnyAsync(d => d.DiscrepancyId == discrepancyId && d.TenantId == ctx.TenantId, ct))
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "resolve_discrepancy", request,
            applicationId: discrepancyId.ToString(), ct: ct);

        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    [HttpPost("{discrepancyId:guid}/reupload-request")]
    public async Task<IActionResult> RequestReupload(Guid discrepancyId, [FromBody] RequestReuploadRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("discrepancy_reupload_request_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var validation = await reuploadValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        if (!await db.Discrepancies.AnyAsync(d => d.DiscrepancyId == discrepancyId && d.TenantId == ctx.TenantId, ct))
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "request_document_reupload", request,
            applicationId: discrepancyId.ToString(), ct: ct);

        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    private async Task<List<DiscrepancyDto>> ToDtosAsync(List<OnboardingDiscrepancy> rows, CancellationToken ct)
    {
        if (rows.Count == 0) return [];

        var typeIds = rows.Select(r => r.DiscrepancyTypeId).Distinct().ToList();
        var severityIds = rows.Select(r => r.DiscrepancySeverityId).Distinct().ToList();
        var statusIds = rows.Select(r => r.DiscrepancyStatusId).Distinct().ToList();

        var types = await db.DiscrepancyTypes.Where(t => typeIds.Contains(t.DiscrepancyTypeId)).ToDictionaryAsync(t => t.DiscrepancyTypeId, ct);
        var severities = await db.DiscrepancySeverities.Where(s => severityIds.Contains(s.DiscrepancySeverityId)).ToDictionaryAsync(s => s.DiscrepancySeverityId, ct);
        var statuses = await db.DiscrepancyStatuses.Where(s => statusIds.Contains(s.DiscrepancyStatusId)).ToDictionaryAsync(s => s.DiscrepancyStatusId, ct);

        return rows.Select(r => new DiscrepancyDto
        {
            Id = r.DiscrepancyId,
            CandidateApplicationId = r.CandidateApplicationId,
            Type = types.TryGetValue(r.DiscrepancyTypeId, out var t) ? t.Code : string.Empty,
            Severity = severities.TryGetValue(r.DiscrepancySeverityId, out var s) ? s.Code : string.Empty,
            Status = statuses.TryGetValue(r.DiscrepancyStatusId, out var st) ? st.Code : string.Empty,
            Description = r.Description
        }).ToList();
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
