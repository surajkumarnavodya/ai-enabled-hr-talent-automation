using HrAutomation.Application.Audit;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Infrastructure.Audit;

public sealed class AuditLogger(HrAutomationDbContext db) : IAuditLogger
{
    public async Task LogAsync(AuditLogEntry entry, CancellationToken ct = default)
    {
        var (entityType, entityId) = ResolvePrimaryEntity(entry);
        var actorUserId = Guid.TryParse(entry.ActorId, out var parsedActorId) ? parsedActorId : (Guid?)null;
        var correlationId = Guid.TryParse(entry.CorrelationId, out var parsedCorrelationId) ? parsedCorrelationId : (Guid?)null;

        await db.Database.ExecuteSqlInterpolatedAsync(
            $"""
             EXEC audit.usp_WriteAuditEvent
                 @TenantId = {entry.TenantId},
                 @ActorUserId = {actorUserId},
                 @ActorType = {ToAuditActorType(entry.ActorType)},
                 @Action = {entry.EventType},
                 @EntityType = {entityType},
                 @EntityId = {entityId},
                 @PreviousStatus = {entry.PriorStatus},
                 @NewStatus = {entry.NewStatus},
                 @MetadataJson = {entry.DetailsJson},
                 @CorrelationId = {correlationId}
             """, ct);
    }

    // Old callers pass at most one of these; new schema's audit.AuditEvent has a single
    // EntityType/EntityId pair, so pick the most specific one supplied.
    private static (string? EntityType, Guid? EntityId) ResolvePrimaryEntity(AuditLogEntry entry)
    {
        if (entry.EntityType is not null) return (entry.EntityType, Guid.TryParse(entry.EntityId, out var id) ? id : null);
        if (Guid.TryParse(entry.TanId, out var tanId)) return ("recruitment.TalentAcquisitionNumber", tanId);
        if (Guid.TryParse(entry.ApplicationId, out var applicationId)) return ("recruitment.CandidateApplication", applicationId);
        if (Guid.TryParse(entry.CandidateId, out var candidateId)) return ("recruitment.Candidate", candidateId);
        if (Guid.TryParse(entry.WorkflowId, out var workflowId)) return ("workflow.ApprovalRequest", workflowId);
        return (null, null);
    }

    // Maps to the audit.AuditEvent.ActorType CHECK constraint ('User','System','AiAgent','ApiClient').
    private static string ToAuditActorType(ActorType actorType) => actorType switch
    {
        ActorType.human => "User",
        ActorType.agent => "AiAgent",
        ActorType.system => "System",
        _ => "System"
    };
}
