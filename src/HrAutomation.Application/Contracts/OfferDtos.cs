namespace HrAutomation.Application.Contracts;

public sealed class OfferDto
{
    public Guid OfferId { get; init; }
    public Guid CandidateApplicationId { get; init; }
    public string OfferNumber { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public string RowVersion { get; init; } = string.Empty;
}

public sealed class CreateOfferRequest
{
    public required Guid CandidateApplicationId { get; init; }
    public Guid? OfferTemplateId { get; init; }
}
