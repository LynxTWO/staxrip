namespace StaxRip.Contracts;

public static class ApiContract
{
    public const string SchemaVersion = "1";
    public const string ApiVersion = "v1";
    public const string EngineVersion = "0.1.0-bootstrap";
    public const string HealthRoute = "/healthz";
    public const string CapabilitiesRoute = "/api/v1/capabilities";
    public const string MediaFactsRoute = "/api/v1/media-facts";
}

public static class ContractLimits
{
    public const int MaxIdentifierLength = 64;
    public const int MaxRuntimeVersionLength = 32;
    public const int MaxLogicalProcessorCount = 4_096;
}

public static class ContractValues
{
    public const string UnknownId = "unknown";
    public const string BootstrapReady = "bootstrap-ready";
    public const string BootstrapUnavailable = "bootstrap-unavailable";
    public const string CompatibilityNotTested = "compatibility-not-tested";
}

public static class FeatureIds
{
    public const string LocalEngine = "local-engine";
    public const string WebShell = "web-shell";
    public const string MediaInspection = "media-inspection";
    public const string Encoding = "encoding";
    public const string Persistence = "persistence";
    public const string RemoteAccess = "remote-access";
    public const string Plugins = "plugins";
    public const string ProjectImport = "project-import";
}

public static class ToolIds
{
    public const string AviSynthPlus = "avisynth-plus";
    public const string Ffmpeg = "ffmpeg";
    public const string Ffprobe = "ffprobe";
    public const string MkvToolNix = "mkvtoolnix";
    public const string NvEnc = "nvenc";
    public const string VapourSynth = "vapoursynth";
}
