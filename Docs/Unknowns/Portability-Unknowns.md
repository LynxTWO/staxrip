# StaxRip Portability Unknowns

This file records unresolved Linux and macOS port questions found during the portability architecture pass. Do not infer full platform support from the additive bootstrap.

## Entries

### P-001: Stable boundary around the legacy workflow

- **Area or file:** `Source/Forms/MainForm.vb`, `Source/General/Misc.vb`, `Source/General/GlobalClass.vb`, and global `g`, `p`, and `s` state
- **Concern:** The smallest workflow contract that can leave WinForms without duplicating or changing current behavior is not established.
- **Why it matters:** A guessed boundary could fork business rules, make Windows and Linux results diverge, or force a risky rewrite.
- **Evidence found so far:** `MainForm` loads, replaces, binds, and saves project state; `Misc.vb:1288-1294` starts the WinForms loop; `GlobalClass` owns application-wide forms and settings. The portability map records the current graph.
- **Confidence:** verified
- **Likely owner:** Cross-platform core maintainer with Windows workflow reviewer
- **Next best check:** Map one read-only source-inspection flow into explicit inputs, outputs, side effects, and current rule owners before extracting it.
- **Risk level:** high
- **Status:** open
- **Notes:** The Linux bootstrap must remain capability-only and must not duplicate source-opening rules.

### P-002: Legacy project and settings compatibility boundary

- **Area or file:** `Source/General/General.vb:294-433`, `Source/General/Project.vb`, `Source/General/ApplicationSettings.vb`, `Source/General/JobManager.vb`, and `Source/Forms/MainForm.vb`
- **Concern:** The safe import, export, migration, downgrade, and corruption behavior for legacy BinaryFormatter data is not mapped.
- **Why it matters:** A new writer could corrupt user-owned projects, settings, templates, profiles, or jobs, and deserializing untrusted data in a server would add a critical security boundary.
- **Evidence found so far:** `SafeSerialization` and `JobManager` use `BinaryFormatter`; `MainForm` reads and writes project and recovery files. A capability-only HTTP response schema now exists under `CrossPlatform/`, but no portable legacy project or settings schema and no HTTP reader for legacy payloads exists.
- **Confidence:** verified
- **Likely owner:** Persistence-slice maintainer
- **Next best check:** Freeze synthetic legacy fixtures, map every reader and writer, and design a Windows-only one-way importer into a versioned typed representation before proposing a new writer.
- **Risk level:** critical
- **Status:** open
- **Notes:** Legacy serialized bytes must never be accepted by the loopback API.

### P-003: Cross-platform process, cancellation, temp, and publication semantics

- **Area or file:** `Source/General/Proc.vb`, `Source/General/ProcController.vb`, `Source/General/GlobalCommands.vb`, and encoder, muxer, and demuxer integrations
- **Concern:** Equivalent rules for argv, environment, process groups, cancellation, retries, cleanup, overwrite, and final output publication are not defined.
- **Why it matters:** A mismatch can run the wrong command, leave encoders alive, delete user data, publish partial output, or hide a failed encode.
- **Evidence found so far:** Current code uses `ProcessStartInfo`, Windows process control, shell and PowerShell paths, explicit kills, and cleanup calls. `ProcController` also owns WinForms processing UI and Windows APIs.
- **Confidence:** verified
- **Likely owner:** Process-boundary slice maintainer
- **Next best check:** Build a current-behavior table for one read-only probe and one cancellable tool, then specify executable identity plus argv and owned-path cleanup invariants.
- **Risk level:** critical
- **Status:** open
- **Notes:** No process execution enters the Linux bootstrap.

### P-004: Linux tool support and provenance matrix

