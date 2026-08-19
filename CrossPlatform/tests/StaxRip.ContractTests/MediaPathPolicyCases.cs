using StaxRip.Core;

namespace StaxRip.ContractTests;

// Contract tests for the D-046 path policy. The policy is pure string judgment, so the
// corpus needs no filesystem and no fixtures: the admissible path below never has to
// exist, which is itself the no-oracle property under test.
internal static class MediaPathPolicyCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-034", "path policy admits canonical contained paths", AdmitsCanonicalContained),
        new("CT-035", "path policy rejects every hostile shape uniformly", RejectsHostileShapes),
    ];

    private static readonly string Root = OperatingSystem.IsWindows()
        ? @"C:\media-library"
        : "/srv/media-library";

    private static MediaPathPolicyOptions Options() => new()
    {
        MediaRoots = [Root],
    };

    private static void AdmitsCanonicalContained(TestContext context)
    {
        context.True(
            MediaPathPolicy.IsAdmissible(Options(), Path.Combine(Root, "film.mkv")),
            "canonical path directly under the root must be admissible");
        context.True(
            MediaPathPolicy.IsAdmissible(Options(), Path.Combine(Root, "season one", "episode.mkv")),
            "canonical path in a subdirectory must be admissible");

        // Containment means inside a root, never the root itself: probing the root
        // directory is not media inspection.
        context.False(
            MediaPathPolicy.IsAdmissible(Options(), Root),
            "the root itself is not an admissible media path");
    }

    private static void RejectsHostileShapes(TestContext context)
    {
        MediaPathPolicyOptions options = Options();
        string separator = Path.DirectorySeparatorChar.ToString();

        // The default policy admits nothing at all.
        context.False(
            MediaPathPolicy.IsAdmissible(new MediaPathPolicyOptions(), Path.Combine(Root, "film.mkv")),
            "the empty default policy admitted a path");

        string[] hostile =
        [
            "",
            "   ",
            "film.mkv",
            Path.Combine("relative", "film.mkv"),
            Root + separator + ".." + separator + "escape.mkv",
            Root + separator + "a" + separator + ".." + separator + "b.mkv",
            Root + separator + "." + separator + "film.mkv",
            Root + separator + separator + "film.mkv",
            Path.Combine(Root, "film.mkv") + separator,
            Path.Combine(Root, "film.mkv") + ":stream",
            @"\\server\share\film.mkv",
            @"\\?\" + Root + separator + "film.mkv",
            @"\\.\PhysicalDrive0",
            Path.Combine(Root, "film.mkv") + "\u0000tail",
            Path.Combine(Root, "film\u0007.mkv"),
            OperatingSystem.IsWindows() ? @"D:\other-root\film.mkv" : "/srv/other-root/film.mkv",
            Path.Combine(Root + "-sibling", "film.mkv"),
            Path.Combine(Root, new string('a', 5000) + ".mkv"),
        ];

        foreach (string path in hostile)
        {
            context.False(
                MediaPathPolicy.IsAdmissible(options, path),
                "hostile shape was admitted: index " + Array.IndexOf(hostile, path).ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
    }
}
