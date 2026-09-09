namespace HrAutomation.Api.Auth;

/// <summary>Dev-only symmetric-key JWT config. Replace with real OIDC/IdP issuer validation before
/// production (spec section 4/9).</summary>
public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public required string SigningKey { get; init; }
    public int ExpiryMinutes { get; init; } = 60;
}
