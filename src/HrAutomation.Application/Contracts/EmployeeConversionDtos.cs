namespace HrAutomation.Application.Contracts;

public sealed class ConversionChecklistItemDto
{
    public string Check { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty; // pass, fail
}

public sealed class ConversionCandidateDto
{
    public Guid ApplicationId { get; init; }
    public string CandidateName { get; init; } = string.Empty;
    public bool Eligible { get; init; }
    public List<ConversionChecklistItemDto> Checklist { get; init; } = [];
}

public sealed class EmployeeCreatedDto
{
    public Guid EmployeeId { get; init; }
    public string EmployeeNumber { get; init; } = string.Empty;
}

public sealed class ApproveShortlistRequest
{
    public string Decision { get; init; } = "approved";
}
