using System.Collections.Immutable;
using System.Diagnostics;
using System.Text;

namespace StaxRip.Platform;

// Raised when a bounded execution could not produce a result. The message is a fixed
// reason class only, never the command line, an argument, a path, or process output.
// When a process existed, ReapedProcessId carries the ownership receipt: the primitive
// throws only after that process has been killed and reaped, and the id is the datum a
// caller or test can use to confirm nothing was left behind. A null receipt means the
// request was rejected before any process was created.
public sealed class BoundedProcessException : Exception
{
    public BoundedProcessException(string reasonClass, int? reapedProcessId = null)
        : base(reasonClass)
    {
        ReapedProcessId = reapedProcessId;
    }

    public int? ReapedProcessId { get; }
}

// One execution request under the D-045 bounds: an explicit fully qualified executable
// path that is never searched for, an argv vector that never passes through a shell, a
// hard wall-clock timeout, and a byte cap per output stream.
public sealed record BoundedProcessRequest
{
    public required string ExecutablePath { get; init; }

    public required ImmutableArray<string> Arguments { get; init; }

    public required TimeSpan Timeout { get; init; }

    public required int MaximumStdOutBytes { get; init; }

    public required int MaximumStdErrBytes { get; init; }
}

// A completed execution. A nonzero exit code is a result, not an exception; whether it
// is an error is the caller's contract, not the primitive's.
public sealed record BoundedProcessResult
{
    public required int ExitCode { get; init; }

    public required string StandardOutput { get; init; }

    public required string StandardError { get; init; }
}

// The single process-execution primitive of the cross-platform tree. Every adapter that
// runs a tool calls this and nothing else, so the D-045 bounds are implemented once and
// tested once; a second execution path is the drift the repository's cross-pass rules
// name. Reason classes: executable-path-not-absolute and executable-missing reject
// before any spawn; timeout, kill-on-cancel, and output-overflow kill the process tree,
// reap it, and only then throw, carrying the receipt. Cancellation observed before the
// spawn is plain OperationCanceledException, because there is nothing to kill.
public static class BoundedProcessRunner
{
    public static async Task<BoundedProcessResult> RunAsync(BoundedProcessRequest request, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (!Path.IsPathFullyQualified(request.ExecutablePath))
            throw new BoundedProcessException("executable-path-not-absolute");

        if (!File.Exists(request.ExecutablePath))
            throw new BoundedProcessException("executable-missing");

        var startInfo = new ProcessStartInfo
        {
            FileName = request.ExecutablePath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            CreateNoWindow = true,
        };
        foreach (string argument in request.Arguments)
            startInfo.ArgumentList.Add(argument);

        using var process = new Process();
        process.StartInfo = startInfo;
        try
        {
            if (!process.Start())
                throw new BoundedProcessException("start-failed");
        }
        catch (SystemException)
        {
            throw new BoundedProcessException("start-failed");
        }

        int processId = process.Id;
        process.StandardInput.Close();

        using var timeoutSource = new CancellationTokenSource(request.Timeout);
        using var killSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutSource.Token);

        // An overflow in one stream cancels the shared source so the other stream's
        // pending read unblocks; the flag keeps the classification honest afterward.
        bool overflowed = false;

        async Task<byte[]> ReadBoundedAsync(Stream stream, int maximumBytes)
        {
            var buffer = new byte[81920];
            using var collected = new MemoryStream();
            while (true)
            {
                int count = await stream.ReadAsync(buffer, killSource.Token).ConfigureAwait(false);
                if (count == 0)
                    return collected.ToArray();

                if (collected.Length + count > maximumBytes)
                {
                    overflowed = true;
                    await killSource.CancelAsync().ConfigureAwait(false);
                    throw new OperationCanceledException(killSource.Token);
                }

                collected.Write(buffer, 0, count);
            }
        }

        Task<byte[]> stdoutTask = ReadBoundedAsync(process.StandardOutput.BaseStream, request.MaximumStdOutBytes);
        Task<byte[]> stderrTask = ReadBoundedAsync(process.StandardError.BaseStream, request.MaximumStdErrBytes);

        try
        {
            byte[][] outputs = await Task.WhenAll(stdoutTask, stderrTask).ConfigureAwait(false);
            await process.WaitForExitAsync(killSource.Token).ConfigureAwait(false);

            return new BoundedProcessResult
            {
                ExitCode = process.ExitCode,
                StandardOutput = Encoding.UTF8.GetString(outputs[0]),
                StandardError = Encoding.UTF8.GetString(outputs[1]),
            };
        }
        catch (OperationCanceledException)
        {
            // Kill and reap before any throw: the receipt below names a process that
            // no longer exists by the time a caller can observe the exception. The
            // caller's own cancellation outranks the internal reasons; a recorded
            // overflow outranks the wall clock, which may expire while the kill runs.
            KillAndReap(process, processId);

            if (cancellationToken.IsCancellationRequested)
                throw new BoundedProcessException("kill-on-cancel", processId);

            if (overflowed)
                throw new BoundedProcessException("output-overflow", processId);

            if (timeoutSource.IsCancellationRequested)
                throw new BoundedProcessException("timeout", processId);

            throw;
        }
    }

    // The reap is bounded. After a successful tree kill the wait returns promptly, so
    // the bound is unreachable in normal operation; it exists so a kill that silently
    // failed surfaces as a typed reap-failed instead of wedging the caller forever
    // behind a child that will never exit. reap-failed is the one reason class whose
    // receipt names a process that may still be alive, which is exactly what it says.
    private static void KillAndReap(Process process, int processId)
    {
        try
        {
            process.Kill(entireProcessTree: true);
        }
        catch (SystemException)
        {
            // Already exited or already terminating; the wait below is the receipt
            // either way.
        }

        bool reaped;
        try
        {
            reaped = process.WaitForExit(15_000);
        }
        catch (SystemException)
        {
            reaped = true;
        }

        if (!reaped)
            throw new BoundedProcessException("reap-failed", processId);
    }
}
