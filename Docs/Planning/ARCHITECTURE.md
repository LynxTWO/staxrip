# StaxRip Community Architecture Document (ADD)

Version: 0.3. Date: 2026-08-16. Authors: LynxTWO and Codex. Status: Confirmed.
Companion documents: `ENGINEERING.md`, `DECISION-LOG.md`, and the slice briefs (`SLICE-001` onward).

## Interview State

- **Last completed:** Portability architecture map, trust boundaries, platform matrix, and risk-ranked slice plan
- **Next:** Repeat the immutable SLICE-002 artifact on an independent Ubuntu host whose unprivileged user units can obtain a private network namespace (R-S2-039), then prepare the read-only media-inspection slice without widening the current bootstrap authority
- **Open questions:** Carried in `../Unknowns/Planning-Unknowns.md` and `../Unknowns/Portability-Unknowns.md`
- **Statuses pending:** None

## Triage Card

- **Project name:** StaxRip Community
- **One-line summary:** A public StaxRip fork that preserves its Windows x64 application while building an additive Linux-first engine and clients, with macOS later.
- **Project type:** Mixed desktop app and utility
- **Starting point:** Existing code
- **Run mode:** Fast-run
- **Scale tier:** T2
- **Team shape:** Solo
- **Experience level:** Built some things
- **Interview depth:** Standard
- **Risk flags:** Personal data in local paths, logs, media metadata, scripts, and command lines
- **Platform targets:** Current application on Windows x64; additive engine and web client on Linux x64 first; macOS later
- **Timeline posture:** Weeks per slice
- **Budget posture:** Near zero
- **Compatibility posture:** Strict upstream compatibility
- **Initial workflow direction:** Source opening through ready-to-encode
- **Privacy depth:** Full depth now

## 1. One-Page Overview

- **What it is:** StaxRip Community preserves the portable Windows x64 video and audio processing front end and adds a separate Linux-first engine architecture. The port keeps projects, settings, templates, scripts, commands, native interfaces, external-tool behavior, and user-owned files behind explicit compatibility boundaries.
- **Who it is for:** Primary users configure local video and audio processing jobs. Secondary users follow guided setup, and community contributors maintain the fork.
- **The core loop:** A user opens source media, StaxRip verifies and probes it, builds the effective processing project, exposes bounded project checks, and then applies its existing Add Job and encode-time authority.
- **Major pieces:** Current desktop shell, source intake, project and profile state, script and filter pipeline, tool orchestration, job engine, FrameServer boundary, diagnostics and AutoCrop; implemented cross-platform contracts, core, host-facts adapter, local host, and web shell; future workflow, tool, and native adapters; and a later native client.
- **Current portability slice:** Approved `SLICE-002`, a capability-only Linux engine bootstrap. It cannot open media, import projects, execute tools, encode, persist state, accept remote requests, distribute a public artifact, or publish media output. A local `dotnet publish` output is authorized only for runtime verification and becomes evidence only after its gates pass.
- **What this is not:** It is not a new encoder, a cloud service, a flag-day rewrite, a remote control plane, or public-release automation.

## 2. System Context

- **Primary actors:** Current Windows users and future Linux users who configure local video and audio processing jobs.
- **Secondary actors:** New users following guided setup, future macOS users, community contributors, and fork maintainers.
- **Local administration:** The user chooses the portable application location, settings location, tools, profiles, templates, scripts, source media, and destinations.
- **External systems:** The Windows, Linux, and later macOS filesystems and process APIs; current Windows Registry and PowerShell surfaces; AviSynth+, VapourSynth, Python, encoders, muxers, demuxers, media probes, plugins, and GitHub release endpoints.
- **Boundary statement:** StaxRip Community owns its clients, workflow contracts, project state, generated scripts and tool plans, job coordination, diagnostics, and external-tool adapters. External tools own codec and container processing. Users own their paths, media, scripts, profiles, settings, projects, and outputs. The fork will not reimplement encoders, script engines, or media containers. The first local host accepts no user media or project data.

