namespace HrAutomation.Mcp;

public sealed class CreateInterviewToolRequest
{
    public required Guid CandidateTanApplicationId { get; init; }
    public required DateTime StartUtc { get; init; }
    public required DateTime EndUtc { get; init; }
}

public sealed class CreateInterviewToolResult
{
    public required bool Configured { get; init; }
    public string? Message { get; init; }
}

/// <summary>
/// Approval-required write tool per spec section 9 - demonstrates the seam (per-tool
/// authorization check independent of the LLM, then an audit-logged call) without a real external
/// calendar/HRMS connection wired in yet. TODO: replace with a real MCP calendar server call.
/// </summary>
public sealed class CreateInterviewTool : IApprovalRequiredMcpTool
{
    public string ToolName => "create_interview";

    public Task<CreateInterviewToolResult> ExecuteAsync(CreateInterviewToolRequest request, CancellationToken ct = default)
    {
        return Task.FromResult(new CreateInterviewToolResult
        {
            Configured = false,
            Message = "Calendar/HRMS MCP integration not configured in this scaffold."
        });
    }
}
