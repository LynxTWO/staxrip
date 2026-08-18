using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Primitives;
using Microsoft.Net.Http.Headers;
using StaxRip.Contracts;

namespace StaxRip.Server;

public sealed record RequestRejection(int StatusCode, ApiErrorCode Code, string Message);

public static class LoopbackRequestPolicy
{
    private const string HttpPrefix = "http://";

    public static IReadOnlyList<string> AllowedRoutes { get; } = Array.AsReadOnly(
    [
        "/",
        "/app.css",
        "/app.js",
        ApiContract.HealthRoute,
        ApiContract.CapabilitiesRoute,
    ]);

    public static RequestRejection? EvaluateRequest(HttpRequest request, string? authority)
    {
        ArgumentNullException.ThrowIfNull(request);

        if (authority is null)
            return Reject(StatusCodes.Status503ServiceUnavailable, ApiErrorCode.InternalError);

        if (!HasExactHost(request.Headers, authority))
            return Reject(StatusCodes.Status400BadRequest, ApiErrorCode.InvalidRequest);

        if (!HasAllowedOrigin(request.Headers, authority))
            return Reject(StatusCodes.Status403Forbidden, ApiErrorCode.Forbidden);

        if (!string.Equals(request.Method, HttpMethods.Get, StringComparison.Ordinal))
            return Reject(StatusCodes.Status405MethodNotAllowed, ApiErrorCode.MethodNotAllowed);

        if (request.QueryString.HasValue)
            return Reject(StatusCodes.Status400BadRequest, ApiErrorCode.InvalidRequest);

        if (!IsBodyless(request))
            return Reject(StatusCodes.Status400BadRequest, ApiErrorCode.InvalidRequest);

        string? rawTarget = request.HttpContext.Features.Get<IHttpRequestFeature>()?.RawTarget;

        if (!IsAllowedRawTarget(rawTarget))
            return Reject(StatusCodes.Status404NotFound, ApiErrorCode.NotFound);

        return null;
    }

    public static bool HasExactHost(IHeaderDictionary headers, string authority)
    {
        ArgumentNullException.ThrowIfNull(headers);

        if (!BoundLoopbackAuthority.TryCanonicalize(authority, out _) ||
            !TryGetHostPart(authority, out string? expectedHost) ||
            expectedHost is null)
            return false;

        return HasExactSingleValue(headers, HeaderNames.Host, expectedHost);
    }

    public static bool HasAllowedOrigin(IHeaderDictionary headers, string authority)
    {
        ArgumentNullException.ThrowIfNull(headers);

        if (!BoundLoopbackAuthority.TryCanonicalize(authority, out _))
            return false;

        if (!headers.TryGetValue(HeaderNames.Origin, out StringValues origins))
            return true;

        return origins.Count == 1 && string.Equals(origins[0], authority, StringComparison.Ordinal);
    }

    public static bool HasExactClientHeader(IHeaderDictionary headers)
    {
        ArgumentNullException.ThrowIfNull(headers);
        return HasExactSingleValue(headers, "X-StaxRip-Client", "web");
    }

    public static bool IsAllowedRawTarget(string? rawTarget)
    {
        if (rawTarget is null)
            return false;

        foreach (string route in AllowedRoutes)
        {
            if (string.Equals(rawTarget, route, StringComparison.Ordinal))
                return true;
        }

        return false;
    }

    public static bool IsBodyless(HttpRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        if (request.ContentLength is > 0)
            return false;

        return !request.Headers.ContainsKey(HeaderNames.TransferEncoding);
    }

    private static bool HasExactSingleValue(
        IHeaderDictionary headers,
        string headerName,
        string expectedValue)
    {
        if (!headers.TryGetValue(headerName, out StringValues values) || values.Count != 1)
            return false;

        return string.Equals(values[0], expectedValue, StringComparison.Ordinal);
    }

    private static bool TryGetHostPart(string authority, out string? host)
    {
        host = null;

        if (!authority.StartsWith(HttpPrefix, StringComparison.Ordinal) ||
            authority.Length <= HttpPrefix.Length)
        {
            return false;
        }

        string candidate = authority[HttpPrefix.Length..];

        if (candidate.Contains('/'))
            return false;

        host = candidate;
        return true;
    }

    private static RequestRejection Reject(int statusCode, ApiErrorCode code) =>
        new(statusCode, code, "The request was rejected.");
}