Current evidence comes from `Source/StaxRip.vbproj`, `Source/FrameServer/FrameServer.vcxproj`, `Source/Tools/AutoCrop/AutoCrop.vbproj`, the bounded source-flow evidence in `../Verification/SLICE-001/M0-SYSTEM-MAP.md`, `../Architecture/Portability-System-Map.md`, and `../Architecture/Coverage-Ledger.md`.

## 3. Product Shape and Platforms

- **Current shape:** Mixed Windows x64 desktop application, native frame-server library, and support executables.
- **Target shape:** Preserve the current application. Add a cross-platform engine, local HTTP host, web shell, platform adapters, and a later native desktop client.
- **Platform order:** Linux x64 now, macOS arm64 later. Windows x64 remains supported throughout the additive migration.
- **Offline behavior:** Normal configured workflows must work offline. Network access is optional for update checks, documentation, and separately approved downloads.
- **Distribution:** Portable archive through GitHub Releases is the intended public shape. Fork release automation remains deferred until the release boundary has its own approved slice.
- **Languages at launch:** English. New user-facing text must not become hidden runtime truth, and touched copy should leave a clean localization seam.
- **Code license:** MIT, retaining required notices and upstream attribution.

DECISION: Product shape and platforms

- **STATUS:** Confirmed
- **CHOICE:** Preserve the existing portable Windows x64 application and external-tool behavior. Build an additive Linux-first engine and clients, then adapt macOS after the contracts stabilize. Do not require a Windows rewrite or installer.
- **BECAUSE:** The current GUI, persistence, process, and native boundaries are coupled. A separate engine can earn platform behavior in small slices without converting user data or changing current workflows.
- **OPTIONS CONSIDERED:** Additive engine beside Windows, selected for compatibility and testability. Complete rewrite first, broad simultaneous risk. Wine-only strategy, compatibility aid but not a native product boundary.
- **REVISIT WHEN:** A portable contract cannot preserve a required Windows outcome, or runtime evidence changes the platform order. See D-038.

## 4. Module Map

These are logical ownership regions. The current code does not consistently enforce them as assembly boundaries.

| Module | Primary responsibility | Owns | Talks to |
|---|---|---|---|
| Desktop shell | Main window, navigation, dialogs, and visible workflow state | Session-only UI state | Workflow coordinator, diagnostics |
| Source intake | Open, inspect, validate, and classify selected media | Source facts for the active project | Media probes, script pipeline, project state |
| Project and profile state | Projects, templates, profiles, settings, and compatibility | Persisted StaxRip state | Desktop shell, workflow coordinator |
| Script and filter pipeline | Build AviSynth or VapourSynth processing graphs | Generated scripts and filter selections | Source intake, FrameServer, tool orchestration |
| Tool orchestration | Resolve packages and construct exact external commands | Tool selection and canonical argument data | External tools, job engine, updates |
| Job engine | Queue, start, monitor, cancel, and report work | Job lifecycle state | Tool orchestration, project state, diagnostics |
| FrameServer boundary | Open scripts and return frames across managed/native code | Native runtime handles and frame ownership | Script pipeline, AviSynth+, VapourSynth |
| Diagnostics and support | Present logs, bounded support reports, errors, and recovery guidance | Diagnostic views and sanitized report content | All runtime modules, user clipboard |
| AutoCrop support tool | Sample frames and return crop values | One AutoCrop process result | FrameServer boundary, source workflow |
| Cross-platform contracts and core | Define versioned DTOs and platform-neutral rules | Capability and future workflow truth | Platform adapters, local host, current and future clients |
| Local engine host | Expose versioned local endpoints now and bounded events only in a later slice | Process-local session and request boundary | Cross-platform core, first-party clients |
| Web shell | Present local engine state and workflows | Browser-only presentation state | Local engine host |
| Platform adapters | Resolve operating-system, filesystem, process, tool, script, native, and storage behavior | Platform-specific side effects | Cross-platform core and external systems |
| Native cross-platform client | Provide later desktop integration without owning engine rules | Desktop-only presentation state | Local application contracts |

**Target dependency rule for new work:** Clients call versioned application contracts. Application owners call the platform-neutral core. The core calls explicit persistence, native, process, and tool adapters. Adapters do not reach into clients. Existing WinForms violations are mapped before they are changed, and the first bootstrap does not reference the current application.

