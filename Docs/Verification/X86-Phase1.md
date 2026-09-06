# X86 Configuration Retirement Phase 1

Phase 1 is commit `e10d99cf` in draft pull request #1992. It changes exactly five solution and project files. It does not edit runtime architecture branches, package fields, scripts, tracked binaries, output paths, or ignore rules.

## Scope

- Removed Debug and Release x86 solution mappings from `Source/StaxRip.sln`.
- Removed Debug and Release x86 property groups from `Source/StaxRip.vbproj`.
- Removed Debug and Release Win32 configurations from `Source/FrameServer/FrameServer.vcxproj`.
- Removed Debug and Release x86 solution mappings from `Source/Tools/AutoCrop/AutoCrop.sln`.
- Removed Debug and Release x86 property groups from `Source/Tools/AutoCrop/AutoCrop.vbproj`.
- Set an omitted direct-project platform to x64 in all three project files.

The C++ `Win32Proj` keyword and old .NET bootstrapper display names containing `x86` remain because they are not build configurations.

## Deterministic results

- Three edited project files parsed as XML.
- Debug and Release x64 configuration validation passed in both solutions.
- Both solutions rejected `Debug|x86` with MSBuild error `MSB4126`.
- Omitted-platform and explicit-x64 property evaluation matched for StaxRip, FrameServer, and AutoCrop.
- Direct Debug and Release x64 rebuilds passed for StaxRip, FrameServer, and AutoCrop.
- Target paths remained `Source/bin/StaxRip.exe`, `Source/bin/FrameServer.dll`, the Debug AutoCrop support path, and the existing tracked Release AutoCrop path.
- The final diff contained only the five approved files and passed `git diff --check`.

FrameServer Release retained the ten known upstream conversion warnings. Phase 1 introduced no new warning class. The generated AutoCrop Release executable and PDB were restored after their hashes were observed, so they are not part of the commit.

## Limits

No destructive packaging or release script ran for Phase 1. An out-of-repository command that requests an obsolete solution configuration will need to select x64. Phase 2 is now implemented and verified separately in `X86-Phase2.md`; its public `Filename32` property is preserved as obsolete for compatibility. The combined portable/runtime/package evidence is in `Portable-X64-Validation.md`.
