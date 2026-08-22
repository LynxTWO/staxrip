using System.Collections.Immutable;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using StaxRip.Contracts;

namespace StaxRip.Core;

// Raised when the authority document cannot be normalized. The message carries a fixed
// reason class only, never document content or a path, so the exception is safe to
// surface through the typed error contract.
public sealed class MediaFactsFormatException : Exception
{
    public MediaFactsFormatException(string reasonClass)
        : base(reasonClass)
    {
    }
}

// Normalizes a MediaInfo CLI JSON document into the typed payload. The rules this layer
// owns, from the agreed-facts list: absence stays absence and nothing is defaulted; no
// identifier is synthesized; canonical values are computed beside the retained raw
// spelling; and the privacy strip runs on the parsed document before any field is read,
// so an unstripped value cannot reach the payload by construction.
public static class MediaFactsNormalizer
{
    public static MediaFactsResponse Normalize(string rawJson)
    {
        JsonNode root;
        try
        {
            root = JsonNode.Parse(rawJson) ?? throw new MediaFactsFormatException("document-empty");
        }
        catch (JsonException)
        {
            throw new MediaFactsFormatException("document-not-json");
        }

        if (root is not JsonObject rootObject)
            throw new MediaFactsFormatException("document-not-object");

        MediaFactsPrivacy.StripBannedFields(rootObject);

        if (rootObject["creatingLibrary"] is not JsonObject library)
            throw new MediaFactsFormatException("creating-library-missing");
        string? libraryName = ReadString(library, "name");
        string? libraryVersion = ReadString(library, "version");
        if (string.IsNullOrWhiteSpace(libraryName) || string.IsNullOrWhiteSpace(libraryVersion))
            throw new MediaFactsFormatException("creating-library-identity-missing");

        if (rootObject["media"] is not JsonObject media)
            throw new MediaFactsFormatException("media-missing");
        if (media["track"] is not JsonArray tracks)
            throw new MediaFactsFormatException("track-list-missing");

        var container = new MediaContainerFacts();
        var video = ImmutableArray.CreateBuilder<MediaVideoFacts>();
        var audio = ImmutableArray.CreateBuilder<MediaAudioFacts>();
        var text = ImmutableArray.CreateBuilder<MediaTextFacts>();
        var chapters = ImmutableArray.CreateBuilder<MediaChapterFacts>();
        int menuIndex = 0;

        foreach (JsonNode? trackNode in tracks)
        {
            if (trackNode is not JsonObject track)
                throw new MediaFactsFormatException("track-not-object");

            switch (ReadString(track, "@type"))
            {
                case "General":
                    container = ReadContainer(track);
                    break;
                case "Video":
                    video.Add(ReadVideo(track, video.Count));
                    break;
                case "Audio":
                    audio.Add(ReadAudio(track, audio.Count));
                    break;
                case "Text":
                    text.Add(ReadText(track, text.Count));
                    break;
                case "Menu":
                    ReadChapters(track, menuIndex, chapters);
                    menuIndex++;
                    break;
            }
        }

        return new MediaFactsResponse
        {
            Authority = new MediaFactsAuthority(libraryName, libraryVersion),
            Container = container,
            Video = video.ToImmutable(),
            Audio = audio.ToImmutable(),
            Text = text.ToImmutable(),
            Chapters = chapters.ToImmutable(),
        };
    }

    private static MediaContainerFacts ReadContainer(JsonObject track) => new()
    {
        Format = ReadString(track, "Format"),
        Duration = ReadString(track, "Duration"),
        DurationSeconds = ReadDouble(track, "Duration"),
        FileSizeBytes = ReadLong(track, "FileSize"),
        Title = ReadString(track, "Title"),
    };

    private static MediaVideoFacts ReadVideo(JsonObject track, int index) => new()
    {
        Index = index,
        Format = ReadString(track, "Format"),
        FormatProfile = ReadString(track, "Format_Profile"),
        Width = ReadInt(track, "Width"),
        Height = ReadInt(track, "Height"),
        PixelAspectRatio = ReadString(track, "PixelAspectRatio"),
        DisplayAspectRatio = ReadString(track, "DisplayAspectRatio"),
        FrameRate = ReadString(track, "FrameRate"),
        FrameRateValue = ReadDouble(track, "FrameRate"),
        FrameRateMode = ReadString(track, "FrameRate_Mode"),
        FrameCount = ReadLong(track, "FrameCount"),
        BitDepth = ReadInt(track, "BitDepth"),
        ChromaSubsampling = ReadString(track, "ChromaSubsampling"),
        ChromaSubsamplingPosition = ReadCanonical(track, "ChromaSubsampling_Position"),
        ColorSpace = ReadString(track, "ColorSpace"),
        ScanType = ReadString(track, "ScanType"),
        ScanOrder = ReadString(track, "ScanOrder"),
        Rotation = ReadString(track, "Rotation"),
        StreamSizeBytes = ReadLong(track, "StreamSize"),
        BitRateBits = ReadLong(track, "BitRate"),
        Language = ReadString(track, "Language"),
        ColourPrimaries = ReadCanonical(track, "colour_primaries"),
        TransferCharacteristics = ReadCanonical(track, "transfer_characteristics"),
        MatrixCoefficients = ReadCanonical(track, "matrix_coefficients"),
        ColourRange = ReadCanonicalRange(track),
        MasteringDisplayColorPrimaries = ReadString(track, "MasteringDisplay_ColorPrimaries"),
        MasteringDisplayLuminance = ReadString(track, "MasteringDisplay_Luminance"),
        MaxCll = ReadString(track, "MaxCLL"),
        MaxFall = ReadString(track, "MaxFALL"),
        HdrFormat = ReadString(track, "HDR_Format"),
        HdrFormatCommercial = ReadString(track, "HDR_Format_Commercial"),
    };

