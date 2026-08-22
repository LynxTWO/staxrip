using System.Collections.Immutable;
using System.Text.Json.Serialization;

namespace StaxRip.Contracts;

public static class MediaFactsContract
{
    public const string SchemaId = "staxrip-media-facts-v1";
}

// A canonicalized fact keeps both views: the canonical value comparison happens on, and
// the raw source spelling, per the agreed-facts ground rules. Absence anywhere in this
// payload is an omitted property, never a default; every nullable member carries the
// null-omission condition so an absent fact does not serialize at all.
public sealed record MediaFactValue(string Canonical, string Raw);

public sealed record MediaFactsAuthority(string Name, string Version);

public sealed record MediaContainerFacts
{
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Format { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Duration { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public double? DurationSeconds { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? FileSizeBytes { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Title { get; init; }
}

public sealed record MediaVideoFacts
{
    public int Index { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Format { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FormatProfile { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Width { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Height { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? PixelAspectRatio { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? DisplayAspectRatio { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FrameRate { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public double? FrameRateValue { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FrameRateMode { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? FrameCount { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? BitDepth { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ChromaSubsampling { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public MediaFactValue? ChromaSubsamplingPosition { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ColorSpace { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ScanType { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ScanOrder { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Rotation { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? StreamSizeBytes { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? BitRateBits { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Language { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public MediaFactValue? ColourPrimaries { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public MediaFactValue? TransferCharacteristics { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public MediaFactValue? MatrixCoefficients { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public MediaFactValue? ColourRange { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? MasteringDisplayColorPrimaries { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? MasteringDisplayLuminance { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? MaxCll { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? MaxFall { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? HdrFormat { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? HdrFormatCommercial { get; init; }
}

public sealed record MediaAudioFacts
{
    public int Index { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Format { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FormatProfile { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Channels { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ChannelLayout { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? SamplingRateHz { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? BitDepth { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? BitRateBits { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Language { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Title { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? Default { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? Forced { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? CompressionMode { get; init; }

    // The stream's delay against video, the agreed audio-delay fact: the raw view
    // beside the typed seconds, absent when the authority does not report it.
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? VideoDelay { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public double? VideoDelaySeconds { get; init; }
}

public sealed record MediaTextFacts
{
    public int Index { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Format { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Language { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Title { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? Default { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? Forced { get; init; }

    // Present on containers that carry real subtitle sample tables, absent on those
    // that do not; both cases are golden-backed, so absence here is a measured fact
    // rather than an untested branch.
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? StreamSizeBytes { get; init; }
}

// One chapter entry, flat by design. The authority reports chapters inside menu tracks,
// and a container can carry more than one menu track for a single chapter list, so the
// menu's own index travels on the entry instead of nesting a collection inside a record.
// Nesting would also defeat the payload's range comparison, because record equality over
// a collection member compares backing references rather than contents.
public sealed record MediaChapterFacts
{
    public int MenuIndex { get; init; }

    public int Index { get; init; }

    // The authority names each entry by its own timecode; both the raw spelling and the
    // parsed milliseconds are retained, and the label is exposed verbatim because a
    // label may legitimately contain the separator any parsing would split on.
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Timecode { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? TimecodeMilliseconds { get; init; }

    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Label { get; init; }
}

public sealed record MediaFactsResponse
{
    public string Schema { get; init; } = MediaFactsContract.SchemaId;

    public MediaFactsAuthority Authority { get; init; } = new("", "");

    public MediaContainerFacts Container { get; init; } = new();

    public ImmutableArray<MediaVideoFacts> Video { get; init; } = [];

    public ImmutableArray<MediaAudioFacts> Audio { get; init; } = [];

    public ImmutableArray<MediaTextFacts> Text { get; init; } = [];

    public ImmutableArray<MediaChapterFacts> Chapters { get; init; } = [];
}
