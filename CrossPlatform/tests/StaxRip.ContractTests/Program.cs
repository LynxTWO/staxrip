using System.Diagnostics;
using System.Globalization;

namespace StaxRip.ContractTests;

internal static class Program
{
    public static async Task<int> Main(string[] args)
    {
        CultureInfo.DefaultThreadCurrentCulture = CultureInfo.InvariantCulture;
        CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.InvariantCulture;

        // The bounded-process cases re-invoke this binary as a controllable child,
        // the adapter cases re-invoke it as the impersonated tool, and the
        // port-inspection gate re-invokes it as a configured server host, because
        // the shipped binary deliberately has no configuration surface. Every
        // sentinel dispatches before any test machinery runs.
        if (args.Length >= 2 && args[0] == "--bounded-child")
            return BoundedChild.Run(args[1..]);
        if (args.Length >= 1 && args[0] == "--Output=JSON")
            return FakeMediaInfo.Run(args);
        if (args.Length == 3 && args[0] == "--serve-configured")
            return await ConfiguredServerHost.RunAsync(args[1], args[2]).ConfigureAwait(false);

        bool selfTestFailure = args.Contains("--self-test-failure", StringComparer.Ordinal);
        TestCase[] cases = selfTestFailure
            ? [new TestCase("HARNESS-FAILURE", "forced harness failure", static context => context.Equal(1, 2, "forced failure did not fail"))]
            : ContractCases.All.Concat(MediaFactsCases.All).Concat(BoundedProcessCases.All).Concat(MediaInfoCliCases.All).Concat(MediaPathPolicyCases.All).Concat(MediaFileProbeCases.All).Concat(MediaFactsEndpointCases.All).Concat(ServerCases.All).ToArray();

        var stopwatch = Stopwatch.StartNew();
        int assertions = 0;

        foreach (TestCase testCase in cases)
        {
            var context = new TestContext();
            try
            {
                await testCase.Run(context).ConfigureAwait(false);
                assertions += context.AssertionCount;
            }
            catch (Exception exception)
            {
                string message = GetSafeFailureMessage(exception);
                Console.Error.WriteLine($"FAIL port-contract case={testCase.Id} type={exception.GetType().Name} message={message}");
                return 1;
            }
        }

        stopwatch.Stop();
        Console.WriteLine($"PASS port-contract cases={cases.Length} assertions={assertions} failures=0 elapsed_ms={stopwatch.ElapsedMilliseconds}");
        return selfTestFailure ? 2 : 0;
    }

    private static string GetSafeFailureMessage(Exception exception)
    {
        if (exception is not TestFailureException)
            return "unexpected test exception";

        string message = exception.Message;
        foreach (string privatePath in new[]
        {
            AppContext.BaseDirectory,
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        }.Where(static path => !string.IsNullOrWhiteSpace(path)).OrderByDescending(static path => path.Length))
        {
            message = message.Replace(privatePath, "<redacted-path>", StringComparison.OrdinalIgnoreCase);
            message = message.Replace(privatePath.Replace('\\', '/'), "<redacted-path>", StringComparison.OrdinalIgnoreCase);
        }

        var safe = new char[Math.Min(message.Length, 320)];
        for (int index = 0; index < safe.Length; index++)
        {
            char value = message[index];
            safe[index] = value is >= ' ' and <= '~' ? value : ' ';
        }

        return new string(safe);
    }
}
