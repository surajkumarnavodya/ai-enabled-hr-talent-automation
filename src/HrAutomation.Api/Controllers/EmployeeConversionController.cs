using System.Data;
using HrAutomation.Application.Contracts;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Persistence.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/employee-conversion")]
public sealed class EmployeeConversionController(HrAutomationDbContext db) : HrControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CursorPage<ConversionCandidateDto>>> List(CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var conversions = await db.EmployeeConversions
            .Where(ec => ec.TenantId == ctx.TenantId)
            .OrderByDescending(ec => ec.RequestedAtUtc)
            .Take(100)
            .ToListAsync(ct);

        var items = new List<ConversionCandidateDto>();
        foreach (var conversion in conversions)
        {
            items.Add(await ToDtoAsync(conversion, ct));
        }

        return Ok(new CursorPage<ConversionCandidateDto> { Items = items, NextCursor = null });
    }

    [HttpGet("{applicationId:guid}")]
    public async Task<IActionResult> GetByApplication(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var conversion = await db.EmployeeConversions
            .FirstOrDefaultAsync(ec => ec.CandidateApplicationId == applicationId && ec.TenantId == ctx.TenantId, ct);
        if (conversion is null)
        {
            return NotFound();
        }

        return Ok(await ToDtoAsync(conversion, ct));
    }

    private async Task<ConversionCandidateDto> ToDtoAsync(EmployeeConversion conversion, CancellationToken ct)
    {
        var application = await db.CandidateApplications.FirstOrDefaultAsync(a => a.CandidateApplicationId == conversion.CandidateApplicationId, ct);
        var candidateName = string.Empty;
        if (application is not null)
        {
            var candidate = await db.Candidates.FirstOrDefaultAsync(c => c.CandidateId == application.CandidateId, ct);
            if (candidate is not null)
            {
                candidateName = $"{candidate.FirstName} {candidate.LastName}";
            }
        }

        var (offerAccepted, greenFormCompleted, verificationCleared, discrepanciesResolved, isEligible) =
            await CheckEligibilityAsync(conversion.EmployeeConversionId, ct);

        return new ConversionCandidateDto
        {
            ApplicationId = conversion.CandidateApplicationId,
            CandidateName = candidateName,
            Eligible = isEligible,
            Checklist =
            [
                new ConversionChecklistItemDto { Check = "Offer accepted", Status = offerAccepted ? "pass" : "fail" },
                new ConversionChecklistItemDto { Check = "Green Form completed", Status = greenFormCompleted ? "pass" : "fail" },
                new ConversionChecklistItemDto { Check = "Verification cleared", Status = verificationCleared ? "pass" : "fail" },
                new ConversionChecklistItemDto { Check = "Discrepancies resolved", Status = discrepanciesResolved ? "pass" : "fail" }
            ]
        };
    }

    /// <summary>Reads employee.usp_CheckEmployeeConversionEligibility directly (not
    /// StoredProcedureExecutor - this procedure returns its own multi-column row shape, not the
    /// uniform Success/Message/EntityId result set). Read-only and safe to call from the API to
    /// render a checklist; the same procedure is re-run server-side inside
    /// usp_ApproveEmployeeConversion/usp_CreateEmployeeFromCandidate before either actually
    /// writes anything, so this read never becomes the authoritative gate.</summary>
    private async Task<(bool OfferAccepted, bool GreenFormCompleted, bool VerificationCleared, bool DiscrepanciesResolved, bool IsEligible)> CheckEligibilityAsync(
        Guid employeeConversionId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var connection = (SqlConnection)db.Database.GetDbConnection();
        var wasClosed = connection.State != ConnectionState.Open;
        if (wasClosed)
        {
            await connection.OpenAsync(ct);
        }

        try
        {
            await using var command = connection.CreateCommand();
            command.CommandType = CommandType.StoredProcedure;
            command.CommandText = "employee.usp_CheckEmployeeConversionEligibility";
            command.Parameters.Add(new SqlParameter("@TenantId", SqlDbType.UniqueIdentifier) { Value = ctx.TenantId });
            command.Parameters.Add(new SqlParameter("@EmployeeConversionId", SqlDbType.UniqueIdentifier) { Value = employeeConversionId });

            await using var reader = await command.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                return (false, false, false, false, false);
            }

            return (
                reader.GetBoolean(reader.GetOrdinal("OfferAccepted")),
                reader.GetBoolean(reader.GetOrdinal("GreenFormCompleted")),
                reader.GetBoolean(reader.GetOrdinal("VerificationCleared")),
                reader.GetBoolean(reader.GetOrdinal("DiscrepanciesResolved")),
                reader.GetBoolean(reader.GetOrdinal("IsEligible")));
        }
        finally
        {
            if (wasClosed)
            {
                await connection.CloseAsync();
            }
        }
    }
}
