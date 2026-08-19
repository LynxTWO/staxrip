using StaxRip.Platform;

namespace StaxRip.ContractTests;

// Contract tests for the regular-file probe, driven by the committed fixture tree so
// nothing is created or deleted: the media fixture is the existing ordinary file, the
// fixture directory is the directory, and a name that cannot exist under the manifest
// root is the absence. The reparse refusal has no producible fixture here and is
// proven by the port-inspection gate, which records that split.
internal static class MediaFileProbeCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-036", "file probe admits only existing ordinary files", RegularFilesOnly),
    ];

    private static void RegularFilesOnly(TestContext context)
    {
        context.True(
            MediaFileProbe.IsRegularFile(FixtureFiles.PathOf(Path.Combine("media", "cfr-h264-aac.mp4"))),
            "committed media fixture must be a regular file");
        context.True(
            MediaFileProbe.IsRegularFile(FixtureFiles.PathOf("cfr-h264-aac.mp4.win-26.05.json")),
            "committed golden document must be a regular file");

        context.False(
            MediaFileProbe.IsRegularFile(FixtureFiles.PathOf("media")),
            "a directory must not probe as a regular file");
        context.False(
            MediaFileProbe.IsRegularFile(FixtureFiles.PathOf("absent-fixture-91c4d7.mkv")),
            "an absent path must not probe as a regular file");
        context.False(
            MediaFileProbe.IsRegularFile(FixtureFiles.PathOf(Path.Combine("media", "cfr-h264-aac.mp4", "impossible-child.mkv"))),
            "a path through a file must not probe as a regular file");
    }
}
