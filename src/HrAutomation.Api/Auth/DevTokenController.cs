using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace HrAutomation.Api.Auth;

public sealed class DevTokenRequest
{
    public Guid? TenantId { get; init; }
    public Guid? UserId { get; init; }

    /// <summary>An iam.Role.RoleName code from HrAutomationDb, e.g. "RECRUITER", "HR_ADMIN".</summary>
    public required string Role { get; init; }
    public string? DepartmentScope { get; init; }
}

public sealed class DevTokenResponse
{
    public required string AccessToken { get; init; }
    public required DateTime ExpiresAtUtc { get; init; }
    public required Guid TenantId { get; init; }
    public required Guid UserId { get; init; }
}

/// <summary>
/// DEV-ONLY token minting endpoint, gated to the Development environment. It exists purely so the
/// scaffold is runnable end-to-end without a real IdP wired up yet. Replace with real OIDC/OAuth
/// 2.1 authentication before any non-development deployment (spec section 4/9).
/// </summary>
[ApiController]
[Route("api/v1/dev")]
public sealed class DevTokenController(IOptions<JwtOptions> jwtOptions, IWebHostEnvironment env) : ControllerBase
{
    [HttpPost("token")]
    public IActionResult IssueToken([FromBody] DevTokenRequest request)
    {
        if (!env.IsDevelopment())
        {
            return NotFound();
        }

        var options = jwtOptions.Value;
        var tenantId = request.TenantId ?? Guid.NewGuid();
        var userId = request.UserId ?? Guid.NewGuid();

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new("tenant_id", tenantId.ToString()),
            new(ClaimTypes.Role, request.Role)
        };

        if (!string.IsNullOrWhiteSpace(request.DepartmentScope))
        {
            claims.Add(new Claim("department_scope", request.DepartmentScope));
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.SigningKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expires = DateTime.UtcNow.AddMinutes(options.ExpiryMinutes);

        var token = new JwtSecurityToken(
            issuer: options.Issuer,
            audience: options.Audience,
            claims: claims,
            expires: expires,
            signingCredentials: credentials);

        return Ok(new DevTokenResponse
        {
            AccessToken = new JwtSecurityTokenHandler().WriteToken(token),
            ExpiresAtUtc = expires,
            TenantId = tenantId,
            UserId = userId
        });
    }
}
