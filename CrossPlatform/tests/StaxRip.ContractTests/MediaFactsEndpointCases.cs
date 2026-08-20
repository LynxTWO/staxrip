using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Http;
using StaxRip.Contracts;
using StaxRip.Core;
using StaxRip.Platform;
using StaxRip.Server;

namespace StaxRip.ContractTests;

// Contract tests for the configured media-facts pipeline, run in process against the
// handler with injected authorities: the rejection split, the uniform acceptance
// shape, and the typed authority failures are all provable without a child process,
// which keeps the corpus wide and cheap. The one wire-level proof with a real spawned
// tool impersonation lives in the server cases.
internal static class MediaFactsEndpointCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-037", "configured pipeline serves normalized golden facts", ConfiguredHappyPath),
        new("CT-038", "path acceptance rejections are one uniform shape", UniformAcceptanceRejection),
        new("CT-039", "malformed request bodies are request errors", MalformedRequestBodies),
        new("CT-040", "authority failures carry typed reason classes", TypedAuthorityFailures),
    ];

    private static MediaInspectionConfiguration Configuration() => new()
    {
        PathPolicy = new MediaPathPolicyOptions
        {
            MediaRoots = [FixtureFiles.PathOf("media")],
        },
        Authority = new MediaInfoCliOptions
        {
            ExecutablePath = Environment.ProcessPath
                ?? throw new InvalidOperationException("test host process path unavailable"),
        },
    };

    private static async Task<(int Status, string Body)> RunAsync(
        IMediaFactAuthority authority,
        string bodyText,
        CancellationToken cancellationToken = default)
    {
        var context = new DefaultHttpContext();
        byte[] payload = Encoding.UTF8.GetBytes(bodyText);
        context.Request.Body = new MemoryStream(payload);
        context.Request.ContentLength = payload.Length;
        context.RequestAborted = cancellationToken;
        var captured = new MemoryStream();
        context.Response.Body = captured;

        await MediaFactsHandler.HandleAsync(context, Configuration(), authority).ConfigureAwait(false);

        return (context.Response.StatusCode, Encoding.UTF8.GetString(captured.ToArray()));
    }

    private static string RequestFor(string mediaPath) =>
        JsonSerializer.Serialize(new MediaFactsRequest(mediaPath), ContractJson.Options);

    private static async Task ConfiguredHappyPath(TestContext context)
    {
        string mediaPath = FixtureFiles.PathOf(Path.Combine("media", "cfr-h264-aac.mp4"));
        var authority = new StubAuthority(FixtureFiles.Read("cfr-h264-aac.mp4.win-26.05.json"));

        (int status, string body) = await RunAsync(authority, RequestFor(mediaPath)).ConfigureAwait(false);

        context.Equal(200, status, "configured happy path status");
        context.Equal(mediaPath, authority.ProbedPath, "authority probed a different path than requested");

        MediaFactsResponse? response = JsonSerializer.Deserialize<MediaFactsResponse>(body, ContractJson.Options);
        context.True(response is not null, "payload was not deserializable");
        context.Equal("MPEG-4", response!.Container.Format, "normalized container format");
        context.Equal("26.05", response.Authority.Version, "normalized authority version");

        // Privacy through the wire: the serialized body must carry none of the
        // banned names even though the raw authority document contains them.
        foreach (string banned in MediaFactsPrivacy.BannedFieldNames)
            context.False(body.Contains(banned, StringComparison.OrdinalIgnoreCase), $"banned field crossed the wire: {banned}");
    }

    private static async Task UniformAcceptanceRejection(TestContext context)
    {
        var authority = new StubAuthority(FixtureFiles.Read("cfr-h264-aac.mp4.win-26.05.json"));
        string root = FixtureFiles.PathOf("media");
        string separator = Path.DirectorySeparatorChar.ToString();

        string[] rejectedPaths =
        [
            Path.Combine(Path.GetTempPath(), "outside-root.mkv"),
            Path.Combine(root, "absent-file-58c1f2.mkv"),
            root,
            root + separator + ".." + separator + "media" + separator + "cfr-h264-aac.mp4",
        ];

        string? uniformBody = null;
        foreach (string rejected in rejectedPaths)
        {
            (int status, string body) = await RunAsync(authority, RequestFor(rejected)).ConfigureAwait(false);
            context.Equal(422, status, "acceptance rejection status");
            uniformBody ??= body;
            context.Equal(uniformBody, body, "acceptance rejections diverged in shape");
        }

        context.True(uniformBody!.Contains("mediaRejected", StringComparison.Ordinal), "acceptance rejection code");
        context.Equal(0, authority.ProbeCount, "a rejected path reached the authority");
    }

    private static async Task MalformedRequestBodies(TestContext context)
    {
        var authority = new StubAuthority(FixtureFiles.Read("cfr-h264-aac.mp4.win-26.05.json"));

        string[] malformed =
        [
            "not json at all",
            "{\"path\":123}",
            "{}",
            "{\"path\":null}",
            "{\"path\":\"x\",\"extra\":1}",
            "[]",
        ];

        foreach (string bodyText in malformed)
        {
            (int status, string body) = await RunAsync(authority, bodyText).ConfigureAwait(false);
            context.Equal(400, status, "malformed body status: " + bodyText);
            context.True(body.Contains("invalidRequest", StringComparison.Ordinal), "malformed body code: " + bodyText);
        }

        context.Equal(0, authority.ProbeCount, "a malformed request reached the authority");
    }

    private static async Task TypedAuthorityFailures(TestContext context)
    {
        string mediaPath = FixtureFiles.PathOf(Path.Combine("media", "cfr-h264-aac.mp4"));
        string request = RequestFor(mediaPath);

        (int timeoutStatus, string timeoutBody) = await RunAsync(
            new ThrowingAuthority(new MediaFactAuthorityException("timeout")), request).ConfigureAwait(false);
        context.Equal(502, timeoutStatus, "authority timeout status");
        context.True(timeoutBody.Contains("authorityFailure", StringComparison.Ordinal), "authority timeout code");
        context.True(timeoutBody.Contains("\"timeout\"", StringComparison.Ordinal), "authority timeout reason class");

        (int malformedStatus, string malformedBody) = await RunAsync(
            new StubAuthority("this is not a json document"), request).ConfigureAwait(false);
        context.Equal(502, malformedStatus, "malformed document status");
        context.True(malformedBody.Contains("document-not-json", StringComparison.Ordinal), "malformed document reason class");

        JsonNode futureDocument = JsonNode.Parse(FixtureFiles.Read("cfr-h264-aac.mp4.win-26.05.json"))!;
        futureDocument["creatingLibrary"]!["version"] = "27.00";
        (int rangeStatus, string rangeBody) = await RunAsync(
            new StubAuthority(futureDocument.ToJsonString()), request).ConfigureAwait(false);
        context.Equal(502, rangeStatus, "version range status");
        context.True(rangeBody.Contains("version-out-of-range", StringComparison.Ordinal), "version range reason class");

        await context.ThrowsAsync<OperationCanceledException>(
            () => RunAsync(new ThrowingAuthority(new OperationCanceledException()), request),
            "cancellation must propagate, not convert").ConfigureAwait(false);
    }

    private sealed class StubAuthority : IMediaFactAuthority
    {
        private readonly string _document;

        public StubAuthority(string document)
        {
            _document = document;
        }

        public int ProbeCount { get; private set; }

        public string? ProbedPath { get; private set; }

        public string AuthorityName => "mediainfo-cli";

        public Task<MediaFactAuthorityDocument> ProbeAsync(string mediaPath, CancellationToken cancellationToken)
        {
            ProbeCount++;
            ProbedPath = mediaPath;
            return Task.FromResult(new MediaFactAuthorityDocument(AuthorityName, _document));
        }
    }

    private sealed class ThrowingAuthority : IMediaFactAuthority
    {
        private readonly Exception _exception;

        public ThrowingAuthority(Exception exception)
        {
            _exception = exception;
        }

        public string AuthorityName => "mediainfo-cli";

        public Task<MediaFactAuthorityDocument> ProbeAsync(string mediaPath, CancellationToken cancellationToken) =>
            Task.FromException<MediaFactAuthorityDocument>(_exception);
    }
}