    private static MediaAudioFacts ReadAudio(JsonObject track, int index) => new()
    {
        Index = index,
        Format = ReadString(track, "Format"),
        FormatProfile = ReadString(track, "Format_Profile"),
        Channels = ReadInt(track, "Channels"),
        ChannelLayout = ReadString(track, "ChannelLayout"),
        SamplingRateHz = ReadInt(track, "SamplingRate"),
        BitDepth = ReadInt(track, "BitDepth"),
        BitRateBits = ReadLong(track, "BitRate"),
        Language = ReadString(track, "Language"),
        Title = ReadString(track, "Title"),
        Default = ReadYesNo(track, "Default"),
        Forced = ReadYesNo(track, "Forced"),
        CompressionMode = ReadString(track, "Compression_Mode"),
        VideoDelay = ReadString(track, "Video_Delay"),
        VideoDelaySeconds = ReadDouble(track, "Video_Delay"),
    };

    private static MediaTextFacts ReadText(JsonObject track, int index) => new()
    {
        Index = index,
        Format = ReadString(track, "Format"),
        Language = ReadString(track, "Language"),
        Title = ReadString(track, "Title"),
        Default = ReadYesNo(track, "Default"),
        Forced = ReadYesNo(track, "Forced"),
        StreamSizeBytes = ReadLong(track, "StreamSize"),
    };

    // Chapters are the one fact the authority reports through dynamically named members
    // rather than through a parameter name: each entry is a member of the menu track's
    // extra block, named by its own timecode. The block is not exclusively chapters, so
    // membership is decided by the timecode grammar and nothing else; sweeping the block
    // would publish the menu's other members as chapters. The label is exposed verbatim,
    // because a label may contain the separator any further parsing would split on.
    private static void ReadChapters(
        JsonObject track,
        int menuIndex,
        ImmutableArray<MediaChapterFacts>.Builder chapters)
    {
        if (track["extra"] is not JsonObject extra)
            return;

        int index = 0;
        foreach (KeyValuePair<string, JsonNode?> member in extra)
        {
            if (!TryReadChapterTimecode(member.Key, out string? timecode, out long milliseconds))
                continue;

            chapters.Add(new MediaChapterFacts
            {
                MenuIndex = menuIndex,
                Index = index,
                Timecode = timecode,
                TimecodeMilliseconds = milliseconds,
                Label = member.Value is JsonValue value && value.TryGetValue(out string? label) && label.Length > 0
                    ? label
                    : null,
            });
            index++;
        }
    }

    // The member grammar is an underscore, then hours, minutes, seconds, and
    // milliseconds, each underscore separated. Anything else is not a chapter.
    private static bool TryReadChapterTimecode(string name, out string? timecode, out long milliseconds)
    {
        timecode = null;
        milliseconds = 0;

        if (name.Length != 13 || name[0] != '_' || name[3] != '_' || name[6] != '_' || name[9] != '_')
            return false;

        if (!TryReadDigits(name, 1, 2, out int hours) ||
            !TryReadDigits(name, 4, 2, out int minutes) ||
            !TryReadDigits(name, 7, 2, out int seconds) ||
            !TryReadDigits(name, 10, 3, out int fraction))
        {
            return false;
        }

        timecode = string.Create(
            CultureInfo.InvariantCulture,
            $"{hours:D2}:{minutes:D2}:{seconds:D2}.{fraction:D3}");
        milliseconds = (((hours * 60L) + minutes) * 60L + seconds) * 1000L + fraction;
        return true;
    }

    private static bool TryReadDigits(string name, int start, int length, out int value)
    {
        value = 0;
        for (int offset = 0; offset < length; offset++)
        {
            char character = name[start + offset];
            if (character is < '0' or > '9')
                return false;

            value = (value * 10) + (character - '0');
        }

        return true;
    }

    private static string? ReadString(JsonObject track, string name) =>
        track[name] is JsonValue value && value.TryGetValue(out string? text) && text.Length > 0
            ? text
            : null;

    // Typed views parse strictly under the invariant culture. A present value that does
    // not parse keeps its raw view and yields no typed view; that is absence of the
    // typed fact, never a default.
    private static int? ReadInt(JsonObject track, string name) =>
        ReadString(track, name) is { } text &&
        int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out int value)
            ? value
            : null;

    private static long? ReadLong(JsonObject track, string name) =>
        ReadString(track, name) is { } text &&
        long.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out long value)
            ? value
            : null;

    private static double? ReadDouble(JsonObject track, string name) =>
        ReadString(track, name) is { } text &&
        double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out double value)
            ? value
            : null;

    private static bool? ReadYesNo(JsonObject track, string name) => ReadString(track, name) switch
    {
        "Yes" => true,
        "No" => false,
        _ => null,
    };

    // Canonicalization keeps the comparison value lowercase and invariant while the raw
    // spelling is retained beside it. The range map is explicit because its two values
    // are a genuine vocabulary, and the explicit map is the mutation target proving the
    // canonical layer is load bearing.
    private static MediaFactValue? ReadCanonical(JsonObject track, string name) =>
        ReadString(track, name) is { } raw
            ? new MediaFactValue(raw.ToLowerInvariant(), raw)
            : null;

    private static MediaFactValue? ReadCanonicalRange(JsonObject track)
    {
        if (ReadString(track, "colour_range") is not { } raw)
            return null;

        string canonical = raw.ToLowerInvariant() switch
        {
            "limited" => "limited",
            "full" => "full",
            var other => other,
        };

        return new MediaFactValue(canonical, raw);
    }
}
