using StaxRip.Contracts;
using StaxRip.Core;
using StaxRip.Platform;

namespace StaxRip.Server;

// The operator's explicit media-inspection configuration, handed to the server as one
// value: the D-046 path policy and the authority options. There is no discovery of
// any kind; when this is absent the capability is unavailable and the endpoint says
// so.
public sealed record MediaInspectionConfiguration
{
    public required MediaPathPolicyOptions PathPolicy { get; init; }

    public required MediaInfoCliOptions Authority { get; init; }
}

// The configured media-facts pipeline behind the session gate: bounded body, strict
// request shape, then the D-046 acceptance judgment, then the authority, the
// normalizer, and the version range. Rejection classes split exactly where the
// ratified contracts split them: every path-acceptance failure is one uniform
// response with no detail, because acceptance is where the no-oracle rule lives;
// failures after acceptance carry a typed reason class, because by then the caller's
// path was admitted and the reason describes the authority, not the filesystem.
public static class MediaFactsHandler
{
    private const string RejectionMessage = "The media path was rejected.";

    public static async Task HandleAsync(
        HttpContext context,
        MediaInspectionConfiguration configuration,
        IMediaFactAuthority authority)
    {
        // The request law already required a declared length within the bound; the
        // handler re-checks and reads exactly that many bytes, so a lying stream
        // cannot feed more than the declaration.
        int declaredLength = (int)(context.Request.ContentLength ?? 0);
        if (declaredLength is <= 0 or > LoopbackRequestPolicy.MaximumMediaFactsBodyBytes)
        {
            await WriteInvalidRequestAsync(context).ConfigureAwait(false);
            return;
        }

        byte[] body = new byte[declaredLength];
        int received = 0;
        while (received < body.Length)
        {
            int read = await context.Request.Body
                .ReadAsync(body.AsMemory(received), context.RequestAborted).ConfigureAwait(false);
            if (read == 0)
                break;
            received += read;
        }

        MediaFactsRequest? request = null;
        if (received == body.Length)
        {
            try
            {
                request = System.Text.Json.JsonSerializer.Deserialize<MediaFactsRequest>(body, ContractJson.Options);
            }
            catch (System.Text.Json.JsonException)
            {
                request = null;
            }
        }

        if (request?.Path is not { Length: > 0 } mediaPath)
        {
            await WriteInvalidRequestAsync(context).ConfigureAwait(false);
            return;
        }

        // The D-046 acceptance judgment: the pure policy and the regular-file probe
        // answer together with one uniform rejection carrying no detail, because
        // acceptance is where the no-oracle rule lives.
        if (!MediaPathPolicy.IsAdmissible(configuration.PathPolicy, mediaPath) ||
            !MediaFileProbe.IsRegularFile(mediaPath))
        {
            await ContractResponses.WriteErrorAsync(
                context.Response,
                StatusCodes.Status422UnprocessableEntity,
                ApiErrorCode.MediaRejected,
                RejectionMessage,
                context.RequestAborted).ConfigureAwait(false);
            return;
        }

        // Past acceptance the ratified error contract takes over: failures carry a
        // typed reason class describing the authority, never tool output or a path.
        // Cancellation is not caught; a killed probe already reaped its child.
        MediaFactAuthorityDocument document;
        try
        {
            document = await authority.ProbeAsync(mediaPath, context.RequestAborted).ConfigureAwait(false);
        }
        catch (MediaFactAuthorityException exception)
        {
            await WriteAuthorityFailureAsync(context, exception.Message).ConfigureAwait(false);
            return;
        }

        MediaFactsResponse facts;
        try
        {
            facts = MediaFactsNormalizer.Normalize(document.RawJson);
        }
        catch (MediaFactsFormatException exception)
        {
            await WriteAuthorityFailureAsync(context, exception.Message).ConfigureAwait(false);
            return;
        }

        if (!MediaInfoCliAuthority.IsSupportedVersion(facts.Authority.Version))
        {
            await WriteAuthorityFailureAsync(context, "version-out-of-range").ConfigureAwait(false);
            return;
        }

        await ContractResponses.WriteMediaFactsAsync(context.Response, facts, context.RequestAborted).ConfigureAwait(false);
    }

    private static Task WriteInvalidRequestAsync(HttpContext context) =>
        ContractResponses.WriteErrorAsync(
            context.Response,
            StatusCodes.Status400BadRequest,
            ApiErrorCode.InvalidRequest,
            "The request was rejected.",
            context.RequestAborted);

    private static Task WriteAuthorityFailureAsync(HttpContext context, string reasonClass) =>
        ContractResponses.WriteErrorAsync(
            context.Response,
            StatusCodes.Status502BadGateway,
            ApiErrorCode.AuthorityFailure,
            reasonClass,
            context.RequestAborted);
}
