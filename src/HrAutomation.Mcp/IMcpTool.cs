namespace HrAutomation.Mcp;

/// <summary>Base marker for every MCP tool - authorization is checked per-tool, independent of the
/// LLM, and every call is recorded via McpToolCallRecord (spec section 9).</summary>
public interface IMcpTool
{
    string ToolName { get; }
}

/// <summary>e.g. search_authorized_policy, get_candidate_summary, get_tan_summary, get_calendar_availability.</summary>
public interface IReadOnlyMcpTool : IMcpTool;

/// <summary>e.g. propose_candidate_shortlist, propose_interview_slots, draft_offer - never mutates state.</summary>
public interface IProposeOnlyMcpTool : IMcpTool;

/// <summary>e.g. create_tan, create_interview, send_offer, create_employee_id - requires human
/// confirmation before the call is allowed to execute (spec section 4/9).</summary>
public interface IApprovalRequiredMcpTool : IMcpTool;

public sealed class McpToolCallRecord
{
    public required string ToolName { get; init; }
    public required Guid AuthorizedUserId { get; init; }
    public required Guid TenantId { get; init; }
    public required string InputClassification { get; init; }
    public required string ResultStatus { get; init; }
    public required DateTime TimestampUtc { get; init; }
    public required string CorrelationId { get; init; }
}
