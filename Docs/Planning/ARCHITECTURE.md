# StaxRip Community Architecture Document (ADD)

Version: 0.1 Draft. Date: 2026-08-13. Authors: LynxTWO and Codex. Status: Confirmed.
Companion documents: `ENGINEERING.md`, `DECISION-LOG.md`, and the slice briefs (`SLICE-001` onward).

## Interview State

- **Last completed:** Phase 2, Architecture
- **Next:** Phase 4, cross-document completeness audit
- **Open questions:** Carried in `../Unknowns/Planning-Unknowns.md`
- **Statuses pending:** None

## Triage Card

- **Project name:** StaxRip Community
- **One-line summary:** A public Windows x64 fork of StaxRip that preserves compatibility while making video and audio processing workflows clearer, safer, and faster.
- **Project type:** Mixed desktop app and utility
- **Starting point:** Existing code
- **Run mode:** Fast-run
- **Scale tier:** T2
- **Team shape:** Solo
- **Experience level:** Built some things
- **Interview depth:** Standard
- **Risk flags:** Personal data in local paths, logs, media metadata, scripts, and command lines
- **Platform targets:** Windows x64
- **Timeline posture:** Weeks per slice
- **Budget posture:** Near zero
- **Compatibility posture:** Strict upstream compatibility
- **Initial workflow direction:** Source opening through ready-to-encode
- **Privacy depth:** Full depth now

## 1. One-Page Overview

- **What it is:** StaxRip Community is a public, portable Windows x64 video and audio processing front end. It improves the existing StaxRip workflow while preserving projects, settings, templates, scripts, commands, native interfaces, external-tool behavior, and user-owned files.
- **Who it is for:** Primary users configure local video and audio processing jobs. Secondary users follow guided setup, and community contributors maintain the fork.
- **The core loop:** A user opens source media, StaxRip verifies and probes it, builds the effective processing project, reports whether the project is ready, and lets the user resolve blockers before encoding.
- **Major pieces:** Desktop shell, source intake, project and profile state, script and filter pipeline, tool orchestration, job engine, FrameServer boundary, diagnostics and support, and AutoCrop.
- **Current slice:** Planning `SLICE-001`, a read-only source readiness summary at the end of the existing source-opening workflow.
- **What this is not:** It is not a new encoder, a cloud service, an installer project, a cross-platform rewrite, or a public-release automation effort.

## 2. System Context

- **Primary actors:** Windows users who configure video and audio processing jobs.
- **Secondary actors:** New users following guided setup, community contributors, and fork maintainers.
- **Local administration:** The user chooses the portable application location, settings location, tools, profiles, templates, scripts, source media, and destinations.
- **External systems:** The Windows filesystem, Registry, process APIs, PowerShell, AviSynth+, VapourSynth, Python, encoders, muxers, demuxers, media probes, plugins, and GitHub release endpoints.
- **Boundary statement:** StaxRip Community owns the desktop workflow, project state, settings, templates, generated scripts, generated command lines, job coordination, diagnostics, and adapters to external tools. External tools own codec and container processing. Users own their paths, media, scripts, profiles, settings, projects, and outputs. The fork will not reimplement encoders, frame-server runtimes, or media containers.

Current evidence comes from `Source/StaxRip.vbproj`, `Source/FrameServer/FrameServer.vcxproj`, `Source/Tools/AutoCrop/AutoCrop.vbproj`, the bounded source-flow inspection named below, and `../Architecture/Coverage-Ledger.md`. No separate system-map artifact is claimed.

## 3. Product Shape and Platforms

- **Shape:** Mixed Windows desktop application, native frame-server library, and support executables.
- **Platform targets:** Windows x64 only.
- **Offline behavior:** Normal configured workflows must work offline. Network access is optional for update checks, documentation, and separately approved downloads.
- **Distribution:** Portable archive through GitHub Releases is the intended public shape. Fork release automation remains deferred until the release boundary has its own approved slice.
- **Languages at launch:** English. New user-facing text must not become hidden runtime truth, and touched copy should leave a clean localization seam.
- **Code license:** MIT, retaining required notices and upstream attribution.

