# StaxRip Portability System Map

Version: 0.3. Date: 2026-08-16. Repository base: `940eaba1`.

This map separates the current Windows runtime from the implemented portability bootstrap and later target boundaries. Source implementation is not build, runtime, browser, Linux-support, or macOS-support evidence. Confidence uses only `verified`, `inferred`, or `unknown`.

## 1. System summary

- **Current product:** StaxRip is a portable Windows x64 desktop front end for video and audio tools. The main application is a .NET Framework 4.8 WinForms executable (`Source/StaxRip.vbproj:26,39,76`).
- **Current native unit:** `FrameServer.dll` is a C++ x64 Windows DLL built with toolset v143 and the Windows SDK (`Source/FrameServer/FrameServer.vcxproj:4-32`).
- **Current support unit:** `AutoCrop.exe` is a .NET Framework 4.8 x64 executable (`Source/Tools/AutoCrop/AutoCrop.vbproj:9-49`).
- **Current runtime model:** The GUI owns project state, renders AviSynth or VapourSynth scripts, builds command lines, launches external tools, coordinates jobs, and writes settings, projects, templates, recovery files, and logs.
- **Portability state:** Preserve the current Windows application. Source now contains separate cross-platform contracts, a capability-only core and platform adapter, a versioned loopback API, and an embedded web shell under root-level `CrossPlatform/`. Focused Windows build, hostile HTTP, installed-browser, dependency, and local WSL runtime gates have pre-freeze local passes. The latest independent evidence review returned NO-GO. Its source remediations and focused probes are present, but final committed-source correspondence and independent re-review are pending. Linux is the first runtime target. The independent Linux host ran the artifact successfully, though only while a host mitigation was temporarily relaxed and then restored, and remains blocked by R-S2-039, an environment limitation on that host rather than an access problem, and macOS follows after Linux contracts and adapters stabilize.
- **Main high-risk domains:** persisted compatibility, command construction, process cancellation, temp cleanup, output publication, tool provenance, native frame serving, local HTTP security, and release assembly.

## 2. Current runtime units and entrypoints

| Unit | State | What it does | Entry or evidence | Data or side effects owned | Confidence |
|---|---|---|---|---|---|
| `StaxRip.exe` | Current | Windows GUI and workflow coordinator | `Source/General/Misc.vb:1288-1294` calls `Application.Run`; project is .NET Framework 4.8 x64 | Projects, settings, scripts, jobs, tools, processes, temp files, logs, UI | verified |
| `MainForm` | Current | Loads and saves projects and owns source-opening workflow | `Source/Forms/MainForm.vb:1760,1802,2535,4000` | Global project replacement, recovery project, project save, UI state | verified |
| `VideoScript` | Current | Renders and writes AviSynth or VapourSynth script text | `Source/Video/VideoScript.vb:22-78,287-305` | `.avs` or `.vpy` script text and files | verified |
| `Proc` and `ProcController` | Current | Start, observe, cancel, and kill external processes | `Source/General/Proc.vb:54,195-209`; `Source/General/ProcController.vb:738-959` | Child processes, output capture, cancellation, processing UI | verified |
| `Package` | Current | Describes and locates external applications and libraries | `Source/General/Package.vb:88,465,3209-3417` | Executable selection, Windows registry and path lookups | verified |
| `FrameServer.dll` | Current | Bridges managed code and native frame serving | `Source/Video/FrameServer.vb:18-87`; `Source/FrameServer/FrameServer.h:4-29` | Native handles, COM, shared memory and frame lifetime | verified |
| `AutoCrop.exe` | Current | Runs the AutoCrop support workflow | `Source/Tools/AutoCrop/AutoCrop.vbproj:9-49` | Support process and crop analysis output | verified |
| Startup automation | Current | Processes command-line input, checks for updates, and schedules PowerShell script loading after the main form appears | `Source/Forms/MainForm.vb:6158-6173` | Commands, network requests, script execution, and application state | verified |
| Auto-load PowerShell | Current | Executes `.ps1` files from configured application and user script folders | `Source/General/GlobalClass.vb:355-360` | User and packaged script side effects under the current process authority | verified |
| Update checker | Current | Requests GitHub release metadata and parses release links | `Source/General/StaxRipUpdate.vb:41-70` | Optional network request and update-facing state | verified |
| Legacy update script | Current file, runtime reachability unknown | Downloads archives, starts a process, and removes replacement files when invoked | `Source/Scripts/Legacy/Update.ps1:7-86` | Network, process, download, and deletion side effects | verified |
| Build and release scripts | Current | Build, package, and release Windows artifacts | `Source/Build.ps1`, `Source/BuildAndPack.ps1`, `Source/Release.ps1` | Build output and distribution artifacts | verified |

