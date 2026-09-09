namespace HrAutomation.Rag;

public sealed class PolicyRetrievalQuery
{
    public required string QueryText { get; init; }
    public required Guid TenantId { get; init; }
    public string? RoleScope { get; init; }
    public string? DocumentType { get; init; }
}

public sealed class PolicyCitation
{
    public required string DocumentTitle { get; init; }
    public required string PolicyVersion { get; init; }
    public string? Section { get; init; }
}

public sealed class PolicyRetrievalResult
{
    public required bool Found { get; init; }
    public IReadOnlyList<PolicyCitation> Citations { get; init; } = [];
    public string? Summary { get; init; }
}

/// <summary>
/// The retrieval seam for the policy_rag_skill (spec section 7/8): metadata + authorization
/// filtering happen first, then hybrid retrieval, then re-ranking. If no authoritative source is
/// found it must say so and request HR/legal review - never fabricate policy guidance.
/// </summary>
public interface IPolicyRetrievalSkill
{
    Task<PolicyRetrievalResult> RetrieveAsync(PolicyRetrievalQuery query, CancellationToken ct = default);
}
