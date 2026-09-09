using System.Security.Claims;
using System.Security.Cryptography;
using HrAutomation.Infrastructure.Persistence.Entities;
using HrAutomation.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace HrAutomation.Api.Middleware;

/// <summary>
/// Backs the Idempotency-Key header contract on POST/PATCH (spec section 6). The header is
/// optional in this scaffold - if the caller omits it, the request simply isn't deduplicated.
/// Runs after authentication so the tenant claim is available.
///
/// NOTE (documented behavior change): integration.IdempotencyKey stores only a
/// ResponseBodyHash (varbinary), not the full response body, unlike the old HrDbContext-backed
/// IdempotencyKeyRecord.ResponseBodyJson. A repeated key therefore returns the original status
/// code with a small "already processed" envelope instead of byte-for-byte replaying the first
/// response body - full replay would need a schema change (a ResponseBody column) that is out of
/// scope for this pass.
/// </summary>
public sealed class IdempotencyKeyMiddleware(RequestDelegate next)
{
    private const string HeaderName = "Idempotency-Key";

    public async Task InvokeAsync(HttpContext context, HrAutomationDbContext db)
    {
        var method = context.Request.Method;
        if (!HttpMethods.IsPost(method) && !HttpMethods.IsPatch(method))
        {
            await next(context);
            return;
        }

        if (!context.Request.Headers.TryGetValue(HeaderName, out var keyValues) || string.IsNullOrWhiteSpace(keyValues))
        {
            await next(context);
            return;
        }

        if (!Guid.TryParse(context.User.FindFirstValue("tenant_id"), out var tenantId))
        {
            await next(context);
            return;
        }

        var key = keyValues.ToString();
        var path = context.Request.Path.ToString();

        var existing = await db.IdempotencyKeys.FirstOrDefaultAsync(r =>
            r.TenantId == tenantId && r.RequestPath == path && r.IdempotencyKeyValue == key && r.ExpiresAtUtc > DateTime.UtcNow);

        if (existing is not null)
        {
            context.Response.StatusCode = existing.ResponseStatusCode ?? StatusCodes.Status200OK;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsync(
                $$"""{"idempotent":true,"message":"This request was already processed with Idempotency-Key '{{key}}'.","originalStatusCode":{{existing.ResponseStatusCode ?? StatusCodes.Status200OK}}}""");
            return;
        }

        var originalBody = context.Response.Body;
        await using var buffer = new MemoryStream();
        context.Response.Body = buffer;

        await next(context);

        buffer.Seek(0, SeekOrigin.Begin);
        var bodyBytes = buffer.ToArray();
        buffer.Seek(0, SeekOrigin.Begin);
        await buffer.CopyToAsync(originalBody);
        context.Response.Body = originalBody;

        if (context.Response.StatusCode is >= 200 and < 300)
        {
            db.IdempotencyKeys.Add(new IdempotencyKeyEntry
            {
                IdempotencyKeyId = Guid.NewGuid(),
                TenantId = tenantId,
                IdempotencyKeyValue = key,
                RequestPath = path,
                ResponseStatusCode = context.Response.StatusCode,
                ResponseBodyHash = SHA256.HashData(bodyBytes),
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddHours(24)
            });
            await db.SaveChangesAsync();
        }
    }
}
