# SLICE-001 M0 System Map

Date: 2026-08-15. Repository base: `c26e0fa6`. Pass: 02. Scope: source opening through job entry.

Confidence labels in this file are `verified`, `inferred`, or `unknown`. This is a source map. StaxRip was not run for this pass.

## 1. System summary

- **verified:** StaxRip is a portable Windows x64 WinForms front end. It builds a mutable in-memory project, generates AviSynth or VapourSynth scripts and external-tool commands, and coordinates local tools. Evidence: `Source/StaxRip.vbproj`, `Source/Forms/MainForm.vb`, and `Source/General/Proc.vb`.
- **verified:** The M0 path crosses the main form, source-opening transaction, Assistant, package verification, application events, job persistence, local files, external tools, and the native frame-server boundary. Evidence: `Source/Forms/MainForm.vb:2477-2890,4177-4316`, `Source/Forms/MainForm_Assistant.vb:8-485`, and `Source/General/GlobalClass.vb:453-590,861-878,1327-1405`.
- **verified:** Project, settings, jobs, scripts, commands, paths, temp files, and outputs are user-owned compatibility surfaces. Evidence: `AGENTS.md` and `Docs/Planning/SLICE-001.md`.
- **verified:** `Source/BuildAndPack.ps1` and `Source/Release.ps1` are live release entrypoints. This pass did not run them.

## 2. Runtime units and entrypoints

| Unit | What it does | Where it lives | Entry | Depends on | Data or side effects owned | Confidence |
|---|---|---|---|---|---|---|
| Main desktop shell | Owns the current project controls, source commands, Assistant area, and job commands | `Source/Forms/MainForm.vb` | Application startup, menus, keyboard, file drop, command manager | Project, settings, controls, tools | Current UI bindings and workflow entry | verified |
| Shared source-opening transaction | Verifies and opens one or more sources, updates project state, runs source work, fires events, and performs recovery | `Source/Forms/MainForm.vb:2469-2890` | Default wrappers and one four-argument job call | MediaInfo, Package, scripts, demux, muxer, frame server, processes, filesystem | Source state, generated script state, recovery actions, logs | verified |
| Assistant | Synchronizes or opens a script, evaluates an ordered set of rules, and controls Add Job state | `Source/Forms/MainForm_Assistant.vb:8-485` | Source open, project open, control changes, encoder changes, Add Job retry | Project, script, frame server, filesystem, encoder and muxer types, controls | `AssistantPassed`, `CanIgnoreTip`, current tip, control state | verified |
| Requirement verification | Checks required packages and active Source filter | `Source/General/GlobalClass.vb:861-878`; `Source/General/Package.vb:2973-3069` | Source open, project open, Add Job | Package registry, project, settings, filesystem, modal Apps form | Abort or pass decision; package UI | verified |
| Add Job workflow | Applies Assistant, requirement, disk, event, collision, and output choices before saving a job | `Source/Forms/MainForm.vb:4177-4316` | Next button, context menu, Preview form, Start Encoding command | Project, settings, jobs file, target disk, event commands | Project skip flags, project file, jobs file, events | verified |
| Application events | Raises in-process events, runs optional PowerShell files, and invokes configured commands | `Source/General/GlobalClass.vb:1327-1405` | Source, project, job, and processing stages | Scripts folder, settings event commands, command manager | Arbitrary configured local action and optional log content | verified |
| Job processor | Loads jobs, opens batch sources with `isEncoding = True`, then processes external tools and restores a project | `Source/General/GlobalClass.vb:453-590` | Start Encoding, Jobs form, command | Jobs persistence, project, source open, tools | Job activation, process state, project replacement | verified |
| FormBase | Applies common sizing, theme, keyboard, and window-position behavior | `Source/UI/Misc.vb:7-168` | Construction of most StaxRip forms | Settings and `WindowPositions` | Restores and saves form placement; optionally saves size | verified |
| Approved project-check coordinator shape | At this M0 base, planned to construct an immutable snapshot and run a pure evaluator | Did not exist at the mapped base | Approved post-success interactive hook, pure activation policy, and explicit refresh | Approved mapper and evaluator delegates | Transient presentation state only | historical M0 boundary; current evidence in `M2-INTEGRATION.md` |