## 3. Portability units

The first five units exist in source and have focused pre-freeze local build and runtime passes. Final committed-source correspondence remains pending. That result does not establish media workflow, current Windows application regression, independent Linux host, supported Linux release, or macOS behavior. The remaining units are deferred designs.

| Unit | First responsibility | Explicit first-slice exclusions | State | Confidence |
|---|---|---|---|---|
| `StaxRip.Contracts` | Stable, serializable capability and error contracts | No legacy project object graph; no command strings; no raw paths | Debug and Release contracts pass | verified |
| `StaxRip.Core` | Platform-neutral capability rules and typed platform abstractions | No WinForms reference; no process start; no persistence | Debug, Release, Windows HTTP, and WSL contract use pass | verified |
| `StaxRip.Server` | Loopback-only HTTP host and bundled web assets | No LAN listener, upload, file picker, tool execution, queue, database, or plugin host | Latest pre-freeze hostile Windows HTTP and installed Edge gates pass; earlier WSL gate passes; final source-bound audit pending | verified |
| `StaxRip.Platform` | Report bounded operating-system, architecture, runtime, and processor facts | No executable search, tool probe, encode, or media inspection in the bootstrap | Windows x64 and WSL Linux x64 runtime facts pass | verified |
| Embedded web shell | Show host health and honest capability state | No node canvas, arbitrary scripts, remote control, or project editing | Latest pre-freeze installed Edge and recorded WSL shell checks pass; final source-bound audit pending | verified |
| Existing WinForms adapter | Future bridge from current workflows to proven core contracts | Not part of the Linux bootstrap | Deferred | inferred |
| Future native desktop client | Optional Avalonia client over the same application contracts | No framework decision or implementation in the bootstrap | Deferred | unknown |

## 4. Dependency graphs

### Current Windows graph

```text
User
  -> StaxRip WinForms / MainForm
       -> global g, p, s state
       -> project and settings BinaryFormatter files
       -> VideoScript -> .avs / .vpy
       -> Package -> registry and bundled Windows tools
       -> Proc / ProcController -> shell, PowerShell, .exe tools
       -> FrameServer.vb -> FrameServer.dll -> COM / Windows APIs
       -> temp, output, recovery, log files
```

### Implemented bootstrap graph and future edges

```text
Browser on the same machine
  -> exact loopback HTTP routes
       /, /app.css, /app.js, /healthz, /api/v1/capabilities
       -> StaxRip.Server
            -> StaxRip.Platform
                 -> StaxRip.Core
                      -> StaxRip.Contracts

Future runtime calls through core-owned interfaces
  -> explicit tool, process, script, storage, and native adapters
  -> future typed workflow intermediate representation

Future clients
  -> WinForms adapter or native desktop client
       -> the same contracts and core rules

Legacy project compatibility
  -> future Windows-only import/export adapter
       -> typed cross-platform representation
```

The implemented bootstrap graph does not route a legacy BinaryFormatter payload through HTTP. It does not make the server authoritative for current Windows projects. It contains no tool adapter or portable workflow representation.

## 5. Current interfaces and stores

| Surface | Format or mechanism | Current owner | Portability concern | Confidence |
|---|---|---|---|---|
| Application entry | WinForms custom `Sub Main` | `Source/General/Misc.vb:1288-1294` | WinForms and the message loop are Windows-only | verified |
| Project and template load | `SafeSerialization.Deserialize` | `Source/Forms/MainForm.vb:1760,1802` | Object graph and runtime type identity bind compatibility to the legacy assembly | verified |
| Project and recovery save | `SafeSerialization.Serialize` | `Source/Forms/MainForm.vb:2535,4000` | A replacement writer could corrupt user-owned files or break downgrade | verified |
| Settings save and load | `SafeSerialization` | `Source/General/GlobalClass.vb:103-127` | Settings include platform-owned paths and application state | verified |
| Job list | `BinaryFormatter` | `Source/General/JobManager.vb:110-143` | Format and scheduling behavior are coupled | verified |
| Script boundary | Text `.avs` and `.vpy` | `Source/Video/VideoScript.vb:22-78,287-305` | Script syntax, paths, plugin names, and quoting vary by platform | verified |
| External command boundary | `ProcessStartInfo`, command strings, shell and PowerShell | `Source/General/Proc.vb:54-209`; encoder command owners | Shell rules, process trees, signals, and executable names vary | verified |
| Native frame boundary | P/Invoke and COM | `Source/Video/FrameServer.vb:18-87`; `Source/FrameServer/` | Current ABI and implementation are Windows-specific | verified |
| Startup extension boundary | Command line, update HTTP, and auto-loaded PowerShell | `Source/Forms/MainForm.vb:6158-6173`; `Source/General/GlobalClass.vb:355-360`; `Source/General/StaxRipUpdate.vb:41-70` | Automation, network, and script compatibility need separate platform rules | verified |
| Registry | Windows registry | `Source/General/General.vb:124-202`; `Source/General/Package.vb:3209-3417` | Linux and macOS need explicit configuration and discovery adapters | verified |