## 5. Interfaces and Contracts

- **Interface style:** Mixed. The managed application mostly uses typed calls and events in one process. It crosses a native exported interface for frame serving, invokes tools through exact argument construction, exchanges scripts and files with runtimes, and exposes command and PowerShell extension surfaces.
- **Compatibility surfaces:** `.srip` projects and templates, application settings, profiles, jobs, command-line commands, PowerShell commands, macros, generated AviSynth and VapourSynth scripts, generated external-tool arguments, native FrameServer exports and structures, temp/output rules, and portable directory conventions.
- **Contract rule:** The owning module defines each shape. Tests and fixtures bind the persisted bytes, generated text, argument vector, native layout, or file behavior that users and external tools consume.
- **Versioning posture:** Additive by default. A breaking change requires an explicit migration or compatibility adapter, focused verification, documentation, and a separate approval decision.

DECISION: Interface and compatibility posture

- **STATUS:** Confirmed
- **CHOICE:** Keep the current mixed interface style and place new workflow behavior behind typed owners and adapters. Preserve every named compatibility surface unless a later approved migration says otherwise.
- **BECAUSE:** A rewrite would combine GUI, persistence, command, native, and tool risk. Bounded seams allow visible improvement without changing the contracts users already depend on.
- **OPTIONS CONSIDERED:** Preserve and isolate current seams, slower cleanup but lowest user risk. Layered internal rewrite before features, cleaner structure but delays value and expands regression risk. New application rewrite, maximum design freedom but incompatible with the stated goal.
- **REVISIT WHEN:** A mapped seam prevents the active slice from being tested or extended without duplicate behavior.

## 6. Core Data Flow

The source-opening flow is a long transaction inside `MainForm.OpenVideoSourceFiles` rather than a separate workflow service. The current flow is:

1. The user selects or drops files, invokes a command, supplies command-line input, reopens a project, or starts a batch path.
2. `OpenAnyFile` classifies the input as a project, ordinary source, disc image, or folder and routes it to the matching handler.
3. Before replacing an active source, StaxRip offers to save it and serializes a recovery project to the temp folder.
4. The application normalizes and sorts paths, verifies sources, records `Project.SourceFiles` and `Project.SourceFile`, and handles special source types.
5. StaxRip selects or confirms the source filter and frame-server engine, then verifies required packages.
6. MediaInfo and related probes populate video, audio, HDR, language, size, rate, and stream facts.
7. The workflow selects temp and target paths, may demux or extract metadata, modifies filters, generates scripts, updates audio and target state, initializes the muxer, and may run AutoCrop, AutoResize, or a compression check.
8. The application raises source-loaded events, re-enables the Assistant, saves the log, and returns control to the configured project workflow.

- **Trigger points:** File dialog, drag and drop, source text field, StaxRip command, command-line input, project recovery, and batch processing.
- **Slow paths:** Media probing, demuxing, metadata extraction, filter or script validation, AutoCrop, AutoResize, and compression checks. Existing dialogs, processing surfaces, the Assistant, and the log provide mixed progress feedback.
- **Abort recovery:** Expected aborts reload the serialized recovery project and restore the project path and window text.
- **Unexpected failure:** For a non-abort exception, the global handler attempts recovery and diagnostics and then terminates the process. The following blank-project call is not a verified recovery outcome. Retained or persisted state across failure routes remains U-005.
- **Required `SLICE-001` seam:** Evaluate project checks only after the whole source-opening transaction returns successfully, its initial-generation capability is current, both source and project-check mutation depths are zero, and the pure activation policy passes. Existing source-loaded and project events are not assumed to prove that boundary. The mapped shared-entry and project-replacement owners clear prior state. Static production, product-assembly, and reviewed production-equivalent source-opening activation evidence passes; exact `Application.Run` and operating-system presentation remain required.

Source-flow evidence: `Source/Forms/MainForm.vb:2289-2342` and `Source/Forms/MainForm.vb:2469-2889`. Failure-path evidence: `Source/Forms/MainForm.vb:2925-2926` and `Source/General/GlobalClass.vb:1570-1597`.