DECISION: Product shape and platforms

- **STATUS:** Confirmed
- **CHOICE:** Preserve the existing portable Windows x64 architecture and external-tool model. Do not begin with a platform rewrite or installer.
- **BECAUSE:** This reaches current users and preserves upstream compatibility while keeping the slice inside the existing runtime model. The exact post-success integration seam remains U-010 rather than a verified boundary.
- **OPTIONS CONSIDERED:** Preserve the portable Windows app, lowest compatibility risk. Add an installer, easier onboarding but introduces a release and machine-state boundary. Cross-platform rewrite, wider reach but breaks the present tool and GUI contracts.
- **REVISIT WHEN:** A measured user need cannot be served by the portable x64 application, or an approved distribution slice establishes a new contract.

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

**Target dependency rule for new work:** UI calls workflow owners. Workflow owners call persistence, native, and external-tool adapters. Persistence, native adapters, and external-tool adapters do not reach back into forms. Existing violations are mapped before they are changed.

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
- **Required first-slice seam:** Evaluate readiness only after the whole source-opening transaction returns successfully. Existing source-loaded and project events are not assumed to prove that boundary. U-010 must map a safe owner and call site before form edits.

Evidence: `Source/Forms/MainForm.vb:2289-2342` and `Source/Forms/MainForm.vb:2469-2889`.

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
- **CHOICE:** Keep VB.NET Windows Forms on .NET Framework 4.8 for the initial fork slices.
- **BECAUSE:** It preserves the existing forms, controls, plugins, serialization behavior, and Windows tool integration while workflow seams are established.
- **OPTIONS CONSIDERED:** Existing WinForms, fastest compatible route. Modern .NET WinForms migration, newer runtime but wide compatibility work. WPF or cross-platform rewrite, more layout freedom but a new application boundary.
- **REVISIT WHEN:** A supported Windows or toolchain requirement cannot be met on .NET Framework 4.8, or a measured UI need cannot be implemented safely in current controls.

### 8.2 Languages

DECISION: Implementation languages

- **STATUS:** Confirmed
- **CHOICE:** Keep VB.NET for the managed app and AutoCrop, C++17 for FrameServer, and PowerShell for user automation. New languages require a slice-specific reason.
- **BECAUSE:** These languages own current runtime contracts. Adding another language would add build, debugging, packaging, and contributor cost at a near-zero budget.
- **OPTIONS CONSIDERED:** Preserve current languages, lowest integration cost. Gradual C# introduction, broader contributor familiarity but mixed managed-language ownership. Rewrite, highest cost and compatibility risk.
- **REVISIT WHEN:** A bounded component has clear ownership, verification, and a measured reason that the current language cannot serve.

### 8.3 Backend

DECISION: Backend approach

- **STATUS:** Confirmed
- **CHOICE:** No application backend. Keep processing, settings, projects, and diagnostics local.
- **BECAUSE:** The product is portable and local-first. A service would add accounts, operations, privacy, availability, and cost without serving the first workflow slice.
- **OPTIONS CONSIDERED:** Local only, preserves portability. Optional community service, enables shared features but adds an external control plane. Required service, simplest central management but breaks offline use.
- **REVISIT WHEN:** A confirmed feature requires shared remote state and cannot use an optional file-based exchange.

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
- **CHOICE:** No product authentication. Windows and filesystem permissions remain the authority for local data.
- **BECAUSE:** There is no application backend or multi-user store. Product accounts would add sensitive credentials without protecting local files from the current user.
- **OPTIONS CONSIDERED:** No authentication, fits the local application. Optional community sign-in, useful only with a future service. Required sign-in, breaks offline and portable use.
- **REVISIT WHEN:** An approved remote service stores user-specific data.

### 8.6 AI layer

Skipped. AI is not part of the product architecture or the initial roadmap. Any future AI feature requires a separate provider, privacy, validation, fallback, cost, and offline decision.

### 8.7 Notifications and messaging

DECISION: Notification channels