## 3. Interface surface

| Trigger | Source owner | What it can invoke | Boundary | Confidence |
|---|---|---|---|---|
| Open source dialogs, source text change, file routes | `Source/Forms/MainForm.vb:2289-2356,5088-5258,5801-5807` | Default source-open wrapper with `isEncoding = False` | User path and local filesystem | verified |
| `LoadSourceFile*` commands | `Source/General/GlobalCommands.vb:551-575` | Default source-open wrapper | Command manager and configured event commands | verified |
| Batch job source open | `Source/General/GlobalClass.vb:553-564` | Four-argument source open with `isEncoding = True` | Persisted job to source/tool boundary | verified |
| Next and Add Job routes | `Source/Forms/MainForm.vb:1075-1079,4177-4316,6165-6177` | Add Job gates and job persistence | Current project to jobs file | verified |
| Start Encoding command | `Source/Forms/MainForm.vb:3484-3489` | Forces `AssistantPassed`, calls the inner Add Job overload, then starts jobs | UI command to job and process boundary | verified |
| Application event command | `Source/General/GlobalClass.vb:1363-1402` | PowerShell file or any registered command | User configuration to code and process boundary | verified |

## 4. Data stores and schemas

### Current project

- **Type:** Mutable in-memory `Project`, referenced through global `p`.
- **Stores:** Source, target, script, encoder, muxer, audio, temp, profile, and workflow state.
- **Persistence:** Project and template paths can serialize this state. The proposed result must never serialize.
- **Risk:** A mutable `Project` reference cannot escape the proposed snapshot mapping call.
- **Confidence:** verified from `Source/General/Project.vb`, `Source/Forms/MainForm.vb:1743-1870`, and the Slice Brief.

### Application settings

- **Type:** Mutable settings object referenced through global `s` and serialized by `g.SaveSettings`.
- **Stores:** Tool verification policy, Assistant choices, event commands, window positions, UI preferences, and other application settings.
- **Non-obvious behavior:** `FormBase` restores `s.WindowPositions` on load and saves its form key on close even when size persistence is disabled. Evidence: `Source/UI/Misc.vb:149-167,269-287`.
- **Confidence:** verified.

### Jobs

- **Type:** Serialized `Jobs.dat` plus serialized project files.
- **Owner:** `Source/General/JobManager.vb:79-138` and Add Job.
- **Risk:** Reads may recover or rewrite corrupt job data; writes and overwrite behavior are outside M0.
- **Confidence:** verified.

### Local executable, script, and output state

- **Type:** Files and drive state outside the process.
- **Uses:** Package paths and timestamps, imported scripts, event PowerShell files, source and target files, free space, and output collisions.
- **Risk:** These facts can change without an in-memory project mutation or event.
- **Confidence:** verified from `Source/General/Package.vb:2973-3069,3510-3546`, `Source/General/GlobalClass.vb:1363-1367`, and `Source/Forms/MainForm.vb:3458-3482,4200-4263`.

## 5. External dependencies

| System | Why this path uses it | Configuration | Failure effect | Recovery or fallback | Confidence |
|---|---|---|---|---|---|
| MediaInfo | Reads media facts during source open | Package registry and source path | Source open can abort or report an error | Existing source recovery path | verified |
| AviSynth or VapourSynth | Builds and opens the effective script | Project script engine and package state | Assistant or source open cannot validate the script | Existing Assistant and recovery behavior | verified |
| Encoder, muxer, demuxer, subtitle, and metadata tools | Prepare source and output work | Project plus package registry | Abort, dialog, or existing error path | Existing tool and recovery behavior | verified |
| PowerShell event files | User extension at application events | `Folder.Scripts/<event>.ps1` | Can change state, fail, or launch work | Existing command/event behavior | verified |
| Windows filesystem and drives | Source, target, job, tool, script, output, and free-space facts | User paths and settings | Prompts, aborts, recovery, or later process failure | Existing dialogs and catches | verified |

