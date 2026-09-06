# StaxRip System Map

This is an evidence-backed map of commit `198223ea` on `master` plus the isolated pull-request branches named below. Configuration found in source is marked `configured-not-observed` until the exact build or runtime path is exercised. Bounded build checks ran on 2026-08-09 and 2026-08-10; the runtime and x86 retirement checks ran on 2026-08-11. Their exact scope and results are recorded under `Docs/Verification/`.

## 1. System summary

- **Repository type:** Mixed Windows desktop application with managed, native, scripting, and external-process components.
- **Main runtime model:** `StaxRip.exe` is a VB.NET Framework 4.8 Windows Forms application. It opens media and serialized projects, generates AviSynth or VapourSynth scripts and command lines, then coordinates external tools. `FrameServer.dll` crosses the managed/native boundary. `AutoCrop.exe` is a separate support process.
- **Main data stores:** Local binary settings, profiles, events, jobs, and `.srip` project or template files; Windows Registry values; generated scripts, logs, temp files, and output media on disk.
- **Main external dependencies:** Bundled or user-selected encoders, muxers, demuxers, frame servers, plugins, Python, PowerShell, native Windows APIs, NuGet packages, and GitHub release endpoints.
- **Highest-risk domains:** Serialized input, script execution, command construction, executable download and replacement, parallel processing, temp deletion, output publication, native interop, and release packaging.
- **Non-obvious entrypoints:** Command-line commands, event commands, PowerShell auto-load folders, the Apps Manager update path, and three local build or release scripts.

## 2. Runtime units and entrypoints

| Unit | What it does | Where it lives | How it starts | Depends on | Triggered by | Data or side effects | Reachability |
|---|---|---|---|---|---|---|---|
| `StaxRip.exe` | Presents the GUI and coordinates projects, scripts, jobs, tools, and outputs | `Source/StaxRip.vbproj` | `Startup.Main`, then `MainForm` | .NET Framework 4.8, NuGet references, runtime `Apps` tree, Windows APIs | User launch or a second StaxRip process | Reads and writes settings, projects, jobs, logs, temp data, and output media; launches tools | direct and solution x64 builds verified; portable startup and four representative GUI source workflows observed on the integration candidate |
| `FrameServer.dll` | Opens AviSynth or VapourSynth scripts and exposes frame data to managed callers | `Source/FrameServer/` | Exported `CreateAviSynthServer` or `CreateVapourSynthServer` functions loaded through P/Invoke | Visual C++ v143, Windows SDK, AviSynth or VapourSynth SDK/runtime | `FrameServerFactory` in StaxRip or AutoCrop | Loads scripts and native plugins; returns decoded frame buffers | direct and solution x64 builds verified; bounded R73, R79, and AviSynth runtime matrix verified on the #1993 and integration branches |
| `AutoCrop.exe` | Samples frames and prints crop values | `Source/Tools/AutoCrop/` | `Module1.Main` with seven positional arguments | .NET Framework 4.8, `FrameServer.dll`, frame-server runtimes | `MainForm` creates a `Proc` with `Package.AutoCrop` | Reads a generated script and emits crop values; StaxRip caches them in `autocrop.tmp` | Debug and Release x64 builds verified; packaged R73, R79, and AviSynth smoke cases observed with the fixed FrameServer |
| Embedded PowerShell | Runs user or packaged automation in process | `Source/General/PowerShell.vb` and `GlobalClass.LoadPowerShellScripts` | Creates a runspace, sets process execution policy to Unrestricted, and calls `AddScript` | PowerShell 5 reference assemblies and local `.ps1` files | Startup auto-load, commands, menus, and events | Executes arbitrary PowerShell with the current user's authority | configured-not-observed |
| Build script | Rebuilds the main solution | `Source/Build.ps1` | Manual PowerShell invocation | `MSBuild.exe`, NuGet-restored packages, native SDK inputs, prepared `Source/bin` tree | Developer | Rewrites build outputs under `Source/bin` | configured-not-observed |
| Pack scripts | Build and create release archives | `Source/BuildAndPack.ps1`, `Source/Release.ps1` | Manual PowerShell invocation | Build prerequisites, 7-Zip, prepared `Source/bin`, `A:\StaxRip-Releases` | Maintainer | Deletes or replaces target folders and archives; copies distributable files | scripts not invoked; equivalent copy, exclusion, EXE/full archive, integrity, and manifest contracts verified in scratch |

