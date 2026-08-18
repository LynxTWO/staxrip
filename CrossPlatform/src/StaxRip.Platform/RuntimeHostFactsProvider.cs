using System.Runtime.InteropServices;
using StaxRip.Contracts;
using StaxRip.Core;

namespace StaxRip.Platform;

public sealed class RuntimeHostFactsProvider : IHostFactsProvider
{
    public HostFacts Capture() => new(
        GetPlatformId(),
        GetArchitectureId(RuntimeInformation.ProcessArchitecture),
        Environment.Version.ToString(),
        Math.Clamp(Environment.ProcessorCount, 1, ContractLimits.MaxLogicalProcessorCount));

    private static string GetPlatformId()
    {
        if (OperatingSystem.IsWindows())
            return "windows";

        if (OperatingSystem.IsLinux())
            return "linux";

        if (OperatingSystem.IsMacOS())
            return "macos";

        return ContractValues.UnknownId;
    }

    private static string GetArchitectureId(Architecture architecture) => architecture switch
    {
        Architecture.X64 => "x64",
        Architecture.Arm64 => "arm64",
        _ => ContractValues.UnknownId,
    };
}
