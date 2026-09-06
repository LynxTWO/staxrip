# Clean Build Dry Run

This report records two bounded contributor-build checks against commit `198223ea`. It is build evidence, not proof that the application or a distributable release works.

## Scope and safety

- Configuration: `Debug|x64` only.
- Build engine: Visual Studio Build Tools 2022 MSBuild 17.14.51.
- Available prerequisites: Visual C++ v143, Windows SDK 10.0.26100.0, and .NET Framework 4.8 reference assemblies.
- Deliberately excluded: dependency installation or restore, application execution, external-tool execution, packaging, `Source/Build.ps1`, `Source/BuildAndPack.ps1`, and `Source/Release.ps1`.
- Expected writes: ignored `Source/bin`, `Source/obj`, `Source/FrameServer/x64`, and `Source/Tools/AutoCrop/obj` build outputs.

## Exact checks and verdicts

### Main solution

```powershell
& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\StaxRip.sln' -t:Rebuild -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal
```

Verdict: **blocked** with exit code 1. `FrameServer.vcxproj` could not find `VSScript4.h`. The project expects it below the ignored path `Source/bin/Apps/FrameServer/VapourSynth/sdk/include/vapoursynth`.

### Managed StaxRip project

```powershell
& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\StaxRip.vbproj' -t:Rebuild -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal
```

Verdict: **blocked** with exit code 1. The clean checkout has no ignored `Source/packages` directory, so the DirectN reference did not resolve and Direct2D types were undefined. ManagedCuda was also unresolved. `Source/packages.config` declares the expected packages, but the repository does not document its restore command.

### AutoCrop support project

```powershell
& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\Tools\AutoCrop\AutoCrop.sln' -t:Rebuild -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal
```

Verdict: **passed** with exit code 0. The build emitted `AutoCrop.exe`, its config, and PDB under `Source/bin/Apps/Support/AutoCrop`. AutoCrop was not executed, and the successful compile does not verify its runtime `FrameServer.dll` dependency.

## Conclusion

A clean clone cannot currently complete the main source build from repository instructions alone. Two bootstrap inputs need maintainer guidance:

1. the supported NuGet restore command for the `packages.config` project;
2. the supported source or preparation step for the VapourSynth SDK and the broader ignored `Source/bin/Apps` tree.

The release configuration mapping also remains a separate open question: `Release|x64` maps StaxRip to `Debug|x64` while mapping FrameServer to `Release|x64`.

## Next check

An isolated follow-up tested one reproducible bootstrap while maintainer intent remains pending. This procedure is verified as a source compile, not as the official build or a release-equivalent process.

