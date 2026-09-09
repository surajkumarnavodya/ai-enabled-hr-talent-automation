using HrAutomation.Domain.Enums;

namespace HrAutomation.Application.Contracts;

public sealed class CreateTanRequest
{
    public string Title { get; init; } = string.Empty;
    public string Location { get; init; } = string.Empty;
    public string Grade { get; init; } = string.Empty;
    public decimal BudgetMin { get; init; }
    public decimal BudgetMax { get; init; }
    public int InterviewStagesCount { get; init; } = 2;
    public bool ClientInterviewRequired { get; init; }
    public string MandatoryCriteriaJson { get; init; } = "[]";
    public string PreferredCriteriaJson { get; init; } = "[]";
    public string RawDescription { get; init; } = string.Empty;
}

public sealed class TanDto
{
    public Guid TanId { get; init; }
    public string TanNumber { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public string Location { get; init; } = string.Empty;
    public string Grade { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public string RowVersion { get; init; } = string.Empty;
}

public sealed class ApproveTanRequest
{
    public required ApprovalDecision Decision { get; init; }
    public string? Comments { get; init; }
    public required int SourceVersion { get; init; }
}
