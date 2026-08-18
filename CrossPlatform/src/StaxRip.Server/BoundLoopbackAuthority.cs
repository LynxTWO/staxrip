using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;

namespace StaxRip.Server;

public sealed class BoundLoopbackAuthority
{
    private const string Prefix = "http://127.0.0.1:";

    private string? _value;

    public string? Value => Volatile.Read(ref _value);

    public Uri PublishFrom(IServer server)
    {
        ArgumentNullException.ThrowIfNull(server);

        IServerAddressesFeature? feature = server.Features.Get<IServerAddressesFeature>();
        string[] addresses = feature?.Addresses.ToArray() ?? [];

        if (addresses.Length != 1 || !TryCanonicalize(addresses[0], out string? authority))
            throw new InvalidOperationException("SRV_ADDRESS_POLICY");

        if (Interlocked.CompareExchange(ref _value, authority, null) is not null)
            throw new InvalidOperationException("SRV_ADDRESS_ALREADY_SET");

        return new Uri(authority + "/", UriKind.Absolute);
    }

    public static bool TryCanonicalize(string? address, out string? authority)
    {
        authority = null;

        if (address is null ||
            !Uri.TryCreate(address, UriKind.Absolute, out Uri? parsed) ||
            !string.Equals(parsed.Scheme, Uri.UriSchemeHttp, StringComparison.Ordinal) ||
            !string.Equals(parsed.Host, "127.0.0.1", StringComparison.Ordinal) ||
            parsed.Port is <= 0 or > 65_535 ||
            parsed.UserInfo.Length != 0 ||
            parsed.AbsolutePath != "/" ||
            parsed.Query.Length != 0 ||
            parsed.Fragment.Length != 0)
        {
            return false;
        }

        string candidate = Prefix + parsed.Port;

        if (!string.Equals(address, candidate, StringComparison.Ordinal))
            return false;

        authority = candidate;
        return true;
    }
}
