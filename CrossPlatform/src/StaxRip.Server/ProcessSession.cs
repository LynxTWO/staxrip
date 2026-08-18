using System.Security.Cryptography;
using Microsoft.Extensions.Primitives;
using Microsoft.Net.Http.Headers;

namespace StaxRip.Server;

public sealed class ProcessSession : IDisposable
{
    public const int TokenSizeBytes = 32;

    private const string CookiePrefix = "staxrip_session_";
    private const string CookiePath = "/api/v1";

    private readonly byte[] _token = RandomNumberGenerator.GetBytes(TokenSizeBytes);
    private readonly string _encodedToken;
    private bool _disposed;

    public ProcessSession()
    {
        _encodedToken = Convert.ToHexString(_token);
        CookieName = CookiePrefix +
            Convert.ToHexString(RandomNumberGenerator.GetBytes(12));
    }

    public string CookieName { get; }

    public void IssueCookie(HttpResponse response)
    {
        ArgumentNullException.ThrowIfNull(response);
        ObjectDisposedException.ThrowIf(_disposed, this);

        response.Cookies.Append(
            CookieName,
            _encodedToken,
            new CookieOptions
            {
                Domain = null,
                Expires = null,
                HttpOnly = true,
                IsEssential = true,
                MaxAge = null,
                Path = CookiePath,
                SameSite = Microsoft.AspNetCore.Http.SameSiteMode.Strict,
                Secure = false,
            });
    }

    public bool IsAuthorized(IHeaderDictionary headers)
    {
        ArgumentNullException.ThrowIfNull(headers);

        return LoopbackRequestPolicy.HasExactClientHeader(headers) &&
            TryGetSingleCookie(headers, CookieName, out string? candidate) &&
            MatchesToken(candidate);
    }

    public bool MatchesToken(string? candidate)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (candidate is null || candidate.Length != TokenSizeBytes * 2)
            return false;

        Span<byte> decoded = stackalloc byte[TokenSizeBytes];
        bool validHex = true;

        for (int index = 0; index < decoded.Length; index++)
        {
            int high = DecodeHex(candidate[index * 2]);
            int low = DecodeHex(candidate[(index * 2) + 1]);
            validHex &= high >= 0 && low >= 0;
            decoded[index] = (byte)((Math.Max(high, 0) << 4) | Math.Max(low, 0));
        }

        bool matches = CryptographicOperations.FixedTimeEquals(_token, decoded);
        CryptographicOperations.ZeroMemory(decoded);
        return validHex && matches;
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        CryptographicOperations.ZeroMemory(_token);
        _disposed = true;
        GC.SuppressFinalize(this);
    }

    private static bool TryGetSingleCookie(
        IHeaderDictionary headers,
        string cookieName,
        out string? value)
    {
        value = null;

        if (!headers.TryGetValue(HeaderNames.Cookie, out StringValues cookieHeaders) ||
            cookieHeaders.Count != 1 ||
            cookieHeaders[0] is not string header)
        {
            return false;
        }

        int matchCount = 0;

        foreach (string segment in header.Split(';', StringSplitOptions.None))
        {
            ReadOnlySpan<char> pair = segment.AsSpan().Trim();
            int separator = pair.IndexOf('=');

            if (separator <= 0)
                continue;

            ReadOnlySpan<char> name = pair[..separator].Trim();

            if (!name.Equals(cookieName.AsSpan(), StringComparison.Ordinal))
                continue;

            matchCount++;
            value = pair[(separator + 1)..].Trim().ToString();
        }

        return matchCount == 1;
    }

    private static int DecodeHex(char value) => value switch
    {
        >= '0' and <= '9' => value - '0',
        >= 'a' and <= 'f' => value - 'a' + 10,
        >= 'A' and <= 'F' => value - 'A' + 10,
        _ => -1,
    };
}
