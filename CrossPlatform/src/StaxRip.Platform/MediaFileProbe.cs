namespace StaxRip.Platform;

// The filesystem half of D-046, behind the pure path policy: a path the policy
// admitted must also name an existing ordinary file before a probe may run. This file
// is the boundary law's second sanctioned crossing, narrowed to reading file metadata
// and nothing else; the static gate names it, bans everything beyond that inside it,
// and fails if it disappears. Reparse points are refused, which refuses symbolic and
// junction indirection into the configured roots; the reparse refusal is proven by
// the port-inspection gate, which can create a junction, not by the contract corpus,
// which cannot.
public static class MediaFileProbe
{
    public static bool IsRegularFile(string mediaPath)
    {
        try
        {
            // Exists on this type is the directory refusal as well as the absence
            // refusal: it is false for a path that names a directory. A separate
            // directory-attribute branch would be unreachable dead code here, proven
            // by a surviving mutation during this unit's proofs.
            var info = new FileInfo(mediaPath);
            if (!info.Exists)
                return false;

            FileAttributes attributes = info.Attributes;
            if ((attributes & FileAttributes.ReparsePoint) != 0)
                return false;

            if ((attributes & FileAttributes.Device) != 0)
                return false;

            return true;
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or ArgumentException
                or NotSupportedException)
        {
            // Unreadable is inadmissible; the caller never learns why.
            return false;
        }
    }
}
