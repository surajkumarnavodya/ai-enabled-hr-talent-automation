namespace HrAutomation.Infrastructure.Persistence.Entities;

public class OfferOffer
{
    public Guid OfferId { get; set; }
    public Guid TenantId { get; set; }
    public Guid CandidateApplicationId { get; set; }
    public Guid? OfferTemplateId { get; set; }
    public string OfferNumber { get; set; } = null!;
    public Guid OfferStatusId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public byte[] RowVersion { get; set; } = null!;
    public bool IsDeleted { get; set; }
}
