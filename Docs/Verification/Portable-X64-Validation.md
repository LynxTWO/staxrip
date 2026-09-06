# Portable x64 Validation

## Scope

This record validates a private integrated x64 candidate built from upstream commit
`198223ead4519be0c8f1c389eb90ccfb379c4307` plus the proposed x64 configuration,
runtime cleanup, FrameServer build-hygiene, conversion, narrowing, and VapourSynth
lifetime changes. It is a representative release-readiness exercise, not a claim that
every StaxRip workflow, media format, plugin, encoder, or machine has been tested.

The checked-in release scripts were not invoked because they contain destructive,
hard-coded targets under `A:\StaxRip-Releases`. Their copy, exclusion, and archive
contracts were reproduced under `.anti-dark-code/scratch/portable-validation`.
Nothing was published.

## Candidate identity

The private integration branch contains these commits in order:

1. `e10d99cf` - retire unsupported x86/Win32 configurations (Phase 1)
2. `ed32aae0` - remove unsupported runtime x86 branches (Phase 2)
3. `9be8c0d0` - explicit Win32 string conversion results
4. `98985ba5` - checked VapourSynth narrowing
5. `bc453e33` - isolated FrameServer intermediate directories
6. `44b7a686` - remove the unused updater architecture parameter
7. `6ac167a8` - retain the validated VapourSynth module for process lifetime

Both Debug x64 and Release x64 solution builds completed with zero warnings and zero
errors. The release candidate binaries were:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `StaxRip.exe` | 3,840,512 | `e2378c3eafca24d7097bebbd6ab58178d57eaf037198d20c8231ce08c16bdbf3` |
| `StaxRip.pdb` | 3,651,072 | `0c9350c09cba2a1a8903b47e588c852cfa3406441febcf430a70e81a64ee9841` |
| `FrameServer.dll` | 33,280 | `221c506fe400124ec15e16b520284b797a18582bc252f39da6d3df2900aa97bf` |

The PE inspection identified the managed executable and native DLL as x64/PE32+.

## Portable base

The official `StaxRip-v2.52.5-x64.7z` asset was used as the prepared runtime tree.
It matched SHA-256
`3ced91af31743d6e6611c700c265066bd85cb6954c251bd3dc218209299dcdd0`.
The extracted tree contained 3,928 files and 3,302,659,437 bytes before the candidate
binaries were overlaid.

Settings were redirected through the existing per-startup-path registry mapping to
unique scratch directories. The exact prior registry value was restored after each
probe. The harness terminated only the process it launched.

## Script and plugin matrix

Four synthetic, non-sensitive media fixtures were generated with the packaged
FFmpeg:

| Fixture | Purpose |
| --- | --- |
| H.264/AAC MP4, 320x180 | common AVC plus audio path |
| VP9/Opus WebM, 256x144 | alternate container, codec, and audio path |
| 10-bit 4:4:4 FFV1/24-bit PCM MKV, 192x108 | high-bit-depth and lossless path |
| VFR FFV1 MKV, 160x120 | variable frame-duration path |

The x64 probe loaded the candidate `FrameServer.dll`, opened each generated script,
read frames 0, 5, and 9, checked stream metadata and pitch, then released the server.
All ten cases passed:

- AviSynth bundled-filter fixture using AddGrainC and core conversion
- VapourSynth bundled-filter fixture using AddGrain and LibP2P
- four AviSynth FFMS2 media scripts
- four VapourSynth FFMS2 media scripts

The VapourSynth fixtures declare the YUV-to-RGB input matrix explicitly. Earlier
failures were reproduced with `VSPipe` and traced to incomplete fixture color metadata,
not to the candidate FrameServer.

Evidence: `.anti-dark-code/scratch/results/portable-validation/runtime-script-matrix.json`.

## GUI operation

The UI harness verified a fresh portable startup, discovered the custom owned
changelog window through UI Automation, activated its default `OK` action, and then
captured the unobstructed main window. The result was responsive, exposed 93 main
window automation elements, and exited with code 0.