## 7. Data Domain Overview

- **Media source:** One or more user-selected paths plus probed media and stream facts.
- **Project:** The active processing configuration, source facts, targets, scripts, encoder, muxer, audio tracks, subtitles, crop, resize, metadata, and workflow state.
- **Template:** A reusable serialized project starting point.
- **Application settings:** User-wide preferences, tool choices, filter profiles, events, folders, and UI behavior.
- **Profile:** Reusable encoder, audio, filter, muxer, demuxer, or workflow configuration.
- **Package:** A known external executable, runtime, plugin, script, or support component and its configured path and requirements.
- **Generated script:** The AviSynth or VapourSynth program derived from the active project.
- **Generated command:** The canonical external-tool invocation derived from project and package state.
- **Job:** A persisted or queued project execution with lifecycle state.
- **Diagnostic record:** Runtime log data and bounded support-report output.

**Key relationships:** A project has one primary source and may have multiple ordered sources. A template initializes a project. A project references profiles and packages but owns its effective processing choices. A job points to a serialized project. Generated scripts and commands derive from the effective project and tool state and must not become a second source of truth.

**Volume expectations:** One local user and one active project per process are the normal interactive shape. Source count, saved profiles, templates, jobs, and media size are user-driven. Repository evidence does not establish safe upper bounds, so performance claims for large collections remain Open.

## 8. Technology Selection

### 8.1 Client

DECISION: Client technology

- **STATUS:** Confirmed
- **CHOICE:** Keep the current VB.NET WinForms client. Add a first-party web shell over UI-neutral local contracts. Prototype a native cross-platform client later, with Avalonia as the first candidate rather than a selected dependency.
- **BECAUSE:** The web shell proves the engine boundary on Linux now. Preserving WinForms avoids a forced migration, and deferring the native toolkit makes the choice depend on a real workflow and accessibility evidence.
- **OPTIONS CONSIDERED:** Web shell then native client, selected. Native client first, stronger desktop integration but slower engine proof. Web-only replacement, simpler but drops the requested native direction. See D-039 and D-042.
- **REVISIT WHEN:** Portable media inspection can drive a representative native workflow on real Linux and Windows hosts.

### 8.2 Languages

DECISION: Implementation languages

- **STATUS:** Confirmed
- **CHOICE:** Keep VB.NET for the current managed app and AutoCrop, C++17 for the current FrameServer, and PowerShell for current user automation. Use C# only in the isolated .NET 10 cross-platform subtree.
- **BECAUSE:** Existing languages retain current contracts. C# provides a bounded modern host and cross-platform core without migrating legacy code.
- **OPTIONS CONSIDERED:** Isolated C# subtree, selected. New portable VB projects, possible but less direct for ASP.NET Core examples and contributors. Rewrite existing owners, rejected as unnecessary risk. See D-039.
- **REVISIT WHEN:** A shared contract must be consumed by the current .NET Framework app and cannot remain language-neutral.

### 8.3 Backend

DECISION: Backend approach

- **STATUS:** Confirmed
- **CHOICE:** Add a local application host for cross-platform engine contracts and first-party clients. Keep it loopback-only, offline-capable, single-user, and free of remote state.
- **BECAUSE:** A local host separates engine work from UI technology without adding an operated service, accounts, availability dependency, or media transfer.
- **OPTIONS CONSIDERED:** Local host, selected. Shared remote backend, wider access but new security, privacy, operations, and cost. No host, keeps one process but couples the first Linux UI to engine implementation. See D-039.
- **REVISIT WHEN:** A confirmed feature requires remote or multi-user behavior and has a separate threat and operations model.

### 8.4 Database

DECISION: Storage approach

- **STATUS:** Confirmed
- **CHOICE:** Preserve existing local files, serialized formats, and Registry use. Do not add a database in the initial workflow slices.
- **BECAUSE:** Strict compatibility makes the existing formats authoritative. A database would require migration, backup, repair, portability, and rollback contracts.
- **OPTIONS CONSIDERED:** Existing local storage, compatible but requires careful ownership. Embedded database, stronger queries but a migration boundary. Remote database, shared access but incompatible with local-first use.
- **REVISIT WHEN:** A confirmed feature needs queries or transactional relationships that existing formats cannot serve safely.