The questions are tracked upstream in [staxrip/staxrip#1985](https://github.com/staxrip/staxrip/issues/1985).

## Prepared source-build follow-up

The follow-up ran on 2026-08-10 in a detached clean worktree at commit `198223ea`. It did not reuse the ignored outputs from the first check.

### Dependency provenance

The managed restore used only `https://api.nuget.org/v3/index.json` and the exact versions in `Source/packages.config`. `dotnet nuget verify --all` accepted all three NuGet.org repository signatures.

| Package | Version | SHA-256 of restored `.nupkg` |
|---|---:|---|
| DirectN | 1.5.0 | `d56d9f1db10caebe1fc2df5b6de7591510c3ec602903d8a3567061244b96ab92` |
| ManagedCuda-100 | 10.0.31 | `46cdb41e1d839ac61f6709981845327f00bc765f5069ffb027f755f6c99044e1` |
| Microsoft.PowerShell.5.ReferenceAssemblies | 1.1.0 | `2bc5ab45f20bfa5d9d141611cf8b68c23a8d94371f01bcea65e5f71a86deea45` |

The repository links to the official VapourSynth releases but does not pin a source tag. R79 was selected for this experiment because it was the current stable release when StaxRip v2.52.5 was published. The tag resolved to commit `acabf605b2205b32d65859bb2736405719d2fafd`.

The official R79 portable archive had the published SHA-256 `625b3410d903943107291592e90d6f521f829ebb8291d952ee91b8d674bbb153`, but it did not contain the SDK headers. The following files were copied from the R79 source tag:

| Header | SHA-256 |
|---|---|
| `VSScript4.h` | `e8a30bfe5422bb1bc04bc7cab65044f02ac3feb62d8ed022e569ab6b317478bf` |
| `VSHelper4.h` | `73bfdccee359b2a07e5fe30dc95017991378dddc854f82f48befc976ef2afa3a` |
| `VapourSynth4.h` | `ba486da1599cfa3358188760fbd5095e0dc1d19c39cd56bc0f368fb8904bc80b` |

Compilation verifies header compatibility for this source revision. It does not verify runtime ABI compatibility with VapourSynth R79.

### Build results

All commands used MSBuild 17.14.51, MSVC 14.44.35207, Windows SDK 10.0.26100.0, and .NET Framework 4.8 reference assemblies.

| Target | Configuration | Exit | Unique warnings | Observed output |
|---|---|---:|---:|---|
| `StaxRip.vbproj` | `Debug|x64` | 0 | 0 | `Source/bin/StaxRip.exe` |
| `StaxRip.vbproj` | `Release|x64` | 0 | 0 | `Source/bin/StaxRip.exe` |
| `FrameServer.vcxproj` | `Debug|x64` | 0 | 0 | `Source/bin/FrameServer.dll` |
| `FrameServer.vcxproj` | `Release|x64` | 0 | 10 | `Source/bin/FrameServer.dll` |
| `StaxRip.sln` | `Debug|x64` | 0 | 0 | StaxRip Debug and FrameServer Debug |
| `StaxRip.sln` | `Release|x64` | 0 | 10 | StaxRip Debug and FrameServer Release |
| `AutoCrop.sln` | `Debug|x64` | 0 | 0 | `Source/bin/Apps/Support/AutoCrop/AutoCrop.exe` |
| `AutoCrop.sln` | `Release|x64` | 0 | 0 | `Source/Tools/AutoCrop/bin/x64/Release/AutoCrop.exe` |

The ten native Release warnings were C4244 and C4267 conversions in `Common.cpp` and `VapourSynthServer.cpp`. They did not fail the current project settings.

The AutoCrop Release build modified the tracked `AutoCrop.exe` and `AutoCrop.pdb` files in its output directory. Native intermediate files also appeared under an unignored nested `Source/FrameServer/FrameServer` directory. These are build side effects, not source edits.

### Configuration comparison

- Direct StaxRip Debug defined `CONFIG="Debug"`, `DEBUG`, and `TRACE` and used `/debug:Full`.
- Direct StaxRip Release defined only `CONFIG="Release"` and did not pass `/debug` or `/optimize+`.
- Solution Debug and solution Release both compiled StaxRip with the Debug constants and full debug information.
- Solution Release compiled FrameServer with `/O2`, `/Oi`, `NDEBUG`, the release CRT, function-level linking, and reference optimization.
- IL inspection found one `Trace.TraceInformation` call in direct Debug and none in direct Release. That call implements `GlobalClass.WriteDebugLog`.
- After build-identity lines and the generated output-path warning were excluded, solution Debug and solution Release produced identical managed IL. Their native DLLs differed as expected.

Keeping `TRACE` active may explain why the solution maps StaxRip Release to Debug, but that intent remains `unknown` until a maintainer confirms it.

### Remaining limits

- No StaxRip, FrameServer, or AutoCrop runtime was launched.
- No AviSynth or VapourSynth script was opened.
- The full portable `Apps` tree was not reconstructed or validated.
- x86 configurations were not built. The user confirmed on 2026-08-10 that current StaxRip builds are x64-only, so legacy x86 entries are not a contributor verification gate.
- `Source/Build.ps1`, `Source/BuildAndPack.ps1`, and `Source/Release.ps1` were not executed.
- No release archive was produced or compared with the official v2.52.5 archive.

## Native warning remediation follow-up

Two independent branches addressed the ten native Release warnings without changing a project file or ABI layout.

| Branch or combination | FrameServer Release x64 | Solution Release x64 | Result |
|---|---:|---:|---|
| `agent/frameserver-string-conversions` (`d8dfc00f`) | 3 warnings | 3 warnings | Seven `Common.cpp` warnings removed; draft pull request #1987 |
| `agent/vapoursynth-narrowing-guards` (`74e15053`) | 7 warnings | 7 warnings | Three `VapourSynthServer.cpp` warnings removed; draft pull request #1988 |
| Both commits on `198223ea` | 0 warnings | 0 warnings | Both Release x64 builds passed |

The string probe compared the unchanged and fixed implementations with ASCII, Unicode, embedded-NUL, empty-input, and Windows error-message cases. The unchanged implementation failed the embedded-NUL and error-length checks. Commit `d8dfc00f` passed all cases and compiled the probe at `/W4` with zero warnings.

The VapourSynth boundary probe loaded the built `FrameServer.dll` with a controlled fake `VSScript.dll` in separate x64 processes. The normal case opened and returned a frame with pitch 8. A frame-rate component of `2147483648` failed during `OpenFile`. A stride of `2147483648` failed during `GetFrame`, cleared the output pointer and pitch, and freed the acquired frame once. The unchanged DLL accepted both overflow cases and exposed negative 32-bit values.

These probes verify branch activation and cleanup for the controlled inputs. A later follow-up completed the representative R73, R79, AviSynth, and packaged AutoCrop matrix in `Docs/Verification/FrameServer-Runtime-Gate.md`. Packaging and release output remain unverified. Unsupported x86 configurations are intentionally outside the contributor gate.

A follow-up lifecycle probe found a separate sequential-server failure. Its evidence and the bounded real-runtime plan are recorded in `Docs/Verification/FrameServer-Runtime-Gate.md`.

## Build-output hygiene follow-up

The baseline x64 FrameServer builds created 42 untracked intermediate files under `Source/FrameServer/FrameServer/x64`: 22 Debug files totaling 2,944,360 bytes and 20 Release files totaling 941,071 bytes. MSBuild evaluated the x64 `IntDir` values as `FrameServer\x64\Debug\` and `FrameServer\x64\Release\`. Both Win32 property groups instead set `IntDir` to `$(Platform)\$(Configuration)\`, and `.gitignore` excludes the resulting direct `Source/FrameServer/x64` tree.

An integration worktree tested concrete command-line overrides of `x64\Debug\` and `x64\Release\`. Both targeted builds passed, retained `Source/bin/FrameServer.dll` as `TargetPath`, wrote intermediates under the ignored direct x64 tree, and left `git status` clean. The first probe attempted to pass `$(Platform)\$(Configuration)\` as a command-line global property. MSBuild preserved that text literally, created a literal `$(Platform)` directory, and failed with C1041 and LNK1181. That result was a probe-construction error, not a source defect. The exact generated directory was moved to `.anti-dark-code/scratch/generated-cleanup/20260810-intdir-probe`.

The AutoCrop Release x64 rebuild changed the tracked executable blob from `a48184cf` to `efa857c6` and the tracked PDB blob from `08f1b6a6` to `65714fdc`; both file sizes remained unchanged. The executable and PDB were introduced with an AutoCrop source fix in commit `10194975` and updated together in five later feature commits through `b8189eec`. A scan of 275 tracked text files found the three relevant path declarations only in `AutoCrop.vbproj`. No tracked build or release script invokes `AutoCrop.sln` or stages the Release directory.

After approval, commit `bf855df7` added the explicit `IntDir` value to both x64 property groups. The edited project parsed as XML. Debug x64 passed with zero warnings and errors. Release x64 passed with the ten known conversion warnings and zero errors. Both configurations evaluated to the direct ignored x64 tree, retained `Source/bin/FrameServer.dll` as the target, and did not recreate the nested default directory. Draft pull request #1989 contains one project file and two added elements.

The AutoCrop policy remains deferred until the maintainer identifies the artifact and staging contract. No ignore, binary, packaging, release, solution mapping, or legacy x86 configuration changed in this follow-up.

## Runtime and x86 retirement follow-up

On 2026-08-11, the exact v2.52.5 package runtime was staged from a GitHub-digest-matched archive. The representative AviSynth+ 3.7.5, packaged VapourSynth R73, VapourSynth R79 compatibility, and packaged AutoCrop cases passed with the process-lifetime repair. The same matrix passed when combined with draft pull requests #1987 and #1988. Exact versions, hashes, cases, and limits are recorded in `Docs/Verification/FrameServer-Runtime-Gate.md`.

Phase 1 x86/Win32 configuration retirement passed its separate structural and six-build gate and opened as draft pull request #1992. The exact scope and limits are recorded in `Docs/Verification/X86-Phase1.md`.
