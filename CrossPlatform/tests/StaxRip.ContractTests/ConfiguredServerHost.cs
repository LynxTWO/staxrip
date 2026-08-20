using Microsoft.AspNetCore.Builder;
using StaxRip.Core;
using StaxRip.Platform;
using StaxRip.Server;

namespace StaxRip.ContractTests;

// The configured server host the port-inspection gate drives. The shipped server
// binary has no configuration surface on purpose; this host is the sanctioned test
// vehicle that composes a configured application the same way the in-process cases
// do, publishes the bound address with the production READY protocol, and shuts down
// when its stdin reaches end of file, which gives the gate a deterministic stop that
// needs no signals. The media root and tool path arrive as explicit argv, never from
// the environment.
internal static class ConfiguredServerHost
{
    public static async Task<int> RunAsync(string mediaRoot, string toolPath)
    {
        var configuration = new MediaInspectionConfiguration
        {
            PathPolicy = new MediaPathPolicyOptions
            {
                MediaRoots = [mediaRoot],
            },
            Authority = new MediaInfoCliOptions
            {
                ExecutablePath = toolPath,
            },
        };

        WebApplication? app = null;
        try
        {
            app = ServerApp.Build(mediaInspection: configuration);
            using var startTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            await app.StartAsync(startTimeout.Token).ConfigureAwait(false);
            Uri readyUri = ServerApp.PublishBoundAddress(app);
            Console.Out.WriteLine($"READY {readyUri.AbsoluteUri}");

            while (await Console.In.ReadLineAsync().ConfigureAwait(false) is not null)
            {
                // Drain until end of file; the gate owns the lifetime.
            }

            using var stopTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            await app.StopAsync(stopTimeout.Token).ConfigureAwait(false);
            await app.DisposeAsync().ConfigureAwait(false);
            app = null;
            Console.Out.WriteLine("STOPPED");
            return 0;
        }
        catch
        {
            Console.Error.WriteLine("ERROR SRV_CONFIGURED_HOST_FAILED");
            return 1;
        }
        finally
        {
            if (app is not null)
            {
                try
                {
                    await app.DisposeAsync().ConfigureAwait(false);
                }
                catch
                {
                    // Failing closed; keep console output bounded.
                }
            }
        }
    }
}
