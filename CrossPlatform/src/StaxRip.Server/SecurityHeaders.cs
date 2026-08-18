using Microsoft.Net.Http.Headers;

namespace StaxRip.Server;

public static class SecurityHeaders
{
    public const string ContentSecurityPolicy =
        "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; " +
        "img-src 'self'; font-src 'none'; object-src 'none'; base-uri 'none'; " +
        "form-action 'none'; frame-ancestors 'none'; worker-src 'none'; manifest-src 'none'";

    public const string PermissionsPolicy =
        "accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), " +
        "fullscreen=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), " +
        "payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), " +
        "serial=(), usb=(), web-share=(), xr-spatial-tracking=()";

    public static void Apply(HttpResponse response)
    {
        ArgumentNullException.ThrowIfNull(response);

        response.Headers[HeaderNames.CacheControl] = "no-store";
        response.Headers[HeaderNames.ContentSecurityPolicy] = ContentSecurityPolicy;
        response.Headers[HeaderNames.XContentTypeOptions] = "nosniff";
        response.Headers[HeaderNames.XFrameOptions] = "DENY";
        response.Headers["Referrer-Policy"] = "no-referrer";
        response.Headers["Cross-Origin-Opener-Policy"] = "same-origin";
        response.Headers["Cross-Origin-Resource-Policy"] = "same-origin";
        response.Headers["Permissions-Policy"] = PermissionsPolicy;
    }
}