## 6. Configuration keys

No secret values were read or recorded.

| Key or owner | Used by | Relevance | Confidence |
|---|---|---|---|
| `s.VerifyToolStatus` | `VerifyRequirements` | Enables live package and Source-filter verification | verified |
| `s.MinimumDiskSpace` | Add Job | Sets the live free-space warning threshold | verified |
| `s.EventCommands` | `RaiseAppEvent` | Can invoke registered commands at source and job stages | verified |
| `s.WindowPositions` | `FormBase` | Persists each FormBase position unless the base gains an approved opt-out | verified |
| `p.BatchMode` | Source open and job processor | Changes source-open flow and must prevent interactive evaluation | verified |
| `g.IsJobProcessing` | Job processor | Distinguishes job processing, including reentrant event commands | verified |

## 7. Trust boundaries and privilege edges

| Boundary | What crosses it | Existing validation | Failure if treated as pure or stable | Confidence |
|---|---|---|---|---|
| User path -> source transaction | Source and target paths | File type, encoding, media, and script checks | Private paths leak or source behavior changes | verified |
| Project -> generated script/tool command | Mutable encoder, muxer, filter, and audio state | Distributed owner checks | A second encode authority would drift from generated behavior | verified |
| Package registry -> filesystem | Tool paths and versions | `VerifyOK` and `GetStatus` | A cached status becomes stale outside StaxRip | verified |
| Application event -> PowerShell/command manager | Event name, project state, and configured parameters | User configuration and command lookup | Post-open snapshot cannot predict later event completion or mutation | verified |
| Job file -> process execution | Serialized project and source paths | Existing load and requirement checks | Test evidence can touch a real queue, tool, temp path, or output | verified |
| Form -> settings persistence | Form type, location, state, and size | Common FormBase behavior | A new details form would add project-check-owned persisted state without the D-037 opt-out | verified |

## 8. Critical data flows

### Interactive source open

1. A dialog, file route, text change, or command calls the default overload at `Source/Forms/MainForm.vb:2469-2474`.
2. The shared transaction saves a recovery project, verifies the source, mutates `p`, runs package, media, demux, script, subtitle, mux, crop, and event work, then runs Assistant at `Source/Forms/MainForm.vb:2477-2870`.
3. Abort and exception branches recover or replace the project at `Source/Forms/MainForm.vb:2871-2888`.
4. **inferred:** A local success flag set only after line 2870, followed by a coordinator call after the whole `Try/Catch/Finally`, can create a success-only hook. `M0-ACTIVATION-LIFECYCLE.md` records the complete entry-plus-completion policy, including atomic depth, UI-thread entry, job, batch, startup `-NoFocus`, and project-identity guards.
5. At this M0 base, production activation and outcomes remained unknown. `M2-INTEGRATION.md` now records deterministic production-source and product-assembly evidence; L3 still owns real source-opening outcomes.

### Add Job and encode entry

1. The normal Add Job route checks current Assistant state and requirements at `Source/Forms/MainForm.vb:4177-4195`.
2. It then checks live disk state, runs `BeforeJobAdding`, checks jobs and outputs, and may ask the user at `Source/Forms/MainForm.vb:4196-4263`.
3. The inner route verifies requirements and Assistant state again, serializes the project, and updates Jobs at `Source/Forms/MainForm.vb:4290-4315`.
4. `StartEncoding` has a separate path that forces `AssistantPassed` and skips the outer gate set at `Source/Forms/MainForm.vb:3484-3489`.
5. **verified:** No single side-effect-free preflight contract owns these routes.

### Batch job source open

