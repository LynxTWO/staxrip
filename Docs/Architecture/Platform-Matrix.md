# StaxRip Cross-Platform Matrix

Version: 0.3. Date: 2026-08-16.

This matrix separates current support, implemented source, pre-freeze local evidence, pending final verification, and later targets. Source presence, a pre-freeze pass, and `Planned` are not support claims.

## Product matrix

| Surface | Windows x64 | Linux x64 | macOS arm64 | macOS x64 |
|---|---|---|---|---|
| Current StaxRip WinForms application | Supported current application | Not available | Not available | Not available |
| Cross-platform contracts and core | Debug and Release builds and contracts pass | Exact self-contained tree passes local WSL runtime contract | Implemented source; macOS build and runtime deferred | Implemented source; demand and runtime evidence unknown |
| Local engine host | Hardened Release HTTP gate has a pre-freeze local pass; final source-bound audit pending | Loopback, HTTP, sandbox, and shutdown gates pass in WSL; local test only | Implemented source; macOS runtime deferred | Implemented source; demand and runtime evidence unknown |
| First-party web shell | Hardened installed Edge gate has a pre-freeze local pass; final source-bound audit pending | Shell and same-origin API pass in WSL; no Linux GUI-browser run | Implemented source; macOS browser/runtime evidence deferred | Implemented source; demand and runtime evidence unknown |
| Native desktop client | Existing WinForms remains | Deferred candidate | Deferred candidate | Deferred candidate |
| Media inspection | Current workflows | Next portability slice | Deferred | Deferred |
| Command and script preview | Current workflows | Planned | Deferred | Deferred |
| Encoding | Current workflows | Planned after guarded adapters | Deferred | Deferred |
| Queue and recovery | Current workflows | Deferred | Deferred | Deferred |
| Public binary | No fork public binary approved; upstream releases are separate | Not approved | Not approved | Not approved |

## Build and runtime matrix

| Tuple | Build source | Runtime evidence required | Current state |
|---|---|---|---|
| Current app, Windows x64, Debug | Visual Studio/MSBuild, .NET Framework 4.8 | Existing bounded build and runtime gates | verified in prior slice evidence |
| Current app, Windows x64, Release | Visual Studio/MSBuild, .NET Framework 4.8 | Direct project and solution mapping recorded separately | verified in prior slice evidence |
| Bootstrap, Windows x64, Debug | `dotnet` SDK 10 | Contract tests and server startup | build and 23-case, 309-assertion contract pass; standalone hostile HTTP matrix not run in Debug |
| Bootstrap, Windows x64, Release | `dotnet` SDK 10 | Contract tests and server startup | build and 23-case contract pass at the recorded checkpoint; latest pre-freeze hardened HTTP and Edge gates pass 4,532 and 758 checks; final committed rerun pending |
| Bootstrap, Linux x64, self-contained | Windows `dotnet publish` | ELF check and non-root WSL runtime gates | exact manifested artifact passes 27-check WSL sandbox; no Linux SDK or runtime installed |
| Bootstrap, independent Linux x64 | Same immutable Linux artifact | Repeat smoke gates on the Tailscale peer | ran there on 2026-08-17 and passed 27 checks, but only while a host mitigation was temporarily relaxed and then restored; blocked by R-S2-039 under the normal configuration |
| Bootstrap, macOS arm64 | Later SDK runner | Build plus actual macOS runtime gate | deferred by P-008 |

The dependency closure is also a build input. Its latest clean 398-check restore derives the exact three 10.0.11 package downloads from five reviewed asset and lock pairs. Schema v2 keeps the NuGet registry content hash, raw archive digests, signature identity, and extracted identity distinct. It binds each signed archive payload and the complete extracted disk inventory by canonical SHA-256, file count, and total bytes. The negative nuspec byte and line-ending mutation failed closed. Focused final-auditor input and inventory probes pass, but full `port-evidence` and independent re-review remain pending for the committed checkpoint.

## Framework facts and choices