### 8.5 Authentication

DECISION: Authentication

- **STATUS:** Confirmed
- **CHOICE:** Add no product account. Protect the loopback browser edge with a random process-local HttpOnly session, exact client header, Host and Origin checks, and no CORS.
- **BECAUSE:** The session, exact authority checks, exact client header, and no-CORS policy reject the tested hostile-origin browser flow without creating identities, stored credentials, or a remote service. The installed-browser result verifies the exact read-only bootstrap boundary; mutation, remote, shared-host, and hostile same-user process threats require a new decision.
- **OPTIONS CONSIDERED:** Process-local session, selected. Loopback without a session, weaker cross-site boundary. Token in URL, leak-prone. User accounts, unnecessary for the local host. See D-040.
- **REVISIT WHEN:** A state-changing endpoint enters scope, a client cannot use the session model, or a listener leaves loopback.

### 8.6 AI layer

Skipped. AI is not part of the product architecture or the initial roadmap. Any future AI feature requires a separate provider, privacy, validation, fallback, cost, and offline decision.

### 8.7 Notifications and messaging

DECISION: Notification channels

- **STATUS:** Confirmed
- **CHOICE:** Use in-app status, Assistant guidance, task dialogs, processing views, and privacy-bounded diagnostics. Do not add email or push messaging.
- **BECAUSE:** Users are present in a local desktop workflow, and `SLICE-001` needs clear state rather than a remote channel.
- **OPTIONS CONSIDERED:** In-app only, direct and offline. Windows notifications, useful for long jobs but adds OS integration behavior. Remote messaging, requires a service and personal data.
- **REVISIT WHEN:** Measured long-running background use shows that in-app completion and failure signals are insufficient.

### 8.8 Hosting and builds

DECISION: Build and distribution path

- **STATUS:** Confirmed
- **CHOICE:** Keep Visual Studio and MSBuild x64 builds for the current application. Add a separate .NET 10 source build and local-test Linux x64 publish under root-level `CrossPlatform/`. Use GitHub for source collaboration. Defer public artifacts and release automation.
- **BECAUSE:** Separate graphs preserve current behavior and permit an actual Linux runtime gate. Existing package and release scripts remain outside the port bootstrap.
- **OPTIONS CONSIDERED:** Separate modern build, selected. Add to the legacy solution, premature coupling. Install a Linux SDK solely for bootstrap tests, unnecessary with self-contained publish. Public preview now, blocked by provenance and support unknowns. See D-041.
- **REVISIT WHEN:** Two-host Linux evidence and a useful media flow justify CI or a release slice.

## 9. Integration Map

| External system | Purpose | Direction | Failure behavior |
|---|---|---|---|
| Windows filesystem and Registry | Portable state, user paths, temp data, outputs, and settings-location selection | Both | Stop the affected action, preserve prior owned state where possible, and identify the path class without exposing unrelated user data |
| MediaInfo | Probe containers and streams | Read | The existing source-opening path reports probe failure. After a successful open, project checks use only final-catalog bounded facts and do not invent media facts. |
| AviSynth+ and plugins | Scripted frame processing | Both | Keep the project recoverable, show the bounded engine or script error, and do not start dependent tools |
| VapourSynth, Python, and plugins | Scripted frame processing | Both | Keep the project recoverable, show the bounded engine or script error, and do not start dependent tools |
| Encoders, muxers, demuxers, and support tools | Perform media transformations | Both | Mark the requirement or operation unavailable; do not substitute a different tool silently |
| PowerShell | User and packaged automation | Both | Stop the command path and report the failure without logging private script inputs by default |
| GitHub release endpoints | Optional update and future distribution metadata | Read | Offline or service failure does not block configured local work |
| Windows process and shell APIs | Launch tools and open external resources | Both | Retain canonical arguments and report launch failure without shell reinterpretation |
| Linux and later macOS process APIs | Future portable tool launch and process-group control | Both | Remain disabled until argv, cancellation, child ownership, temp, and publication contracts pass |
| Local browser and Kestrel host | First-party cross-platform UI over versioned local contracts | Both | Bind to loopback, reject invalid session, Host, and Origin, enable no CORS, and expose no product mutation in the bootstrap |
| Linux filesystem and executable search path | Future local state and tool discovery | None in bootstrap | Report the fixed tool catalog as unverified; defer path and executable inspection to P-004 |

