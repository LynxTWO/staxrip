using System.Collections.Immutable;
using StaxRip.Core;

namespace StaxRip.Platform;

// Configuration for the primary authority adapter. The executable path is operator
// configuration, never discovered; the bounds are adapter policy handed to the
// execution primitive unchanged. The document cap is generous because the authority
// serializes every track of a large file, and the hard cap is the primitive's law, not
// a soft limit.
public sealed record MediaInfoCliOptions
{
    public required string ExecutablePath { get; init; }

    public TimeSpan ProbeTimeout { get; init; } = TimeSpan.FromSeconds(30);

    public int MaximumDocumentBytes { get; init; } = 16 * 1024 * 1024;

    public int MaximumDiagnosticBytes { get; init; } = 64 * 1024;
}

// The MediaInfo CLI adapter, the primary implementation of the authority port under
// D-045. It owns exactly two things: the recorded invocation shape, one flag and the
// media path as a single argv element, matching the committed fixture manifest; and
// the mapping from execution outcomes to the ratified reason classes. It runs nothing
// itself; the bounded-execution primitive is the only path to a child, and everything
// after the raw document, normalization and the privacy strip, belongs to the core
// layer above.
public sealed class MediaInfoCliAuthority : IMediaFactAuthority
{
    private readonly MediaInfoCliOptions options;

    public MediaInfoCliAuthority(MediaInfoCliOptions options)
    {
        this.options = options;
    }

    public string AuthorityName => "mediainfo-cli";

    // The pinned supported range from the tool matrix, proven schema-stable by the
    // committed goldens at both ends. The vocabulary belongs to this authority; a
    // version outside it, or one this parser cannot read, is unsupported, and range
    // enforcement happens on every probed document because the version travels in
    // the document itself.
    public const string SupportedVersionFloor = "24.01";
    public const string SupportedVersionCeiling = "26.05";

    public bool IsSupportedDocumentVersion(string? version) => IsSupportedVersion(version);

    public static bool IsSupportedVersion(string? version)
    {
        if (version is null)
            return false;

        string[] parts = version.Split('.');
        if (parts.Length < 2 ||
            !int.TryParse(parts[0], System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out int major) ||
            !int.TryParse(parts[1], System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out int minor))
        {
            return false;
        }

        int value = (major * 100) + minor;
        return value is >= 2401 and <= 2605;
    }

    public async Task<MediaFactAuthorityDocument> ProbeAsync(string mediaPath, CancellationToken cancellationToken)
    {
        var request = new BoundedProcessRequest
        {
            ExecutablePath = options.ExecutablePath,
            Arguments = ImmutableArray.Create("--Output=JSON", mediaPath),
            Timeout = options.ProbeTimeout,
            MaximumStdOutBytes = options.MaximumDocumentBytes,
            MaximumStdErrBytes = options.MaximumDiagnosticBytes,
        };

        BoundedProcessResult result;
        try
        {
            result = await BoundedProcessRunner.RunAsync(request, cancellationToken).ConfigureAwait(false);
        }
        catch (BoundedProcessException exception)
        {
            // The mapping never forwards the primitive's message object, only the
            // ratified reason classes, so nothing below this layer can widen what an
            // error may carry. A killed-on-cancel child surfaces as cancellation
            // because that is what it is; the kill and reap already happened.
            throw exception.Message switch
            {
                "kill-on-cancel" => (Exception)new OperationCanceledException(cancellationToken),
                "executable-path-not-absolute" or "executable-missing" => new MediaFactAuthorityException("resolver-failure"),
                "timeout" => new MediaFactAuthorityException("timeout"),
                "output-overflow" => new MediaFactAuthorityException("output-overflow"),
                _ => new MediaFactAuthorityException("execution-failure"),
            };
        }

        if (result.ExitCode != 0)
            throw new MediaFactAuthorityException("nonzero-exit");

        return new MediaFactAuthorityDocument(AuthorityName, result.StandardOutput);
    }
}
