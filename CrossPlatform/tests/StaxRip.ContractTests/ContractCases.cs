using System.Text.Json;
using StaxRip.Contracts;
using StaxRip.Core;
using StaxRip.Platform;

namespace StaxRip.ContractTests;

internal static class ContractCases
{
    public static IReadOnlyList<TestCase> All { get; } =
    [
        new("CT-001", "contract constants", ContractConstants),
        new("CT-002", "health serialization", HealthSerialization),
        new("CT-003", "strict JSON input", StrictJsonInput),
        new("CT-004", "capability catalog", CapabilityCatalog),
        new("CT-005", "unavailable bootstrap authority", BootstrapAuthority),
        new("CT-006", "tool catalog stays unverified", ToolCatalog),
        new("CT-007", "host facts allowlist", HostFactsAllowlist),
        new("CT-008", "host facts bounds", HostFactsBounds),
        new("CT-009", "catalog determinism", CatalogDeterminism),
        new("CT-010", "identifier grammar", IdentifierGrammar),
        new("CT-011", "capability JSON allowlist", CapabilityJsonAllowlist),
        new("CT-012", "error envelope", ErrorEnvelope),
        new("CT-013", "runtime provider bounds", RuntimeProviderBounds),
        new("CT-014", "provider failure remains explicit", ProviderFailure),
    ];

    private static void ContractConstants(TestContext context)
    {
        context.Equal("1", ApiContract.SchemaVersion, "schema version drift");
        context.Equal("v1", ApiContract.ApiVersion, "API version drift");
        context.Equal("0.1.0-bootstrap", ApiContract.EngineVersion, "engine version drift");
        context.Equal("/healthz", ApiContract.HealthRoute, "health route drift");
        context.Equal("/api/v1/capabilities", ApiContract.CapabilitiesRoute, "capability route drift");
        context.Equal(4_096, ContractLimits.MaxLogicalProcessorCount, "processor bound drift");
        context.Equal(32, ContractLimits.MaxRuntimeVersionLength, "runtime version bound drift");
    }

    private static void HealthSerialization(TestContext context)
    {
        string json = JsonSerializer.Serialize(CapabilityService.GetHealth(), ContractJson.Options);
        using JsonDocument document = JsonDocument.Parse(json);
        string[] keys = document.RootElement.EnumerateObject().Select(static item => item.Name).ToArray();

        context.SequenceEqual(
            ["schemaVersion", "apiVersion", "engineVersion", "status"],
            keys,
            "health keys changed");
        context.Equal("ready", document.RootElement.GetProperty("status").GetString(), "health state changed");
        context.Equal(
            "{\"schemaVersion\":\"1\",\"apiVersion\":\"v1\",\"engineVersion\":\"0.1.0-bootstrap\",\"status\":\"ready\"}",
            json,
            "health JSON changed");
    }

    private static void StrictJsonInput(TestContext context)
    {
        const string integerEnum = "{\"schemaVersion\":\"1\",\"apiVersion\":\"v1\",\"engineVersion\":\"0.1.0-bootstrap\",\"status\":1}";
        const string unknownMember = "{\"schemaVersion\":\"1\",\"apiVersion\":\"v1\",\"engineVersion\":\"0.1.0-bootstrap\",\"status\":\"ready\",\"extra\":true}";

        context.Throws<JsonException>(
            () => JsonSerializer.Deserialize<HealthResponse>(integerEnum, ContractJson.Options),
            "integer enum was accepted");
        context.Throws<JsonException>(
            () => JsonSerializer.Deserialize<HealthResponse>(unknownMember, ContractJson.Options),
            "unknown member was accepted");
    }

    private static void CapabilityCatalog(TestContext context)
    {
        CapabilityResponse result = CreateService().GetCapabilities();
        context.Equal(ApiContract.SchemaVersion, result.SchemaVersion, "capability schema drift");
        context.Equal(ApiContract.ApiVersion, result.ApiVersion, "capability API drift");
        context.Equal(ApiContract.EngineVersion, result.EngineVersion, "capability engine drift");
        context.Equal(8, result.Features.Length, "feature count drift");
        context.Equal(6, result.Tools.Length, "tool count drift");
        context.SequenceEqual(
            [
                FeatureIds.LocalEngine,
                FeatureIds.WebShell,
                FeatureIds.MediaInspection,
                FeatureIds.Encoding,
                FeatureIds.Persistence,
                FeatureIds.RemoteAccess,
                FeatureIds.Plugins,
                FeatureIds.ProjectImport,
            ],
            result.Features.Select(static feature => feature.Id),
            "feature order drift");
    }

