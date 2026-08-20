using System.Collections.Immutable;
using StaxRip.Contracts;

namespace StaxRip.Core;

public sealed class CapabilityService
{
    private readonly ImmutableArray<FeatureCapability> _features;

    private static readonly ImmutableArray<ToolCapability> Tools =
    [
        UnverifiedTool(ToolIds.Ffmpeg, "FFmpeg"),
        UnverifiedTool(ToolIds.Ffprobe, "ffprobe"),
        UnverifiedTool(ToolIds.VapourSynth, "VapourSynth"),
        UnverifiedTool(ToolIds.AviSynthPlus, "AviSynth+"),
        UnverifiedTool(ToolIds.MkvToolNix, "MKVToolNix"),
        UnverifiedTool(ToolIds.NvEnc, "NVEnc"),
    ];

    private readonly IHostFactsProvider _hostFactsProvider;

    // Media inspection is the one capability with a real activation condition: the
    // server's composition root decides it from explicit configuration and passes
    // the verdict in, so this service never guesses and the published capability
    // always matches what the endpoint will actually do.
    public CapabilityService(IHostFactsProvider hostFactsProvider, bool mediaInspectionAvailable = false)
    {
        ArgumentNullException.ThrowIfNull(hostFactsProvider);
        _hostFactsProvider = hostFactsProvider;
        _features =
        [
            AvailableFeature(FeatureIds.LocalEngine, "Local engine"),
            AvailableFeature(FeatureIds.WebShell, "Web shell"),
            mediaInspectionAvailable
                ? new FeatureCapability(FeatureIds.MediaInspection, "Media inspection", CapabilityAvailability.Available, "inspection-configured")
                : UnavailableFeature(FeatureIds.MediaInspection, "Media inspection"),
            UnavailableFeature(FeatureIds.Encoding, "Encoding"),
            UnavailableFeature(FeatureIds.Persistence, "Persistence"),
            UnavailableFeature(FeatureIds.RemoteAccess, "Remote access"),
            UnavailableFeature(FeatureIds.Plugins, "Plugins"),
            UnavailableFeature(FeatureIds.ProjectImport, "Project import"),
        ];
    }

    public static HealthResponse GetHealth() => new(
        ApiContract.SchemaVersion,
        ApiContract.ApiVersion,
        ApiContract.EngineVersion,
        HealthState.Ready);

    public CapabilityResponse GetCapabilities()
    {
        HostFacts supplied = _hostFactsProvider.Capture();
        HostFacts safeHost = new(
            NormalizePlatformId(supplied.PlatformId),
            NormalizeArchitectureId(supplied.ArchitectureId),
            NormalizeRuntimeVersion(supplied.RuntimeVersion),
            Math.Clamp(supplied.LogicalProcessorCount, 1, ContractLimits.MaxLogicalProcessorCount));

        return new CapabilityResponse(
            ApiContract.SchemaVersion,
            ApiContract.ApiVersion,
            ApiContract.EngineVersion,
            safeHost,
            _features,
            Tools);
    }

    private static FeatureCapability AvailableFeature(string id, string displayName) =>
        new(id, displayName, CapabilityAvailability.Available, ContractValues.BootstrapReady);

    private static FeatureCapability UnavailableFeature(string id, string displayName) =>
        new(id, displayName, CapabilityAvailability.Unavailable, ContractValues.BootstrapUnavailable);

    private static ToolCapability UnverifiedTool(string id, string displayName) =>
        new(id, displayName, ToolCompatibility.Unverified, ContractValues.CompatibilityNotTested);

    private static string NormalizePlatformId(string? value) => value switch
    {
        "windows" => "windows",
        "linux" => "linux",
        "macos" => "macos",
        _ => ContractValues.UnknownId,
    };

    private static string NormalizeArchitectureId(string? value) => value switch
    {
        "x64" => "x64",
        "arm64" => "arm64",
        _ => ContractValues.UnknownId,
    };

    private static string NormalizeRuntimeVersion(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > ContractLimits.MaxRuntimeVersionLength)
            return ContractValues.UnknownId;

        foreach (char character in value)
        {
            bool isAsciiLetter = character is >= 'A' and <= 'Z' or >= 'a' and <= 'z';
            bool isAsciiDigit = character is >= '0' and <= '9';

            if (!isAsciiLetter && !isAsciiDigit && character is not '.' and not '-' and not '_')
                return ContractValues.UnknownId;
        }

        return value;
    }
}