## 6. External tool boundary

The repository has broad Windows executable and DLL assumptions. A deterministic scan over 184 tracked `.vb`, `.cpp`, `.h`, and `.ps1` candidates found 46 files matching `(?i)\.exe\b|\.dll\b` and 12 files matching `DllImport|Declare Function|Declare Sub`. Generated, vendored, ignored `Source/bin`, and binary content were excluded. This is coverage evidence, not a claim that every match blocks a port.

| Tool family | Current integration | Portable upstream signal | Required StaxRip work | Confidence |
|---|---|---|---|---|
| FFmpeg and FFprobe | Windows package paths and command construction | Linux and macOS packages exist | Typed executable resolution, argv construction, version and capability probes, golden commands | inferred |
| VapourSynth | Generated `.vpy` plus Windows package/runtime assumptions | Upstream documents Windows, Linux, and macOS builds | Platform plugin manifest, Python/runtime discovery, script fixtures | inferred |
| AviSynth+ | Generated `.avs` plus Windows-native frame path | Upstream documents multiple operating systems | Decide supported Linux path, plugin ABI, and frame transport | inferred |
| NVEncC | Windows tool package integration | Upstream documents Linux builds | GPU discovery, Linux CLI parity, driver failure handling | inferred |
| MKVToolNix | Windows executable integration | Project distributes Linux and macOS builds | Platform resolver and argv parity tests | inferred |
| Windows-only utilities and libraries | `.exe`, `.dll`, registry, COM, and shell integrations | No single portable replacement is established | Classify replace, adapt, disable, or defer per capability | unknown |

No tool availability statement above is a bundled-tool provenance or support commitment. U-006 and the portability unknowns still block public artifacts.

## 7. Trust boundaries and privilege edges

| Boundary | What crosses it | Current or portability safeguard | Failure if loose | Confidence |
|---|---|---|---|---|
| User media and project -> current GUI | Paths, scripts, metadata, serialized objects | Existing validation varies by workflow | Data loss, command injection, unsafe deserialization, privacy leak | verified |
| Current GUI -> external tool | Executable, command line, environment, working directory | `Proc` and package-specific logic | Wrong executable, quoting error, orphan process, overwrite | verified |
| Managed app -> native frame server | Handles, formats, frame buffers, lifetime | P/Invoke and COM contracts | Crash, corruption, leak, ABI mismatch | verified |
| Browser -> implemented server | HTTP requests and session state | Exact loopback, Host, Origin, per-instance HttpOnly SameSite session, no-CORS, concurrent-instance, hostile-origin, CSP, and framing checks pass for the read-only bootstrap | Cross-site request, local data exposure, unintended remote control | verified |
| Verifier -> owned test process | Exact executable, argv, output pipes, socket, and task root | Register PID, start time, executable, and arguments before readiness; cap live stdout and stderr; revalidate before forced stop; prove reap, port release, cleanup, and empty task root | Orphan process, unrelated-process termination, memory exhaustion, stale evidence | verified |
| Reviewed restore graph -> dependency record | Exactly five `project.assets.json` files, five matching lock files, two targets, and three pinned package downloads | Final auditor derives the exact project-only graph, `[10.0.11, 10.0.11]` ranges, package identities, versions, and five-project membership instead of trusting an allowlist; focused probe passes and full audit is pending | An unrelated or partial signed package subset can be reported as the evaluated closure | verified |
| Signed package archive -> extracted publish input | ZIP paths, payload bytes, and complete repository-local package directory | Dependency schema v2 separates registry hash, raw archive digests, signature identity, and extracted identity; it compares every allowed archive payload and binds the complete ordinal disk inventory by SHA-256, file count, and total bytes; Restore passes and final audit is pending | Publish can consume bytes or extra files not covered by the verified signature | verified |
| Evidence producer -> final audit | Ignored JSON, TSV, hashes, failure records, task-root state, and mutable wrapper state | One atomic cross-OS `.evidence-writer.lock`; Restore holds it across its entire mutable workflow and distinguishes partial acquisition from validated ownership; `Verify.ps1` retains canonical `.port-verify-running` across all child steps; final-auditor source rejects that marker and case-drifted or nonempty task roots at its primary read and both closeouts; full audit is pending | Mixed green records, stale audit, concurrent publication, or audit during an incomplete workflow | verified |
| Future portability core -> filesystem | Future paths, projects, scripts, temp and output | SLICE-002 accepts no path, contains no product-state writer, and passed the bounded read-only WSL sandbox with zero observed state writes; future path authority is unimplemented | Traversal, overwrite, deletion, compatibility loss | inferred |
| Future portability core -> process | Future executable identity plus argv | SLICE-002 source starts no external tool; future work requires a typed process specification and separate approval | Injection, wrong binary, bad cancellation, child leak | inferred |
| Build host -> public artifact | SDK output, native libraries, bundled tools | No public artifact in the bootstrap | Unproven provenance, machine-local contamination, unsafe update | verified |