- **Area or file:** `Source/General/Package.vb`, tool-specific integrations, generated scripts, and future platform adapters
- **Concern:** The supported version, install source, executable name, CLI parity, plugin path, license, and fallback for each Linux tool are not selected.
- **Why it matters:** Reporting a tool as present does not prove that StaxRip can invoke it correctly or distribute it lawfully.
- **Evidence found so far:** Current package discovery is Windows-oriented. A generic `StaxRip.Platform` host-facts adapter now reports bounded operating-system and process-architecture facts. Primary upstream sources document Linux support for FFmpeg, VapourSynth, AviSynth+, NVEncC, and MKVToolNix, but the repository has no Linux tool manifest or tool adapter. Two tools have crossed the full provenance bar, MediaInfo CLI under D-045 and ffmpeg under D-047, and the catalogue was measured on 2026-08-22 at 299 entries, recorded with line citations in `Docs/Architecture/Tool-Matrix.md`. D-049 tiers the matrix so those 299 entries can be carried as records that make no support claim and cannot be invoked, rather than as 299 approval cycles.
- **Confidence:** inferred
- **Likely owner:** Tool-adapter maintainer
- **Next best check:** Enumerate the portable catalogue through the dictionary equivalent of `Items`, never through named properties. Measurement shows the named-property walk reaches 145 of 299 entries, so a port built on it returns a catalogue that is 51 percent short and looks complete. The check that catches this is an entry count asserted against the legacy source, not a spot check of familiar tool names, because the 154 unnamed entries are exactly the ones no reviewer would think to look for. The FFprobe row follows when its backup activation or the ffmpeg family arrives.
- **Risk level:** high
- **Status:** in progress
- **Notes:** Bootstrap feature availability uses only `available` or `unavailable`. Every fixed tool-catalog compatibility row remains `unverified`; the bootstrap must not claim compatibility.

### P-005: Unix frame-source and native boundary

- **Area or file:** `Source/Video/FrameServer.vb` and `Source/FrameServer/`
- **Concern:** The Linux and macOS frame transport, plugin ABI, pixel-format ownership, and shutdown model are not selected.
- **Why it matters:** A wrong native boundary can corrupt frames, crash the process, leak shared resources, or make seeking and cancellation unreliable.
- **Evidence found so far:** The current managed boundary uses P/Invoke and COM. The native project is an x64 Windows DLL with Windows headers and SDK dependencies. VapourSynth and AviSynth+ have upstream Unix support, but no StaxRip Unix integration exists.
- **Confidence:** verified
- **Likely owner:** Native and script-engine maintainers
- **Next best check:** Compare direct VapourSynth output, pipe-based transport, and a small portable native adapter using deterministic frame hashes and lifetime tests.
- **Risk level:** high
- **Status:** open
- **Notes:** Keep the current Windows ABI unchanged until a separate native-boundary approval.

### P-006: Loopback web threat model and session bootstrap

- **Area or file:** `CrossPlatform/src/StaxRip.Server` and its embedded web shell
- **Concern:** The exact read-only browser session bootstrap, host and origin checks, and error contract required runtime proof. Future state-changing request protection remains a new boundary.
- **Why it matters:** A local malicious page could try to drive a loopback service, discover local media data, or start work under the user's authority.
- **Evidence found so far:** Source implements exact numeric IPv4 loopback authority on a random port, no CORS, a manual 256-bit process token in a per-instance HttpOnly and SameSite=Strict cookie scoped to `/api/v1`, an exact client header, exact Host and Origin checks, and no mutation route. The cookie deliberately omits `Secure` because the approved boundary is plain loopback HTTP with no TLS. The contract suite and WSL socket and sandbox run passed at their recorded checkpoints. The latest pre-freeze Windows HTTP and installed Edge gates passed 4,532 and 758 checks. The browser proof correlates the hostile logical GET with its preflight, 403 response-extra-info, absent API response, and CORS failure, and binds the CDP endpoint to exact process receipts and the reviewed executable hash. Hostile same-user local processes, shared multi-user hosts, and browser-process background traffic outside the selected page target remain outside this session model. Final committed-source correspondence is pending.
- **Confidence:** verified
- **Likely owner:** Cross-platform server maintainer and security reviewer
- **Next best check:** Reopen this threat model before the first state-changing route, media path, upload, remote listener, shared-host use, or non-browser client. Repeat the current matrices whenever the host, session, request policy, or browser contract changes.
- **Risk level:** high
- **Status:** resolved for SLICE-002
- **Notes:** The resolution is exact to the read-only bootstrap. Never put a session token in a query string, URL fragment, log, console line, API body, or JavaScript-readable storage. Cookie names are per instance because cookies do not bind to a port.

### P-007: Second Linux host execution

