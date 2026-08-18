using System.Collections.ObjectModel;
using System.Reflection;

namespace StaxRip.Server;

public sealed record EmbeddedAsset(string Route, string ContentType, ReadOnlyMemory<byte> Content);

public sealed class EmbeddedAssetCatalog
{
    private const int MaximumAssetBytes = 256 * 1024;

    private static readonly (string Route, string ResourceName, string ContentType)[] Definitions =
    [
        ("/", "StaxRip.Server.Web.index.html", "text/html; charset=utf-8"),
        ("/app.css", "StaxRip.Server.Web.app.css", "text/css; charset=utf-8"),
        ("/app.js", "StaxRip.Server.Web.app.js", "text/javascript; charset=utf-8"),
    ];

    private static readonly ReadOnlyCollection<string> DefinedRoutes =
        Array.AsReadOnly(Definitions.Select(static definition => definition.Route).ToArray());

    private readonly IReadOnlyDictionary<string, EmbeddedAsset> _assets;

    private EmbeddedAssetCatalog(IReadOnlyDictionary<string, EmbeddedAsset> assets)
    {
        _assets = assets;
    }

    public IReadOnlyList<string> Routes => DefinedRoutes;

    public static EmbeddedAssetCatalog Load(Assembly assembly)
    {
        ArgumentNullException.ThrowIfNull(assembly);

        var assets = new Dictionary<string, EmbeddedAsset>(StringComparer.Ordinal);

        foreach ((string route, string resourceName, string contentType) in Definitions)
        {
            using Stream stream = assembly.GetManifestResourceStream(resourceName) ??
                throw new InvalidOperationException("SRV_ASSET_MISSING");

            if (stream.Length is < 1 or > MaximumAssetBytes)
                throw new InvalidOperationException("SRV_ASSET_SIZE");

            using var buffer = new MemoryStream((int)stream.Length);
            stream.CopyTo(buffer);

            if (!assets.TryAdd(route, new EmbeddedAsset(route, contentType, buffer.ToArray())))
                throw new InvalidOperationException("SRV_ASSET_DUPLICATE");
        }

        return new EmbeddedAssetCatalog(
            new ReadOnlyDictionary<string, EmbeddedAsset>(assets));
    }

    public bool TryGet(string route, out EmbeddedAsset? asset) =>
        _assets.TryGetValue(route, out asset);
}