    private static void BootstrapAuthority(TestContext context)
    {
        CapabilityResponse result = CreateService().GetCapabilities();
        string[] allowed = [FeatureIds.LocalEngine, FeatureIds.WebShell];
        string[] unavailable =
        [
            FeatureIds.MediaInspection,
            FeatureIds.Encoding,
            FeatureIds.Persistence,
            FeatureIds.RemoteAccess,
            FeatureIds.Plugins,
            FeatureIds.ProjectImport,
        ];

        foreach (FeatureCapability feature in result.Features)
        {
            CapabilityAvailability expected = allowed.Contains(feature.Id, StringComparer.Ordinal)
                ? CapabilityAvailability.Available
                : CapabilityAvailability.Unavailable;
            context.Equal(expected, feature.Availability, $"feature authority changed for {feature.Id}");
            context.Equal(
                expected == CapabilityAvailability.Available
                    ? ContractValues.BootstrapReady
                    : ContractValues.BootstrapUnavailable,
                feature.ReasonCode,
                $"feature reason changed for {feature.Id}");
        }

        context.SequenceEqual(unavailable, result.Features.Where(static item => item.Availability == CapabilityAvailability.Unavailable).Select(static item => item.Id), "unavailable feature set drift");
    }

    private static void ToolCatalog(TestContext context)
    {
        CapabilityResponse result = CreateService().GetCapabilities();
        context.SequenceEqual(
            [ToolIds.Ffmpeg, ToolIds.Ffprobe, ToolIds.VapourSynth, ToolIds.AviSynthPlus, ToolIds.MkvToolNix, ToolIds.NvEnc],
            result.Tools.Select(static tool => tool.Id),
            "tool order drift");

        foreach (ToolCapability tool in result.Tools)
        {
            context.Equal(ToolCompatibility.Unverified, tool.Compatibility, $"tool compatibility overstated for {tool.Id}");
            context.Equal(ContractValues.CompatibilityNotTested, tool.ReasonCode, $"tool reason drift for {tool.Id}");
        }
    }

    private static void HostFactsAllowlist(TestContext context)
    {
        foreach (string platform in new[] { "windows", "linux", "macos" })
            context.Equal(platform, CreateService(platform: platform).GetCapabilities().Host.PlatformId, "allowed platform changed");

        foreach (string architecture in new[] { "x64", "arm64" })
            context.Equal(architecture, CreateService(architecture: architecture).GetCapabilities().Host.ArchitectureId, "allowed architecture changed");

        foreach (string architecture in new[] { "x86", "arm" })
            context.Equal(ContractValues.UnknownId, CreateService(architecture: architecture).GetCapabilities().Host.ArchitectureId, "32-bit architecture became supported");

        context.Equal(ContractValues.UnknownId, CreateService(platform: "Linux").GetCapabilities().Host.PlatformId, "platform normalization became permissive");
        context.Equal(ContractValues.UnknownId, CreateService(architecture: "x64 ").GetCapabilities().Host.ArchitectureId, "architecture normalization became permissive");
    }

    private static void HostFactsBounds(TestContext context)
    {
        context.Equal(1, CreateService(processors: 0).GetCapabilities().Host.LogicalProcessorCount, "low processor bound changed");
        context.Equal(ContractLimits.MaxLogicalProcessorCount, CreateService(processors: int.MaxValue).GetCapabilities().Host.LogicalProcessorCount, "high processor bound changed");
        context.Equal(ContractValues.UnknownId, CreateService(runtime: "").GetCapabilities().Host.RuntimeVersion, "empty runtime accepted");
        context.Equal(ContractValues.UnknownId, CreateService(runtime: new string('1', ContractLimits.MaxRuntimeVersionLength + 1)).GetCapabilities().Host.RuntimeVersion, "long runtime accepted");
        context.Equal(ContractValues.UnknownId, CreateService(runtime: "10.0/path").GetCapabilities().Host.RuntimeVersion, "unsafe runtime text accepted");
        context.Equal("10.0.11-test_1", CreateService(runtime: "10.0.11-test_1").GetCapabilities().Host.RuntimeVersion, "safe runtime text rejected");
    }

    private static void CatalogDeterminism(TestContext context)
    {
        var service = CreateService();
        string first = JsonSerializer.Serialize(service.GetCapabilities(), ContractJson.Options);
        for (int index = 0; index < 100; index++)
            context.Equal(first, JsonSerializer.Serialize(service.GetCapabilities(), ContractJson.Options), "capability output changed across repetition");
    }