### Dependency, shipping, and reachability graphs

#### Solution and build graph

- `Source/StaxRip.sln` contains `StaxRip.vbproj` and `FrameServer.vcxproj`; the managed project declares a dependency on the native project.
- `Source/Tools/AutoCrop/AutoCrop.sln` is separate and is not built by the three root `Source/*.ps1` scripts found in this pass.
- The StaxRip and AutoCrop projects target .NET Framework 4.8. FrameServer targets the Windows 10 SDK with Visual C++ toolset v143.
- On the upstream base, the main solution maps `Release|x64` and `Release|x86` for the StaxRip project to its Debug configurations while FrameServer maps those solution configurations to Release. Phase 1 removes the x86/Win32 mappings but deliberately leaves the unusual x64 Release mapping unchanged. The x64 compiler inputs and output differences are verified; maintainer intent for that mapping is unknown.
- Contributor verification is x64-only. `Docs/Introduction/System-Requirements.md` explicitly rejects 32-bit Windows, and the user confirmed on 2026-08-10 that current StaxRip builds are 64-bit-only. The three checked-in build and release scripts all select x64, the current updater matches only `-x64` release archives, and 105 GitHub releases expose no asset named x86 or 32-bit. Phase 1 removes the five coordinated x86/Win32 project surfaces. Phase 2 removes the internal runtime branches while preserving the public `Filename32` compatibility property as obsolete. The stacked candidate passed compile, runtime, GUI, soak, and packaging-equivalent gates.
- `Source/bin` and `Source/bin-x86` are ignored. FrameServer includes VapourSynth headers from the prepared `Source/bin/Apps/...` tree. A clean checkout therefore does not contain every configured build input or runtime dependency. Manual staging of the three R79 API headers plus a locked NuGet restore was sufficient for the verified x64 source builds.

#### Shipping graph

- The build scripts rebuild `Source/StaxRip.sln` into `Source/bin`.
- `Release.ps1` copies most of the prepared `Source/bin` tree to a versioned directory and archives it with 7-Zip.
- `BuildAndPack.ps1` archives only `StaxRip.exe` and its PDB.
- `AutoCrop.vbproj` is configured to emit into `Source/bin/Apps/Support/AutoCrop`, but its separate solution is not invoked by the inspected release scripts.
- The exact process that populates all ignored bundled applications, plugins, SDK headers, and AutoCrop before packaging is unknown.

#### Runtime dependency graph

- `Package.Items` is the central registry for bundled and optional applications. Each package defines names, paths, requirements, version behavior, and download or help URLs.
- `Proc` resolves a package path, expands environment variables, constructs `ProcessStartInfo`, adjusts environment variables, launches the process, and captures output when configured.
- Encoder, muxer, demuxer, audio, script, and tool-update classes select packages and build their command lines.
- The managed application loads `FrameServer.dll`, MediaInfo, Everything, and Windows libraries through native imports.

#### AutoCrop reachability trace

1. Implementation: `Source/Tools/AutoCrop/Main.vb` (`verified`).
2. Build target: separate VB.NET 4.8 project; the upstream base retains x64 and x86 configurations, while Phase 1 retains x64 only. Both x64 configurations built successfully (`verified`).
3. Shipping: Debug x64 wrote under the ignored `Source/bin/Apps/Support/AutoCrop` tree, while Release x64 overwrote tracked binaries under `Source/Tools/AutoCrop/bin/x64/Release` (`verified`); orchestration that builds or stages it before packaging is `unknown`.
4. Discovery: `Package.AutoCrop` names `AutoCrop.exe` in `Support/AutoCrop` (`verified`).
5. Native dependency: AutoCrop loads `FrameServer.dll` and a selected frame-server runtime (`verified` as configuration).
6. Enablement: the GUI auto-crop flow selects the package (`verified`).
7. Invocation: `MainForm` passes the source script and crop parameters to `Proc.Start` (`verified`).
8. Observation: the packaged AutoCrop host and its frame-server dependency completed bounded AviSynth, R73, and R79 smoke cases on the #1993 and integration branches. The StaxRip integration candidate also opened four representative sources through the GUI (`tested` for the recorded fixtures; arbitrary AutoCrop and GUI paths remain unbounded).