- **STATUS:** Confirmed
- **CHOICE:** Use in-app status, Assistant guidance, task dialogs, processing views, and privacy-bounded diagnostics. Do not add email or push messaging.
- **BECAUSE:** Users are present in a local desktop workflow, and the first slice needs clear state rather than a remote channel.
- **OPTIONS CONSIDERED:** In-app only, direct and offline. Windows notifications, useful for long jobs but adds OS integration behavior. Remote messaging, requires a service and personal data.
- **REVISIT WHEN:** Measured long-running background use shows that in-app completion and failure signals are insufficient.

### 8.8 Hosting and builds

DECISION: Build and distribution path

- **STATUS:** Confirmed
- **CHOICE:** Keep Visual Studio and MSBuild x64 source builds. Use GitHub for source collaboration. Design public portable releases in a later approval-gated slice.
- **BECAUSE:** Source builds are verified. The checked-in release scripts contain destructive and machine-specific behavior, so public release work needs its own contract and rollback plan.
- **OPTIONS CONSIDERED:** Manual verified source builds now, lowest immediate risk. Add source-build CI, useful guardrail with dependency work. Automate public releases now, fastest distribution but crosses unresolved packaging and provenance boundaries.
- **REVISIT WHEN:** `SLICE-001` is stable and the fork is ready to define a reproducible public artifact.

## 9. Integration Map

| External system | Purpose | Direction | Failure behavior |
|---|---|---|---|
| Windows filesystem and Registry | Portable state, user paths, temp data, outputs, and settings-location selection | Both | Stop the affected action, preserve prior owned state where possible, and identify the path class without exposing unrelated user data |
| MediaInfo | Probe containers and streams | Read | The existing source-opening path reports probe failure. After a successful open, readiness uses only retained bounded facts and does not invent media facts. |
| AviSynth+ and plugins | Scripted frame processing | Both | Keep the project recoverable, show the bounded engine or script error, and do not start dependent tools |
| VapourSynth, Python, and plugins | Scripted frame processing | Both | Keep the project recoverable, show the bounded engine or script error, and do not start dependent tools |
| Encoders, muxers, demuxers, and support tools | Perform media transformations | Both | Mark the requirement or operation unavailable; do not substitute a different tool silently |
| PowerShell | User and packaged automation | Both | Stop the command path and report the failure without logging private script inputs by default |
| GitHub release endpoints | Optional update and future distribution metadata | Read | Offline or service failure does not block configured local work |
| Windows process and shell APIs | Launch tools and open external resources | Both | Retain canonical arguments and report launch failure without shell reinterpretation |

**Adapter rule for new work:** A touched external boundary gets one owning adapter or choke point. Legacy direct access is mapped before cleanup. A slice does not spread new provider calls across forms.

## 10. Extension Points

| Future capability | Connects at | What exists now | What is deliberately absent |
|---|---|---|---|
| Source readiness summary | End of source intake and Assistant refresh | Source facts, requirement checks, project state, dialogs, and logs | One typed readiness result and one consistent GUI presentation |
| Guided blocker repair | Readiness result plus package and project owners | Existing requirement dialogs and package verification | Automatic setting, tool, template, or project mutations |
| Source-opening progress model | Source intake stages and processing UI | Mixed dialogs, logs, task execution, and processing surfaces | One stage model with measured timing and cancellation ownership |
| Workflow performance evidence | Source intake and diagnostics | Existing timestamps and logs in selected paths | Privacy-safe stage metrics and a regression baseline |
| Job recovery improvements | Job engine, project persistence, and process control | Existing recovery projects and job files | New retry, concurrency, or publication semantics |

The first three likely expansions are readiness summary, guided blocker repair, and source-opening progress. They remain seams, not committed feature scope.

## 11. Scale and Performance Posture