**Adapter rule for new work:** A touched external boundary gets one owning adapter or choke point. Legacy direct access is mapped before cleanup. A slice does not spread new provider calls across forms.

## 10. Extension Points

| Future capability | Connects at | What exists now | What is deliberately absent |
|---|---|---|---|
| Source project checks | End of source intake and explicit refresh | Typed transient result, pure evaluator, mapper, coordinator, lifecycle hooks, explicit refresh, summary, details, and fixed menu route | Add Job or encode authority, persistence, automatic repair, and completed workflow or human evidence |
| Guided blocker repair | Project-check result plus project owners | Existing controls and requirement dialogs | Automatic setting, tool, template, or project mutations |
| Source-opening progress model | Source intake stages and processing UI | Mixed dialogs, logs, task execution, and processing surfaces | One stage model with measured timing and cancellation ownership |
| Workflow performance evidence | Source intake and diagnostics | Existing timestamps and logs in selected paths | Privacy-safe stage metrics and a regression baseline |
| Job recovery improvements | Job engine, project persistence, and process control | Existing recovery projects and job files | New retry, concurrency, or publication semantics |

The Source project-check seam belongs to prior `SLICE-001`; its remaining operating-system and human presentation checks stay with that slice. The active slice is `SLICE-002`, the Linux engine bootstrap. Likely later Source expansions include guided blocker repair, source-opening progress, and privacy-safe workflow performance evidence. They are candidates, not committed feature scope.

## 11. Scale and Performance Posture

- **Load expectations:** One interactive user and one active project per process. Multiple input files and queued jobs remain supported, but `SLICE-001` does not add parallel source-opening work.
- **Measurement rule:** Establish a fixed synthetic fixture baseline before optimizing. Separate existing source-opening time from time added by project-check evaluation and rendering.
- **Performance targets:** Project-check evaluation and rendering add no more than 100 ms at the 95th percentile on the agreed local fixture set. The median full source-opening time must not regress by more than 5 percent or 100 ms, whichever allowance is larger. Fifty repeated project-check evaluations of an unchanged loaded project must show no net process-handle growth.
- **Scaling approach:** Optimize only stages with measured cost. Cache immutable probe facts only when ownership and invalidation are explicit. Do not add concurrency until cancellation, recovery, and shared-resource behavior are mapped and tested.

DECISION: Performance targets

- **STATUS:** Confirmed
- **CHOICE:** Start with bounded added-overhead, total-flow regression, and handle-growth targets instead of promising a total open time before a baseline exists.
- **BECAUSE:** Media, tools, storage, plugins, and scripts make total source-opening time hardware and fixture dependent. Added overhead and regression are controllable by the slice.
- **OPTIONS CONSIDERED:** Relative regression targets, honest before a baseline. Fixed total-open target, easier to read but unsupported across media and hardware. No numeric target, faster planning but unable to verify speed claims.
- **REVISIT WHEN:** A representative baseline exists across fast local media, slow storage, multiple sources, and both frame-server engines.

## 12. Deployment Topology

- **Development environments:** Local source worktree, isolated deterministic fixtures, Windows x64 build host, WSL Ubuntu runtime, and an independent Ubuntu peer, reachable and exercised on 2026-08-17 though blocked for isolation reasons recorded as R-S2-039. A later macOS runner is required.
- **Current verification path:** The separate .NET 10 subtree built on Windows, published one self-contained Linux x64 local-test artifact, and ran those exact bytes in WSL. The same immutable tree ran on the independent Ubuntu host on 2026-08-17 and passed 27 checks, but only while a host mitigation was temporarily relaxed and then restored; under the normal configuration the sandbox prerequisite is unavailable (R-S2-039).
- **Future public release path:** An approved release slice must define dependency provenance, portable-tree assembly, artifact identity, signing posture, archive verification, publication approval, and release notes before GitHub distribution begins.
- **Rollback:** Source changes revert as bounded commits. A future binary release must keep the prior portable archive available and document whether its settings and projects can safely open data last written by the new release. Rollback must not overwrite or downgrade user-owned state silently.