## 8. Critical flows

### Current source opening through encode preparation

- **Trigger:** A user opens media in the WinForms application.
- **State:** `MainForm` replaces global project state and drives source selection and preparation.
- **Generated data:** AviSynth or VapourSynth script, command previews, temp paths, logs, and project state.
- **External boundary:** Package resolution and `Proc` or `ProcController` start external tools.
- **Portability blocker:** UI ownership, global state, Windows discovery, shell command composition, and Windows-native frame serving share the same flow.

### Verified local Linux bootstrap

- **Runtime trigger:** The WSL harness starts the exact manifested self-contained Linux x64 artifact as non-root and opens its printed loopback URL through bounded HTTP clients.
- **State:** Process-local session only.
- **Read surface:** Bounded operating-system, architecture, runtime, and logical-processor facts plus a fixed tool catalog whose compatibility is `unverified`.
- **Application-owned write surface:** Bounded console output and HTTP responses only. The tested sandbox observed zero product or runtime-state writes and an unchanged application tree.
- **Process surface:** The server starts no tool or worker process. Two hundred runtime child samples observed zero children.
- **Outcome:** The web shell reports media inspection, encoding, persistence, remote access, plugins, and project import unavailable.

### Pre-freeze verification publication

- **Trigger:** A PowerShell or Bash producer is ready to mutate audited evidence, build inputs, intermediate state, or a bounded failure.
- **Ownership:** Atomic create-new on the shared evidence lease. The owner verifies its exact random receipt before removal and never steals a competing receipt. Restore holds the lease over its complete mutable workflow and records partial acquisition separately from validated ownership and prior-audit invalidation.
- **Wrapper continuity:** `Verify.ps1` creates canonical `.port-verify-running` under the evidence lease before its child sequence and removes the exact-owned marker under the lease only after publication or an owned failure closeout. The final auditor rejects the marker at its primary snapshot and both closeouts.
- **Process proof:** HTTP and browser producers register ownership before readiness, bound live output, clean up before publishing failure truth, and require empty task roots.
- **Dependency proof:** Restore verifies retained signatures, derives the exact three downloads from five reviewed project inputs, binds archive payloads, and records the complete post-verification disk inventory. A nuspec byte and line-ending mutation failed closed; the ignored cache was quarantined intact and restored from the approved signed source.
- **Status:** The latest restore passes 398 checks, and focused graph, marker, task-root, redaction, and binder probes pass. The independent review verdict remains NO-GO until the full committed-source producer run, final auditor, and re-review pass.

### Future portable encode flow

- **Trigger:** A typed, validated project is submitted through a local client.
- **Required stages:** Inspect media, build a platform-neutral workflow model, select explicit tool adapters, render scripts and argv, reserve outputs, start a process group, stream bounded events, cancel safely, publish output, and clean only owned temp data.
- **Status:** unknown. The bootstrap must not imply this flow exists.

## 9. Rule authority