- **Area or file:** External Tailscale-connected Ubuntu test host
- **Concern:** Resolved as stated. Access to the independent Linux machine works and the artifact was executed there, though only while a host mitigation was temporarily relaxed and then restored. The remaining obstacle is a different one, recorded as R-S2-039: that host cannot give an unprivileged systemd user unit a private network namespace, so the sandbox the gate requires is unavailable.
- **Why it matters:** WSL proves a Linux runtime boundary on the development machine, but it does not prove behavior on a separate kernel, filesystem, CPU, or host configuration.
- **Evidence found so far:** On 2026-08-17 the host answered a non-interactive command over Tailscale SSH, reporting Ubuntu 24.04.4 on kernel 7.0.0-28-generic with a non-root account, ext4, and dotnet present. The published artifact was transferred and the gate ran against it. The gate failed its own `sandbox-activation-network-not-private` check before the application started. A controlled comparison then showed the same probe yielding a single loopback interface under WSL and all seventeen host interfaces on the independent host, with `systemd-run` returning 0 in both cases, and `unshare` failing outright with a permission error on the uid map. Relaxing the restriction made isolation appear and restoring it made isolation vanish, which establishes the cause by intervention.
- **Confidence:** verified
- **Likely owner:** Test-host administrator
- **Next best check:** Either source a host that permits unprivileged user namespaces, or give the gate a documented reduced-isolation mode that states plainly what it did and did not prove. Do not disable the host mitigation to obtain a pass.
- **Risk level:** high
- **Status:** resolved
- **Notes:** This entry closes because its stated concern, connectivity, is no longer true. The independent-host claim remains blocked under R-S2-039, which the maintainer accepted on 2026-08-17 as a documented environment limitation. Host identity is intentionally omitted from this document.

### P-008: macOS targets and distribution requirements

- **Area or file:** Future macOS adapter, UI, native dependencies, packaging, signing, and notarization
- **Concern:** Supported macOS versions, architectures, tool sources, native GUI framework, signing identity, entitlements, and notarization process are not selected or tested.
- **Why it matters:** A cross-compiled binary can still fail at runtime or violate macOS distribution and native-library requirements.
- **Evidence found so far:** Source contracts and host facts recognize macOS and arm64. No macOS runtime, tool, process, native, UI, or distribution adapter evidence exists, and no macOS runner, artifact, signing setup, or notarization path exists.
- **Confidence:** unknown
- **Likely owner:** Future macOS slice maintainer
- **Next best check:** After Linux core contracts stabilize, obtain a macOS arm64 runner and map tool/runtime availability before selecting packaging or a native UI.
- **Risk level:** high
- **Status:** deferred
- **Notes:** Cross-build output is not runtime evidence.

### P-009: Public cross-platform artifact contract

- **Area or file:** Future cross-platform build, packaging, release, update, and download paths
- **Concern:** Reproducibility, software bill of materials, bundled-tool provenance, signing, naming, update, downgrade, and rollback are not approved.
- **Why it matters:** A public artifact could include unverified binaries, machine-local state, unsafe update behavior, or branding that needs separate permission.
- **Evidence found so far:** U-001, U-006, and U-009 already block public branding and release. The first Linux output is a local test artifact only.
- **Confidence:** verified
- **Likely owner:** Release-slice maintainer
- **Next best check:** Define and approve a release slice after Linux runtime behavior and tool provenance are tested on two hosts.
- **Risk level:** high
- **Status:** open
- **Notes:** Do not run existing protected packaging or release scripts for the bootstrap.

### P-010: Native cross-platform desktop client

- **Area or file:** Future desktop UI project
- **Concern:** The product needs a native desktop client in addition to the web shell, but the framework, accessibility contract, deployment size, and Linux display-server support are not selected.
- **Why it matters:** Choosing a framework early could couple engine rules back into the UI or exclude Linux users and accessibility needs.
- **Evidence found so far:** Official .NET MAUI platform support excludes Linux. Avalonia documents Windows, macOS, and Linux desktop support, with X11 as the default Linux backend and Wayland still experimental. No UI framework dependency exists in the implemented bootstrap.
- **Confidence:** inferred
- **Likely owner:** Future desktop-client maintainer and accessibility reviewer
- **Next best check:** Keep the API and contracts UI-neutral, then prototype one accessible workflow in Avalonia after the engine can inspect media without WinForms.
- **Risk level:** medium
- **Status:** deferred
- **Notes:** The web shell is the first client and does not decide the native GUI framework.

### P-011: Startup automation and extension compatibility

