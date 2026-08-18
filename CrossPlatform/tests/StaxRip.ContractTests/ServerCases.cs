using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Primitives;
using Microsoft.Net.Http.Headers;
using StaxRip.Contracts;
using StaxRip.Core;
using StaxRip.Server;

namespace StaxRip.ContractTests;

internal static class ServerCases
{
    private const string Authority = "http://127.0.0.1:49152";
    private const string Host = "127.0.0.1:49152";

    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("ST-001", "bound authority allowlist", BoundAuthorityAllowlist),
        new("ST-002", "request header authority", RequestHeaderAuthority),
        new("ST-003", "raw target allowlist", RawTargetAllowlist),
        new("ST-004", "request rejection matrix", RequestRejectionMatrix),
        new("ST-005", "process session isolation", ProcessSessionIsolation),
        new("ST-006", "embedded asset allowlist", EmbeddedAssetAllowlist),
        new("ST-007", "response security headers", ResponseSecurityHeaders),
        new("ST-008", "contract JSON is immutable", ContractJsonIsImmutable),
        new("ST-009", "provider failure HTTP envelope", ProviderFailureHttpEnvelopeAsync),
    ];

    private static void BoundAuthorityAllowlist(TestContext context)
    {
        context.True(BoundLoopbackAuthority.TryCanonicalize(Authority, out string? authority), "numeric loopback authority rejected");
        context.Equal(Authority, authority, "numeric loopback authority changed");

        string[] rejected =
        [
            "http://127.0.0.1:49152/",
            "http://127.0.0.1:049152",
            "http://localhost:49152",
            "http://[::1]:49152",
            "https://127.0.0.1:49152",
            "http://127.0.0.1:0",
            "http://127.0.0.1:65536",
            "http://127.0.0.1:49152?query",
            "HTTP://127.0.0.1:49152",
        ];

        foreach (string value in rejected)
            context.False(BoundLoopbackAuthority.TryCanonicalize(value, out _), $"non-canonical authority accepted: {value}");
    }

    private static void RequestHeaderAuthority(TestContext context)
    {
        var headers = new HeaderDictionary
        {
            [HeaderNames.Host] = Host,
        };

        context.True(LoopbackRequestPolicy.HasExactHost(headers, Authority), "exact Host rejected");
        headers[HeaderNames.Host] = "localhost:49152";
        context.False(LoopbackRequestPolicy.HasExactHost(headers, Authority), "hostname Host accepted");
        headers[HeaderNames.Host] = new StringValues([Host, Host]);
        context.False(LoopbackRequestPolicy.HasExactHost(headers, Authority), "duplicate Host accepted");

        headers = new HeaderDictionary();
        context.True(LoopbackRequestPolicy.HasAllowedOrigin(headers, Authority), "absent Origin rejected");
        headers[HeaderNames.Origin] = Authority;
        context.True(LoopbackRequestPolicy.HasAllowedOrigin(headers, Authority), "exact Origin rejected");
        headers[HeaderNames.Origin] = Authority + "/";
        context.False(LoopbackRequestPolicy.HasAllowedOrigin(headers, Authority), "trailing-slash Origin accepted");
        headers[HeaderNames.Origin] = "null";
        context.False(LoopbackRequestPolicy.HasAllowedOrigin(headers, Authority), "null Origin accepted");
        headers[HeaderNames.Origin] = new StringValues([Authority, Authority]);
        context.False(LoopbackRequestPolicy.HasAllowedOrigin(headers, Authority), "duplicate Origin accepted");

        headers = new HeaderDictionary();
        context.False(LoopbackRequestPolicy.HasExactClientHeader(headers), "missing client header accepted");
        headers["X-StaxRip-Client"] = "web";
        context.True(LoopbackRequestPolicy.HasExactClientHeader(headers), "exact client header rejected");
        headers["X-StaxRip-Client"] = "Web";
        context.False(LoopbackRequestPolicy.HasExactClientHeader(headers), "case-variant client header accepted");
        headers["X-StaxRip-Client"] = new StringValues(["web", "web"]);
        context.False(LoopbackRequestPolicy.HasExactClientHeader(headers), "duplicate client header accepted");
    }

    private static void RawTargetAllowlist(TestContext context)
    {
        context.SequenceEqual(
            ["/", "/app.css", "/app.js", ApiContract.HealthRoute, ApiContract.CapabilitiesRoute],
            LoopbackRequestPolicy.AllowedRoutes,
            "route allowlist changed");

        foreach (string route in LoopbackRequestPolicy.AllowedRoutes)
            context.True(LoopbackRequestPolicy.IsAllowedRawTarget(route), $"allowed raw target rejected: {route}");

        string[] rejected =
        [
            "",
            "/healthz/",
            "/HEALTHZ",
            "/%68ealthz",
            "/./healthz",
            "/app.js?",
            "/api/v1/capabilities?x=1",
            "//api/v1/capabilities",
        ];

        foreach (string route in rejected)
            context.False(LoopbackRequestPolicy.IsAllowedRawTarget(route), $"non-canonical raw target accepted: {route}");
    }

    private static void RequestRejectionMatrix(TestContext context)
    {
        context.Equal<RequestRejection?>(null, Evaluate("GET", "/healthz"), "valid health request rejected");
        context.Equal(503, Evaluate("GET", "/healthz", authority: null)?.StatusCode, "unpublished authority did not fail closed");
        context.Equal(400, Evaluate("GET", "/healthz", host: "localhost:49152")?.StatusCode, "invalid Host status changed");
        context.Equal(403, Evaluate("GET", "/healthz", origin: "http://127.0.0.1:49153")?.StatusCode, "invalid Origin status changed");
        context.Equal(400, Evaluate("GET", "/healthz?x=1", query: "?x=1")?.StatusCode, "query status changed");
        context.Equal(400, Evaluate("GET", "/healthz", contentLength: 1)?.StatusCode, "request body status changed");
        context.Equal(400, Evaluate("GET", "/healthz", transferEncoding: true)?.StatusCode, "transfer encoding status changed");
        context.Equal(404, Evaluate("GET", "/healthz/")?.StatusCode, "unknown route status changed");

        foreach (string method in new[] { "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "TRACE", "CONNECT" })
            context.Equal(405, Evaluate(method, "/healthz")?.StatusCode, $"method status changed: {method}");
    }

    private static void ProcessSessionIsolation(TestContext context)
    {
        using var session = new ProcessSession();
        var responseContext = new DefaultHttpContext();
        session.IssueCookie(responseContext.Response);

        string setCookie = responseContext.Response.Headers.SetCookie.ToString();
        string[] attributes = setCookie.Split(';', StringSplitOptions.TrimEntries);
        string[] pair = attributes[0].Split('=', 2, StringSplitOptions.None);

        context.Equal(session.CookieName, pair[0], "session cookie name changed");
        context.Equal(64, pair[1].Length, "session token length changed");
        context.True(session.CookieName.StartsWith("staxrip_session_", StringComparison.Ordinal), "session cookie prefix changed");
        context.Equal(40, session.CookieName.Length, "session cookie name entropy changed");
        context.True(attributes.Contains("path=/api/v1", StringComparer.OrdinalIgnoreCase), "session cookie path changed");
        context.True(attributes.Contains("httponly", StringComparer.OrdinalIgnoreCase), "session cookie lost HttpOnly");
        context.True(attributes.Contains("samesite=strict", StringComparer.OrdinalIgnoreCase), "session cookie SameSite changed");
        context.False(attributes.Contains("secure", StringComparer.OrdinalIgnoreCase), "plain HTTP cookie unexpectedly became Secure");
        context.False(attributes.Any(static item => item.StartsWith("domain=", StringComparison.OrdinalIgnoreCase)), "session cookie gained Domain");
        context.False(attributes.Any(static item => item.StartsWith("expires=", StringComparison.OrdinalIgnoreCase)), "session cookie gained Expires");
        context.False(attributes.Any(static item => item.StartsWith("max-age=", StringComparison.OrdinalIgnoreCase)), "session cookie gained Max-Age");
        context.True(session.MatchesToken(pair[1]), "issued token did not match");

        char replacement = pair[1][0] == '0' ? '1' : '0';
        string invalid = replacement + pair[1][1..];
        context.False(session.MatchesToken(invalid), "wrong token matched");
        context.False(session.MatchesToken("not-a-token"), "malformed token matched");

        var headers = new HeaderDictionary
        {
            ["X-StaxRip-Client"] = "web",
            [HeaderNames.Cookie] = $"unrelated=value; {session.CookieName}={pair[1]}",
        };
        context.True(session.IsAuthorized(headers), "valid session headers rejected");
        headers[HeaderNames.Cookie] = $"{session.CookieName}={pair[1]}; {session.CookieName}={pair[1]}";
        context.False(session.IsAuthorized(headers), "duplicate session cookie accepted");

        using var second = new ProcessSession();
        context.False(string.Equals(session.CookieName, second.CookieName, StringComparison.Ordinal), "concurrent sessions reused a cookie name");
        context.False(second.MatchesToken(pair[1]), "concurrent session accepted another token");
    }

    private static void EmbeddedAssetAllowlist(TestContext context)
    {
        EmbeddedAssetCatalog catalog = EmbeddedAssetCatalog.Load(typeof(ServerApp).Assembly);
        context.SequenceEqual(["/", "/app.css", "/app.js"], catalog.Routes, "embedded route set changed");

        foreach (string route in catalog.Routes)
        {
            context.True(catalog.TryGet(route, out EmbeddedAsset? asset), $"embedded route missing: {route}");
            context.True(asset is not null && asset.Content.Length is > 0 and <= 256 * 1024, $"embedded asset size invalid: {route}");
            string text = Encoding.UTF8.GetString(asset!.Content.Span);
            context.False(text.Contains("file://", StringComparison.OrdinalIgnoreCase), $"embedded asset contains file URL: {route}");
        }

        context.False(catalog.TryGet("/favicon.ico", out _), "unlisted asset resolved");
        context.False(catalog.TryGet("../app.js", out _), "traversal asset resolved");
    }

    private static void ResponseSecurityHeaders(TestContext context)
    {
        var response = new DefaultHttpContext().Response;
        SecurityHeaders.Apply(response);

        context.Equal("no-store", response.Headers.CacheControl.ToString(), "cache policy changed");
        context.Equal(SecurityHeaders.ContentSecurityPolicy, response.Headers.ContentSecurityPolicy.ToString(), "CSP changed");
        context.Equal("nosniff", response.Headers.XContentTypeOptions.ToString(), "content-type policy changed");
        context.Equal("DENY", response.Headers.XFrameOptions.ToString(), "frame policy changed");
        context.Equal("no-referrer", response.Headers["Referrer-Policy"].ToString(), "referrer policy changed");
        context.Equal("same-origin", response.Headers["Cross-Origin-Opener-Policy"].ToString(), "opener policy changed");
        context.Equal("same-origin", response.Headers["Cross-Origin-Resource-Policy"].ToString(), "resource policy changed");
        context.Equal(SecurityHeaders.PermissionsPolicy, response.Headers["Permissions-Policy"].ToString(), "permissions policy changed");
        context.False(response.Headers.ContainsKey(HeaderNames.Server), "Server header was added");
        context.False(response.Headers.Keys.Any(static key => key.StartsWith("Access-Control-Allow-", StringComparison.OrdinalIgnoreCase)), "CORS allow header was added");
    }

    private static void ContractJsonIsImmutable(TestContext context)
    {
        context.True(ContractJson.Options.IsReadOnly, "shared JSON options remained mutable");
        context.Throws<InvalidOperationException>(
            () => ContractJson.Options.WriteIndented = true,
            "shared JSON options accepted mutation");
    }

    private static async Task ProviderFailureHttpEnvelopeAsync(TestContext context)
    {
        await using var app = ServerApp.Build(new ThrowingHostFactsProvider());
        using var startTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        await app.StartAsync(startTimeout.Token).ConfigureAwait(false);

        try
        {
            Uri authority = ServerApp.PublishBoundAddress(app);
            using var handler = new SocketsHttpHandler
            {
                AllowAutoRedirect = false,
                UseCookies = false,
                UseProxy = false,
            };
            using var client = new HttpClient(handler)
            {
                Timeout = TimeSpan.FromSeconds(5),
            };

            using var rootRequest = CreateRequest(authority, "/");
            using HttpResponseMessage rootResponse = await client.SendAsync(rootRequest).ConfigureAwait(false);
            context.Equal(System.Net.HttpStatusCode.OK, rootResponse.StatusCode, "session bootstrap failed");
            context.True(rootResponse.Headers.TryGetValues("Set-Cookie", out IEnumerable<string>? setCookies), "session cookie missing");
            string cookiePair = SingleCookiePair(setCookies!);

            using var apiRequest = CreateRequest(authority, ApiContract.CapabilitiesRoute);
            apiRequest.Headers.TryAddWithoutValidation("X-StaxRip-Client", "web");
            apiRequest.Headers.TryAddWithoutValidation("Cookie", cookiePair);
            using HttpResponseMessage apiResponse = await client.SendAsync(apiRequest).ConfigureAwait(false);
            string body = await apiResponse.Content.ReadAsStringAsync().ConfigureAwait(false);

            context.Equal(System.Net.HttpStatusCode.InternalServerError, apiResponse.StatusCode, "provider failure status changed");
            context.Equal("application/json; charset=utf-8", apiResponse.Content.Headers.ContentType?.ToString(), "provider failure content type changed");
            context.False(apiResponse.Headers.Any(static header => header.Key.StartsWith("Access-Control-Allow-", StringComparison.OrdinalIgnoreCase)), "provider failure added CORS authority");
            context.False(body.Contains("synthetic-provider-secret", StringComparison.Ordinal), "provider failure exposed exception text");
            context.False(body.Contains("stack", StringComparison.OrdinalIgnoreCase), "provider failure exposed stack text");

            ErrorResponse? error = JsonSerializer.Deserialize<ErrorResponse>(body, ContractJson.Options);
            context.True(error is not null, "provider failure envelope was not deserializable");
            context.Equal(ApiErrorCode.InternalError, error!.Error.Code, "provider failure code changed");
            context.Equal("The request could not be completed.", error.Error.Message, "provider failure message changed");
        }
        finally
        {
            using var stopTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            await app.StopAsync(stopTimeout.Token).ConfigureAwait(false);
        }
    }

    private static RequestRejection? Evaluate(
        string method,
        string rawTarget,
        string? authority = Authority,
        string host = Host,
        string? origin = null,
        string? query = null,
        long? contentLength = null,
        bool transferEncoding = false)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Request.Method = method;
        httpContext.Request.Headers.Host = host;
        httpContext.Request.ContentLength = contentLength;

        if (origin is not null)
            httpContext.Request.Headers.Origin = origin;

        if (query is not null)
            httpContext.Request.QueryString = new QueryString(query);

        if (transferEncoding)
            httpContext.Request.Headers.TransferEncoding = "chunked";

        IHttpRequestFeature feature = httpContext.Features.Get<IHttpRequestFeature>() ??
            throw new InvalidOperationException("default request feature missing");
        feature.RawTarget = rawTarget;

        return LoopbackRequestPolicy.EvaluateRequest(httpContext.Request, authority);
    }

    private static HttpRequestMessage CreateRequest(Uri authority, string route) => new(
        HttpMethod.Get,
        new Uri(authority, route))
    {
        Version = System.Net.HttpVersion.Version11,
        VersionPolicy = HttpVersionPolicy.RequestVersionExact,
    };

    private static string SingleCookiePair(IEnumerable<string> headers)
    {
        string[] values = headers.ToArray();
        if (values.Length != 1)
            throw new TestFailureException("session cookie cardinality changed", 1, values.Length);

        string pair = values[0].Split(';', 2, StringSplitOptions.None)[0];
        if (!pair.StartsWith("staxrip_session_", StringComparison.Ordinal) || !pair.Contains('='))
            throw new TestFailureException("session cookie shape changed", "bounded session pair", "invalid shape");

        return pair;
    }

    private sealed class ThrowingHostFactsProvider : IHostFactsProvider
    {
        public HostFacts Capture() => throw new InvalidOperationException("synthetic-provider-secret");
    }
}