- **Load expectations:** One interactive user and one active project per process. Multiple input files and queued jobs remain supported, but the first slice does not add parallel source-opening work.
- **Measurement rule:** Establish a fixed synthetic fixture baseline before optimizing. Separate existing source-opening time from time added by readiness evaluation and rendering.
- **Performance targets:** Readiness evaluation and rendering add no more than 100 ms at the 95th percentile on the agreed local fixture set. The median full source-opening time must not regress by more than 5 percent or 100 ms, whichever allowance is larger. Fifty repeated readiness evaluations of an unchanged loaded project must show no net process-handle growth.
- **Scaling approach:** Optimize only stages with measured cost. Cache immutable probe facts only when ownership and invalidation are explicit. Do not add concurrency until cancellation, recovery, and shared-resource behavior are mapped and tested.

DECISION: Performance targets

- **STATUS:** Confirmed
- **CHOICE:** Start with bounded added-overhead, total-flow regression, and handle-growth targets instead of promising a total open time before a baseline exists.
- **BECAUSE:** Media, tools, storage, plugins, and scripts make total source-opening time hardware and fixture dependent. Added overhead and regression are controllable by the slice.
- **OPTIONS CONSIDERED:** Relative regression targets, honest before a baseline. Fixed total-open target, easier to read but unsupported across media and hardware. No numeric target, faster planning but unable to verify speed claims.
- **REVISIT WHEN:** A representative baseline exists across fast local media, slow storage, multiple sources, and both frame-server engines.

## 12. Deployment Topology

- **Development environments:** Local source worktree, isolated deterministic fixtures, and an isolated portable runtime fixture.
- **Current release path:** Commit to the fork, run static and x64 build gates, run slice-specific semantic checks, and retain source-bound evidence. No public binary is produced by the initial workflow slice.
- **Future public release path:** An approved release slice must define dependency provenance, portable-tree assembly, artifact identity, signing posture, archive verification, publication approval, and release notes before GitHub distribution begins.
- **Rollback:** Source changes revert as bounded commits. A future binary release must keep the prior portable archive available and document whether its settings and projects can safely open data last written by the new release. Rollback must not overwrite or downgrade user-owned state silently.

DECISION: Deployment posture

- **STATUS:** Confirmed
- **CHOICE:** Develop and verify the first slice in source and isolated portable fixtures. Publish no community binary until a separate release slice is approved.
- **BECAUSE:** The source build is known, but portable assembly, bundled-tool provenance, release scripts, and downgrade behavior retain open contracts.
- **OPTIONS CONSIDERED:** Source-only development first, slower public access but bounded risk. Manual binary uploads, faster access with weak reproducibility. Automated releases now, repeatable only after the missing artifact contract exists.
- **REVISIT WHEN:** The first user-facing slice passes its audit and the user approves release-boundary planning.

## 13. Failure and Degraded Modes

This table is the target posture for touched paths. It does not claim every current path already behaves this way. Failures that abort source opening remain owned by the existing source-opening UI and produce no first-slice readiness result. Q-001 decides which post-success rows can enter the bounded readiness catalog without execution or mutation.

| Failure | User sees | System does | Recovery |
|---|---|---|---|
| Missing, inaccessible, or unsupported source | The existing source-opening error tied to the selected source | Does not invoke the first-slice readiness adapter, invent media facts, or retain a ready claim | User selects another source or corrects access |
| Media probe failure | The existing probe error and bounded failure category | Does not invoke the first-slice readiness adapter or invent media facts | Retry after tool, file, or format correction |
| Missing frame-server runtime or required tool | Missing requirement and affected workflow stage | Does not substitute another engine or executable silently | User repairs configuration or explicitly selects a supported alternative |
| Script or FrameServer open failure | Bounded engine or script error with a route to diagnostics | Does not publish a preview or ready state | User edits the script, filter, runtime, or source choice |
| Temp path unavailable or storage exhausted | Temp or capacity blocker without unrelated path disclosure | Stops before dependent tool work and preserves prior owned state | User selects a valid temp location or frees space |
| Demuxer or helper-process failure | Tool name, stage, and bounded exit status | Keeps partial outputs non-authoritative and does not advance readiness | User reviews diagnostics and retries after correction |
| User cancellation | Canceled state, not a failure claim | Stops at a defined boundary and does not mark the project ready | User restarts source opening |
| Recovery snapshot cannot be written | Warning that rollback protection is unavailable | Current behavior continues only under the existing source-opening contract; the first slice does not change this decision | A later recovery slice defines whether opening must stop |
| Unexpected source-opening exception | Existing exception and diagnostic route | For a non-abort exception, the global handler attempts recovery and diagnostics and terminates the process; the first-slice readiness adapter is not invoked | Later failure-injection work must establish the retained-state and recovery contract |
| GitHub or network unavailable | Optional update information is unavailable | Local configured workflows continue | Automatic or user-triggered retry later |
| Diagnostic content contains private values | Preview and review warning | New reports use an explicit allowlist and bounded redaction; raw logs are not attached automatically | User edits the preview before sharing |