Terminal status: independent AutoCrop compilation is verified. Clean-checkout shipping remains `unknown-at-link-3` because the inspected release scripts do not build its separate solution.

## 3. Interface surface

| Trigger | Path or command | What it does | Authority | Data read or written | Downstream |
|---|---|---|---|---|---|
| GUI startup | `Startup.Main` | Loads settings and creates `MainForm` | Current Windows user | Registry and local settings files | Main GUI, update check, script auto-load |
| File dialog or drag/drop | `MainForm.OpenAnyFile` | Routes projects, media, audio, ISO images, or folders | Current Windows user | User-selected files and project state | Project deserializer, demux and source-opening flows |
| Process command line | `MainForm.ProcessCommandLine` | Treats existing paths as input files; routes other arguments through `CommandManager` | Caller who can start the process | Paths, switches, project state, settings | Reflected command methods and normal GUI workflows |
| Serialized project | `.srip` -> `MainForm.OpenProject` | Deserializes project or template state and binds it to the UI | File opener | Project fields, profiles, commands, paths | Script generation, jobs, tool execution |
| Job queue | `Jobs.dat` -> `GlobalClass.ProcessJobsRecursive` | Opens queued `.srip` jobs and runs processing | Current user and other StaxRip processes sharing settings | Job list, project files, temp and output files | Parallel audio, subtitle, video, mux, cleanup flows |
| Event command | `ApplicationEvent` -> `CommandManager.ProcessPlusFixParams` | Invokes registered commands when application events fire | Persisted settings or project owner | Event criteria, parameters, command line, progress | GUI commands, process control, files, system actions |
| PowerShell auto-load | `Apps/Scripts/*.ps1`, `Settings/Scripts/Auto Load/*.ps1` | Executes scripts at startup | File owner and current Windows user | Script content and any accessible local data | In-process PowerShell and exposed application commands |
| Apps Manager update | package URL or dropped archive | Downloads or accepts an archive, extracts it, and copies files into a tool directory after prompts | User confirmation | Network content or local archive, package files | 7-Zip and runtime executable tree |
| AutoCrop command | `AutoCrop.exe SCRIPT_PATH ...` | Samples frames and returns four crop values | StaxRip process | Generated script, temp cache | FrameServer and selected script runtime |
| Release command | `Build.ps1`, `BuildAndPack.ps1`, `Release.ps1` | Builds or packages artifacts | Developer or maintainer shell | Source, prepared bin tree, release target | MSBuild, 7-Zip, `A:` release destination |

There is no application-level authentication boundary. These entrypoints run with the current Windows user's permissions. Some registered commands can shut down or suspend the machine.

## 4. Data stores and schemas

### Settings registry

- **Type:** Windows Registry.
- **Stores:** Settings directory selection and shutdown state, plus reads for installed applications, Windows capabilities, and frame-server registrations.
- **Key locations:** `HKCU\Software\StaxRip\SettingsLocation`, `HKCU\Software\StaxRip`, and several read-only HKLM or HKCR locations.
- **Deletion notes:** Invalid settings locations are removed during settings path resolution.

### Binary settings and profiles

- **Type:** Local files serialized with `SafeSerialization` or direct `BinaryFormatter` use.
- **Stores:** `Settings.dat`, `AudioProfiles.dat`, `VideoEncoderProfiles.dat`, `Events.dat`, `Jobs.dat`, and theme state.
- **Relationships:** Settings choose templates, tools, concurrency, update behavior, and persistence options. Jobs reference `.srip` paths.
- **Recovery:** Settings are copied to a versioned backup. Several reads catch errors and reset or return an empty value.

### Projects and templates

- **Type:** `.srip` binary files using `SafeSerialization`, which embeds non-simple objects as BinaryFormatter byte arrays.
- **Stores:** Source and target paths, profiles, scripts, event commands, processing choices, temp policy, and logs.
- **Relationships:** Templates seed projects. Job entries point to projects. Projects select package and command behavior.
- **Trust note:** `.srip` files can enter through file dialogs, drag/drop, and the process command line. The repository does not state whether they must be trusted.

### Media, temp, and output files

