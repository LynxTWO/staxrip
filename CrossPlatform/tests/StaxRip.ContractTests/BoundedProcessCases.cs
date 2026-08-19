using System.Collections.Immutable;
using System.Diagnostics;
using System.Reflection;
using StaxRip.Platform;

namespace StaxRip.ContractTests;

// Contract tests for the single bounded-execution primitive, run against this test
// binary re-invoked as a controllable child via the --bounded-child sentinel. Self as
// child keeps the corpus deterministic and dependency free: no external tool's
// behavior is under test here, only the primitive's bounds.
internal static class BoundedProcessCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-023", "argv vector round trip without a shell", ArgvVectorRoundTrip),
        new("CT-024", "exit code and stderr are results not errors", ExitCodeAndStdErr),
        new("CT-025", "output overflow kills and reaps", OutputOverflow),
        new("CT-026", "hard timeout kills and reaps", HardTimeout),
        new("CT-027", "cancellation kills and reaps", KillOnCancel),
        new("CT-028", "no path search and no spawn on rejection", NoPathSearch),
    ];

    // Generous ceiling for the killed-child cases: red when a neutralized kill leaves
    // the primitive waiting out the child's full 30 second sleep.
    private static readonly TimeSpan KilledCaseCeiling = TimeSpan.FromSeconds(15);

    private static BoundedProcessRequest ChildRequest(params string[] childArguments)
    {
        string processPath = Environment.ProcessPath
            ?? throw new InvalidOperationException("test host process path unavailable");

        var arguments = ImmutableArray.CreateBuilder<string>();
        if (Path.GetFileNameWithoutExtension(processPath).Equals("dotnet", StringComparison.OrdinalIgnoreCase))
            arguments.Add(Assembly.GetExecutingAssembly().Location);

        arguments.Add("--bounded-child");
        arguments.AddRange(childArguments);

        return new BoundedProcessRequest
        {
            ExecutablePath = processPath,
            Arguments = arguments.ToImmutable(),
            Timeout = TimeSpan.FromSeconds(60),
            MaximumStdOutBytes = 1024 * 1024,
            MaximumStdErrBytes = 64 * 1024,
        };
    }

    private static void AssertProcessGone(TestContext context, BoundedProcessException exception, string message)
    {
        context.True(exception.ReapedProcessId is not null, $"{message}: no ownership receipt");

        // The receipt names the killed child. By the time the exception is observable
        // the primitive has reaped it, so the id either names no process anymore or,
        // if the handle is still resolvable, an exited one.
        bool gone;
        try
        {
            using Process receipt = Process.GetProcessById(exception.ReapedProcessId!.Value);
            gone = receipt.HasExited;
        }
        catch (ArgumentException)
        {
            gone = true;
        }

        context.True(gone, $"{message}: receipt process still alive");
    }

    private static async Task ArgvVectorRoundTrip(TestContext context)
    {
        // Each argument is chosen to break under shell interpretation: embedded
        // spaces, a double quote, a caret, a percent pair, and a non-ascii character.
        // The vector contract says they arrive verbatim.
        string[] hostileArguments =
        [
            "alpha beta",
            "quote\"inside",
            "caret^and^more",
            "%PATH%",
            "unicode-\u00e4\u00df\u00e9",
        ];

        BoundedProcessRequest request = ChildRequest(["echo-args", .. hostileArguments]);
        BoundedProcessResult result = await BoundedProcessRunner.RunAsync(request, CancellationToken.None).ConfigureAwait(false);

        context.Equal(0, result.ExitCode, "echo child exit code");
        context.SequenceEqual(
            hostileArguments,
            result.StandardOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries).Select(static line => line.TrimEnd('\r')),
            "argv vector did not round trip verbatim");
        context.Equal(0, result.StandardError.Length, "echo child wrote to stderr");
    }

    private static async Task ExitCodeAndStdErr(TestContext context)
    {
        BoundedProcessResult exitResult = await BoundedProcessRunner.RunAsync(ChildRequest("exit", "7"), CancellationToken.None).ConfigureAwait(false);
        context.Equal(7, exitResult.ExitCode, "nonzero exit code must surface as a result");

        BoundedProcessResult stderrResult = await BoundedProcessRunner.RunAsync(ChildRequest("stderr", "100"), CancellationToken.None).ConfigureAwait(false);
        context.Equal(0, stderrResult.ExitCode, "stderr child exit code");
        context.Equal(100, stderrResult.StandardError.Length, "stderr capture length");
        context.Equal(0, stderrResult.StandardOutput.Length, "stderr child wrote to stdout");
    }

    private static async Task OutputOverflow(TestContext context)
    {
        BoundedProcessRequest request = ChildRequest("emit", "65536") with { MaximumStdOutBytes = 4096 };

        var stopwatch = Stopwatch.StartNew();
        BoundedProcessException exception = await context.ThrowsAsync<BoundedProcessException>(() => BoundedProcessRunner.RunAsync(request, CancellationToken.None), "overflow must throw typed").ConfigureAwait(false);
        stopwatch.Stop();

        context.Equal("output-overflow", exception.Message, "overflow reason class");
        AssertProcessGone(context, exception, "overflow");
        context.True(stopwatch.Elapsed < KilledCaseCeiling, "overflow was not enforced promptly");

        // The same emission under a sufficient cap completes: the bound is the cap,
        // not the emission size.
        BoundedProcessResult within = await BoundedProcessRunner.RunAsync(ChildRequest("emit", "65536"), CancellationToken.None).ConfigureAwait(false);
        context.Equal(65536, within.StandardOutput.Length, "within-cap emission length");
    }

    private static async Task HardTimeout(TestContext context)
    {
        BoundedProcessRequest request = ChildRequest("sleep") with { Timeout = TimeSpan.FromMilliseconds(500) };

        var stopwatch = Stopwatch.StartNew();
        BoundedProcessException exception = await context.ThrowsAsync<BoundedProcessException>(() => BoundedProcessRunner.RunAsync(request, CancellationToken.None), "timeout must throw typed").ConfigureAwait(false);
        stopwatch.Stop();

        context.Equal("timeout", exception.Message, "timeout reason class");
        AssertProcessGone(context, exception, "timeout");
        context.True(stopwatch.Elapsed < KilledCaseCeiling, "timeout did not kill the sleeping child");
    }

    private static async Task KillOnCancel(TestContext context)
    {
        using var cancellation = new CancellationTokenSource(TimeSpan.FromMilliseconds(200));

        var stopwatch = Stopwatch.StartNew();
        BoundedProcessException exception = await context.ThrowsAsync<BoundedProcessException>(() => BoundedProcessRunner.RunAsync(ChildRequest("sleep"), cancellation.Token), "cancellation must throw typed").ConfigureAwait(false);
        stopwatch.Stop();

        context.Equal("kill-on-cancel", exception.Message, "cancellation reason class");
        AssertProcessGone(context, exception, "cancel");
        context.True(stopwatch.Elapsed < KilledCaseCeiling, "cancellation did not kill the sleeping child");
    }

    private static async Task NoPathSearch(TestContext context)
    {
        // A bare name must be rejected before any spawn, never resolved against PATH
        // or the application directory; a null receipt is the no-spawn proof.
        BoundedProcessException bareName = await context.ThrowsAsync<BoundedProcessException>(() => BoundedProcessRunner.RunAsync(
            ChildRequest("sleep") with { ExecutablePath = "mediainfo" }, CancellationToken.None), "bare name must be rejected").ConfigureAwait(false);
        context.Equal("executable-path-not-absolute", bareName.Message, "bare name reason class");
        context.True(bareName.ReapedProcessId is null, "bare name rejection spawned a process");

        BoundedProcessException relative = await context.ThrowsAsync<BoundedProcessException>(() => BoundedProcessRunner.RunAsync(
            ChildRequest("sleep") with { ExecutablePath = Path.Combine(".", "mediainfo.exe") }, CancellationToken.None), "relative path must be rejected").ConfigureAwait(false);
        context.Equal("executable-path-not-absolute", relative.Message, "relative path reason class");

        string missing = Path.Combine(AppContext.BaseDirectory, "does-not-exist-7f3a9c.exe");
        BoundedProcessException absent = await context.ThrowsAsync<BoundedProcessException>(() => BoundedProcessRunner.RunAsync(
            ChildRequest("sleep") with { ExecutablePath = missing }, CancellationToken.None), "missing executable must be rejected").ConfigureAwait(false);
        context.Equal("executable-missing", absent.Message, "missing executable reason class");
        context.True(absent.ReapedProcessId is null, "missing executable rejection spawned a process");
    }
}