DECISION: Deployment posture

- **STATUS:** Confirmed
- **CHOICE:** Verify the current application through its existing Windows gates and the new bootstrap through its separate .NET 10 and Linux gates. Produce only ignored local-test artifacts until a release slice is approved.
- **BECAUSE:** Runtime proof needs an executable Linux artifact, but local verification does not settle provenance, support, signing, update, downgrade, or publication.
- **OPTIONS CONSIDERED:** Isolated local artifacts, selected. Manual public upload, weak identity and rollback. Automated release, premature privileged boundary. See D-041.
- **REVISIT WHEN:** A useful Linux workflow passes on two hosts and P-009 is ready for a release decision.

## 13. Failure and Degraded Modes

This table is the target posture for touched paths. It does not claim every current path already behaves this way. Failures that abort source opening remain owned by the existing source-opening UI and produce no `SLICE-001` project-check result. The approved three-check catalog includes only post-success rows that map without execution or mutation.

| Failure | User sees | System does | Recovery |
|---|---|---|---|
| Missing, inaccessible, or unsupported source | The existing source-opening error tied to the selected source | Does not invoke the `SLICE-001` project-check adapter, invent media facts, or retain a current result | User selects another source or corrects access |
| Media probe failure | The existing probe error and bounded failure category | Does not invoke the `SLICE-001` project-check adapter or invent media facts | Retry after tool, file, or format correction |
| Missing frame-server runtime or required tool | Missing requirement and affected workflow stage | Does not substitute another engine or executable silently | User repairs configuration or explicitly selects a supported alternative |
| Script or FrameServer open failure | Bounded engine or script error with a route to diagnostics | Does not publish a preview or current project-check result | User edits the script, filter, runtime, or source choice |
| Temp path unavailable or storage exhausted | Temp or capacity blocker without unrelated path disclosure | Stops before dependent tool work and preserves prior owned state | User selects a valid temp location or frees space |
| Demuxer or helper-process failure | Tool name, stage, and bounded exit status | Keeps partial outputs non-authoritative and does not advance project-check presentation | User reviews diagnostics and retries after correction |
| User cancellation | Canceled state, not a failure claim | Stops at a defined boundary and clears prior project-check presentation | User restarts source opening |
| Recovery snapshot cannot be written | Warning that rollback protection is unavailable | Current behavior continues only under the existing source-opening contract; `SLICE-001` does not change this decision | A later recovery slice defines whether opening must stop |
| Unexpected source-opening exception | Existing exception and diagnostic route | For a non-abort exception, the global handler attempts recovery and diagnostics and terminates the process; the `SLICE-001` project-check adapter is not invoked | Later failure-injection work must establish the retained-state and recovery contract |
| GitHub or network unavailable | Optional update information is unavailable | Local configured workflows continue | Automatic or user-triggered retry later |
| Diagnostic content contains private values | Preview and review warning | New reports use an explicit allowlist and bounded redaction; raw logs are not attached automatically | User edits the preview before sharing |

DECISION: Failure and recovery posture

- **STATUS:** Confirmed
- **CHOICE:** The project-check slice observes and explains selected existing state. It does not change recovery, cancellation, temp-file, process, or cleanup semantics.
- **BECAUSE:** Those behaviors cross protected ownership and failure boundaries. A read-only result can improve clarity without changing what source opening commits or rolls back.
- **OPTIONS CONSIDERED:** Observe and report only, smallest safe slice. Repair selected failures in the same slice, more value but mixed recovery behavior. Rewrite source opening as a transaction first, broad risk and delayed user value.
- **REVISIT WHEN:** The project-check summary identifies one frequent blocker with a deterministic recovery harness and separate approval.

## 14. Architecture Guardrails

