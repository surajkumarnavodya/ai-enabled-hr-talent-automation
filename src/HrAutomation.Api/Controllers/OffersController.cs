using System.Globalization;
using System.Text;
using FluentValidation;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/offers")]
public sealed class OffersController(
    HrAutomationDbContext db,
    ISkillRegistry skillRegistry,
    IGuardrailPipeline guardrails,
    IValidator<CreateOfferRequest> createValidator) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<OfferDto>>> ListOffers(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.Offers
            .Where(o => o.TenantId == ctx.TenantId)
            .OrderByDescending(o => o.CreatedAtUtc)
            .ThenByDescending(o => o.OfferId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterCreatedAt, out var afterId))
        {
            query = query.Where(o =>
                o.CreatedAtUtc < afterCreatedAt ||
                (o.CreatedAtUtc == afterCreatedAt && o.OfferId.CompareTo(afterId) < 0));
        }

        var offers = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = offers.Count > limit;
        var pageOffers = offers.Take(limit).ToList();

        var dtos = await ToDtosAsync(pageOffers, ct);
        var nextCursor = hasMore ? EncodeCursor(pageOffers[^1].CreatedAtUtc, pageOffers[^1].OfferId) : null;

        return Ok(new CursorPage<OfferDto> { Items = dtos, NextCursor = nextCursor });
    }

    [HttpGet("{offerId:guid}")]
    public async Task<IActionResult> GetOffer(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var offer = await db.Offers.FirstOrDefaultAsync(o => o.OfferId == offerId && o.TenantId == ctx.TenantId, ct);
        if (offer is null)
        {
            return NotFound();
        }

        var dtos = await ToDtosAsync([offer], ct);
        return Ok(dtos[0]);
    }

    [HttpPost]
    public async Task<IActionResult> CreateOffer([FromBody] CreateOfferRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("create_offer_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var validation = await createValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "create_offer", request,
            applicationId: request.CandidateApplicationId.ToString(), ct: ct);

        if (response.ActionStatus != ActionStatus.completed || response.OfferId is not { } offerIdText)
        {
            return UnprocessableEntity(response);
        }

        return CreatedAtAction(nameof(GetOffer), new { offerId = Guid.Parse(offerIdText) }, response);
    }

    [HttpPost("{offerId:guid}/approve")]
    public async Task<IActionResult> ApproveOffer(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("offer_approval_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        if (!await db.Offers.AnyAsync(o => o.OfferId == offerId && o.TenantId == ctx.TenantId, ct))
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "approve_offer", null, tanId: offerId.ToString(), ct: ct);
        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    [HttpPost("{offerId:guid}/send")]
    public async Task<IActionResult> SendOffer(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("offer_send_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        if (!await db.Offers.AnyAsync(o => o.OfferId == offerId && o.TenantId == ctx.TenantId, ct))
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "send_offer", null, tanId: offerId.ToString(), ct: ct);
        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    [HttpPost("{offerId:guid}/acceptance")]
    public async Task<IActionResult> RecordAcceptance(Guid offerId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("offer_acceptance_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        if (!await db.Offers.AnyAsync(o => o.OfferId == offerId && o.TenantId == ctx.TenantId, ct))
        {
            return NotFound();
        }

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "record_offer_acceptance", null, tanId: offerId.ToString(), ct: ct);
        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    private async Task<List<OfferDto>> ToDtosAsync(List<Infrastructure.Persistence.Entities.OfferOffer> offers, CancellationToken ct)
    {
        if (offers.Count == 0) return [];

        var statusIds = offers.Select(o => o.OfferStatusId).Distinct().ToList();
        var statuses = await db.OfferStatuses
            .Where(s => statusIds.Contains(s.OfferStatusId))
            .ToDictionaryAsync(s => s.OfferStatusId, ct);

        return offers.Select(o => new OfferDto
        {
            OfferId = o.OfferId,
            CandidateApplicationId = o.CandidateApplicationId,
            OfferNumber = o.OfferNumber,
            Status = statuses.TryGetValue(o.OfferStatusId, out var status) ? status.Code : string.Empty,
            RowVersion = Convert.ToBase64String(o.RowVersion)
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