The four media fixtures were then opened through StaxRip's own command-line and GUI
workflow using an explicit `Automatic Workflow` template and hidden source-selection
dialogs. StaxRip populated the expected source, target, filter, audio, and job controls:

| Fixture | Observed UI identity |
| --- | --- |
| H.264/AAC | 320x180, YUV 4:2:0 8-bit AVC; AAC LC 48 kHz |
| VP9/Opus | 256x144, 4:2:0 8-bit VP9; Opus 48 kHz |
| FFV1/PCM | 192x108, YUV 4:4:4 10-bit FFV1; PCM 24-bit 48 kHz |
| VFR FFV1 | 160x120, YUV 4:2:0 8-bit FFV1 with VFR source timing |

Each observed process was responsive. The harness selected `Don't Save` in the
expected modified-project close prompt and required exit code 0. Loading the template
must precede `-SetHideDialogsOption:true`; reversing those arguments modifies the
current project before template loading and correctly opens a save prompt.

Evidence: `gui-candidate-unblocked-9.json` and the `gui-source-*-verified*.json`
records under `.anti-dark-code/scratch/results/portable-validation`.

## Bounded lifecycle soak

After ten warm-up iterations per engine, the probe performed 5,000 measured
create/open/read/release cycles for AviSynth and another 5,000 for VapourSynth. It
sampled process resources every 250 iterations.

| Engine | Elapsed | Handles | Net private growth | Maximum private bytes | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| AviSynth | 125.385 s | 149 -> 149 | 29,462,528 | 36,392,960 | PASS |
| VapourSynth | 123.725 s | 143 -> 143 | 29,544,448 | 44,638,208 | PASS |

The gate allowed at most eight net handles and 64 MiB net private-memory growth.
Samples show stepwise lazy allocation with flat handles; this is evidence against an
obvious per-session leak for the exact fixtures, not proof that all long-running jobs
are leak-free.

Evidence: `soak-avs-5000.log`, `soak-vs-5000.log`, and
`soak-5000-summary.json`.

## Packaging contract

The release source-policy scan checked 86 applicable project files and found zero
non-ASCII violations. The release exclusion expression passed a ten-case sentinel
matrix, including the intended rule that `eac3to.ini` is retained while unrelated
`.ini` files are excluded.

The filtered staging copy contained exactly 3,928 files and 3,302,686,573 bytes, with
zero missing or unexpected files. The EXE-only archive contained exactly
`StaxRip.exe` and `StaxRip.pdb` and passed `7z test`.

The full archive used the exact `Release.ps1` compression arguments. It took 1,038.3
seconds and consumed approximately 10.3 GiB private memory during compression. The
result was 738,816,342 bytes with SHA-256
`9605a91b603f78f87bcda04f257bc72784579126cc376b864406a416a8944275`.
Independent `7z test` reported 661 folders, 3,928 files, and 3,302,686,573 unpacked
bytes. Manifest comparison found:

- zero missing members
- zero unexpected members
- zero forbidden members
- all required StaxRip, FrameServer, AviSynth, and VapourSynth files present
- packaged candidate binary hashes identical to the tested inputs

The EXE-only archive SHA-256 is
`1836b0b00c6ecaa1190dea3b55f7a66b790895fb04625a19ea3936d679e44e3a`.

Evidence: `.anti-dark-code/scratch/portable-validation/package-output-2/`.

## Verified boundary and remaining unknowns

Verified for the recorded candidate and fixtures:

- Debug and Release x64 compilation
- x64 binary identity
- fresh portable startup and changelog dismissal
- representative StaxRip GUI source loading
- representative AviSynth and VapourSynth scripts and bundled plugins
- 10,000 repeated frame-server lifecycles
- release-equivalent copy, exclusion, archive, integrity, and manifest closure

Not established:

- arbitrary user media, scripts, or third-party plugins
- full interactive coverage of every StaxRip form and command
- real hardware encoder execution and driver-specific behavior
- multi-hour encoding, suspend/resume, cancellation, or disk-full recovery
- live tool updates, StaxRip self-update, or untrusted archive handling
- reproducible provenance for every bundled executable in the ignored Apps tree
- invocation of the hard-coded release scripts or publication of a release

