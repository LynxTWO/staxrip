using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Primitives;
using Microsoft.Net.Http.Headers;
using StaxRip.Contracts;

namespace StaxRip.Server;

public sealed record RequestRejection(int StatusCode, ApiErrorCode Code, string Message);

public static class LoopbackRequestPolicy
{
    private const string HttpPrefix = "http://";

    // The one request body the server accepts, on the one POST route, per D-046: a
    // media path has to cross the boundary somewhere, and a bounded JSON body keeps
    // user paths out of URLs, logs, and browser history. The bound matches the
    // transport-level request body limit so the two laws cannot drift apart silently.
    public const int MaximumMediaFactsBodyBytes = 1024;
    private const string MediaFactsContentType = "application/json; charset=utf-8";

    public static IReadOnlyList<string> AllowedRoutes { get; } = Array.AsReadOnly(
    [
        "/",
        "/app.css",
        "/app.js",
        ApiContract.HealthRoute,
        ApiContract.CapabilitiesRoute,
        ApiContract.MediaFactsRoute,
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

        string? rawTarget = request.HttpContext.Features.Get<IHttpRequestFeature>()?.RawTarget;

        if (!string.Equals(request.Method, AllowedMethodFor(rawTarget), StringComparison.Ordinal))
            return Reject(StatusCodes.Status405MethodNotAllowed, ApiErrorCode.MethodNotAllowed);

        if (request.QueryString.HasValue)
            return Reject(StatusCodes.Status400BadRequest, ApiErrorCode.InvalidRequest);

        if (string.Equals(rawTarget, ApiContract.MediaFactsRoute, StringComparison.Ordinal))
        {
            // The amended body law for the one POST route: an exact declared length
            // within the bound and the exact JSON content type, never chunked. The
            // law admits the shape; authorization and capability remain the
            // handler's judgments.
            if (request.Headers.ContainsKey(HeaderNames.TransferEncoding) ||
                request.ContentLength is not (> 0 and <= MaximumMediaFactsBodyBytes) ||
                !HasExactSingleValue(request.Headers, HeaderNames.ContentType, MediaFactsContentType))
            {
                return Reject(StatusCodes.Status400BadRequest, ApiErrorCode.InvalidRequest);
            }
        }
        else if (!IsBodyless(request))
        {
            return Reject(StatusCodes.Status400BadRequest, ApiErrorCode.InvalidRequest);
        }

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

    // The method law keys on the path part alone: a query is banned everywhere and
    // earns its own rejection, but it must not flip which method a path allows, or a
    // rejected request would carry an Allow header naming a method the path refuses.
    public static string AllowedMethodFor(string? rawTarget)
    {
        if (rawTarget is null)
            return HttpMethods.Get;

        ReadOnlySpan<char> path = rawTarget.AsSpan();
        int queryStart = path.IndexOf('?');
        if (queryStart >= 0)
            path = path[..queryStart];

        return path.SequenceEqual(ApiContract.MediaFactsRoute.AsSpan())
            ? HttpMethods.Post
            : HttpMethods.Get;
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
