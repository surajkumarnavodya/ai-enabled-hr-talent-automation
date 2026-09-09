namespace HrAutomation.Agents.CvIngestion;

public sealed class CvExtractionResult
{
    public required string FullName { get; init; }
    public string? Email { get; init; }
    public string? Phone { get; init; }
    public required IReadOnlyList<string> Skills { get; init; }
    public required decimal ConfidenceScore { get; init; }
    public required bool RequiresHumanReview { get; init; }
    public required string ExtractedFieldsJson { get; init; }
}

public interface ICvFieldExtractor
{
    CvExtractionResult Extract(byte[] content, string contentType, string fileName);
}
