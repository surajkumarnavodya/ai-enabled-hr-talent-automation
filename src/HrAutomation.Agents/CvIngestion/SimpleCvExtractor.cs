using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace HrAutomation.Agents.CvIngestion;

/// <summary>
/// Deterministic, dependency-free extractor for the scaffold. Only the "text/plain" path is
/// actually parsed; PDF/DOCX/OCR extraction is a pluggable ICvFieldExtractor implementation to be
/// swapped in before production (spec section 3.B) - binary formats are stored and flagged for
/// human review rather than guessed at.
/// </summary>
public sealed partial class SimpleCvExtractor : ICvFieldExtractor
{
    private static readonly string[] KnownSkills =
    [
        "C#", ".NET", "Java", "Python", "SQL", "Azure", "AWS", "React", "Angular",
        "JavaScript", "TypeScript", "Kubernetes", "Docker", "DevOps", "Machine Learning", "Project Management"
    ];

    [GeneratedRegex(@"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")]
    private static partial Regex EmailPattern();

    [GeneratedRegex(@"(\+?\d[\d\-\s]{7,}\d)")]
    private static partial Regex PhonePattern();

    public CvExtractionResult Extract(byte[] content, string contentType, string fileName)
    {
        if (!string.Equals(contentType, "text/plain", StringComparison.OrdinalIgnoreCase))
        {
            return new CvExtractionResult
            {
                FullName = Path.GetFileNameWithoutExtension(fileName),
                Skills = [],
                ConfidenceScore = 0.2m,
                RequiresHumanReview = true,
                ExtractedFieldsJson = "{}"
            };
        }

        var text = Encoding.UTF8.GetString(content);
        var email = EmailPattern().Match(text) is { Success: true } emailMatch ? emailMatch.Value : null;
        var phone = PhonePattern().Match(text) is { Success: true } phoneMatch ? phoneMatch.Value : null;
        var firstLine = text.Split('\n', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault()?.Trim();
        var fullName = string.IsNullOrWhiteSpace(firstLine) ? Path.GetFileNameWithoutExtension(fileName) : firstLine;
        var skills = KnownSkills.Where(s => text.Contains(s, StringComparison.OrdinalIgnoreCase)).ToList();

        var confidence = (email is not null ? 0.4m : 0m) + (phone is not null ? 0.3m : 0m) + (skills.Count > 0 ? 0.3m : 0m);

        return new CvExtractionResult
        {
            FullName = fullName,
            Email = email,
            Phone = phone,
            Skills = skills,
            ConfidenceScore = Math.Min(confidence, 1.0m),
            RequiresHumanReview = confidence < 0.6m,
            ExtractedFieldsJson = JsonSerializer.Serialize(new { fullName, email, phone, skills })
        };
    }
}