- **Area or file:** `Source/Forms/MainForm.vb:6158-6173`, `Source/General/GlobalClass.vb:355-360`, `Source/General/StaxRipUpdate.vb:41-70`, command implementations, and PowerShell scripts
- **Concern:** The cross-platform contract for command-line automation, auto-loaded scripts, update checks, event scripts, macros, and extension ordering is not mapped.
- **Why it matters:** A port could silently skip user automation, execute it with different authority or timing, add startup network traffic, or break script and command compatibility.
- **Evidence found so far:** The main form processes the command line, shows and checks updates, and schedules PowerShell loading on startup. `LoadPowerShellScripts` executes `.ps1` files from application and user folders. The update checker calls GitHub. The legacy update script also contains download, process, and deletion behavior.
- **Confidence:** verified
- **Likely owner:** Automation and compatibility slice maintainer
- **Next best check:** Enumerate every startup-triggered command, script, process, filesystem, and network path, then classify preserve, adapt, opt-in, disable, or defer before Windows parity work.
- **Risk level:** high
- **Status:** open
- **Notes:** The bootstrap implements none of these paths and makes no extension compatibility claim.

## Resolution state

P-006 is resolved only for the exact read-only SLICE-002 boundary. P-007 is resolved: the independent host is reachable and ran the artifact, though only while a host mitigation was temporarily relaxed and then restored. The independent-host claim is blocked instead by R-S2-039, an environment limitation on that host rather than an access problem. The workflow, persistence, process, tool, native, macOS, native-client, automation, and public-release boundaries remain open, in progress, or deferred as recorded above.

### P-012: Subtitle disposition facts are not stable across the pinned authority range

- **Area or file:** `CrossPlatform/src/StaxRip.Contracts/MediaFacts.cs` (`MediaTextFacts`), `Docs/Architecture/Media-Inspection-Agreed-Facts.md:126`, `Docs/Architecture/Tool-Matrix.md` version-skew row
- **Concern:** The agreed subtitle commentary and hearing-impaired facts have no carrier at the range floor, so they cannot ship under the ratified range-first rule, and the agreed row names a carrier that neither pinned version reports.
- **Why it matters:** The exit-criteria review recorded these two facts as blocked by the fixture-first rule, which is wrong and makes the remaining work look smaller and cheaper than it is. A wrong reason produces a wrong next action.
- **Evidence found so far:** A chaptered dual-subtitle Matroska file probed with both pinned binaries: 26.05 reports `ServiceKind` on each Text track, `HI` for the hearing-impaired track and `C` for the commentary track; 24.01 reports no such field. Both ends agree on every other Text member. The agreed row at `Media-Inspection-Agreed-Facts.md:126` names `Text/Commentary` and `Text/HearingImpaired`, which the ceiling's own parameter enumeration does not list at all. The probe file is not committed; the probe was run from the scratchpad.
- **Confidence:** verified for the two pinned binaries on one file; the value vocabulary beyond `HI` and `C` is unknown
- **Likely owner:** Cross-platform inspection maintainer with the tool-matrix owner
- **Next best check:** Decide whether the range floor moves to a version that reports `ServiceKind`, or whether the two facts are recorded as ceiling-only and excluded from version 1. Either path amends the agreed-facts row to name the real carrier first.
- **Risk level:** low
- **Status:** resolved
- **Notes:** Recorded 2026-08-21. Resolved 2026-08-22 by D-048: both facts stay out of version 1, the pinned range is unchanged, and the deferral is enforced by CT-045, which asserts the instability from the committed goldens and turns red if the floor ever gains the carrier.

### P-013: The value-embedded-path strip rule is specified but unimplemented

