using StaxRip.Contracts;

namespace StaxRip.Core;

public interface IHostFactsProvider
{
    HostFacts Capture();
}
