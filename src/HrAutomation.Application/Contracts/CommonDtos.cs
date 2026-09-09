namespace HrAutomation.Application.Contracts;

/// <summary>Cursor pagination envelope used by all list endpoints (spec section 6).</summary>
public sealed class CursorPage<T>
{
    public required IReadOnlyList<T> Items { get; init; }
    public string? NextCursor { get; init; }
}
