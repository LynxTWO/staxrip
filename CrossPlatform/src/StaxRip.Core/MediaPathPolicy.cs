using System.Collections.Immutable;

namespace StaxRip.Core;

// D-046 configuration: the media roots the operator explicitly configured. The default
// is empty, and an empty policy admits nothing, which is the ratified stance that the
// capability does not exist until someone turns it on.
public sealed record MediaPathPolicyOptions
{
    public ImmutableArray<string> MediaRoots { get; init; } = [];
}

// The D-046 path acceptance policy, ratified 2026-08-19: configured media roots,
// canonical containment, uniform rejection with no existence oracle. This layer is
// pure string judgment and never touches the filesystem, which is what makes the
// no-oracle property hold by construction: nothing here can observe whether a path
// exists, so no rejection can reveal it. The regular-file requirement needs a
// filesystem probe and lives with the boundary-sanctioned code, behind this check,
// which runs first.
//
// The verdict is a single bool with no reason classes at all. Every hostile shape,
// traversal, device namespace, alternate stream, overlong, control characters,
// outside the roots, is the same false, so the rejection shape cannot be used to
// probe the policy from outside.
public static class MediaPathPolicy
{
    private const int MaximumPathLength = 4096;

    public static bool IsAdmissible(MediaPathPolicyOptions options, string mediaPath)
    {
        if (string.IsNullOrWhiteSpace(mediaPath) || mediaPath.Length > MaximumPathLength)
            return false;

        foreach (char value in mediaPath)
        {
            if (value < ' ')
                return false;
        }

        // Device, UNC, and extended-prefix namespaces are outside the v1 policy, and a
        // colon is admitted only as the second character of a drive prefix, which
        // rejects device names and alternate stream spellings in one rule.
        if (mediaPath.StartsWith(@"\\", StringComparison.Ordinal) ||
            mediaPath.StartsWith("//", StringComparison.Ordinal))
        {
            return false;
        }

        for (int index = 0; index < mediaPath.Length; index++)
        {
            if (mediaPath[index] == ':' && index != 1)
                return false;
        }

        if (!Path.IsPathFullyQualified(mediaPath))
            return false;

        // A media path names a file, never a directory spelling; canonicalization
        // preserves a trailing separator, so it is rejected explicitly.
        char last = mediaPath[^1];
        if (last == Path.DirectorySeparatorChar || last == Path.AltDirectorySeparatorChar)
            return false;

        // The caller presents the canonical spelling or is rejected: anything
        // canonicalization would rewrite, dot segments, doubled separators, alternate
        // separators, is refused rather than repaired, so containment is judged on
        // exactly one spelling of each path and a traversal that lands inside a root
        // is still refused for not being canonical.
        string canonical;
        try
        {
            canonical = Path.GetFullPath(mediaPath);
        }
        catch (Exception exception) when (
            exception is ArgumentException or PathTooLongException or NotSupportedException)
        {
            return false;
        }

        if (!string.Equals(canonical, mediaPath, StringComparison.Ordinal))
            return false;

        foreach (string root in options.MediaRoots)
        {
            // A configured root that is not itself canonical is dead, never repaired:
            // repairing configuration would move the boundary somewhere the operator
            // did not write down.
            if (string.IsNullOrWhiteSpace(root) || !Path.IsPathFullyQualified(root))
                continue;

            string canonicalRoot;
            try
            {
                canonicalRoot = Path.GetFullPath(root);
            }
            catch (Exception exception) when (
                exception is ArgumentException or PathTooLongException or NotSupportedException)
            {
                continue;
            }

            if (!string.Equals(canonicalRoot, root, StringComparison.Ordinal))
                continue;

            if (mediaPath.Length > root.Length + 1 &&
                mediaPath.StartsWith(root, StringComparison.Ordinal) &&
                mediaPath[root.Length] == Path.DirectorySeparatorChar)
            {
                return true;
            }
        }

        return false;
    }
}