| Item | Evidence | Portability use |
|---|---|---|
| .NET 10 | Microsoft lists .NET 10 as an active LTS release through 2028-11-14 | Selected for the isolated bootstrap; no change to the .NET Framework 4.8 app |
| Self-contained publish | Microsoft documents runtime-specific self-contained and single-file deployment | Use self-contained Linux x64 test output because WSL has no .NET runtime; single-file is not required yet |
| .NET MAUI | Microsoft lists Android, iOS, macOS, Windows, and Tizen; Linux is not a supported target | Not selected for the native desktop client |
| Avalonia | Avalonia documents Windows, macOS, and Linux desktop support; X11 is the current default Linux backend | Candidate for a later native-client proof, not a bootstrap dependency |
| ASP.NET Core Kestrel | Microsoft documents endpoint configuration and loopback binding | Selected host technology for the local bootstrap |

## Tool adapter discovery matrix

Availability means only that an executable or runtime can be identified. Compatibility needs version, invocation, fixture, and failure evidence.

| Capability | Windows integration today | Linux path to investigate | macOS path to investigate | First allowed action |
|---|---|---|---|---|
| Media facts | MediaInfo and tool-specific probes | FFprobe read-only adapter | Same contract with macOS resolver | Inspect one synthetic file |
| VapourSynth | Bundled Windows runtime and generated `.vpy` | Distribution/runtime and plugin manifest | Framework/runtime and plugin manifest | Render and hash a known frame graph |
| AviSynth+ | Windows runtime, plugins, frame server | Upstream Unix build and plugin ABI | Upstream macOS build and plugin ABI | Decide supported engine posture |
| Software encode | Windows FFmpeg and encoder packages | FFmpeg package or approved bundle | FFmpeg package or approved bundle | Preview argv before execution |
| NVIDIA encode | Windows NVEncC and driver | NVEncC Linux plus NVIDIA driver | Not applicable on Apple Silicon; unknown on older Intel systems | Capability probe, then one synthetic encode |
| Matroska tools | Windows MKVToolNix package | Linux MKVToolNix | macOS MKVToolNix | Read version, then fixture mux |
| Windows-only helpers | Registry, COM, `.dll`, `.exe`, shell tools | Replace, adapt, disable, or defer per row | Replace, adapt, disable, or defer per row | Honest unsupported capability |

## Verification hosts

| Host | Purpose | Constraint | Evidence posture |
|---|---|---|---|
| Windows development host | Fast builds, contract tests, Windows regression gates, Linux cross-publish | Ryzen 9 5950X, RTX 3060 12 GB, 64 GB RAM | Use bounded parallelism; do not translate host power into a product requirement |
| Local WSL Ubuntu | First Linux x64 runtime and socket checks | Shares the development machine; no .NET runtime or SDK installed | Self-contained artifact passes as non-root with zero observed state writes and children; proves Linux runtime, not independent-host behavior |
| Network Ubuntu peer | Intended second-host compatibility and low-resource check | Older Lenovo T540p; reachable over Tailscale SSH as of 2026-08-17; Ubuntu 24.04.4, kernel 7.0.0-28-generic, x86-64, ext4, non-root account, dotnet present; glibc version still unrecorded | The artifact ran there without rebuilding on 2026-08-17, though only while a host mitigation was temporarily relaxed and then restored; the sandbox isolation prerequisite is unavailable under the normal configuration (R-S2-039) |
| Future macOS arm64 host | macOS runtime, native dependencies, UI, signing, and notarization | Not available | Required before any macOS support claim |

## Primary platform references

- .NET support policy: https://dotnet.microsoft.com/en-us/platform/support/policy
- .NET application publishing: https://learn.microsoft.com/dotnet/core/deploying/
- Kestrel endpoints: https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/endpoints
- .NET MAUI supported platforms: https://learn.microsoft.com/dotnet/maui/what-is-maui
- Avalonia supported platforms: https://docs.avaloniaui.net/docs/supported-platforms
- VapourSynth: https://github.com/vapoursynth/vapoursynth
- AviSynth+: https://github.com/AviSynth/AviSynthPlus
- NVEncC: https://github.com/rigaya/NVEnc
- MKVToolNix downloads: https://mkvtoolnix.download/downloads.html