DECISION: Failure and recovery posture

- **STATUS:** Confirmed
- **CHOICE:** The readiness slice observes and explains existing outcomes. It does not change recovery, cancellation, temp-file, process, or cleanup semantics.
- **BECAUSE:** Those behaviors cross protected ownership and failure boundaries. A read-only result can improve clarity without changing what source opening commits or rolls back.
- **OPTIONS CONSIDERED:** Observe and report only, smallest safe slice. Repair selected failures in the same slice, more value but mixed recovery behavior. Rewrite source opening as a transaction first, broad risk and delayed user value.
- **REVISIT WHEN:** The readiness summary identifies one frequent blocker with a deterministic recovery harness and separate approval.

## 14. Architecture Guardrails

1. Do not silently change generated commands, scripts, project files, settings, templates, profiles, jobs, temp rules, or output behavior.
2. Do not parse UI text, localized text, logs, or exception prose to determine readiness.
3. Readiness facts use stable ids, typed values, and an explicit severity and ownership model.
4. The first slice does not save new persisted state or rewrite existing persisted state.
5. The first slice does not download, replace, select, or execute a different external tool.
6. The first slice does not delete, move, overwrite, publish, or repair user-owned files.
7. New diagnostics use allowlisted fields, synthetic fixtures, bounded lengths, and culture-invariant handling.
8. A form consumes one readiness result. It does not reproduce source, package, script, or encoder checks in event handlers.
9. A touched external boundary has one owner or adapter. New direct provider calls do not spread across forms.
10. No new concurrency, retries, cancellation policy, or background worker enters the first slice.
11. Existing source-opening recovery remains unchanged until branch activation and retained-state behavior are deterministically tested.
12. Public binaries, packaging, signing, and release publication remain outside the first slice.

DECISION: Architecture guardrails

- **STATUS:** Confirmed
- **CHOICE:** Make the first slice a typed, read-only interpretation and presentation layer over existing post-open state.
- **BECAUSE:** This isolates user-visible improvement from persistence, command, native, tool, cleanup, concurrency, and release behavior.
- **OPTIONS CONSIDERED:** Read-only slice, narrowest compatibility surface. Readiness plus automatic repair, more immediate help but mutates protected state. Broad source-opening refactor, cleaner target structure but too many unverified branches.
- **REVISIT WHEN:** The read-only slice has evidence and a later brief selects one guarded boundary for expansion.

## 15. Current Build Boundary

- **Current slice:** Planning candidate `SLICE-001`, source readiness summary. It will derive a typed readiness result only after the existing source-opening flow returns successfully and present facts, warnings, and blockers in the GUI. U-010 must first identify the safe seam.
- **Modules the slice may touch:** Source intake, project state read models, package requirement readers, the desktop shell or a separately owned Assistant-adjacent readiness presentation, and a deterministic test seam.
- **Capabilities excluded rather than stubbed:** Guided repair actions, source-opening stage progress, performance optimization, job recovery, release automation, localization implementation, and new telemetry. The slice contains no partial implementation of them.
- **Everything else:** Existing behavior remains in place. Implementation does not begin until the Engineering Document, audit, and Slice Brief are approved.

---

*Sections filled: 15 of 15. Unknowns carried: 12. See `DECISION-LOG.md` for reasoning.*
