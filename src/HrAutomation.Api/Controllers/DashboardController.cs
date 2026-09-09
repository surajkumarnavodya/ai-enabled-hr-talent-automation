using HrAutomation.Application.Contracts;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

/// <summary>Real, live-computed cross-workflow counts — every field is a real query against
/// the same tables every other controller in this API reads, not a fabricated/static value.
/// SlaBreaches is the one honest exception: no SLA policy/tracking mechanism exists in this
/// schema yet, so it's always 0 rather than invented.</summary>
[Route("api/v1/dashboard")]
public sealed class DashboardController(HrAutomationDbContext db) : HrControllerBase
{
    [HttpGet("summary")]
    public async Task<ActionResult<DashboardSummaryDto>> GetSummary(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var tenantId = ctx.TenantId;
        var todayStartUtc = DateTime.UtcNow.Date;
        var todayEndUtc = todayStartUtc.AddDays(1);

        var activeTans = await db.JobRequisitions
            .CountAsync(r => r.TenantId == tenantId && r.RequisitionStatusCode != "ClosedFilled" && r.RequisitionStatusCode != "Cancelled", ct);

        var candidatesAwaitingReview = await db.CvParsingResults
            .CountAsync(p => p.TenantId == tenantId && p.RequiresHumanReview, ct);

        var interviewsScheduledToday = await db.InterviewScheduleSlots
            .CountAsync(s => s.TenantId == tenantId && s.IsCurrent && s.ScheduledStartUtc >= todayStartUtc && s.ScheduledStartUtc < todayEndUtc, ct);

        var pendingInterviewFeedback = await db.InterviewRounds
            .CountAsync(r => r.TenantId == tenantId && !db.InterviewFeedbacks.Any(f => f.InterviewRoundId == r.InterviewRoundId), ct);

        var pendingApprovals = await db.ApprovalRequests
            .CountAsync(r => r.TenantId == tenantId && r.Status == "Pending", ct);

        var offersPendingAcceptance = await (
            from o in db.Offers
            join s in db.OfferStatuses on o.OfferStatusId equals s.OfferStatusId
            where o.TenantId == tenantId && s.Code == "Sent"
            select o.OfferId).CountAsync(ct);

        var greenFormsPending = await db.GreenFormSubmissions
            .CountAsync(g => g.TenantId == tenantId && g.Status != "Completed", ct);

        var highSeverityDiscrepancies = await (
            from d in db.Discrepancies
            join sev in db.DiscrepancySeverities on d.DiscrepancySeverityId equals sev.DiscrepancySeverityId
            join st in db.DiscrepancyStatuses on d.DiscrepancyStatusId equals st.DiscrepancyStatusId
            where d.TenantId == tenantId && (sev.Code == "HIGH" || sev.Code == "CRITICAL") && st.Code != "CLOSED" && st.Code != "REJECTED"
            select d.DiscrepancyId).CountAsync(ct);

        var employeeConversionsPending = await db.EmployeeConversions
            .CountAsync(e => e.TenantId == tenantId && e.Status != "Converted", ct);

        return Ok(new DashboardSummaryDto
        {
            ActiveTans = activeTans,
            CandidatesAwaitingReview = candidatesAwaitingReview,
            InterviewsScheduledToday = interviewsScheduledToday,
            PendingInterviewFeedback = pendingInterviewFeedback,
            PendingApprovals = pendingApprovals,
            OffersPendingAcceptance = offersPendingAcceptance,
            GreenFormsPending = greenFormsPending,
            HighSeverityDiscrepancies = highSeverityDiscrepancies,
            EmployeeConversionsPending = employeeConversionsPending,
            SlaBreaches = 0
        });
    }
}