    private static void IdentifierGrammar(TestContext context)
    {
        CapabilityResponse result = CreateService().GetCapabilities();
        string[] ids = result.Features.Select(static item => item.Id).Concat(result.Tools.Select(static item => item.Id)).ToArray();
        context.Equal(ids.Length, ids.Distinct(StringComparer.Ordinal).Count(), "duplicate capability id");
        foreach (string id in ids)
        {
            context.True(id.Length is > 0 and <= ContractLimits.MaxIdentifierLength, $"id length invalid for {id}");
            context.True(id.All(static character => character is >= 'a' and <= 'z' or >= '0' and <= '9' or '-'), $"id grammar invalid for {id}");
        }
    }

    private static void CapabilityJsonAllowlist(TestContext context)
    {
        string json = JsonSerializer.Serialize(CreateService().GetCapabilities(), ContractJson.Options);
        using JsonDocument document = JsonDocument.Parse(json);
        context.SequenceEqual(
            ["schemaVersion", "apiVersion", "engineVersion", "host", "features", "tools"],
            document.RootElement.EnumerateObject().Select(static item => item.Name),
            "capability root keys changed");
        context.SequenceEqual(
            ["platformId", "architectureId", "runtimeVersion", "logicalProcessorCount"],
            document.RootElement.GetProperty("host").EnumerateObject().Select(static item => item.Name),
            "host keys changed");
        context.False(
            EnumerateStringValues(document.RootElement).Any(static value =>
                value.Contains('\\') || value.Contains('/')),
            "capability JSON contains a path separator");
        context.False(json.Contains("\"machine", StringComparison.OrdinalIgnoreCase), "capability JSON exposed a machine field");
    }

    private static void ErrorEnvelope(TestContext context)
    {
        var response = new ErrorResponse(
            ApiContract.SchemaVersion,
            ApiContract.ApiVersion,
            new ApiError(ApiErrorCode.Unauthorized, "The local client session is not valid."));
        string json = JsonSerializer.Serialize(response, ContractJson.Options);
        using JsonDocument document = JsonDocument.Parse(json);
        context.SequenceEqual(
            ["schemaVersion", "apiVersion", "error"],
            document.RootElement.EnumerateObject().Select(static item => item.Name),
            "error root keys changed");
        context.Equal("unauthorized", document.RootElement.GetProperty("error").GetProperty("code").GetString(), "error code drift");
        context.False(json.Contains("stack", StringComparison.OrdinalIgnoreCase), "error exposed stack text");
    }

    private static void RuntimeProviderBounds(TestContext context)
    {
        HostFacts facts = new RuntimeHostFactsProvider().Capture();
        context.True(facts.PlatformId is "windows" or "linux" or "macos" or ContractValues.UnknownId, "runtime platform escaped allowlist");
        context.True(facts.ArchitectureId is "x64" or "arm64" or ContractValues.UnknownId, "runtime architecture escaped 64-bit allowlist");
        context.True(facts.LogicalProcessorCount is >= 1 and <= ContractLimits.MaxLogicalProcessorCount, "runtime processor count escaped bounds");
        context.True(facts.RuntimeVersion.Length is > 0 and <= ContractLimits.MaxRuntimeVersionLength, "runtime version escaped bounds");
    }

    private static void ProviderFailure(TestContext context)
    {
        var service = new CapabilityService(new ThrowingHostFactsProvider());
        context.Throws<InvalidOperationException>(() => service.GetCapabilities(), "provider failure was hidden inside the pure service");
    }

    private static CapabilityService CreateService(
        string platform = "linux",
        string architecture = "x64",
        string runtime = "10.0.11",
        int processors = 32) =>
        new(new FixedHostFactsProvider(new HostFacts(platform, architecture, runtime, processors)));

    private static IEnumerable<string> EnumerateStringValues(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (JsonProperty property in element.EnumerateObject())
                {
                    foreach (string value in EnumerateStringValues(property.Value))
                        yield return value;
                }
                break;
            case JsonValueKind.Array:
                foreach (JsonElement item in element.EnumerateArray())
                {
                    foreach (string value in EnumerateStringValues(item))
                        yield return value;
                }
                break;
            case JsonValueKind.String:
                yield return element.GetString() ?? string.Empty;
                break;
        }
    }

    private sealed class FixedHostFactsProvider(HostFacts facts) : IHostFactsProvider
    {
        public HostFacts Capture() => facts;
    }

    private sealed class ThrowingHostFactsProvider : IHostFactsProvider
    {
        public HostFacts Capture() => throw new InvalidOperationException("synthetic provider failure");
    }
}

internal sealed class TestCase
{
    public TestCase(string id, string name, Action<TestContext> run)
        : this(
            id,
            name,
            context =>
            {
                run(context);
                return Task.CompletedTask;
            })
    {
    }

    public TestCase(string id, string name, Func<TestContext, Task> run)
    {
        Id = id;
        Name = name;
        Run = run;
    }

    public string Id { get; }

    public string Name { get; }

    public Func<TestContext, Task> Run { get; }
}
