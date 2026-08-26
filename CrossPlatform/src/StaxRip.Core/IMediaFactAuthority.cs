namespace StaxRip.Core;

// The swappable-authority port D-045 requires. The primary implementation is the
// MediaInfo CLI adapter in the platform layer; the named backup activates by adding a
// second implementation there, and nothing above this interface changes. The port takes
// a path from its caller: path acceptance policy (D-046) is enforced by the server
// boundary, and the contract test harness is a legitimate caller for fixtures.
public interface IMediaFactAuthority
{
    string AuthorityName { get; }

    Task<MediaFactAuthorityDocument> ProbeAsync(string mediaPath, CancellationToken cancellationToken);

    // The supported-version judgment belongs to the authority, because the range is
    // authority-specific vocabulary: callers above the port ask, they never consult a
    // concrete adapter, which is what keeps the backup swappable at this boundary.
    bool IsSupportedDocumentVersion(string? version);

    // D-058: the readiness probe. Executes the tool once and returns the version it
    // reports, in the same vocabulary IsSupportedDocumentVersion judges, or null when
    // the tool did not run or did not answer readably. The composition root calls
    // this once at activation, so a capability advertised available is one whose
    // tool has actually executed under the constructed environment.
    Task<string?> ProbeVersionAsync(CancellationToken cancellationToken);
}

// D-059: the closed vocabulary of reason classes the server may surface for an
// authority or normalization failure. Anything outside it, which a future adapter
// could throw as free text, is reported as the generic member so no tool output, path,
// or argument can reach the wire through an exception message.
public static class MediaFactAuthorityReasons
{
    public const string Generic = "authority-error";

    private static readonly System.Collections.Immutable.ImmutableHashSet<string> Members =
        System.Collections.Immutable.ImmutableHashSet.Create(
            StringComparer.Ordinal,
            "resolver-failure",
            "timeout",
            "output-overflow",
            "nonzero-exit",
            "execution-failure",
            "version-out-of-range",
            "document-empty",
            "document-not-json",
            "document-not-object",
            "media-missing",
            "track-list-missing",
            "track-not-object",
            "creating-library-missing",
            "creating-library-identity-missing",
            Generic);

    public static string Surface(string? reasonClass) =>
        reasonClass is not null && Members.Contains(reasonClass) ? reasonClass : Generic;
}

// The raw authority output, before normalization. RawJson is the authority's own
// document; the normalizer owns everything after this point, including the privacy
// strip, so an adapter cannot accidentally publish an unstripped payload.
public sealed record MediaFactAuthorityDocument(string AuthorityName, string RawJson);

// Raised when the authority could not answer, the third outcome of the ratified error
// contract. The message is a fixed reason class only: resolver-failure, timeout,
// output-overflow, nonzero-exit, execution-failure. It never carries tool output, an
// argument, or a path, which is what makes it safe to surface through the typed error
// shape. Cancellation is not an error and travels as the runtime's cancellation
// exception instead.
public sealed class MediaFactAuthorityException : Exception
{
    public MediaFactAuthorityException(string reasonClass)
        : base(reasonClass)
    {
    }
}