- **Type:** User and generated filesystem content.
- **Stores:** Source media, generated AviSynth or VapourSynth scripts, indexes, intermediate audio or video, logs, project recovery files, and final outputs.
- **Deletion notes:** `GlobalClass.DeleteTempFiles` checks temp naming and job references, then applies project-configured deletion rules. Full safety under path aliases, multiple processes, or interrupted publication is not established by this map.

### Scripts and plugins

- **Type:** `.ps1`, `.avs`, `.vpy`, plugin binaries, and support assets in application or settings folders.
- **Stores:** User automation and video-processing behavior.
- **Trust note:** PowerShell auto-load scripts execute in process. AviSynth and VapourSynth scripts load native plugins and process media.

### Logs

- **Type:** UTF-8 text beside the source or in the temp directory.
- **Stores:** Machine characteristics, culture, tool and project configuration, media paths and metadata, complete scripts, command lines, progress, and errors.
- **Redaction:** `ObfuscateLogFile` is used when the built-in log viewer exports a log. Normal `LogBuilder.Save` writes the raw log.

### Language and rendered text

- UI copy is primarily embedded in VB and WinForms resources. Documentation is under `Docs/`.
- Script templates and command strings are executable behavior, not display-only text.
- Audio language values, project names, profile names, event commands, and some user-authored text are persisted.
- The boundary between localizable display text and persisted or executable truth has not been mapped fully.

## 5. External dependencies

| System | Purpose | Configuration | Dependent units | Failure impact | Confirmed recovery |
|---|---|---|---|---|---|
| Bundled and optional tools | Encode, decode, mux, demux, inspect, index, script, and package media | `Package.Items` and the `Apps` tree | Main app and AutoCrop | Selected operation cannot run or may use a user override | Package verification messages and user setup paths; complete policy unknown |
| AviSynth and VapourSynth | Execute generated video-processing scripts | Portable `Apps` tree, installed locations, registry, and settings | Main app, FrameServer, AutoCrop | Source scripts cannot open or return frames | GUI can fall back to portable mode when installed paths are absent |
| GitHub API and release pages | Check StaxRip and tool releases | Hard-coded HTTPS URLs and package records | Update checker and Apps Manager | Updates are unavailable; core local processing can continue | Exceptions in StaxRip update checks are swallowed; tool updates are manual |
| NuGet packages | Compile managed code | `Source/packages.config` and project hint paths | StaxRip build | A no-restore build failed on missing DirectN types | MSBuild packages.config restore from NuGet.org verified; repository documentation was proposed |
| Windows APIs and Registry | UI, process control, shell, path, hardware, native media, and settings integration | P/Invoke and registry paths | All runtime units | Feature-specific or startup failures | Varies by call; not mapped globally |
| 7-Zip | Tool extraction and release archive creation | `Package.SevenZip` or `7z.exe` on the maintainer path | Apps Manager and pack scripts | Tool install or packaging fails | Error messages and manual retry |

No authenticated network API or required secret name was found in the inspected application configuration. This does not cover every bundled external executable.

## 6. Configuration inputs

| Input | Used by | Required? | Notes |
|---|---|---|---|
| `Source/app.config` | StaxRip | required at runtime | Selects .NET Framework 4.8 and contains empty client service URIs |
| `Source/packages.config` | managed build | required for current project references | DirectN, ManagedCuda, and PowerShell reference assemblies |
| Process `PATH` | package and process discovery | environment-specific | Read, extended, and passed to child processes |
| `HKCU\Software\StaxRip\SettingsLocation` | settings storage | optional on first run | Points to a user-selected settings directory |
| Package paths and overrides | external tools | feature-specific | Derived from application folders, settings, installed applications, registry, and user choices |
| Command-line switches and paths | MainForm | optional | Can load input files or invoke registered commands |
| `.srip` and `.dat` files | projects, settings, profiles, events, jobs | workflow-specific | Binary serialized input |
| Application and settings script folders | PowerShell automation | optional | `.ps1` files are auto-loaded at startup |

## 7. Trust boundaries and privilege edges

