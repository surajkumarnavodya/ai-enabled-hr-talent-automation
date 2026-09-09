namespace HrAutomation.Mcp;

public sealed class GetCalendarAvailabilityRequest
{
    public required Guid InterviewerUserId { get; init; }
    public required DateOnly Date { get; init; }
}

public sealed class GetCalendarAvailabilityResult
{
    public required bool Configured { get; init; }
    public IReadOnlyList<(DateTime Start, DateTime End)> AvailableSlots { get; init; } = [];
}

/// <summary>TODO: wire a real calendar integration (Microsoft Graph / Google Calendar) via OAuth
/// 2.1 with tool-level scopes before production (spec section 9).</summary>
public sealed class GetCalendarAvailabilityTool : IReadOnlyMcpTool
{
    public string ToolName => "get_calendar_availability";

    public Task<GetCalendarAvailabilityResult> ExecuteAsync(GetCalendarAvailabilityRequest request, CancellationToken ct = default)
    {
        return Task.FromResult(new GetCalendarAvailabilityResult { Configured = false, AvailableSlots = [] });
    }
}
