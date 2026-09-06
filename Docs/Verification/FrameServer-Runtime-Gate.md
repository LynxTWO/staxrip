# FrameServer Runtime Gate

This gate is intentionally representative. It does not claim "full AviSynth and VapourSynth behavior," which is unbounded across runtime versions, plugins, scripts, media, and host state.

## Verified lifecycle failure

The current `VapourSynthServer` uses a process-wide resolved flag and entry-point pointer but unloads `VSScript.dll` through a per-instance handle. A focused x64 host loaded only `FrameServer.dll` and then performed two sequential create/open/read/release cycles against the controlled VSScript runtime.

- Attempt 1 printed `attempt=1 open=0 frame=0 pitch=8`.
- The process terminated before attempt 2 could report a result.
- The Windows process status was `0xC0000005`.
- Reproducer source: `.anti-dark-code/scratch/frameserver-reopen-probe.cpp`.
- Probe executable: `.anti-dark-code/scratch/results/frameserver-reopen-probe/frameserver-reopen-probe.exe`.
- FrameServer under test: the x64 integration build containing draft pull requests #1987 and #1988.
- Runtime under test: `.anti-dark-code/scratch/results/fix-vapoursynth-narrowing/fake-runtime/VSScript.dll`.

Confidence: **verified** for the sequential failure and its source lifetime mismatch. The final repair and representative real-runtime outcomes below are also **verified** for their exact tuples.

The earlier single-server boundary probe preloaded the controlled runtime so it could inspect a test counter. That extra library reference kept the module loaded and made the probe unsuitable for lifecycle verification.

## Regression gate for the lifetime fix

Commit `eec333a3` in draft pull request #1993 passed all required x64 checks:

1. Two sequential create/open/read/release cycles succeed in one process.
2. A missing-runtime failure does not prevent a later retry after the runtime becomes available.
3. Two overlapping server instances retain valid, instance-consistent library and API state.
4. Debug and Release builds pass for `FrameServer.vcxproj` and `StaxRip.sln`.
5. The native ABI, API version, error contract, and x64 target path remain unchanged.

The unchanged build failed the sequential, script-failure recovery, and overlap processes. The repaired build passed those three differential cases. It also passed a fourth preservation case in which the runtime was unavailable for the first open and became available for a later retry in the same process. A first per-instance ownership design passed packaged R73 but failed the R79 sequential case. The accepted design therefore serializes initialization and retains one validated VSScript module and entry point until process exit.

## Representative real-runtime matrix

The matrix ran against the standalone #1993 branch and against an integration build containing draft pull requests #1987, #1988, and #1993.

| Runtime | Cases | Result |
|---|---|---|
| Packaged VapourSynth R73 | Normal metadata and first/middle/last frames, UTF-8 script path, invalid script, sequential servers, overlap | 5/5 native; 2/2 packaged AutoCrop host |
| Packaged AviSynth+ 3.7.5 | Normal metadata and first/middle/last frames, active-code-page script path, invalid script, sequential servers, overlap | 5/5 native; 2/2 packaged AutoCrop host |
| VapourSynth R79 compatibility fixture | Normal metadata and first/middle/last frames, UTF-8 script path, invalid script, sequential servers, overlap | 5/5 native; 2/2 packaged AutoCrop host |

The integration build passed FrameServer and solution Debug and Release x64 with zero warnings. Its `FrameServer.dll` SHA-256 was `c793463341c9de3637eb00216b507a5a4ee9e3296121deb81f4dc4eba5bce14b`. The standalone #1993 build hash was `ea6c8c21c222c8651b9eeb0f23af563bb2c243eb969936dd911cce82ed2b3f95`.

## Dependency state

- GitHub release asset `StaxRip-v2.52.5-x64.7z`, asset id `506460866`, size `738815433`, matched GitHub's SHA-256 `3ced91af31743d6e6611c700c265066bd85cb6954c251bd3dc218209299dcdd0`.
- The packaged AviSynth tree contained 671 files and 346,763,306 bytes. Its path/size/file-hash closure digest was `357e12a370686486cb08ad52e7a42baed98c8de79f8220c22db19ff510418221`. `AviSynth.dll` reported version 3.7.5 and SHA-256 `8f7d07917e4b364df5fd7f1b8b3c1e135465d73325f8d25bc4354dd6435afab4`.
- The packaged VapourSynth tree contained 797 files and 76,745,342 bytes. Its closure digest was `1bce05242ec62944b1440a7623d82f05c6185c820e50ed107b785d177cd261b2`. Runtime inspection reported R73, API 4.1, and Python 3.13.9.
- The packaged AutoCrop tree contained three files and 103,099 bytes. Its closure digest was `22e7568269c1bccb82b481d5a7712ade29a079b02ce746d15e13d22ebb1fcc3c`.
- The official R79 outer archive matched SHA-256 `625b3410d903943107291592e90d6f521f829ebb8291d952ee91b8d674bbb153`. Its ABI3 wheel matched `643d9708df7e98807a66d4e8804e2e9a1380af22bea2873387d8af103e69aa5b` and reported R79, API 4.2, under the packaged Python 3.13.9 runtime.
- The active R79 compatibility tree contained 819 files and 137,049,089 bytes. Its closure digest was `7bd447c6239f2cfa76d388b3e8c3c510e3d684ff187b77dc1266cae02b92c772`.

## Relationship to x86 retirement

The real-runtime gate validates the native behavior changes in draft pull requests #1987, #1988, and #1993. Phase 1 x86/Win32 configuration removal in draft pull request #1992 has its own solution parsing, explicit/default configuration evaluation, six x64 builds, target-path checks, stale-configuration search, and five-file diff audit. Dependent Phase 2 removes the remaining internal runtime branches while preserving the public compatibility property. See `X86-Phase1.md`, `X86-Phase2.md`, and `Portable-X64-Validation.md`.

## Remaining limits

- Follow-up integration launched the full executable and exercised startup plus four representative source-opening workflows; it did not traverse every form or command.
- Follow-up integration exercised selected media, bundled plugins/scripts, and 5,000 lifecycles per engine. Arbitrary user inputs and multi-hour encode behavior remain unbounded.
- Build commands and release-equivalent scratch packaging were run. The destructive hard-coded pack scripts and release publication were not.
- The R79 fixture is a compatibility check, not evidence that v2.52.5 shipped R79.
