using System.Text.Json;
using System.Text.Json.Nodes;
using StaxRip.Contracts;
using StaxRip.Core;

namespace StaxRip.ContractTests;

internal static class MediaFactsCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-015", "media facts schema and serialization shape", SchemaAndShape),
        new("CT-016", "golden normalization avc aac", GoldenAvcAac),
        new("CT-017", "golden normalization ffv1 pcm", GoldenFfv1Pcm),
        new("CT-018", "golden normalization vp9 opus absences", GoldenVp9Opus),
        new("CT-019", "golden vfr absence has no silent default", GoldenVfrAbsence),
        new("CT-020", "privacy guard strips every banned field", PrivacyGuard),
        new("CT-021", "canonical mappings are load bearing", CanonicalMappings),
        new("CT-022", "malformed documents fail typed", MalformedDocuments),
        new("CT-041", "golden chapters mp4 two menus and grammar filter", GoldenChaptersMp4),
        new("CT-042", "golden chapters and subtitle facts mkv", GoldenSubtitlesMkv),
        new("CT-043", "subtitle stream size presence and absence", SubtitleStreamSizePair),
        new("CT-044", "path-shaped values never reach the payload", PathShapedValueGuard),
        new("CT-045", "subtitle disposition carrier is range unstable", SubtitleDispositionRangeTripwire),
    ];

    // Both range ends of a fixture, from the committed goldens. The range stability the
    // tool matrix records is asserted here every run: the exposed payload must be
    // identical from both documents, authority version aside.
    private static (MediaFactsResponse Floor, MediaFactsResponse Ceiling) NormalizePair(string fixtureName)
    {
        MediaFactsResponse floor = MediaFactsNormalizer.Normalize(FixtureFiles.Read($"{fixtureName}.wsl-24.01.json"));
        MediaFactsResponse ceiling = MediaFactsNormalizer.Normalize(FixtureFiles.Read($"{fixtureName}.win-26.05.json"));
        return (floor, ceiling);
    }

    private static void AssertRangeStable(TestContext context, MediaFactsResponse floor, MediaFactsResponse ceiling)
    {
        context.Equal("24.01", floor.Authority.Version, "floor authority version drift");
        context.Equal("26.05", ceiling.Authority.Version, "ceiling authority version drift");

        // Compared per section, not as one record: record equality over immutable-array
        // members is reference equality of the backing array, so a whole-payload Equal
        // could never pass and would hide real agreement. SequenceEqual compares the
        // element records by value, which is the comparison the range claim needs.
        context.Equal(floor.Container, ceiling.Container, "container facts differ between range ends");
        context.SequenceEqual(floor.Video, ceiling.Video, "video facts differ between range ends");
        context.SequenceEqual(floor.Audio, ceiling.Audio, "audio facts differ between range ends");
        context.SequenceEqual(floor.Text, ceiling.Text, "text facts differ between range ends");
        context.SequenceEqual(floor.Chapters, ceiling.Chapters, "chapter facts differ between range ends");
    }

    private static void SchemaAndShape(TestContext context)
    {
        context.Equal("staxrip-media-facts-v1", MediaFactsContract.SchemaId, "schema id drift");

        (MediaFactsResponse response, _) = NormalizePair("cfr-h264-aac.mp4");
        string json = JsonSerializer.Serialize(response, ContractJson.Options);
        using JsonDocument document = JsonDocument.Parse(json);

        context.SequenceEqual(
            ["schema", "authority", "container", "video", "audio", "text", "chapters"],
            document.RootElement.EnumerateObject().Select(static member => member.Name),
            "payload top-level keys changed");
        context.Equal(
            MediaFactsContract.SchemaId,
            document.RootElement.GetProperty("schema").GetString(),
            "payload schema value changed");
        context.Equal("MediaInfoLib", response.Authority.Name, "authority name drift");

        // Absence is omission: this fixture has no HDR facts, so no HDR member may
        // appear anywhere in the serialized video object.
        string videoJson = document.RootElement.GetProperty("video")[0].GetRawText();
        context.False(videoJson.Contains("masteringDisplay", StringComparison.OrdinalIgnoreCase), "absent mastering facts serialized");
        context.False(videoJson.Contains("maxCll", StringComparison.OrdinalIgnoreCase), "absent light-level facts serialized");
        context.False(json.Contains("null", StringComparison.Ordinal), "a null was serialized where omission is required");
    }

    private static void GoldenAvcAac(TestContext context)
    {
        (MediaFactsResponse floor, MediaFactsResponse ceiling) = NormalizePair("cfr-h264-aac.mp4");
        AssertRangeStable(context, floor, ceiling);

        MediaContainerFacts container = ceiling.Container;
        context.Equal("MPEG-4", container.Format, "container format");
        context.Equal(215647L, container.FileSizeBytes, "container size");
        context.Equal(2.000, container.DurationSeconds, "container duration");

        context.Equal(1, ceiling.Video.Length, "video stream count");
        MediaVideoFacts video = ceiling.Video[0];
        context.Equal("AVC", video.Format, "video format");
        context.Equal("Constrained Baseline", video.FormatProfile, "video profile");
        context.Equal(320, video.Width, "width");
        context.Equal(180, video.Height, "height");
        context.Equal("1.000", video.PixelAspectRatio, "pixel aspect ratio");
        context.Equal("1.778", video.DisplayAspectRatio, "display aspect ratio");
        context.Equal("23.976", video.FrameRate, "frame rate raw");
        context.Equal(23.976, video.FrameRateValue, "frame rate value");
        context.Equal("CFR", video.FrameRateMode, "frame rate mode");
        context.Equal(47L, video.FrameCount, "frame count");
        context.Equal(8, video.BitDepth, "bit depth");
        context.Equal("4:2:0", video.ChromaSubsampling, "chroma subsampling");
        context.Equal("YUV", video.ColorSpace, "color space");
        context.Equal("Progressive", video.ScanType, "scan type");
        context.Equal(771028L, video.BitRateBits, "video bitrate");
        context.Equal(188930L, video.StreamSizeBytes, "video stream size");

        context.Equal(1, ceiling.Audio.Length, "audio stream count");
        MediaAudioFacts audio = ceiling.Audio[0];
        context.Equal("AAC", audio.Format, "audio format");
        context.Equal(1, audio.Channels, "channels");
        context.Equal("M", audio.ChannelLayout, "channel layout");
        context.Equal(48000, audio.SamplingRateHz, "sampling rate");
        context.Equal(96000L, audio.BitRateBits, "audio bitrate");
        context.Equal("Lossy", audio.CompressionMode, "compression mode");
        context.Equal(true, audio.Default, "audio default flag");
        context.True(audio.BitDepth is null, "aac bit depth must be absent, not defaulted");
        context.True(audio.VideoDelay is null, "mp4 audio delay must be absent, not defaulted");
        context.True(audio.VideoDelaySeconds is null, "mp4 audio delay seconds must be absent, not defaulted");

        context.Equal(0, ceiling.Text.Length, "text stream count");
    }

    private static void GoldenFfv1Pcm(TestContext context)
    {
        (MediaFactsResponse floor, MediaFactsResponse ceiling) = NormalizePair("cfr-ffv1-10bit-pcm.mkv");
        AssertRangeStable(context, floor, ceiling);

        context.Equal("Matroska", ceiling.Container.Format, "container format");
        MediaVideoFacts video = ceiling.Video[0];
        context.Equal("FFV1", video.Format, "video format");
        context.True(video.FormatProfile is null, "ffv1 profile must be absent");
        context.Equal(10, video.BitDepth, "ten bit depth");
        context.Equal("4:4:4", video.ChromaSubsampling, "chroma subsampling");
        context.Equal("25.000", video.FrameRate, "frame rate raw");
        context.Equal(25.000, video.FrameRateValue, "frame rate value");

        // The canonical range mapping over a real captured value.
        context.Equal(new MediaFactValue("limited", "Limited"), video.ColourRange, "canonical colour range");

        MediaAudioFacts audio = ceiling.Audio[0];
        context.Equal("PCM", audio.Format, "audio format");
        context.Equal(24, audio.BitDepth, "pcm bit depth");
        context.Equal(1152000L, audio.BitRateBits, "pcm bitrate");
        context.Equal(false, audio.Default, "audio default flag");
        context.Equal(false, audio.Forced, "audio forced flag");
        context.Equal("0.000", audio.VideoDelay, "audio delay raw");
        context.Equal(0.0, audio.VideoDelaySeconds, "audio delay seconds");
    }

    private static void GoldenVp9Opus(TestContext context)
    {
        (MediaFactsResponse floor, MediaFactsResponse ceiling) = NormalizePair("cfr-vp9-opus.webm");
        AssertRangeStable(context, floor, ceiling);

        context.Equal("WebM", ceiling.Container.Format, "container format");
        MediaVideoFacts video = ceiling.Video[0];
        context.Equal("VP9", video.Format, "video format");
        context.Equal("0", video.FormatProfile, "vp9 profile zero survives as a value");
        context.True(video.ColorSpace is null, "vp9 color space must be absent");
        context.True(video.ScanType is null, "vp9 scan type must be absent");
        context.True(video.BitRateBits is null, "vp9 stream bitrate must be absent");

        MediaAudioFacts audio = ceiling.Audio[0];
        context.Equal("Opus", audio.Format, "audio format");
        context.True(audio.BitRateBits is null, "opus bitrate must be absent, not defaulted");
        context.Equal(16, audio.BitDepth, "opus bit depth");
        context.Equal("0.000", audio.VideoDelay, "audio delay raw");
        context.Equal(0.0, audio.VideoDelaySeconds, "audio delay seconds");
    }

    private static void GoldenVfrAbsence(TestContext context)
    {
        (MediaFactsResponse floor, MediaFactsResponse ceiling) = NormalizePair("vfr-ffv1.mkv");
        AssertRangeStable(context, floor, ceiling);

        MediaVideoFacts video = ceiling.Video[0];

        // The load-bearing absence rule. The current Windows wrapper reports 25 for this
        // exact file through its fallback ladder; this payload must expose absence.
        // These assertions are the mutation target for the silent-default proof.
        context.True(video.FrameRate is null, "vfr frame rate must be absent");
        context.True(video.FrameRateValue is null, "vfr frame rate value must be absent, never a default");
        context.True(video.FrameCount is null, "vfr frame count must be absent");
        context.Equal("VFR", video.FrameRateMode, "frame rate mode");

        context.Equal(0, ceiling.Audio.Length, "no audio stream");
        context.Equal("2.966", ceiling.Container.Duration, "container duration raw");
        context.Equal(160, video.Width, "width");
        context.Equal(120, video.Height, "height");
        context.Equal("1.333", video.DisplayAspectRatio, "display aspect ratio");
    }

    // A synthetic authority document carrying every banned field, a text track, and
    // canonical color values the fixture corpus cannot supply. Synthetic input is the
    // sanctioned vehicle for cases real captures cannot produce; it never stands in for
    // a fact a golden could assert.
    private const string SyntheticDocument = """
        {
          "creatingLibrary": { "name": "MediaInfoLib", "version": "26.05", "url": "https://mediaarea.net/MediaInfo" },
          "media": {
            "@ref": "synthetic.mkv",
            "track": [
              {
                "@type": "General",
                "Format": "Matroska",
                "FileSize": "1000",
                "Duration": "1.000",
                "UniqueID": "123456789012345678901234567890",
                "UniqueID/String": "123456789012345678901234567890 (0xABCDEF)",
                "Encoded_Application": "synthetic-writer 1.0",
                "Encoded_Application_Name": "synthetic-writer",
                "Encoded_Application_Version": "1.0 (build 12345) 64-bit",
                "File_Created_Date": "2026-08-19 00:00:00 UTC",
                "File_Created_Date_Local": "2026-08-19 00:00:00",
                "File_Modified_Date": "2026-08-19 00:00:00 UTC",
                "File_Modified_Date_Local": "2026-08-19 00:00:00",
                "CompleteName": "synthetic.mkv",
                "FolderName": "somewhere",
                "Title": "C:\\Users\\someone\\Videos\\holiday.mkv",
                "extra": { "UniqueID_Source": "container" }
              },
              {
                "@type": "Video",
                "Format": "HEVC",
                "Width": "3840",
                "Height": "2160",
                "colour_range": "Full",
                "colour_primaries": "BT.2020",
                "transfer_characteristics": "PQ",
                "matrix_coefficients": "BT.2020 non-constant",
                "ChromaSubsampling_Position": "Type 2",
                "MasteringDisplay_ColorPrimaries": "Display P3",
                "MasteringDisplay_Luminance": "min: 0.0050 cd/m2, max: 1000 cd/m2",
                "MaxCLL": "1000 cd/m2",
                "MaxFALL": "400 cd/m2",
                "HDR_Format": "SMPTE ST 2086",
                "HDR_Format_Commercial": "HDR10",
                "Encoded_Library_Settings": "cpuid=1111 / rc=crf"
              },
              {
                "@type": "Text",
                "Format": "UTF-8",
                "Language": "en",
                "Title": "/home/someone/subs/final draft.srt",
                "Default": "Yes",
                "Forced": "No"
              },
              {
                "@type": "Menu",
                "extra": {
                  "_00_00_00_000": "Opening",
                  "_00_00_01_000": "\\\\server\\share\\notes.txt",
                  "_00_00_02_000": "Act Two: 24/7 Coverage"
                }
              }
            ]
          }
        }
        """;

    private static void GoldenChaptersMp4(TestContext context)
    {
        (MediaFactsResponse floor, MediaFactsResponse ceiling) = NormalizePair("cfr-h264-aac-chapters.mp4");
        AssertRangeStable(context, floor, ceiling);

        // This container reports one chapter list through two menu tracks. Both are
        // exposed with their own menu index rather than one being chosen, because
        // choosing would be a silent rule the payload cannot justify.
        context.Equal(4, ceiling.Chapters.Length, "chapter entry count across both menus");
        context.SequenceEqual([0, 0, 1, 1], ceiling.Chapters.Select(static chapter => chapter.MenuIndex), "menu indexes");
        context.SequenceEqual([0, 1, 0, 1], ceiling.Chapters.Select(static chapter => chapter.Index), "chapter indexes within menus");

        MediaChapterFacts first = ceiling.Chapters[0];
        context.Equal("00:00:00.000", first.Timecode, "first chapter timecode raw");
        context.Equal(0L, first.TimecodeMilliseconds, "first chapter timecode milliseconds");
        context.Equal("Cold Open", first.Label, "first chapter label");

        // The label carries the separator that a language-prefix parser would split on.
        // Exposing it verbatim is the rule; this assertion is its proof.
        MediaChapterFacts second = ceiling.Chapters[1];
        context.Equal("00:00:01.000", second.Timecode, "second chapter timecode raw");
        context.Equal(1000L, second.TimecodeMilliseconds, "second chapter timecode milliseconds");
        context.Equal("Act One: The Setup", second.Label, "second chapter label survives verbatim");

        // The authority's menu block also carries members that are not chapters. A
        // reader that swept the block instead of matching the timecode grammar would
        // invent them as entries, so their absence is asserted by name.
        context.False(
            ceiling.Chapters.Any(static chapter => chapter.Label is "1,2,3" || chapter.Timecode is "Menu_For"),
            "a non-chapter menu member was exposed as a chapter");
    }

    private static void GoldenSubtitlesMkv(TestContext context)
    {
        (MediaFactsResponse floor, MediaFactsResponse ceiling) = NormalizePair("cfr-h264-aac-subtitles.mkv");
        AssertRangeStable(context, floor, ceiling);

        context.Equal(2, ceiling.Chapters.Length, "matroska chapter entry count");
        context.SequenceEqual([0, 0], ceiling.Chapters.Select(static chapter => chapter.MenuIndex), "single menu index");
        context.Equal("Act One: The Setup", ceiling.Chapters[1].Label, "matroska chapter label survives verbatim");

        context.Equal(2, ceiling.Text.Length, "subtitle track count");
        MediaTextFacts sdh = ceiling.Text[0];
        context.Equal("UTF-8", sdh.Format, "subtitle format");
        context.Equal("English SDH", sdh.Title, "subtitle title");
        context.Equal("en", sdh.Language, "subtitle language");
        context.Equal(true, sdh.Default, "subtitle default flag");
        context.Equal(false, sdh.Forced, "subtitle forced flag");

        MediaTextFacts commentary = ceiling.Text[1];
        context.Equal("Director Commentary", commentary.Title, "commentary title");
        context.Equal(false, commentary.Default, "commentary default flag");
    }

    private static void SubtitleStreamSizePair(TestContext context)
    {
        // The presence and absence legs of one fact, both golden-backed and both
        // range-stable: an authority that measures the subtitle stream reports it, one
        // that does not omits it, and omission stays omission rather than becoming zero.
        (_, MediaFactsResponse mp4) = NormalizePair("cfr-h264-aac-chapters.mp4");
        context.Equal(1, mp4.Text.Length, "mp4 subtitle track count");
        context.Equal(42L, mp4.Text[0].StreamSizeBytes, "mp4 subtitle stream size present");

        (MediaFactsResponse mkvFloor, MediaFactsResponse mkvCeiling) = NormalizePair("cfr-h264-aac-subtitles.mkv");
        context.True(mkvCeiling.Text[0].StreamSizeBytes is null, "matroska subtitle stream size must be absent, not defaulted");
        context.True(mkvCeiling.Text[1].StreamSizeBytes is null, "matroska commentary stream size must be absent, not defaulted");
        context.True(mkvFloor.Text[0].StreamSizeBytes is null, "matroska subtitle stream size absent at the range floor too");
    }

    private static void PathShapedValueGuard(TestContext context)
    {
        // The contract's second privacy rule, beside the banned-name rule: no field may
        // carry an absolute filesystem path. Names cannot enforce this, because the
        // fields at risk are author-controlled free text, so the guard judges values.
        MediaFactsResponse response = MediaFactsNormalizer.Normalize(SyntheticDocument);
        string payload = JsonSerializer.Serialize(response, ContractJson.Options);

        foreach (string fragment in new[] { "C:\\\\Users", "someone", "/home/", "\\\\\\\\server", "notes.txt", "holiday.mkv" })
            context.False(payload.Contains(fragment, StringComparison.OrdinalIgnoreCase), $"a path-shaped value reached the payload: {fragment}");

        // The three carriers the synthetic document poisons are absent rather than
        // emptied, because a redacted placeholder would be a fact the media does not
        // contain.
        context.True(response.Container.Title is null, "container title carrying a windows path must be absent");
        context.True(response.Text[0].Title is null, "subtitle title carrying a posix path must be absent");
        context.Equal(2, response.Chapters.Length, "the chapter carrying a UNC path must be dropped, the other two kept");

        // False positives are the real risk of a value rule, so a legitimate label that
        // merely contains separators is asserted to survive intact.
        context.Equal("Opening", response.Chapters[0].Label, "plain chapter label survives");
        context.Equal("Act Two: 24/7 Coverage", response.Chapters[1].Label, "a label with a colon and a slash is not a path and survives");

        // The rule itself, exercised directly at its boundary: the D-059 ratified
        // adversarial table. Every row below was signed off before the matcher was
        // written to it; a change to the law adds a row here first.
        foreach (string pathLike in new[]
        {
            "C:\\Users\\me\\a.mkv",
            "c:/media/file.mp4",
            "D:/media/clip.mp4",
            "Encoded at D:\\renders\\x",
            "/etc/passwd",
            "/home/alice/file.mkv",
            "source=/home/alice/file",
            "file:/home/alice/file",
            "path is /mnt/media/movies/x.mkv",
            "file:///home/user/x",
            "on /home/alice",
            "\\\\host\\share\\x",
            "\\\\server\\share\\file.mkv",
            "//host/share/x",
            "//server/share/file.mkv",
            "see \\\\nas01\\videos",
            "see /a/b/c prose",
        })
        {
            context.True(MediaFactsPrivacy.HasEmbeddedPath(pathLike), $"path shape not recognized: {pathLike}");
        }

        foreach (string ordinary in new[]
        {
            "Act One: The Setup",
            "24/7 Coverage",
            "S01E02",
            "ratio 16:9",
            "AC-3 5.1",
            "",
            "https://example.com/watch",
            "24//7 support",
            "A/V sync",
            "16/9",
            "und/eng",
            "w/ commentary",
            "Movie: The Return / Part 2",
            "/private",
            "/dev",
            "AC/DC - Back in Black",
            "x264 - core 164 r3095",
            "MPEG4:\\profile",
            "path%2Fhome%2Fuser",
            "see /docs/readme",
            "/r/movies",
            "posted in /r/movies today",
        })
        {
            context.False(MediaFactsPrivacy.HasEmbeddedPath(ordinary), $"ordinary text misread as a path: {ordinary}");
        }
    }

    private static void SubtitleDispositionRangeTripwire(TestContext context)
    {
        // D-048 defers the commentary and hearing-impaired facts because their carrier
        // exists at the range ceiling and not at the floor. This case makes that
        // deferral falsifiable instead of merely written down: it asserts the
        // instability directly from the committed goldens, so the day a moved floor
        // reports the carrier, this case goes red and sends the reader to the decision
        // rather than letting a stale exclusion sit unnoticed.
        JsonNode ceiling = JsonNode.Parse(FixtureFiles.Read("cfr-h264-aac-subtitles.mkv.win-26.05.json"))!;
        JsonNode floor = JsonNode.Parse(FixtureFiles.Read("cfr-h264-aac-subtitles.mkv.wsl-24.01.json"))!;

        context.True(CarriesServiceKind(ceiling), "the range ceiling must still report the subtitle disposition carrier");
        context.False(CarriesServiceKind(floor), "the range floor now reports the disposition carrier: revisit D-048 before exposing the facts");

        // And the payload exposes neither fact while the deferral stands. Asserted on
        // member names, not on a substring of the document: this fixture's own
        // subtitle is legitimately titled "Director Commentary", and a loose scan
        // reports that real title as a leaked fact.
        string payload = JsonSerializer.Serialize(
            MediaFactsNormalizer.Normalize(FixtureFiles.Read("cfr-h264-aac-subtitles.mkv.win-26.05.json")),
            ContractJson.Options);
        foreach (string member in new[] { "\"commentary\":", "\"hearingImpaired\":", "\"serviceKind\":" })
            context.False(payload.Contains(member, StringComparison.OrdinalIgnoreCase), $"a deferred disposition member reached the payload: {member}");

        // The legitimate title is asserted present, so the tightened check above cannot
        // be satisfied by the title having gone missing.
        context.Equal("Director Commentary", MediaFactsNormalizer
            .Normalize(FixtureFiles.Read("cfr-h264-aac-subtitles.mkv.win-26.05.json")).Text[1].Title,
            "the legitimate subtitle title must survive");
    }

    private static bool CarriesServiceKind(JsonNode document) =>
        document["media"]?["track"] is JsonArray tracks &&
        tracks.Any(track => track is JsonObject item &&
            item["@type"] is JsonValue type &&
            type.TryGetValue(out string? typeName) &&
            typeName == "Text" &&
            item["ServiceKind"] is not null);

    private static void PrivacyGuard(TestContext context)
    {
        // The guard itself, on a document containing every banned name.
        JsonNode root = JsonNode.Parse(SyntheticDocument) ?? throw new TestFailureException("synthetic parse", "node", "<null>");
        MediaFactsPrivacy.StripBannedFields(root);
        string stripped = root.ToJsonString();

        foreach (string banned in MediaFactsPrivacy.BannedFieldNames)
            context.False(stripped.Contains($"\"{banned}\"", StringComparison.Ordinal), $"banned field survived the guard: {banned}");
        context.False(stripped.Contains("UniqueID", StringComparison.Ordinal), "a UniqueID variant survived the guard");

        // Variant coverage, from a measured range-ceiling capture: an authority that
        // reports a writing application also reports it split across a name and a
        // version field, and an exact-name ban misses both. Every banned family is
        // therefore a prefix, proven here on the same shapes the ceiling emits.
        foreach (string variant in new[]
        {
            "Encoded_Application_Name",
            "Encoded_Application_Version",
            "File_Created_Date_Local",
            "File_Modified_Date_Local",
        })
        {
            context.False(stripped.Contains($"\"{variant}\"", StringComparison.Ordinal), $"banned-family variant survived the guard: {variant}");
        }

        // The normalized payload end to end: no banned name may appear in what leaves.
        string payload = JsonSerializer.Serialize(MediaFactsNormalizer.Normalize(SyntheticDocument), ContractJson.Options);
        foreach (string banned in MediaFactsPrivacy.BannedFieldNames)
            context.False(payload.Contains(banned, StringComparison.OrdinalIgnoreCase), $"banned field reached the payload: {banned}");
        context.False(payload.Contains("uniqueId", StringComparison.OrdinalIgnoreCase), "an identifier reached the payload");

        // And the same claim over every committed golden.
        foreach (string fixture in FixtureFiles.GoldenNames)
        {
            string goldenPayload = JsonSerializer.Serialize(
                MediaFactsNormalizer.Normalize(FixtureFiles.Read(fixture)),
                ContractJson.Options);
            context.False(goldenPayload.Contains("uniqueId", StringComparison.OrdinalIgnoreCase), $"identifier leaked from {fixture}");
            context.False(goldenPayload.Contains("File_Created", StringComparison.OrdinalIgnoreCase), $"file date leaked from {fixture}");
        }
    }

    private static void CanonicalMappings(TestContext context)
    {
        MediaFactsResponse response = MediaFactsNormalizer.Normalize(SyntheticDocument);
        MediaVideoFacts video = response.Video[0];

        // The canonical side is the comparison value; the raw side preserves the source
        // spelling. Flipping any mapping below must turn this case red; that flip is the
        // recorded mutation proof for canonicalization.
        context.Equal(new MediaFactValue("full", "Full"), video.ColourRange, "colour range canonical");
        context.Equal(new MediaFactValue("bt.2020", "BT.2020"), video.ColourPrimaries, "colour primaries canonical");
        context.Equal(new MediaFactValue("pq", "PQ"), video.TransferCharacteristics, "transfer canonical");
        context.Equal(new MediaFactValue("bt.2020 non-constant", "BT.2020 non-constant"), video.MatrixCoefficients, "matrix canonical");
        context.Equal(new MediaFactValue("type 2", "Type 2"), video.ChromaSubsamplingPosition, "chroma position canonical");

        // HDR prose facts pass through raw; they are display labels, not canonical enums.
        context.Equal("Display P3", video.MasteringDisplayColorPrimaries, "mastering primaries raw");
        context.Equal("1000 cd/m2", video.MaxCll, "max content light level raw");
        context.Equal("HDR10", video.HdrFormatCommercial, "commercial hdr label raw");

        // Text track normalization, covered here because no committed fixture carries one.
        context.Equal(1, response.Text.Length, "text stream count");
        MediaTextFacts text = response.Text[0];
        context.Equal("UTF-8", text.Format, "text format");
        context.Equal("en", text.Language, "text language");
        context.Equal(true, text.Default, "text default flag");
        context.Equal(false, text.Forced, "text forced flag");
    }

    private static void MalformedDocuments(TestContext context)
    {
        context.Throws<MediaFactsFormatException>(
            static () => MediaFactsNormalizer.Normalize("this is not json"),
            "unparseable input must fail typed");
        context.Throws<MediaFactsFormatException>(
            static () => MediaFactsNormalizer.Normalize("{}"),
            "missing creating library must fail typed");
        context.Throws<MediaFactsFormatException>(
            static () => MediaFactsNormalizer.Normalize("{\"creatingLibrary\":{\"name\":\"MediaInfoLib\"},\"media\":{\"track\":[]}}"),
            "missing library version must fail typed");
        context.Throws<MediaFactsFormatException>(
            static () => MediaFactsNormalizer.Normalize("{\"creatingLibrary\":{\"name\":\"MediaInfoLib\",\"version\":\"26.05\"}}"),
            "missing media must fail typed");
        context.Throws<MediaFactsFormatException>(
            static () => MediaFactsNormalizer.Normalize("{\"creatingLibrary\":{\"name\":\"MediaInfoLib\",\"version\":\"26.05\"},\"media\":{\"track\":{}}}"),
            "non-array track must fail typed");
    }
}

