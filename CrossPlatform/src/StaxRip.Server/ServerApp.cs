using System.Net;
using System.Reflection;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using StaxRip.Contracts;
using StaxRip.Core;
using StaxRip.Platform;

namespace StaxRip.Server;

public static class ServerApp
{
    private const string StartupErrorCode = "SRV_STARTUP_FAILED";
    private const string GenericErrorMessage = "The request could not be completed.";

    public static WebApplication Build(
        IHostFactsProvider? hostFactsProvider = null,
        Assembly? assetAssembly = null)
    {
        var options = new WebApplicationOptions
        {
            ApplicationName = typeof(ServerApp).Assembly.GetName().Name,
            Args = [],
            ContentRootPath = AppContext.BaseDirectory,
            EnvironmentName = Environments.Production,
        };

        WebApplicationBuilder builder = WebApplication.CreateEmptyBuilder(options);
        builder.Configuration.Sources.Clear();
        builder.Configuration.AddInMemoryCollection();
        builder.Logging.ClearProviders();

        builder.WebHost
            .UseKestrelCore()
            .UseSetting(WebHostDefaults.PreventHostingStartupKey, bool.TrueString)
            .UseSetting(WebHostDefaults.SuppressStatusMessagesKey, bool.TrueString)
            .ConfigureKestrel(kestrel =>
            {
                kestrel.AddServerHeader = false;
                kestrel.AllowSynchronousIO = false;
                kestrel.Limits.KeepAliveTimeout = TimeSpan.FromSeconds(30);
                kestrel.Limits.MaxConcurrentConnections = 32;
                kestrel.Limits.MaxConcurrentUpgradedConnections = 0;
                kestrel.Limits.MaxRequestBodySize = 1024;
                kestrel.Limits.MaxRequestBufferSize = 16 * 1024;
                kestrel.Limits.MaxRequestHeaderCount = 32;
                kestrel.Limits.MaxRequestHeadersTotalSize = 16 * 1024;
                kestrel.Limits.MaxRequestLineSize = 2 * 1024;
                kestrel.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(10);
                kestrel.Listen(IPAddress.Loopback, 0, listen =>
                {
                    listen.Protocols = HttpProtocols.Http1;
                });
            });

        builder.Services.Configure<HostOptions>(host =>
        {
            host.ShutdownTimeout = TimeSpan.FromSeconds(5);
        });
        builder.Services.AddRouting();
        builder.Services.AddSingleton(hostFactsProvider ?? new RuntimeHostFactsProvider());
        builder.Services.AddSingleton<CapabilityService>();
        builder.Services.AddSingleton<ProcessSession>();
        builder.Services.AddSingleton<BoundLoopbackAuthority>();
        builder.Services.AddSingleton(
            EmbeddedAssetCatalog.Load(assetAssembly ?? typeof(ServerApp).Assembly));

        WebApplication app = builder.Build();
        ConfigurePipeline(app);
        return app;
    }