1. `ProcessJobsRecursive` sets `g.IsJobProcessing = True` and loads the job project at `Source/General/GlobalClass.vb:485-503`.
2. `ProcessJob` calls source open with `isEncoding = True` for batch jobs at `Source/General/GlobalClass.vb:542-564`.
3. Source opening can demux, extract metadata, initialize a muxer, start another StaxRip process, or run a compressibility check before returning at `Source/Forms/MainForm.vb:2723-2863`.
4. `BeforeProcessing` occurs later at `Source/General/GlobalClass.vb:572`.
5. **verified:** A successful runtime trip through this path cannot stop before source-opening tool and output work. Confirmed D-037 excludes that runtime-equivalence claim and replaces it with static mapping, a source-linked pure policy test, and focused clear-owner checks.

## 8a. Rule authority

| Rule or contract | Canonical implementation | Downstream view or adapter | Drift guard | Confidence |
|---|---|---|---|---|
| Required tools and active Source filter | `GlobalClass.VerifyRequirements`; `Package.VerifyOK` | Apps form and Add Job | Repeated live check only; no pure token | verified |
| Assistant workflow pass | `MainForm.Assistant`, `CanIgnoreTip`, `AssistantPassed` | Assistant label and Next button | Sequential re-evaluation; no immutable result | verified |
| Disk decision | `MainForm.AbortDueToLowDiskSpace` | Task dialog | Live drive read at action time | verified |
| Before-job extension | `GlobalClass.RaiseAppEvent(BeforeJobAdding)` | PowerShell and command manager | No pure prediction or freshness token | verified |
| Job and output collision choices | `MainForm.AddJob` | Task dialogs and skip flags | Live jobs/output reads | verified |
| Overall `Ready` | None | Rejected summary claim | D-034 evidence and Confirmed D-037 | verified excluded |
| Approved selected project checks | Final catalog was pending at this M0 map | Approved summary and details | Pure evaluator plus complete mapped invalidation | historical boundary; final catalog is in `M0-CATALOG.md` |

## 8b. Diagnostics and observability authority

- **verified:** Existing source and event paths can log full paths, media summaries, scripts, command parameters, and event details. Evidence: `Source/Forms/MainForm.vb:2705-2712` and `Source/General/GlobalClass.vb:1388-1393`.
- **verified:** The approved feature adds no project-check log, telemetry, clipboard route, or exception prose.
- **verified:** Existing logs are observational and are not an approved catalog input.
- **unknown:** Whole-product redaction and replay support remain outside this slice.

## 9. Operational notes

- The supported build graph is x64 only. Reintroducing x86 or Win32 needs a new decision and approval.
- M0 ran no StaxRip executable, repository build, package update, network action, release script, job, media tool, or output work.
- The ignored M0 delegate probe is documented in `M0-FAULT-PROBE.md`.
- A future successful job-path runtime check needs separate approval for an isolated tool boundary.

## 10. Known gaps and stop conditions

- **verified:** `BeforeJobAdding` alone prevents an honest pure post-open `Ready` claim under D-034.
- **verified:** Live package, disk, job, output, and event state has no complete in-memory freshness contract.
- **verified:** `isEncoding = False` is insufficient for interactive-only activation because job events can invoke default source commands while `g.IsJobProcessing = True`.
- **verified:** D-037 approves a default-preserving `FormBase.RememberPosition` opt-out for only the new details form. The strict design model, production source contract, and bounded production-control probe pass; loaded MainForm persistence remains pending.
- **verified:** The old S-018 successful job-path runtime protocol cannot stop before source-opening tool work and is superseded by D-037.
- **verified:** `M0-CATALOG.md` approves three pure checks and maps their repository-owned mutation and invalidation owners.

Confirmed D-037 supplies that scope change. It replaces `Ready` with `Selected checks passed`, explicitly leaves Add Job and encode-time checks authoritative, revises S-018 to static caller mapping plus pure policy and clear-owner evidence, approves the default-preserving position opt-out, and approves ignored fixture bytes with a tracked identity manifest.
