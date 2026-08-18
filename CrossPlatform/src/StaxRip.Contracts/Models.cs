using System.Collections.Immutable;

namespace StaxRip.Contracts;

public enum HealthState
{
    Ready = 1,
}

public enum CapabilityAvailability
{
    Unavailable = 0,
    Available = 1,
}

public enum ToolCompatibility
{
    Unverified = 0,
}

public enum ApiErrorCode
{
    InvalidRequest = 1,
    Unauthorized = 2,
    Forbidden = 3,
    NotFound = 4,
    MethodNotAllowed = 5,
    InternalError = 6,
}

public sealed record HealthResponse(
    string SchemaVersion,
    string ApiVersion,
    string EngineVersion,
    HealthState Status);

public sealed record HostFacts(
    string PlatformId,
    string ArchitectureId,
    string RuntimeVersion,
    int LogicalProcessorCount);

public sealed record FeatureCapability(
    string Id,
    string DisplayName,
    CapabilityAvailability Availability,
    string ReasonCode);

public sealed record ToolCapability(
    string Id,
    string DisplayName,
    ToolCompatibility Compatibility,
    string ReasonCode);

public sealed record CapabilityResponse(
    string SchemaVersion,
    string ApiVersion,
    string EngineVersion,
    HostFacts Host,
    ImmutableArray<FeatureCapability> Features,
    ImmutableArray<ToolCapability> Tools);

public sealed record ApiError(
    ApiErrorCode Code,
    string Message);

public sealed record ErrorResponse(
    string SchemaVersion,
    string ApiVersion,
    ApiError Error);