| Boundary | What crosses it | Validation or confirmation | Assumptions | Failure if loose |
|---|---|---|---|---|
| User-selected file -> project deserializer | `.srip` bytes and embedded objects | Extension routing and deserialization exceptions | Project files are compatible and sufficiently trusted | Unsafe object construction, corrupted state, or actions driven by hostile project data |
| Settings folder -> in-process PowerShell | `.ps1` source | File extension and folder ownership; no prompt at each startup | Auto-load folders contain trusted scripts | Code execution as the current user |
| Project or UI state -> external process | Executable path, arguments, environment, generated scripts | Package resolution, quoting helpers, feature checks | Paths and arguments remain correctly separated for every tool | Wrong tool, command injection, encoding failure, overwrite, or data loss |
| Internet or dropped archive -> Apps tree | Executables, DLLs, scripts, and assets | User prompts, archive extraction, expected filename check | Selected source and archive contents are trustworthy | Replacement of runtime tools or plugins |
| Managed VB -> native DLL or plugin | Script paths, pointers, frame metadata, buffers | ABI declarations and runtime error handling | Architecture, versions, structs, and encodings match | Crash, corrupt frames, or memory safety failure |
| Parallel actions -> filesystem and process controller | Audio, subtitle, video, logs, temp and output paths | `Parallel.Invoke`, process-controller state, project settings | Concurrent actions do not collide on shared resources | Cross-action cancellation, corruption, stale outputs, or wrong cleanup |
| Temp policy -> filesystem deletion | Calculated temp directory and selected files | `_temp` suffix, source exclusion, job-reference checks, user settings | Canonical paths and job visibility identify ownership | Deletion of source or unrelated files, or leaked temp data |
| Raw log -> issue report or exported file | Paths, machine data, scripts, commands, media metadata | Optional built-in obfuscation during export | Users use the protected export path and review content | Privacy or sensitive-path disclosure |
| Maintainer shell -> release destination | Built binaries and prepared `bin` tree | Hard-coded targets and manual invocation | Local tree and drive contents are correct | Incorrect or incomplete release, or deletion of prior artifacts |

## 8. Critical data flows

### Startup and extension loading

- **Trigger:** Launch `StaxRip.exe`.
- **Entrypoints:** `Startup.Main`, `MainForm.OnShown`, update checker, `LoadPowerShellScripts`.
- **Stores:** Registry, `Settings.dat`, profile and event files, script folders.
- **External systems:** Optional GitHub update request; installed or portable frame-server and tool paths.
- **Trust boundaries:** Serialized settings and auto-loaded PowerShell enter the application process.

### Source open to completed output

- **Trigger:** GUI, drag/drop, or command-line file input.
- **Entrypoints:** `OpenAnyFile`, template selection, `OpenVideoSourceFiles`, generated `VideoScript`, `AddJob`, `ProcessJob`.
- **Stores:** Source media, project, jobs, generated scripts, temp files, logs, encoded streams, and final container.
- **Parallel work:** Audio, subtitle, and video actions are collected and run with `Parallel.Invoke`; muxing follows.
- **External systems:** Frame servers, encoders, audio tools, subtitle tools, muxers, metadata utilities, and native plugins.
- **Trust boundaries:** User paths and media -> generated scripts and commands -> child processes -> filesystem outputs.

### Project and job persistence

- **Trigger:** Save project, add job, startup, or process queued jobs.
- **Entrypoints:** `SaveProjectPath`, `SafeSerialization`, `JobManager`, `ProcessJobsRecursive`.
- **Stores:** `.srip`, `Jobs.dat`, settings, temp and output paths.
- **Recovery:** Settings backups, deserialize fallbacks, retries around job-file access, and recovery projects.
- **Trust boundaries:** Local binary files become runtime objects and command-bearing state.

### Tool update

- **Trigger:** Apps Manager download or archive drag/drop.
- **Entrypoints:** `ToolUpdate.Download`, `DownloadForm`, `Extract`, `CopyFiles`.
- **Stores:** Downloaded archive, extraction directory, application tool directory, package version metadata.
- **External systems:** Package download sites and 7-Zip.
- **Trust boundaries:** Network or local archive content becomes executable runtime content after user prompts.

### Release packaging

- **Trigger:** Manual execution of a PowerShell script.
- **Entrypoints:** `Build.ps1`, `BuildAndPack.ps1`, `Release.ps1`.
- **Stores:** Source tree, build output, release directory, archives.
- **External systems:** MSBuild, NuGet-restored references, 7-Zip, prepared bundled tools.
- **Trust boundaries:** A local development tree becomes a distributable artifact.

