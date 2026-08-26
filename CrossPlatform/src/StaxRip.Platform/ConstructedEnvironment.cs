using System.Collections.Immutable;
using System.Runtime.InteropServices;

namespace StaxRip.Platform;

// D-056: the one definition of what a child process may inherit, which is nothing
// beyond this. The base set is the smallest environment on which a portable tool boots
// on each platform; anything a specific tool needs beyond it is stated by the adapter
// that knows it, through the request, never discovered from the parent's map.
public static class ConstructedEnvironment
{
    // Windows: the runtime and loader need the system root, and portable tools that
    // write scratch files need a temp location; the values are copied from the
    // parent because they describe the machine, not the parent. Elsewhere: a fixed
    // locale so tool output is deterministic regardless of the parent's.
    public static ImmutableDictionary<string, string> BaseSet()
    {
        ImmutableDictionary<string, string>.Builder builder =
            ImmutableDictionary.CreateBuilder<string, string>(StringComparer.Ordinal);

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            foreach (string name in new[] { "SystemRoot", "SystemDrive", "TEMP", "TMP" })
            {
                string? value = Environment.GetEnvironmentVariable(name);
                if (!string.IsNullOrEmpty(value))
                    builder[name] = value;
            }
        }
        else
        {
            builder["LANG"] = "C.UTF-8";
        }

        return builder.ToImmutable();
    }
}