1. Do not silently change generated commands, scripts, project files, settings, templates, profiles, jobs, temp rules, or output behavior.
2. Do not parse UI text, localized text, logs, or exception prose to determine project-check outcomes.
3. Project checks use stable ids, typed values, and an explicit severity and ownership model.
4. `SLICE-001` does not save new persisted state or rewrite existing persisted state.
5. `SLICE-001` does not download, replace, select, or execute a different external tool.
6. `SLICE-001` does not delete, move, overwrite, publish, or repair user-owned files.
7. New diagnostics use allowlisted fields, synthetic fixtures, bounded lengths, and culture-invariant handling.
8. A form consumes one project-check result. It does not reproduce project rules in event handlers.
9. A touched external boundary has one owner or adapter. New direct provider calls do not spread across forms.
10. No new concurrency, retries, cancellation policy, or background worker enters `SLICE-001`.
11. Existing source-opening recovery remains unchanged until branch activation and retained-state behavior are deterministically tested.
12. Public binaries, packaging, signing, and release publication remain outside `SLICE-001`.
13. New cross-platform projects remain separate from current Windows projects until a parity slice approves a dependency.
14. Browser, desktop, and current WinForms clients remain downstream of typed application contracts.
15. Legacy BinaryFormatter payloads never cross HTTP and receive no new server-side reader.
16. New process contracts use executable identity and separate argv. Shell strings are not the default authority.
17. Platform adapters own operating-system checks. Core rules do not infer platforms from path strings or executable suffixes.
18. A local server binds to loopback by default and gains no remote mode without a separate threat model and approval.
19. Current bootstrap capability output uses `available` or `unavailable` for features and `unverified` for every fixed tool-catalog row. It never treats executable presence as compatibility proof. A future `unsupported` state requires an explicit contract revision.

DECISION: Architecture guardrails

- **STATUS:** Confirmed
- **CHOICE:** Make `SLICE-001` a typed, read-only interpretation and presentation layer over existing post-open state.
- **BECAUSE:** This isolates user-visible improvement from persistence, command, native, tool, cleanup, concurrency, and release behavior.
- **OPTIONS CONSIDERED:** Read-only slice, narrowest compatibility surface. Project checks plus automatic repair, more immediate help but mutates protected state. Broad source-opening refactor, cleaner target structure but too many unverified branches.
- **REVISIT WHEN:** The read-only slice has evidence and a later brief selects one guarded boundary for expansion.

## 15. Current Build Boundary

- **Active local portability slice:** Approved `SLICE-002-LINUX-ENGINE-BOOTSTRAP.md` adds only root-level `CrossPlatform/`, planning and verification docs, and repo-local anti-dark-code calibration. Focused Windows, WSL, restore, and installed-browser results exist at recorded pre-freeze checkpoints. The latest independent evidence review returned NO-GO; its remediations, full committed-source rerun, final auditor, and re-review remain pending. Independent-host evidence is blocked by R-S2-039, an environment limitation on that host, not by access; the artifact ran there successfully on 2026-08-17, though only while that mitigation was temporarily relaxed and then restored. The slice exposes health and capability state only. The root-level location prevents the current build scripts from recursively scanning the new solution and PowerShell files under `Source/`.
- **Current application boundary:** The Windows x64 application, solutions, projects, persistence, commands, scripts, processes, cleanup, FrameServer, tools, packaging, and release behavior are read-only for SLICE-002.
- **Capabilities excluded rather than stubbed:** The API explicitly reports `media-inspection`, `project-import`, `persistence`, `encoding`, `plugins`, and `remote-access` as unavailable. Tool-catalog rows report compatibility as `unverified` and do not expose execution. Media input, command preview, tool execution, queue, native desktop UI, macOS runtime, and public distribution have no route or contract and remain absent.
- **Prior slice evidence:** `SLICE-001` retains its own evidence and open human or operating-system checks. SLICE-002 does not weaken, replace, or claim completion of them.
- **Rollback:** Removing the new subtree and its docs restores the exact prior runtime and build graph. No user data conversion or artifact rollback is required.

---

*Sections filled: 15 of 15. See both unknowns files and `DECISION-LOG.md` for current evidence and reasoning.*
