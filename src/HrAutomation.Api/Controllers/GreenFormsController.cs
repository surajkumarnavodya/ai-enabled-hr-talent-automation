using System.Data;
using System.Text.Json;
using FluentValidation;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;

namespace HrAutomation.Api.Controllers;

[Route("api/v1/green-forms")]
public sealed class GreenFormsController(
    HrAutomationDbContext db,
    ISkillRegistry skillRegistry,
    IGuardrailPipeline guardrails,
    IValidator<SubmitGreenFormRequest> submitValidator) : HrControllerBase
{
    [HttpPost("{applicationId:guid}/issue-link")]
    public async Task<IActionResult> IssueLink(Guid applicationId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("green_form_issue_link_skill");
        if (!IsAuthorizedForSkill(skill, ctx)) return ForbiddenForSkill(skill, ctx);

        var response = await InvokeStandaloneAsync(guardrails, skill, ctx, "issue_green_form_link", null,
            applicationId: applicationId.ToString(), ct: ct);
        return response.ActionStatus == ActionStatus.completed ? Ok(response) : UnprocessableEntity(response);
    }

    // --- Candidate-facing, token-authorized below: no internal session exists for an external
    // candidate, so these three endpoints are deliberately anonymous. Authorization is
    // possession of the unguessable token (GreenFormSubmissionId) sent to the candidate
    // out-of-band - see onboarding.usp_SubmitGreenForm's header comment in
    // 07-create-stored-procedures.sql for how this stays consistent with "never trust
    // client-supplied tenant context alone" despite having no authenticated tenant. ---

    [HttpGet("by-token/{token:guid}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetByToken(Guid token, CancellationToken ct)
    {
        var details = await GetSubmissionStatusAsync(token, ct);
        return details is null ? NotFound() : Ok(details);
    }

    [HttpGet("submission/{submissionId:guid}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetSubmission(Guid submissionId, CancellationToken ct)
    {
        var details = await GetSubmissionStatusAsync(submissionId, ct);
        return details is null ? NotFound() : Ok(details);
    }

    [HttpPost("by-token/{token:guid}/submissions")]
    [AllowAnonymous]
    public async Task<IActionResult> Submit(Guid token, [FromBody] SubmitGreenFormRequest request, CancellationToken ct)
    {
        var validation = await submitValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        var employmentJson = JsonSerializer.Serialize(request.EmploymentHistory.Select(e => new
        {
            employerName = e.EmployerName,
            startDate = e.StartDate,
            endDate = e.EndDate
        }));
        var educationJson = JsonSerializer.Serialize(request.Education.Select(e => new
        {
            institution = e.Institution,
            qualification = e.Qualification,
            year = e.Year
        }));

        var result = await StoredProcedureExecutor.ExecuteAsync(
            db.Database, "onboarding.usp_SubmitGreenForm",
            [
                StoredProcedureExecutor.Param("@GreenFormSubmissionId", token, SqlDbType.UniqueIdentifier),
                StoredProcedureExecutor.Param("@EmploymentHistoryJson", employmentJson, SqlDbType.NVarChar),
                StoredProcedureExecutor.Param("@EducationJson", educationJson, SqlDbType.NVarChar)
            ], ct);

        if (!result.Success)
        {
            return result.ErrorCode == "NOT_FOUND"
                ? NotFound()
                : UnprocessableEntity(Problem(statusCode: StatusCodes.Status422UnprocessableEntity, detail: result.Message));
        }

        return Ok(new { status = "recorded" });
    }

    /// <summary>Reads onboarding.usp_GetGreenFormSubmissionStatus directly (not
    /// StoredProcedureExecutor - that helper assumes every procedure returns the uniform
    /// Success/Message/EntityId result set; this one returns its own row shape since it's a
    /// query, not a state-changing action).</summary>
    private async Task<GreenFormDetailsDto?> GetSubmissionStatusAsync(Guid submissionId, CancellationToken ct)
    {
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
            command.CommandText = "onboarding.usp_GetGreenFormSubmissionStatus";
            command.Parameters.Add(new SqlParameter("@GreenFormSubmissionId", SqlDbType.UniqueIdentifier) { Value = submissionId });

            await using var reader = await command.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                return null;
            }

            var status = reader.GetString(reader.GetOrdinal("Status"));
            var createdAtUtc = reader.GetDateTime(reader.GetOrdinal("CreatedAtUtc"));

            return new GreenFormDetailsDto
            {
                Id = submissionId,
                Status = status,
                // No configurable link-validity window exists yet - 14 days from issuance is a
                // fixed, documented default, not a persisted/configurable value.
                ExpiresAt = createdAtUtc.AddDays(14),
                RequiredDocuments = [] // No GreenFormFieldDefinition rows are seeded yet - honestly empty, not fabricated.
            };
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