// The controllable child the cases spawn. Dispatched from Main before any test runs;
// each mode is minimal and side-effect free beyond its own streams.
internal static class BoundedChild
{
    public static int Run(string[] arguments)
    {
        // A redirected console child writes the platform codepage by default; the
        // primitive's capture contract is UTF-8, which is also what the real tool
        // emits, so the fixture declares it explicitly.
        Console.OutputEncoding = new System.Text.UTF8Encoding(encoderShouldEmitUTF8Identifier: false);

        switch (arguments[0])
        {
            case "echo-args":
                foreach (string argument in arguments.Skip(1))
                    Console.Out.Write(argument + "\n");
                return 0;

            case "emit":
                Console.Out.Write(new string('a', int.Parse(arguments[1], System.Globalization.CultureInfo.InvariantCulture)));
                return 0;

            case "stderr":
                Console.Error.Write(new string('e', int.Parse(arguments[1], System.Globalization.CultureInfo.InvariantCulture)));
                return 0;

            case "sleep":
                Thread.Sleep(TimeSpan.FromSeconds(30));
                return 0;

            case "exit":
                return int.Parse(arguments[1], System.Globalization.CultureInfo.InvariantCulture);

            default:
                Console.Error.Write("unknown bounded-child mode\n");
                return 64;
        }
    }
}
