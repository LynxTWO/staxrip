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
        Assembly? assetAssembly = null,
        MediaInspectionConfiguration? mediaInspection = null)
    {
        // The one activation judgment for media inspection, made here at the
        // composition root so the published capability and the endpoint behavior can
        // never disagree: explicit configuration, at least one media root, and a
        // resolvable tool binary. The version range is enforced on every probed
        // document because the version travels in the document itself.
        bool mediaInspectionAvailable = mediaInspection is not null &&
            !mediaInspection.PathPolicy.MediaRoots.IsDefaultOrEmpty &&
            MediaFileProbe.IsRegularFile(mediaInspection.Authority.ExecutablePath);

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
        IHostFactsProvider factsProvider = hostFactsProvider ?? new RuntimeHostFactsProvider();
        builder.Services.AddSingleton(factsProvider);
        builder.Services.AddSingleton(new CapabilityService(factsProvider, mediaInspectionAvailable));
        builder.Services.AddSingleton<ProcessSession>();
        builder.Services.AddSingleton<BoundLoopbackAuthority>();
        builder.Services.AddSingleton(
            EmbeddedAssetCatalog.Load(assetAssembly ?? typeof(ServerApp).Assembly));

        WebApplication app = builder.Build();
        ConfigurePipeline(app, mediaInspectionAvailable ? mediaInspection : null);
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

    private static void ConfigurePipeline(WebApplication app, MediaInspectionConfiguration? mediaInspection)
    {
        BoundLoopbackAuthority authority =
            app.Services.GetRequiredService<BoundLoopbackAuthority>();
        IMediaFactAuthority? mediaAuthority = mediaInspection is null
            ? null
            : new MediaInfoCliAuthority(mediaInspection.Authority);
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

                // D-052. This rejection answers without reading the request body, so the
                // connection cannot be reused: the unread bytes would be parsed as the
                // start of the next request. The connection closes either way. What this
                // header changes is whether the client knows, because a client told
                // nothing is entitled to treat the connection as reusable, return it to
                // its pool, and send the next request into a close it cannot see coming.
                // POST is not idempotent, so a correct client will not silently retry,
                // and the race surfaces to the caller as an I/O error with no status.
                // Measured at roughly 1 percent of oversized-then-next request pairs
                // before this line existed. The predicate is the policy's own, so the
                // rule cannot drift from the law that decides a body is present.
                if (!LoopbackRequestPolicy.IsBodyless(context.Request))
                {
                    context.Response.Headers[Microsoft.Net.Http.Headers.HeaderNames.Connection] =
                        "close";
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

            // The endpoint and the published capability share one verdict, decided
            // at the composition root: unconfigured or unresolvable means
            // unavailable, said plainly without reading the body.
            if (mediaInspection is null || mediaAuthority is null)
            {
                await ContractResponses.WriteErrorAsync(
                    context.Response,
                    StatusCodes.Status503ServiceUnavailable,
                    ApiErrorCode.CapabilityUnavailable,
                    "The capability is unavailable.",
                    context.RequestAborted).ConfigureAwait(false);
                return;
            }

            await MediaFactsHandler.HandleAsync(context, mediaInspection, mediaAuthority).ConfigureAwait(false);
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
