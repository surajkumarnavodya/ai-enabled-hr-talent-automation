using System.Globalization;
using System.Text;
using HrAutomation.Application.Contracts;
using HrAutomation.Infrastructure.Persistence.Entities;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/audit-logs")]
public sealed class AuditLogsController(HrAutomationDbContext db) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<AuditLogDto>>> ListAuditLogs(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.AuditEvents
            .Where(a => a.TenantId == ctx.TenantId)
            .OrderByDescending(a => a.OccurredAtUtc)
            .ThenByDescending(a => a.AuditEventId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterOccurredAt, out var afterId))
        {
            query = query.Where(a =>
                a.OccurredAtUtc < afterOccurredAt ||
                (a.OccurredAtUtc == afterOccurredAt && a.AuditEventId < afterId));
        }

        var items = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = items.Count > limit;
        var page = items.Take(limit).Select(ToDto).ToList();
        var nextCursor = hasMore ? EncodeCursor(items[limit - 1].OccurredAtUtc, items[limit - 1].AuditEventId) : null;

        return Ok(new CursorPage<AuditLogDto> { Items = page, NextCursor = nextCursor });
    }

    // audit.AuditEvent stores one EntityType/EntityId pair (see AuditLogger.ResolvePrimaryEntity);
    // this reverses that mapping back into the DTO's per-entity-kind fields.
    private static AuditLogDto ToDto(AuditEvent a) => new()
    {
        Id = a.EventId,
        EventType = a.Action,
        ActorType = a.ActorType,
        ActorId = a.ActorUserId?.ToString() ?? string.Empty,
        WorkflowId = a.EntityType == "workflow.ApprovalRequest" ? a.EntityId?.ToString() : null,
        TanId = a.EntityType == "recruitment.TalentAcquisitionNumber" ? a.EntityId?.ToString() : null,
        CandidateId = a.EntityType == "recruitment.Candidate" ? a.EntityId?.ToString() : null,
        ApplicationId = a.EntityType == "recruitment.CandidateApplication" ? a.EntityId?.ToString() : null,
        CorrelationId = a.CorrelationId?.ToString() ?? string.Empty,
        PriorStatus = a.PreviousStatus,
        NewStatus = a.NewStatus,
        CreatedAtUtc = a.OccurredAtUtc
    };

    private static string EncodeCursor(DateTime occurredAtUtc, long id) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{occurredAtUtc:O}|{id}"));

    private static bool TryDecodeCursor(string cursor, out DateTime occurredAtUtc, out long id)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|');
            occurredAtUtc = DateTime.Parse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
            id = long.Parse(parts[1], CultureInfo.InvariantCulture);
            return true;
        }
        catch (FormatException)
        {
            occurredAtUtc = default;
            id = default;
            return false;
        }
    }
}
