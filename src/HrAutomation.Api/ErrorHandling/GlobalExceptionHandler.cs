using Microsoft.AspNetCore.Diagnostics;

namespace HrAutomation.Api.ErrorHandling;

/// <summary>Catches anything a controller didn't handle and returns RFC 7807 Problem Details -
/// never the raw exception message/stack trace (spec section 6).</summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        logger.LogError(exception, "Unhandled exception for {Method} {Path}", httpContext.Request.Method, httpContext.Request.Path);

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
        httpContext.Response.ContentType = "application/problem+json";

        await httpContext.Response.WriteAsJsonAsync(new
        {
            type = "about:blank",
            title = "An unexpected error occurred.",
            status = StatusCodes.Status500InternalServerError,
            traceId = httpContext.TraceIdentifier
        }, cancellationToken);

        return true;
    }
}