## 8a. Rule authority

| Rule or contract | Canonical implementation | Downstream views or adapters | Drift guard | Confidence |
|---|---|---|---|---|
| Package identity and executable path | `Source/General/Package.vb` | Apps Manager, encoders, muxers, demuxers, `Proc` | Runtime `VerifyOK`; deterministic coverage unknown | verified as configuration |
| Child-process launch and capture | `Source/General/Proc.vb` and `ProcController.vb` | Every tool integration | Exit-code/error handling per caller; central contract tests absent | inferred |
| Project and settings serialization | `SafeSerialization` plus direct BinaryFormatter callers | Projects, templates, profiles, events, jobs, themes | Version fields and fallback behavior; adversarial tests absent | verified as implementation |
| Temp directory selection and deletion | `GlobalClass.SetTempDir` and `DeleteTempFiles` | Project settings and job processing | `_temp` suffix and job/source checks | verified as implementation |
| Job orchestration | `GlobalClass.ProcessJobsRecursive` and `ProcessJob` | Jobs UI and command-line start | Process controller and job-file retry loops; cross-process contract unknown | inferred |
| StaxRip update selection | `StaxRipUpdate` | MainForm startup and global command | Version comparison against GitHub release links | configured-not-observed |
| Release contents | PowerShell scripts plus prepared `Source/bin` | Release archives | Manual exclusions and existence checks; complete provenance unknown | inferred |

## 8b. Diagnostics and observability authority

- **Diagnostic surfaces:** Raw job log, processing form, debug trace, issue reports, and event progress callbacks.
- **Observational only:** `LogBuilder` is observational in the inspected paths.
- **Authoritative use:** `WhileProcessing` command line and progress values can feed persisted event commands through macro expansion. That automation path is intentionally behavior-bearing, not purely diagnostic.
- **Redaction boundary:** Normal logs are raw. The built-in log viewer can export through `ObfuscateLogFile`.
- **Replay support:** Logs capture commands and scripts, but no deterministic replay harness or minimized fixture corpus was found.

## 9. Operational notes

- Jobs run recursively in one application process. Audio, subtitle, and video work may execute in parallel according to `s.ParallelProcsNum`.
- The application may launch a new StaxRip process to continue jobs after memory use exceeds 1500 MiB.
- Settings saves use a named mutex. `Jobs.dat` uses exclusive file access and retry loops; cross-process identity and crash-recovery guarantees remain unknown.
- Startup may contact GitHub only after the user answers the update-check prompt. Tool updates are separate user-triggered downloads.
- No GitHub Actions workflows or repository test project were found. Build and release automation is local and manual in the checked tree.
- `Release.ps1` and `BuildAndPack.ps1` contain destructive replacement operations against versioned targets under `A:\StaxRip-Releases`. They were not executed. Their selection and archive contracts were reproduced under a verified scratch root; exact full compression took 1,038.3 seconds and about 10.3 GiB private memory.

## 10. Known gaps and coverage limits

- This pass mapped entrypoints and trust boundaries. It did not review all 145 VB files, 17 C/C++ implementation or header files, 51 resource files, or every package definition semantically.
- Direct and solution Debug and Release x64 builds succeeded after isolated dependency preparation. The integrated portable candidate passed startup, representative GUI media opening, real AviSynth/VapourSynth scripts, a 10,000-session lifecycle soak, and release-equivalent scratch packaging. No real encoding job, live update, hard-coded release-script invocation, or publication was run.
- Bundled executables and plugins live outside the tracked source tree. The exact v2.52.5 portable tree and selected plugins were exercised, but complete license/source provenance and arbitrary runtime behavior remain outside this map.
- UI actions and 175 command attributes across seven files need risk-ranked slicing before claiming complete interface coverage.
- The build and shipping graph is incomplete for AutoCrop and the prepared `Source/bin` tree.
- The trust model and compatibility policy for BinaryFormatter-backed files are not documented.
- The provenance and integrity policy for tool updates is not established by the four inspected download/update files.
- Logging, concurrency, deletion, script execution, and publication need dedicated passes before strong safety claims.

See `Docs/Unknowns/Architecture-Pass.md` for actionable evidence gaps.
