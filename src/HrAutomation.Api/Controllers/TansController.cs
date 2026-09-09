using System.Globalization;
using System.Text;
using FluentValidation;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Orchestration;
using HrAutomation.Application.Skills;
using HrAutomation.Domain.Enums;
using HrAutomation.Infrastructure.Persistence.Entities;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Controllers;

// "tanId" throughout this controller is recruitment.JobRequisitionId, not
// TalentAcquisitionNumberId - see CreateTanSkill's class comment for why.
[Route("api/v1/tans")]
public sealed class TansController(
    HrAutomationDbContext db,
    ISkillRegistry skillRegistry,
    IGuardrailPipeline guardrails,
    IWorkflowOrchestrator orchestrator,
    IValidator<CreateTanRequest> createValidator,
    IValidator<ApproveTanRequest> approveValidator) : HrControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CreateTan([FromBody] CreateTanRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("create_tan_skill");

        if (!IsAuthorizedForSkill(skill, ctx))
        {
            return ForbiddenForSkill(skill, ctx);
        }

        var validation = await createValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        var guardrailResults = guardrails.Evaluate(new GuardrailCheckInput
        {
            RequestContext = ctx,
            RequiredRoles = skill.RequiredRoles,
            UntrustedTextToScan = request.RawDescription
        });

        if (!guardrailResults.AllPass)
        {
            var blocked = new SkillResult
            {
                Status = ActionStatus.blocked,
                Summary = "Blocked by guardrail check.",
                RisksOrExceptions = ["One or more guardrail checks failed - see guardrail_results."]
            };
            return Ok(AgentActionResponseFactory.Build(ctx, "create_tan", "n/a", "N/A", null, blocked, guardrailResults, actorId: skill.SkillName));
        }

        var skillResult = await skill.ExecuteAsync(new SkillContext
        {
            RequestContext = ctx,
            WorkflowInstanceId = Guid.Empty,
            Input = request
        }, ct);

        var response = AgentActionResponseFactory.Build(
            ctx, "create_tan", skillResult.TanId ?? "n/a",
            skillResult.ProposedNextState ?? "Draft",
            null, skillResult, guardrailResults, actorId: skill.SkillName);

        return skillResult.Status == ActionStatus.completed
            ? CreatedAtAction(nameof(GetTan), new { tanId = skillResult.TanId }, response)
            : UnprocessableEntity(response);
    }

    [HttpGet]
    public async Task<ActionResult<CursorPage<TanDto>>> ListTans(
        [FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var ctx = BuildRequestContext();
        limit = Math.Clamp(limit, 1, 100);

        var query = db.JobRequisitions
            .Where(r => r.TenantId == ctx.TenantId)
            .OrderByDescending(r => r.CreatedAtUtc)
            .ThenByDescending(r => r.JobRequisitionId)
            .AsQueryable();

        if (!string.IsNullOrEmpty(cursor) && TryDecodeCursor(cursor, out var afterCreatedAt, out var afterId))
        {
            query = query.Where(r =>
                r.CreatedAtUtc < afterCreatedAt ||
                (r.CreatedAtUtc == afterCreatedAt && r.JobRequisitionId.CompareTo(afterId) < 0));
        }

        var items = await query.Take(limit + 1).ToListAsync(ct);
        var hasMore = items.Count > limit;
        var pageItems = items.Take(limit).ToList();

        var tanNumberIds = pageItems.Select(r => r.TalentAcquisitionNumberId).Distinct().ToList();
        var tanNumbers = await db.TalentAcquisitionNumbers
            .Where(t => tanNumberIds.Contains(t.TalentAcquisitionNumberId))
            .ToDictionaryAsync(t => t.TalentAcquisitionNumberId, t => t.TanNumber, ct);

        var page = pageItems.Select(r => ToDto(r, tanNumbers.GetValueOrDefault(r.TalentAcquisitionNumberId))).ToList();
        var nextCursor = hasMore ? EncodeCursor(pageItems[^1].CreatedAtUtc, pageItems[^1].JobRequisitionId) : null;

        return Ok(new CursorPage<TanDto> { Items = page, NextCursor = nextCursor });
    }

    [HttpGet("{tanId:guid}")]
    public async Task<IActionResult> GetTan(Guid tanId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var requisition = await db.JobRequisitions.FirstOrDefaultAsync(r => r.JobRequisitionId == tanId && r.TenantId == ctx.TenantId, ct);
        if (requisition is null)
        {
            return NotFound();
        }

        var tanNumber = await db.TalentAcquisitionNumbers
            .Where(t => t.TalentAcquisitionNumberId == requisition.TalentAcquisitionNumberId)
            .Select(t => t.TanNumber)
            .FirstOrDefaultAsync(ct);

        return Ok(ToDto(requisition, tanNumber));
    }

    [HttpPost("{tanId:guid}/approve")]
    public async Task<IActionResult> ApproveTan(Guid tanId, [FromBody] ApproveTanRequest request, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("tan_approval_skill");

        if (!IsAuthorizedForSkill(skill, ctx))
        {
            return ForbiddenForSkill(skill, ctx);
        }

        var validation = await approveValidator.ValidateAsync(request, ct);
        if (!validation.IsValid)
        {
            return ValidationProblemFrom(validation);
        }

        var requisition = await db.JobRequisitions.FirstOrDefaultAsync(t => t.JobRequisitionId == tanId && t.TenantId == ctx.TenantId, ct);
        if (requisition is null)
        {
            return NotFound();
        }

        if (request.Decision == ApprovalDecision.ReturnedForInfo)
        {
            // No state transition applies - handled directly (see TanApprovalSkill remarks).
            var directResult = await skill.ExecuteAsync(new SkillContext
            {
                RequestContext = ctx,
                WorkflowInstanceId = requisition.JobRequisitionId,
                TanId = requisition.JobRequisitionId.ToString(),
                Input = request
            }, ct);

            var directGuardrails = guardrails.Evaluate(new GuardrailCheckInput { RequestContext = ctx, RequiredRoles = skill.RequiredRoles });
            return Ok(AgentActionResponseFactory.Build(
                ctx, "approve_tan", requisition.JobRequisitionId.ToString(), requisition.RequisitionStatusCode, null,
                directResult, directGuardrails, actorId: skill.SkillName));
        }

        // No RequiresPriorApproval gate here - this action IS the approval decision itself
        // (TanApprovalSkill records it against the Pending workflow.ApprovalRequest that
        // CreateTanSkill's usp_SubmitJobRequisitionForApproval call already created).
        var response = await orchestrator.ExecuteAsync(new OrchestratorRequest
        {
            RequestContext = ctx,
            Action = "approve_tan",
            EntityType = "recruitment.JobRequisition",
            EntityId = requisition.JobRequisitionId,
            Skill = skill,
            SkillInput = request,
            TanId = requisition.JobRequisitionId.ToString()
        }, ct);

        return Ok(response);
    }

    [HttpPost("{tanId:guid}/match-candidates")]
    public async Task<IActionResult> MatchCandidates(Guid tanId, CancellationToken ct)
    {
        var ctx = BuildRequestContext();
        var skill = skillRegistry.Get("match_candidates_skill");

        if (!IsAuthorizedForSkill(skill, ctx))
        {
            return ForbiddenForSkill(skill, ctx);
        }

        var requisition = await db.JobRequisitions.FirstOrDefaultAsync(t => t.JobRequisitionId == tanId && t.TenantId == ctx.TenantId, ct);
        if (requisition is null)
        {
            return NotFound();
        }

        // Matching may only start once the requisition itself has been through the TAN
        // approval gate above.
        var response = await orchestrator.ExecuteAsync(new OrchestratorRequest
        {
            RequestContext = ctx,
            Action = "match_candidates",
            EntityType = "recruitment.JobRequisition",
            EntityId = requisition.JobRequisitionId,
            RequiresPriorApproval = true,
            Skill = skill,
            TanId = requisition.JobRequisitionId.ToString()
        }, ct);

        return Ok(response);
    }

    // NOTE (documented gap): TanDto.Location/Grade have no backing columns on
    // recruitment.JobRequisition today - see CreateTanSkill's class comment.
    private static TanDto ToDto(RecruitmentJobRequisition r, string? tanNumber) => new()
    {
        TanId = r.JobRequisitionId,
        TanNumber = tanNumber ?? string.Empty,
        Title = r.Title,
        Location = string.Empty,
        Grade = string.Empty,
        Status = r.RequisitionStatusCode,
        RowVersion = Convert.ToBase64String(r.RowVersion)
    };

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