    public static async Task<int> RunAsync(CancellationToken cancellationToken = default)
    {
        WebApplication? app = null;

        try
        {
            app = Build();
            await app.StartAsync(cancellationToken).ConfigureAwait(false);
            Uri readyUri = PublishBoundAddress(app);
            Console.Out.WriteLine($"READY {readyUri.AbsoluteUri}");
            await app.WaitForShutdownAsync(cancellationToken).ConfigureAwait(false);
            await app.DisposeAsync().ConfigureAwait(false);
            app = null;
            Console.Out.WriteLine("STOPPED");
            return 0;
        }
        catch
        {
            Console.Error.WriteLine($"ERROR {StartupErrorCode}");
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
                    // The process is already failing closed. Keep console output bounded.
                }
            }
        }
    }

    public static Uri PublishBoundAddress(WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        IServer server = app.Services.GetRequiredService<IServer>();
        BoundLoopbackAuthority authority =
            app.Services.GetRequiredService<BoundLoopbackAuthority>();
        return authority.PublishFrom(server);
    }

    private static void ConfigurePipeline(WebApplication app)
    {
        BoundLoopbackAuthority authority =
            app.Services.GetRequiredService<BoundLoopbackAuthority>();
        ProcessSession session = app.Services.GetRequiredService<ProcessSession>();
        CapabilityService capabilityService =
            app.Services.GetRequiredService<CapabilityService>();
        EmbeddedAssetCatalog assets =
            app.Services.GetRequiredService<EmbeddedAssetCatalog>();

        app.Use(async (context, next) =>
        {
            SecurityHeaders.Apply(context.Response);

            try
            {
                await next(context).ConfigureAwait(false);
            }
            catch
            {
                if (context.Response.HasStarted)
                {
                    context.Abort();
                    return;
                }

                try
                {
                    context.Response.Clear();
                    SecurityHeaders.Apply(context.Response);
                    await ContractResponses.WriteErrorAsync(
                        context.Response,
                        StatusCodes.Status500InternalServerError,
                        ApiErrorCode.InternalError,
                        GenericErrorMessage,
                        CancellationToken.None).ConfigureAwait(false);
                }
                catch
                {
                    context.Abort();
                }
            }
        });

        app.Use(async (context, next) =>
        {
            RequestRejection? rejection =
                LoopbackRequestPolicy.EvaluateRequest(context.Request, authority.Value);

            if (rejection is not null)
            {
                if (rejection.StatusCode == StatusCodes.Status405MethodNotAllowed)
                {
                    string? rejectedTarget = context.Features
                        .Get<Microsoft.AspNetCore.Http.Features.IHttpRequestFeature>()?.RawTarget;
                    context.Response.Headers[Microsoft.Net.Http.Headers.HeaderNames.Allow] =
                        LoopbackRequestPolicy.AllowedMethodFor(rejectedTarget);
                }

                await ContractResponses.WriteErrorAsync(
                    context.Response,
                    rejection.StatusCode,
                    rejection.Code,
                    rejection.Message,
                    context.RequestAborted).ConfigureAwait(false);
                return;
            }

            await next(context).ConfigureAwait(false);
        });

        app.MapGet("/", async context =>
        {
            session.IssueCookie(context.Response);
            await WriteAssetAsync(context, assets, "/").ConfigureAwait(false);
        });

        app.MapGet("/app.css", context => WriteAssetAsync(context, assets, "/app.css"));
        app.MapGet("/app.js", context => WriteAssetAsync(context, assets, "/app.js"));

        app.MapGet("/healthz", context =>
            ContractResponses.WriteHealthAsync(
                context.Response,
                CapabilityService.GetHealth(),
                context.RequestAborted));

        app.MapGet("/api/v1/capabilities", async context =>
        {
            if (!session.IsAuthorized(context.Request.Headers))
            {
                await ContractResponses.WriteErrorAsync(
                    context.Response,
                    StatusCodes.Status401Unauthorized,
                    ApiErrorCode.Unauthorized,
                    "Authorization is required.",
                    context.RequestAborted).ConfigureAwait(false);
                return;
            }

            await ContractResponses.WriteCapabilitiesAsync(
                context.Response,
                capabilityService.GetCapabilities(),
                context.RequestAborted).ConfigureAwait(false);
        });

        app.MapPost("/api/v1/media-facts", async context =>
        {
            if (!session.IsAuthorized(context.Request.Headers))
            {
                await ContractResponses.WriteErrorAsync(
                    context.Response,
                    StatusCodes.Status401Unauthorized,
                    ApiErrorCode.Unauthorized,
                    "Authorization is required.",
                    context.RequestAborted).ConfigureAwait(false);
                return;
            }

            // No inspection configuration path exists yet, so the capability is
            // honestly unavailable and the endpoint says exactly that without
            // reading the body. The configured pipeline arrives with the D-046
            // wiring; until then this route exists so the request law, session
            // gate, and capability answer are real and tested rather than pending.
            await ContractResponses.WriteErrorAsync(
                context.Response,
                StatusCodes.Status503ServiceUnavailable,
                ApiErrorCode.CapabilityUnavailable,
                "The capability is unavailable.",
                context.RequestAborted).ConfigureAwait(false);
        });

    }

    private static async Task WriteAssetAsync(
        HttpContext context,
        EmbeddedAssetCatalog catalog,
        string route)
    {
        if (!catalog.TryGet(route, out EmbeddedAsset? asset) || asset is null)
            throw new InvalidOperationException("SRV_ASSET_ROUTE");

        context.Response.ContentType = asset.ContentType;
        context.Response.ContentLength = asset.Content.Length;
        await context.Response.Body.WriteAsync(asset.Content, context.RequestAborted)
            .ConfigureAwait(false);
    }
}
