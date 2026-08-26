using System.Runtime.InteropServices;

namespace StaxRip.Platform;

// D-055: an admitted file stays bound to its identity from admission through the
// probe, so facts read from a file the policy never admitted are never published.
// The authority is an external process that re-opens by path, so no handle held here
// can be handed to it; what the handle does is make a swap either impossible or
// detectable. On Windows the handle is opened without delete sharing, which refuses a
// rename or delete of the admitted file for as long as it is held. On Linux a held
// descriptor cannot prevent a rename, so the binding is checked afterward: the
// kernel's own view of where the descriptor points must still be the admitted path,
// and a file renamed away or replaced shows as a different target or as deleted.
// The residual, the tool briefly reading a swapped file whose content reaches nobody,
// is the configured-root trust boundary the decision records.
public sealed class MediaFileIdentity : IDisposable
{
    private readonly FileStream stream;
    private readonly string admittedPath;

    private MediaFileIdentity(FileStream stream, string admittedPath)
    {
        this.stream = stream;
        this.admittedPath = admittedPath;
    }

    // Null means the file could not be bound, which the caller treats exactly like
    // an inadmissible path: unreadable is inadmissible, and the caller never learns
    // why. The share mode is the whole point on Windows and harmless elsewhere.
    public static MediaFileIdentity? TryBind(string mediaPath)
    {
        try
        {
            string fullPath = Path.GetFullPath(mediaPath);
            var stream = new FileStream(
                fullPath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                bufferSize: 1,
                FileOptions.None);
            return new MediaFileIdentity(stream, fullPath);
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or ArgumentException
                or NotSupportedException)
        {
            return null;
        }
    }

    // True while the admitted path still names the bound file. On Windows the held
    // handle makes a swap impossible, so the remaining question is whether the path's
    // directory chain is still free of reparse points, which a file handle cannot
    // pin. On Linux the kernel is asked where the descriptor points now.
    public bool IsStillBound()
    {
        if (!MediaFileProbe.IsRegularFile(admittedPath))
            return false;

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return !stream.SafeFileHandle.IsInvalid && !stream.SafeFileHandle.IsClosed;

        try
        {
            long descriptor = stream.SafeFileHandle.DangerousGetHandle().ToInt64();
            var link = new FileInfo($"/proc/self/fd/{descriptor}");
            string? target = link.LinkTarget;
            return target is not null &&
                string.Equals(target, admittedPath, StringComparison.Ordinal);
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or ArgumentException
                or NotSupportedException)
        {
            return false;
        }
    }

    public void Dispose() => stream.Dispose();
}