| Rule or contract | Current authority | Portability authority | Drift guard | Confidence |
|---|---|---|---|---|
| Existing project compatibility | Repository evidence identifies legacy readers and writers in `SafeSerialization`, `Project`, and `MainForm` as current owners | Future Windows compatibility adapter only | Frozen fixtures and round-trip tests before any writer | unknown |
| Script rendering | Repository evidence identifies `VideoScript` and format-specific helpers as current owners | Future typed script renderer behind explicit platform inputs | Golden scripts for Windows and Linux | inferred |
| Process invocation | Repository evidence identifies `Proc`, `ProcController`, and callers as current owners | Future executable identity plus an argv list, with no shell by default | Argument-boundary and cancellation tests | inferred |
| Capability truth | Distributed current package and runtime checks | Implemented source catalog in `StaxRip.Core`: two available bootstrap features, six unavailable product features, and six tools with compatibility `unverified` | Contract tests and honest unavailable defaults | verified |
| HTTP error semantics | No current Windows authority | Versioned fixed error codes and privacy sentinels pass contract, hostile Windows HTTP, and WSL runtime checks without raw exception, path, environment, token, or full command output | Endpoint contract and redaction tests | verified |
| UI copy | Current WinForms resources and controls | Structured capability state rendered downstream | Contract/UI fixture tests | inferred |

## 10. Configuration and diagnostics

- Current configuration includes registry values, serialized settings, executable paths, package metadata, and application globals. No single portable configuration boundary exists. Confidence: verified.
- Current logs and issue reports can include user paths, media metadata, scripts, tool output, environment details, full command lines, and credential-bearing headers embedded in quoted JSON. A portable engine must redact at the structured event boundary. Verifier redaction now covers quoted and unquoted credential headers anywhere in bounded text, long prefixes, credential schemes, token fields, and URI user information. Confidence: verified for source and focused synthetic probes; full producer reruns remain pending.
- The bootstrap adds no telemetry, analytics, database, remote configuration, update check, or product external request. Static guards and Windows, WSL, and page-target browser evidence cover the exact tested boundary. `Browser.getVersion`, `SystemInfo.getProcessInfo` operating-system PIDs, exact process receipts, and the browser-file hash bind the selected browser control path. Browser-process subsystems outside the selected page target remain unobserved.
- Session tokens must not appear in URLs, console output, logs, API bodies, or JavaScript-readable storage.

## 11. Operational notes

- The current supported application build remains Windows x64. The new subtree must not enter `Source/StaxRip.sln` or change current project mappings in its first slice.
- The new subtree remains outside `Source/`. `Source/Build.ps1:10,35-51`, `Source/BuildAndPack.ps1:10,35-51`, and `Source/Release.ps1:10,36-53` recursively inspect selected files below `Source/`, so a nested port would not be isolated from current build preflight.
- The local Windows host has .NET SDK 8, 9, and 10. Local WSL Ubuntu exposes the NVIDIA GPU but has no .NET runtime or SDK command. The self-contained Linux x64 artifact passed without installing dependencies; GPU behavior remains outside this slice.
- One network Linux peer is reachable over Tailscale SSH as of 2026-08-17 and ran the artifact, passing 27 checks, though only while a host mitigation was temporarily relaxed and then restored. Under the host's normal configuration the gate fails before the application starts. Second-host execution is blocked by R-S2-039: on that host unprivileged systemd user units cannot obtain a private network namespace, so the sandbox the gate requires is unavailable. This is an environment limitation, not a source defect.
- Old test-owned browser run directories were moved intact to ignored recoverable quarantine after exact-path checks proved that no process referenced them. The active task root must remain empty, and final evidence rejects a stale entry.
- Windows final-audit enumeration treats task-root and workflow-marker names case-insensitively, rejects case drift or collisions, and then requires exact canonical paths.
- No Docker or Podman runtime was found on the Windows host. Containers are not required for the first slice.
- macOS build, runtime, signing, notarization, and tool checks require later access to macOS hardware or CI. A cross-build alone cannot prove those boundaries.

## 12. Known gaps

- Global `g`, `p`, and `s` state and UI-owned orchestration do not expose a stable application boundary.
- BinaryFormatter compatibility cannot safely become a network contract.
- Process cancellation, process-tree ownership, temp cleanup, and output publication need a platform-neutral contract before encoding moves.
- Current tool packages mix executable selection, installation layout, registry discovery, capabilities, and user-visible setup.
- The COM frame server has no proven Unix equivalent in this repository.
- A native cross-platform desktop client remains a separate decision. Official .NET MAUI platforms do not include Linux; Avalonia is a candidate, not a selected dependency.
- No current CI runner proves Linux or macOS behavior.
- Public artifact provenance, signing, update, downgrade, and branding remain approval-gated.

See `../Unknowns/Portability-Unknowns.md` for the checks that must resolve these gaps.
