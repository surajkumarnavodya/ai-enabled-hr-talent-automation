namespace HrAutomation.Application.Contracts;

public sealed class GreenFormDetailsDto
{
    public Guid Id { get; init; }
    public string Status { get; init; } = string.Empty;
    public DateTime ExpiresAt { get; init; }
    public List<RequiredDocumentDto> RequiredDocuments { get; init; } = [];
}

public sealed class RequiredDocumentDto
{
    public string DocumentType { get; init; } = string.Empty;
    public bool Uploaded { get; init; }
}

public sealed class EmploymentHistoryEntry
{
    public string EmployerName { get; init; } = string.Empty;
    public DateOnly StartDate { get; init; }
    public DateOnly? EndDate { get; init; }
}

public sealed class EducationHistoryEntry
{
    public string Institution { get; init; } = string.Empty;
    public string Qualification { get; init; } = string.Empty;
    public int Year { get; init; }
}

public sealed class SubmitGreenFormRequest
{
    public List<EmploymentHistoryEntry> EmploymentHistory { get; init; } = [];
    public List<EducationHistoryEntry> Education { get; init; } = [];
}
