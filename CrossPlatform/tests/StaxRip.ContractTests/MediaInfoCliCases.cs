using StaxRip.Core;
using StaxRip.Platform;

namespace StaxRip.ContractTests;

// Contract tests for the MediaInfo CLI adapter, run hermetically: the configured
// executable is this test binary, which impersonates the tool when invoked with the
// recorded flag. The real tool never runs here; the adapter's invocation shape and
// outcome mapping are what these cases prove, and the port-inspection gate owns the
// real-tool integration a level above. The impersonation requires the apphost: these
// cases assume the harness runs the built executable, not a dll under a shared host.
internal static class MediaInfoCliCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-029", "adapter golden document pass through", GoldenPassThrough),
        new("CT-030", "adapter nonzero exit is typed and sanitized", NonzeroExit),
        new("CT-031", "adapter timeout is typed", Timeout),
        new("CT-032", "adapter cancellation is cancellation not error", Cancellation),
        new("CT-033", "adapter resolver failure before any execution", ResolverFailure),
    ];

    private static MediaInfoCliOptions Options() => new()
    {
        ExecutablePath = Environment.ProcessPath
            ?? throw new InvalidOperationException("test host process path unavailable"),
    };

    private static async Task GoldenPassThrough(TestContext context)
    {
        var authority = new MediaInfoCliAuthority(Options());
        context.Equal("mediainfo-cli", authority.AuthorityName, "authority identity drift");

        // The fake accepts only the recorded invocation, one flag and one path, so a
        // drifted flag or an extra argument fails this case through the fake's
        // rejection exit code.
        string goldenPath = FixtureFiles.PathOf("cfr-h264-aac.mp4.win-26.05.json");
        MediaFactAuthorityDocument document = await authority.ProbeAsync(goldenPath, CancellationToken.None).ConfigureAwait(false);

        context.Equal("mediainfo-cli", document.AuthorityName, "document authority identity");
        context.Equal(FixtureFiles.Read("cfr-h264-aac.mp4.win-26.05.json"), document.RawJson, "document bytes did not pass through verbatim");

        // The adapter output must feed the existing normalization pipeline unchanged.
        MediaFactsResponseAsserts(context, document.RawJson);
    }

    private static void MediaFactsResponseAsserts(TestContext context, string rawJson)
    {
        var response = MediaFactsNormalizer.Normalize(rawJson);
        context.Equal("MPEG-4", response.Container.Format, "normalized container format");
        context.Equal("26.05", response.Authority.Version, "normalized authority version");
    }

    private static async Task NonzeroExit(TestContext context)
    {
        var authority = new MediaInfoCliAuthority(Options());
        MediaFactAuthorityException exception = await context.ThrowsAsync<MediaFactAuthorityException>(
            () => authority.ProbeAsync(FakeMediaInfo.ExitSevenMarker, CancellationToken.None),
            "nonzero exit must throw typed").ConfigureAwait(false);

        // Exact equality is the sanitization proof: the fake wrote detail to its error
        // stream and the reason class is all that may surface.
        context.Equal("nonzero-exit", exception.Message, "nonzero exit reason class");
    }

    private static async Task Timeout(TestContext context)
    {
        var authority = new MediaInfoCliAuthority(Options() with { ProbeTimeout = TimeSpan.FromMilliseconds(500) });
        MediaFactAuthorityException exception = await context.ThrowsAsync<MediaFactAuthorityException>(
            () => authority.ProbeAsync(FakeMediaInfo.SleepMarker, CancellationToken.None),
            "timeout must throw typed").ConfigureAwait(false);

        context.Equal("timeout", exception.Message, "timeout reason class");
    }

    private static async Task Cancellation(TestContext context)
    {
        var authority = new MediaInfoCliAuthority(Options());
        using var cancellation = new CancellationTokenSource(TimeSpan.FromMilliseconds(200));

        await context.ThrowsAsync<OperationCanceledException>(
            () => authority.ProbeAsync(FakeMediaInfo.SleepMarker, cancellation.Token),
            "cancellation must surface as cancellation").ConfigureAwait(false);
    }

    private static async Task ResolverFailure(TestContext context)
    {
        var missing = new MediaInfoCliAuthority(Options() with
        {
            ExecutablePath = Path.Combine(AppContext.BaseDirectory, "mediainfo-absent-3e51b2.exe"),
        });
        MediaFactAuthorityException absent = await context.ThrowsAsync<MediaFactAuthorityException>(
            () => missing.ProbeAsync(FakeMediaInfo.SleepMarker, CancellationToken.None),
            "missing tool must throw typed").ConfigureAwait(false);
        context.Equal("resolver-failure", absent.Message, "missing tool reason class");

        var bare = new MediaInfoCliAuthority(Options() with { ExecutablePath = "mediainfo" });
        MediaFactAuthorityException unqualified = await context.ThrowsAsync<MediaFactAuthorityException>(
            () => bare.ProbeAsync(FakeMediaInfo.SleepMarker, CancellationToken.None),
            "bare tool name must throw typed").ConfigureAwait(false);
        context.Equal("resolver-failure", unqualified.Message, "bare tool name reason class");
    }
}

// The tool impersonation this binary performs when spawned with the recorded flag as
// its first argument. Exactly two arguments are accepted; anything else is rejected
// with a diagnostic exit, which is what makes the adapter's invocation shape load
// bearing in CT-029. Behavior is selected by the path argument: an existing document
// is emitted verbatim, and the markers drive the failure cases without touching the
// filesystem.
internal static class FakeMediaInfo
{
    public const string SleepMarker = "#probe-sleep";
    public const string ExitSevenMarker = "#probe-exit-seven";

    public static int Run(string[] arguments)
    {
        Console.OutputEncoding = new System.Text.UTF8Encoding(encoderShouldEmitUTF8Identifier: false);

        if (arguments.Length != 2 || arguments[0] != "--Output=JSON")
        {
            Console.Error.Write("unexpected invocation shape\n");
            return 64;
        }

        switch (arguments[1])
        {
            case SleepMarker:
                Thread.Sleep(TimeSpan.FromSeconds(30));
                return 0;

            case ExitSevenMarker:
                Console.Error.Write("synthetic failure detail that must never surface\n");
                return 7;

            default:
                // A .json path is emitted verbatim, which is the adapter cases'
                // direct pass-through. A media path answers with its sibling golden
                // from the fixture root, which is how the wire-level pipeline case
                // probes a real committed media file through a real child process.
                string probed = arguments[1];
                if (!probed.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                {
                    string? mediaDirectory = Path.GetDirectoryName(probed);
                    string? fixtureRoot = mediaDirectory is null ? null : Path.GetDirectoryName(mediaDirectory);
                    probed = fixtureRoot is null
                        ? probed
                        : Path.Combine(fixtureRoot, Path.GetFileName(probed) + ".win-26.05.json");
                }

                if (!File.Exists(probed))
                {
                    Console.Error.Write("document not found\n");
                    return 65;
                }

                Console.Out.Write(File.ReadAllText(probed));
                return 0;
        }
    }
}