- **Area or file:** `CrossPlatform/src/StaxRip.Core/MediaFactsPrivacy.cs`, `Docs/Architecture/Media-Inspection-Adapter-Contract.md` privacy guard section
- **Concern:** The adapter contract requires stripping any field whose value embeds a filesystem path other than the probed path itself, and the guard implements name-based stripping only. No value inspection exists anywhere in it.
- **Why it matters:** Every exposed string fact is free text from the media. Title, subtitle title, and any future chapter label are author-controlled and can carry an absolute path, which would cross the wire while the payload's own contract says it cannot.
- **Evidence found so far:** `MediaFactsPrivacy.cs` matches names only; the contract text requires a value rule beside it. No committed fixture carries a path-shaped value, and the per-golden leak assertions in CT-020 grep for identifier and file-date names, not for path shapes.
- **Confidence:** verified as a gap between the contract and the code
- **Likely owner:** Cross-platform inspection maintainer
- **Next best check:** Decide the rule's shape before writing it: a value scan risks stripping legitimate titles that merely contain separators, so the cheaper first move may be to bound and record the exposure rather than to filter it. A hostile-label fixture is the enforcement evidence either way.
- **Risk level:** medium
- **Status:** resolved
- **Notes:** Recorded 2026-08-21, surfaced by an independent review of a corpus-growth plan that would have routed author-controlled chapter labels to the wire verbatim. Resolved 2026-08-22: the guard now judges values as well as names, removing any member whose value carries an absolute path in drive-letter, doubled-separator, or rooted-POSIX form. CT-044 proves both directions, that the three poisoned carriers are dropped and that a label containing a colon and a slash survives intact, because a value rule that strips real facts is its own defect.

### P-014: No performance baseline exists, so no efficiency claim can be graded

- **Area or file:** `Docs/` as a whole, `Source/Encoding/`, `Source/General/Proc.vb`, `CrossPlatform/eng/`
- **Concern:** The repository has no benchmark, no timing corpus, and no recorded performance measurement of any kind. Nothing establishes what StaxRip's throughput is today on either platform, so no change can be shown to improve or regress it.
- **Why it matters:** Speed and efficiency are stated goals for the port, and every gate the repository has grades correctness. A performance change with no baseline is graded by impression, which is the same failure class as a check that cannot fail: it cannot report a regression, so it always passes. It also makes the port's central risk unmeasurable, because a portable pipeline that is correct and half as fast is a failed port, and nothing currently would say so.
- **Evidence found so far:** A directed search of `Docs/` on 2026-08-22 found no benchmark document, no timing artifact, and no performance section. The only existing mention of benchmarking is a privacy constraint on what such output may contain (`Docs/Planning/ENGINEERING.md:336-337`), which already gives a future harness its recording rules: aggregate durations, counts, exit status, stable fixture ids, and the tested commit are permitted; paths, media names, scripts, and command lines are not. The seven verification gates measure counts and exit status, never elapsed work. Candidate levers exist and are unmeasured, all read from the source on 2026-08-22: `ParallelProcsNum` defaults to 3, and audio processing, subtitle cutting, and video chunk encoding are appended to one action list run under a single `Parallel.Invoke` bounded by it, so they share one budget (`Source/General/ApplicationSettings.vb:70`, `Source/General/GlobalClass.vb:622-651`); `EncoderProcessPriority` defaults to `BelowNormal` while `ToolProcessPriority` defaults to `Normal`, so the encoder is the lowest-priority participant in its own pipeline (`:44` against `:105`); and the two demuxers are structurally asymmetric, where `ffmpegDemuxer` starts one process per audio stream (loop at `Source/General/Demux.vb:288-292` into the launch at `:375-383`) and one per subtitle (loop at `:401` into `:434-441`), while `mkvDemuxer` accumulates every stream into one argument list across its loop and starts a single `mkvextract` outside it (`:948-964` then `:970-980`).
- **Confidence:** verified as an absence, by directed search
- **Likely owner:** Cross-platform engine maintainer
- **Next best check:** Build the baseline before touching any lever. The cheapest honest form is a harness that runs a fixed job over committed fixtures and records per-stage elapsed time, run several times to establish variance, because a single timing on a shared desktop cannot distinguish a real regression from scheduler noise. Measure first on Windows, where the product runs today, so the port has a number to be compared against rather than a number invented after the fact.
- **Risk level:** medium
- **Status:** open
- **Notes:** Recorded 2026-08-22. The three levers above are candidates, not findings; none has been measured, and listing them here is a record of where to look, not a claim that changing them helps. Separately verified while gathering this: the application recycles its own process between jobs once private memory exceeds 1500 MB, relaunching itself with `-StartJobs -NoFocus` and closing the running instance (`Source/General/GlobalClass.vb:516-519`). That is on the normal batch path, so any throughput measurement over a long queue has to account for a full application restart mid-run, and a harness that assumes one continuous process will mis-attribute the gap. Findings adjacent to this unknown are in `Docs/Review/Legacy-Efficiency-Findings.md`.
