using System.Text.Json;
using System.Text.Json.Serialization;

namespace StaxRip.Contracts;

public static class ContractJson
{
    public static JsonSerializerOptions Options { get; } = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = false,
            NumberHandling = JsonNumberHandling.Strict,
            UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
            WriteIndented = false,
        };

        options.Converters.Add(
            new JsonStringEnumConverter<HealthState>(JsonNamingPolicy.CamelCase, allowIntegerValues: false));
        options.Converters.Add(
            new JsonStringEnumConverter<CapabilityAvailability>(JsonNamingPolicy.CamelCase, allowIntegerValues: false));
        options.Converters.Add(
            new JsonStringEnumConverter<ToolCompatibility>(JsonNamingPolicy.CamelCase, allowIntegerValues: false));
        options.Converters.Add(
            new JsonStringEnumConverter<ApiErrorCode>(JsonNamingPolicy.CamelCase, allowIntegerValues: false));
        options.TypeInfoResolver = ContractJsonContext.Default;
        options.MakeReadOnly();

        return options;
    }
}

[JsonSerializable(typeof(HealthResponse))]
[JsonSerializable(typeof(CapabilityResponse))]
[JsonSerializable(typeof(ApiError))]
[JsonSerializable(typeof(ErrorResponse))]
[JsonSerializable(typeof(MediaFactsResponse))]
internal sealed partial class ContractJsonContext : JsonSerializerContext
{
}