// Locates the committed golden fixtures from the test assembly location by a bounded
// upward walk, so the cases run identically under the wrapper and under a direct
// dotnet run, with no environment variable and no current-directory assumption.
internal static class FixtureFiles
{
    public static IReadOnlyList<string> GoldenNames { get; } =
    [
        "cfr-ffv1-10bit-pcm.mkv.win-26.05.json",
        "cfr-ffv1-10bit-pcm.mkv.wsl-24.01.json",
        "cfr-h264-aac.mp4.win-26.05.json",
        "cfr-h264-aac.mp4.wsl-24.01.json",
        "cfr-vp9-opus.webm.win-26.05.json",
        "cfr-vp9-opus.webm.wsl-24.01.json",
        "cfr-h264-aac-chapters.mp4.win-26.05.json",
        "cfr-h264-aac-chapters.mp4.wsl-24.01.json",
        "cfr-h264-aac-subtitles.mkv.win-26.05.json",
        "cfr-h264-aac-subtitles.mkv.wsl-24.01.json",
        "vfr-ffv1.mkv.win-26.05.json",
        "vfr-ffv1.mkv.wsl-24.01.json",
    ];

    private static readonly Lazy<string> Root = new(LocateRoot);

    public static string Read(string name) =>
        File.ReadAllText(Path.Combine(Root.Value, name));

    public static string PathOf(string name) =>
        Path.Combine(Root.Value, name);

    private static string LocateRoot()
    {
        string? current = AppContext.BaseDirectory;
        for (int depth = 0; depth < 10 && current is not null; depth++)
        {
            string candidate = Path.Combine(current, "eng", "fixtures", "media-inspection");
            if (File.Exists(Path.Combine(candidate, "MANIFEST.md")))
                return candidate;

            current = Path.GetDirectoryName(current);
        }

        throw new TestFailureException("fixture root not found above test assembly", "eng/fixtures/media-inspection", "<missing>");
    }
}
