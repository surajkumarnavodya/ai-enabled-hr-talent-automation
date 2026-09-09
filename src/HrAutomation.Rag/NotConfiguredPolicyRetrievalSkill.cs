namespace HrAutomation.Rag;

/// <summary>
/// TODO: replace with a real vector-store-backed implementation (e.g. pgvector on the same SQL
/// Server-adjacent Postgres instance, or Azure AI Search) before production - see spec section 7
/// for the required metadata filtering, hybrid retrieval, and re-ranking pipeline.
/// </summary>
public sealed class NotConfiguredPolicyRetrievalSkill : IPolicyRetrievalSkill
{
    public Task<PolicyRetrievalResult> RetrieveAsync(PolicyRetrievalQuery query, CancellationToken ct = default)
    {
        return Task.FromResult(new PolicyRetrievalResult
        {
            Found = false,
            Summary = "No RAG corpus or vector store is configured yet - escalate to HR/legal for authoritative policy guidance."
        });
    }
}
