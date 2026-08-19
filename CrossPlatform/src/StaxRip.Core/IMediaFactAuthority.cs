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
}

// The raw authority output, before normalization. RawJson is the authority's own
// document; the normalizer owns everything after this point, including the privacy
// strip, so an adapter cannot accidentally publish an unstripped payload.
public sealed record MediaFactAuthorityDocument(string AuthorityName, string RawJson);
