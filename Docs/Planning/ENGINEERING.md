# StaxRip Community Engineering Document (EDD)

Version: 0.1 Draft. Date: 2026-08-14. Authors: LynxTWO and Codex. Status: Confirmed.
Companion documents: `ARCHITECTURE.md`, `DECISION-LOG.md`, `../Unknowns/Planning-Unknowns.md`, and the slice briefs (`SLICE-001` onward).

## Interview State

- **Last completed:** Phase 4, decision completeness audit
- **Next:** Phase 5, slice selection
- **Open questions:** Q-001 through Q-003 and Q-007 in section 4.3
- **Statuses pending:** None

## 1. One-Page Overview

StaxRip Community keeps the existing portable Windows x64 application, .NET Framework 4.8 WinForms client, C++17 frame server, project formats, generated scripts and commands, and external-tool contracts. The first delivery slice adds a read-only source-readiness summary after the existing source-opening transaction has succeeded. It does not replace source opening or start encoding.

One pure evaluator receives a bounded immutable snapshot and returns a transient ordered result with stable check ids, typed outcomes, severity, message keys, and safe arguments. It performs no file write, persistence, network request, process launch, download, executable selection, or logging. Expected missing facts are typed results. An unexpected evaluator failure becomes a privacy-safe `Unavailable` presentation state and leaves the loaded project untouched.

The confirmed GUI prototype target is a compact textual summary near the Assistant with separate ownership, a labeled details button, a menu route, and a read-only details form. Exact placement remains Q-002 until a prototype proves layout and navigation. Keyboard-only use, explicit accessibility properties, UI Automation and Narrator output, visible focus, non-color semantics, high contrast, and 100 through 200 percent DPI are completion gates.

Verification starts with static contract checks and a confirmed standalone .NET Framework 4.8 x64 VB console harness outside `Source/StaxRip.sln`. It continues through direct and solution x64 builds, fixed synthetic source-opening comparisons, GUI evidence, and performance and handle gates. The harness adds no package or solution mapping. Test weakening needs the same review as production weakening.

The slice is source-only, offline, local, manual, and zero-recurring-cost. It adds no backend, database, authentication, telemetry, CI, installer, release automation, migration, or public binary. Q-001, Q-002, Q-003, and Q-007 close through approved catalog, seam and UI-ownership, timing, and lifecycle spikes before dependent implementation. Public branding, legacy publish metadata, portable assembly, and release provenance remain separate unknowns and approval-gated work.

## 2. Engineering Principles

1. User-owned behavior and compatibility outrank delivery speed.
2. Evidence outranks confidence. A build proves compilation, not the complete workflow.
3. One bounded slice stays in flight. Scope changes enter the Decision Log first.
4. Read and explain existing state before adding mutation or repair.
5. Generated commands, scripts, serialized state, native layouts, and file behavior are contracts.
6. Stable ids and typed values carry truth. UI text and logs are rendered views.
7. Diagnostics collect the minimum and use allowlists, bounded output, synthetic fixtures, and manual review where needed.
8. Cheap deterministic checks run before portable runtime, GUI, soak, or release evidence.

## 3. System Goals

The first three goals outrank the others in the order shown.

| Priority | Goal | Target | How measured |
|---|---|---|---|
| 1 | Compatible and reliable | The readiness slice causes zero changes to fixed-fixture project state, scripts, commands, tool selection, temp rules, and output rules | Before-and-after state and generated-contract comparisons plus focused build and runtime checks |
| 2 | Clear and accessible | A loaded project exposes one labeled readiness result whose facts, warnings, and blockers are reachable by keyboard and are not distinguished by color alone | Keyboard-only walkthrough, accessibility-property inspection, and deterministic presentation tests |
| 3 | Measured performance | Meet ADD section 11 added-overhead, total-flow regression, and handle-growth targets | Repeated fixture timing and handle measurements |
| Supporting | Private by default | No path, user name, media title, script content, command text, token, or unrelated diagnostic value enters new readiness output | Sensitive-sentinel assertions and bounded-output review |
| Supporting | Maintainable | One typed readiness model owns ids, severity, ordering, and evidence; forms contain presentation wiring rather than duplicate rules | Source and dependency review plus unit checks |
| Supporting | Near-zero operating cost | No required hosted service and no recurring infrastructure charge | Dependency and service inventory review |
| Supporting | Observable without analytics | Each readiness check is inspectable in the result; no usage analytics or new telemetry is added | Result-schema inspection and logging diff |

DECISION: Engineering goal priority

- **STATUS:** Confirmed
- **CHOICE:** Protect compatibility and reliability first, workflow clarity and accessibility second, and measured performance third.
- **BECAUSE:** The fork cannot improve the workflow by changing the processing result. The selected user value is clarity, and speed must be measured rather than asserted.
- **OPTIONS CONSIDERED:** Compatibility then clarity then performance, fits the confirmed posture. Visual redesign first, visible but weak behavior proof. Performance first, premature before stage baselines exist.
- **REVISIT WHEN:** Compatibility gates are automated and measured user feedback identifies a different primary constraint.

## 4. Requirements Ledger

### 4.1 Confirmed requirements

| ID | Requirement | Acceptance test |
|---|---|---|
| R-001 | Existing source-opening behavior remains authoritative | Given each fixed fixture, opening it before and after the slice produces equivalent effective project, script, command, tool, temp, and target state apart from transient readiness UI state |
| R-002 | A successfully loaded project produces one typed readiness result | Given a loaded fixture, when readiness is evaluated, then one result contains stable check ids, status, severity, ordering, and bounded presentation data |
| R-003 | The GUI distinguishes ready facts, warnings, and blockers | Given a result containing each category, when shown, then every item has visible text and a non-color-only status indicator |
| R-004 | Readiness evaluation is read-only | Given a serialized project and fixed tool configuration, evaluating readiness leaves persisted and effective processing state unchanged |
| R-005 | The slice works offline | Given network denial, opening a configured local fixture and showing readiness does not require a remote call |
| R-006 | The slice does not change or substitute tools | Given a missing or invalid requirement, readiness reports it and does not download, replace, launch, or select another executable |
| R-007 | New output excludes private diagnostic values by default | Given synthetic sensitive sentinels in paths, metadata, scripts, commands, and settings, readiness output contains none of those values unless a separately approved field requires a bounded safe derivative |
| R-008 | The readiness surface supports keyboard use | Given the main workflow with no pointing device, the user can reach, inspect, and leave the readiness surface with visible focus and meaningful accessibility names |
| R-009 | The slice meets the ADD section 11 performance targets | Given the approved fixture and repetition protocol, added latency, total-flow regression, and handle growth stay within the confirmed limits |
| R-010 | Verification is deterministic and source-bound | Given the committed candidate, the same fixed inputs produce the same ordered readiness result and all evidence names the tested commit |
| R-011 | No public binary is released by this slice | Given completion of `SLICE-001`, no packaging or publication command has run and no community release asset has been created |
| R-012 | Repository steering is tracked before implementation | Given the approved slice branch, the canonical `AGENTS.md` is present, reviewed, and names the current approval gates and build boundary |

### 4.2 Assumed requirements

| ID | Assumption | How it gets verified |
|---|---|---|
| A-001 | Users benefit from one consolidated readiness summary after source opening | Review the first interactive prototype with the user, then collect public feedback only after an approved distribution path exists |
| A-002 | Existing in-memory project and package state can supply the initial check catalog without new external process execution | Source-state mapping spike traces each proposed check to an owner and rejects checks that require side effects |
| A-003 | The Assistant area or an adjacent main-window surface can present readiness without disrupting established navigation | UI ownership spike compares current Assistant, status, and main-window layout behavior with keyboard and scaling checks |
| A-004 | The selected synthetic fixtures represent the initial compatibility and timing risk | Fixture review covers common container and codec shapes, both frame-server engines where required, failure sentinels, and a slow-path case |

### 4.3 Open questions

| ID | Question | Blocks what | Close by |
|---|---|---|---|
| Q-001 | Which checks, ids, severities, and precedence form the first readiness catalog? | Readiness model and tests | Source-state mapping spike before implementation |
| Q-002 | Where does the readiness surface live in the existing main-window and Assistant interaction model? | GUI implementation | UI ownership spike and user approval before form edits |
| Q-003 | Which fixtures and measurement protocol define the source-opening baseline? | Performance acceptance | Timing spike before performance-dependent implementation |
| Q-004 | Which existing WinForms accessibility pattern should the readiness surface follow? | Closed on 2026-08-14 | D-025 selects an explicitly hardened composite of current layout and control precedents; runtime accessibility remains a completion gate |
| Q-005 | How will readiness logic tests run without weakening or silently changing solution configuration? | Closed on 2026-08-14 | D-024 approves a standalone source-linked x64 VB harness outside the solution with no package or project reference |
| Q-006 | Which reviewed steering content should be tracked as the fork's canonical `AGENTS.md`? | Closed on 2026-08-13 | The user confirmed the x64-only project graph; root `AGENTS.md` is tracked with that correction |
| Q-007 | Which events or explicit actions invalidate and recompute readiness after relevant project state changes? | Adapter and GUI implementation | Lifecycle spike maps each approved snapshot field to mutation owners and proves stale results cannot survive project replacement, failed later open, or relevant setting changes |

## 5. Data Model

The first slice adds transient read models only. It does not change `Project`, `ApplicationSettings`, templates, profiles, jobs, or their serialized formats.

ENTITY: `ReadinessSnapshot`

- **Purpose:** Immutable input containing only values the readiness evaluator needs from an already loaded project and current configured requirement state.
- **Owned by:** Source readiness evaluator.
- **Fields:** Schema version; source-present flag; bounded media capability facts; selected script-engine id; encoder and muxer selection ids; target-present flag; requirement states keyed by stable owner id. The mapping spike approves the final field set.
- **Relations:** Created from current project and package readers. Consumed by one evaluation. It does not retain a mutable `Project` reference.
- **Deletion rule:** Discard after evaluation. Never serialize it.

ENTITY: `ReadinessCheck`

- **Purpose:** One deterministic fact, warning, blocker, unknown, or not-applicable outcome.
- **Owned by:** Source readiness evaluator.
- **Fields:** Stable ASCII `Id`; category enum; outcome enum; severity enum; stable message key; ordered safe primitive arguments; optional stable evidence code; integer sort order.
- **Constraints:** Ids are unique. Message arguments have explicit count and length limits. Arguments exclude raw paths, media titles, scripts, commands, exception text, URLs, credentials, and arbitrary tool output.
- **Relations:** Belongs to one `ReadinessResult`.
- **Deletion rule:** Transient. Discard when the result is replaced.

ENTITY: `ReadinessResult`

- **Purpose:** Immutable ordered evaluation output consumed by the GUI and deterministic tests.
- **Owned by:** Source readiness evaluator.
- **Fields:** Schema version; overall status enum; ordered read-only list of checks.
- **Constraints:** Overall status derives from checks by one precedence function. Time, duration, culture, rendered strings, and control state are not part of functional equality.
- **Relations:** Derived from one snapshot. Rendered by one readiness presentation owner.
- **Deletion rule:** Replace or hide when relevant in-memory project or configured requirement state changes. Never persist it in the first slice. Q-007 and U-012 must identify the trigger owner and stale-result safeguard before adapter implementation.

DECISION: Readiness data model

- **STATUS:** Confirmed
- **CHOICE:** Use immutable transient snapshot, check, and result types. Keep stable ids and typed outcomes separate from rendered English text.
- **BECAUSE:** This permits deterministic testing, avoids mutating legacy state, and leaves a localization seam without implementing a localization system.
- **OPTIONS CONSIDERED:** Typed transient model, clear ownership and no migration. Read fields directly in the form, less code but duplicated rules and hidden mutation risk. Persist readiness in projects, faster reload but a compatibility and invalidation boundary.
- **REVISIT WHEN:** A later approved feature needs historical readiness and defines retention, migration, privacy, and invalidation.

**Data conventions:** The model adds no identifier generator or timestamp convention because no entity persists. Stable ids are source constants reviewed as compatibility surfaces. Any future persistence requires a new data-model decision and migration plan.

## 6. Permissions and Access Model

- **Runtime roles:** Local user, child external process, and community maintainer receiving user-chosen diagnostic content.

| Role | Local project and settings | Source and output files | Readiness result | Public support content |
|---|---|---|---|---|
| Local user | Read and write where Windows permits | Read or write only through existing approved workflows | Full local view | Chooses whether and what to copy |
| Child external process | Only explicit files, arguments, environment, and inherited Windows access from its launch contract | Existing tool-specific access | None in the first slice | None |
| Community maintainer | None | None | None unless the user shares a reviewed representation | Reads only content the user deliberately publishes |

- **Enforcement points:** Windows and filesystem permissions control local access. StaxRip boundary validation controls which paths and values enter a workflow. Readiness adds no privilege and launches no child process.
- **Admin surface:** None. The public fork does not create remote administration or access to user machines.
- **Inheritance warning:** Existing external tools run with the user's process authority and may see inherited environment data. The readiness slice does not broaden or reinterpret that contract.

## 7. Security Requirements

### Threat model

- **Assets:** User media, destinations, temp data, settings, projects, templates, profiles, scripts, credentials embedded in user configuration, generated commands, logs, and executable selection.
- **Potential attackers or hazards:** Malicious or malformed media, project, template, profile, script, plugin, executable, or update metadata; a compromised external download; unsafe public diagnostics; and accidental user actions.
- **Entry points:** File and folder opening, project and settings deserialization, command line, PowerShell, plugins, generated scripts, package paths, child-process output, update requests, clipboard, and public issue uploads.
- **Worst hostile outcome:** Code execution under the user's Windows identity, destructive file behavior, or private-data disclosure.
- **Worst authorized accident:** Overwriting or deleting user-owned media or outputs, changing processing commands silently, or publishing a private log.

### Requirements for the readiness slice

- Secrets, tokens, credentials, private certificates, and connection strings do not enter source, fixtures, docs, screenshots, commits, or readiness output.
- The slice adds no network request, download, process launch, script execution, deserialization path, privileged operation, or new dependency.
- Snapshot construction validates enum ranges, collection bounds, string lengths, and owner ids at its boundary.
- Readiness does not interpret source contents, project bytes, logs, exception text, or arbitrary external-tool output.
- Readiness never creates an execution command from human-readable presentation data.
- Security-sensitive failures produce stable categories. Private source values remain outside presentation and tests.
- New public network work, if later approved, uses encrypted transport. Existing non-HTTPS package catalog entries remain outside this slice and prevent a whole-product encrypted-transport claim.
- Dependency and executable provenance remains an open release boundary. No automatic install or update is added.

### Incident response posture for a public source fork

1. Preserve a redacted reproducer and identify the affected commit and distributed artifact, if any.
2. Stop publication or mark the affected source state clearly. Do not publish private logs or exploit details that increase user risk.
3. Prepare the smallest reversible fix and run the affected privacy, compatibility, build, and runtime gates.
4. Notify users through the repository and release channel available at that time.
5. Record the failure, root boundary, test, and prevention rule in the planning and maintenance documents.

Rate limits, sessions, tokens, remote access reviews, and hosted-service compliance are not applicable because ADD sections 8.3 and 8.5 confirm no backend or authentication.

DECISION: Local security boundary

- **STATUS:** Confirmed
- **CHOICE:** Keep readiness pure, local, read-only, dependency-free, and process-free. Treat all loaded project and tool state as untrusted input to the snapshot boundary.
- **BECAUSE:** The current application already has broad local authority. The first slice can add user value without expanding that authority or adding a new entry point.
- **OPTIONS CONSIDERED:** Pure local evaluation, smallest security change. Live tool probes, fresher facts but process and privacy risk. Remote validation, shared rules but network and data exposure.
- **REVISIT WHEN:** A required readiness fact cannot be established from bounded current state and the user approves a new boundary.

## 8. Privacy and Data Handling

| Data class | Why StaxRip uses it | Existing locations | Readiness rule |
|---|---|---|---|
| User and machine paths | Open sources, choose temp and output locations, resolve tools | Projects, settings, jobs, logs, scripts, commands, filesystem | Use presence or safe category only; do not copy raw values into checks |
| Media names, titles, and stream metadata | Configure processing and muxing | Project state, MediaInfo results, logs, outputs | Include only an approved bounded technical fact needed for readiness |
| Scripts, profiles, templates, events, and custom text | Define user-selected processing | Settings and project files, generated scripts, logs | Do not include content in readiness output |
| Generated commands and external-tool output | Execute and diagnose processing | Memory, logs, support paths | Do not include in readiness output |
| System and tool details | Verify requirements and diagnose failures | Settings, package catalog, logs, support reports | Use stable tool id and bounded state only when the catalog approves it |
| Exception and diagnostic text | Troubleshoot failures | Logs, dialogs, debug trace, AutoCrop output | Use stable error category; exclude arbitrary exception text |
| Clipboard and public issue content | User-controlled support sharing | Clipboard and GitHub after user action | No automatic sharing; user reviews before publication |

- **Retention:** Readiness snapshots and results live in memory only and are replaced when relevant state changes. Existing log, history, temp, project, settings, and job retention remains unchanged and is not fully mapped by this document.
- **User deletion:** Users control their local files through Windows and existing StaxRip workflows. The slice adds no delete or cleanup operation. Full application-data deletion and retention changes require a separate approval-gated slice.
- **Sharing:** Readiness sends nothing to a third party. Existing external tools receive data through their local execution contracts. Public support content leaves the machine only after explicit user action.
- **User-facing legal:** Before a public binary release, publish a plain privacy notice describing local processing, update checks, diagnostics, external tools, and voluntary support sharing. Retain the MIT license and required third-party notices. Naming and trademark posture remains U-001.

DECISION: Readiness privacy posture

- **STATUS:** Confirmed
- **CHOICE:** Keep readiness transient and local. Use safe typed facts and message keys instead of raw user, media, script, command, tool-output, or exception text.
- **BECAUSE:** Readiness can explain configuration state without creating another diagnostic record containing private workflow details.
- **OPTIONS CONSIDERED:** Minimal transient facts, lowest disclosure risk. Reuse the raw log, easy but private and unbounded. Persist detailed readiness history, useful trends but new retention and deletion obligations.
- **REVISIT WHEN:** A confirmed feature requires history or public sharing and defines the minimum data, retention, deletion, and consent contract.

## 9. Coding Standards

- **Language and typing:** Keep `Option Strict On`, explicit boundary conversions, existing VB.NET and C++ project standards, and C++17 at the native boundary per ADD section 8.2.
- **Naming:** Preserve repository conventions. New readiness types use full domain names. Stable ids use lowercase ASCII segments with a documented prefix and are not derived from display text.
- **Functions:** Snapshot mapping, evaluation, precedence, and presentation mapping are separate single-purpose functions. The evaluator receives immutable input and has no access to forms, global mutation, filesystem writes, network, or process launch.
- **Errors:** Expected readiness outcomes are typed results. Unexpected programmer or boundary errors propagate out of the evaluator to the readiness adapter. D-026 requires that adapter to present `Unavailable`, never a false ready result, without changing the loaded project or copying exception prose.
- **Logging:** The evaluator logs nothing by default. Any later diagnostic event requires an allowlist, bounded fields, and a logging-audit update. Never log secrets, raw paths, media titles, scripts, commands, or arbitrary tool output from readiness.
- **Comments:** Explain ownership, precedence, invalidation, compatibility, privacy, and why a boundary is read-only. Do not narrate obvious statements.
- **Accessibility:** Interactive elements have accessibility names, keyboard order, visible focus, and text or icon semantics beyond color. Scaling and high-contrast behavior follow existing Windows conventions.
- **User-facing text:** Stable message keys and typed arguments stay separate from evaluation. The first slice may render English, but evaluation does not parse or compare the rendering.
- **Formatting:** Preserve local style and line endings. Do not add a formatter or apply broad formatting in the feature patch.
- **AI-generated code:** Apply the same review, evidence, privacy, compatibility, and ownership rules as any other code.

## 10. Repository Organization

- **Top-level layout:** `Source/` owns application and build inputs. `Docs/` owns user, contributor, verification, and planning material. `.github/` owns repository interaction templates. Root files own license, overview, changelogs, and steering when approved.
- **Feature organization:** Keep the current hybrid layout. Place pure readiness types and evaluation under one feature-named managed owner, with thin GUI wiring under the existing form or UI owner chosen by Q-002. Do not put rules in a generic helper file.
- **Shared code:** Stable readiness types live with the evaluator. Only the presentation interface crosses into forms.
- **Dependency direction:** Follow ADD section 4. The form consumes a result; the evaluator does not depend on a form.
- **Documentation location:** Scaffold documents live in `Docs/Planning/`. Verification records stay under `Docs/Verification/` when the repository adopts them.
- **Steering:** Root `AGENTS.md` is the tracked canonical file. It states the x64-only project graph and the approval gates that apply before implementation.
- **Setup:** `Docs/Contribution/README.md` is the verified x64 source-build path. Re-test it when project, package, SDK, solution, or supported-platform inputs change.
- **Tests:** D-024 selects a deterministic standalone harness without changing solution mappings or adding a dependency.

DECISION: Code and repository organization

- **STATUS:** Confirmed
- **CHOICE:** Add one feature-owned pure readiness evaluator and keep the UI adapter thin. Track reviewed steering before implementation and approve the test harness separately if it changes build configuration.
- **BECAUSE:** This fits the existing repository while preventing new readiness rules from spreading through `MainForm` event handlers.
- **OPTIONS CONSIDERED:** Feature-owned evaluator plus thin adapter, clear boundary. Put logic in `MainForm`, fewer files but deeper coupling. Broad layer reorganization, cleaner target but unrelated churn.
- **REVISIT WHEN:** The mapping spike shows an existing owner that already provides the same typed boundary.

## 11. Testing and Verification

Verification uses the cheapest deterministic evidence first. Every result names the tested commit, configuration, platform, fixture, command, and untested boundary. Branch activation evidence is recorded separately from outcome evidence.

| Level | Gate | Required evidence |
|---|---|---|
| L0 | Static contract | Bounded diff, project and solution XML parse, x64-only configuration scan, prohibited-boundary search, privacy-field review, and `git diff --check` |
| L1 | Pure readiness harness | A framework-free .NET Framework 4.8 x64 VB console executable runs fixed vectors, boundary vectors, sensitive sentinels, determinism repetitions, and forced failure branches |
| L2 | Product build | `Source/StaxRip.sln` Debug x64 and Release x64 builds plus direct `Source/StaxRip.vbproj` Debug x64 and Release x64 builds; the evidence notes that solution Release intentionally maps the managed project to Debug |
| L3 | Source workflow | Fixed synthetic sources open before and after the change; effective project, generated script, command, tool selection, temp, and target contracts are compared |
| L4 | GUI and accessibility | Deterministic presentation and Windows UI Automation checks cover the summary, details, invalidation and refresh, forced `Unavailable`, return focus, scaling, high contrast, privacy sentinels, and non-color status semantics |
| L5 | Performance and soak | The approved fixture protocol measures p95 readiness overhead, median full-flow regression, and process handles across 50 unchanged evaluations |

The L1 harness is a standalone project at `Source/Tests/Readiness/ReadinessEvaluatorTests.vbproj`. It is not added to `Source/StaxRip.sln` and is not referenced by `Source/StaxRip.vbproj`. It explicitly links only the approved pure readiness model and evaluator source files. It uses `Option Strict On`, deterministic compilation, x64, Base Class Library references only, and output and intermediate directories below ignored `Source/obj/ReadinessTests/`. The application project receives only its normal explicit compile entries for production files.

The harness covers at least:

- stable check ids, ordering, overall-status precedence, and not-applicable behavior;
- empty, minimum, maximum, invalid enum, bounded collection, and bounded string inputs;
- identical functional results across repetition, supported cultures, and render order changes;
- no mutation of the supplied snapshot or loaded project state;
- sensitive sentinels in paths, titles, scripts, commands, settings, external output, and exception text never entering pure readiness results;
- every expected fact, warning, blocker, unknown, and not-applicable evaluator branch;
- aggregate timing output with no user or media values.

The L1 harness ends at the pure model and evaluator boundary. Forced `Unavailable`, rendered text, accessibility values, focus, and stale-result behavior belong to deterministic presentation checks and L4 GUI evidence. They are not claimed by L1 unless a later confirmed decision adds a pure production presentation mapper to the source-linked harness.

Test changes receive the same scrutiny as production changes. Removed assertions, widened bounds, new skips, broader fakes, changed fixtures, timeout increases, and expected-output updates require an explanation tied to a confirmed decision. A compact failure packet keeps the first failure, command, commit, configuration, fixture id, and bounded expected-versus-actual values. It excludes full logs and machine-specific paths. No release or packaging script is a verification command for this slice.

DECISION: Verification harness and evidence ladder

- **STATUS:** Confirmed
- **CHOICE:** Add a standalone .NET Framework 4.8 x64 VB console harness that source-links only the pure readiness files. Keep it outside `Source/StaxRip.sln`, add no package or application project reference, write outputs below ignored `Source/obj`, and pair it with the existing x64 product builds and higher-level runtime gates.
- **BECAUSE:** The repository has no automated test framework. This provides deterministic edit-loop evidence without adding a dependency or changing the protected solution mapping.
- **OPTIONS CONSIDERED:** Standalone source-linked VB harness, smallest deterministic fit. Reflection harness against `StaxRip.exe`, stronger assembly integration but slower and name-brittle. MSTest in the solution, better IDE discovery but adds dependencies and solution mappings before the suite justifies them.
- **REVISIT WHEN:** Multiple feature suites need shared discovery, coverage reporting, or approved CI integration.

The GUI prototype target is a compact textual summary near the existing Assistant area, owned separately from Assistant evaluation. It shows overall state and counts in text, exposes a `ButtonEx` labeled `View readiness details`, and has a main-menu route for deterministic keyboard entry. The details surface uses `FormBase`, a DPI-scaled `TableLayoutPanel`, a read-only `DataGridViewEx` with Status, Check, and Explanation text columns, and standard close behavior. Every interactive element gets an explicit accessibility name. Final placement remains Q-002 until the ownership spike proves it does not disrupt established layout or navigation.

Do not copy the Assistant's script synchronization, frame-server creation, raw script-error, or exception behavior. Do not use `ButtonLabel`, color-only package status, an unverified task dialog, or owner-drawn focus suppression as the sole interaction. The prototype must prove Tab and Shift+Tab traversal, arrow-key rows, Enter or Space activation, Escape and Alt+F4 exit, return focus, non-stealing refresh, Narrator order, high contrast, and StaxRip plus Windows scaling.

DECISION: Readiness UI and accessibility pattern

- **STATUS:** Confirmed
- **CHOICE:** Prototype a separate compact summary near the Assistant, a labeled `ButtonEx` and menu entry, and a read-only `DataGridViewEx` details form with explicit accessibility properties and keyboard, high-contrast, and DPI verification.
- **BECAUSE:** No existing form is a verified accessibility pattern to copy unchanged. This composes the strongest current layout and keyboard precedents while hardening their unproven accessibility behavior.
- **OPTIONS CONSIDERED:** Composite summary and details form, compact and testable. Reuse Assistant logic, close visually but side-effecting. Task dialog only, quick but UI Automation behavior is unverified. Broad main-window redesign, useful later but exceeds the slice.
- **REVISIT WHEN:** Q-002 shows the adjacent placement disrupts the main workflow or runtime accessibility inspection rejects the selected controls.

## 12. Tool and Agent Discipline

- Work from a named branch or worktree. Confirm the active commit before each evidence run.
- Map the touched runtime path, owner, side effects, external boundary, failure route, and verification path before behavior edits.
- Use `verified`, `inferred`, or `unknown` for confidence. Convert an unknown with a focused check or carry it to `../Unknowns/Planning-Unknowns.md`.
- Keep parallel reviews read-only unless one writer owns an explicit non-overlapping file set. The lead reviews every shared-tree edit before it counts as evidence.
- Use repository-local enumeration, parsers, builds, synthetic fixtures, and deterministic executables before GUI or timing evidence.
- Do not install or update dependencies, tools, SDKs, packages, or workloads automatically. A missing prerequisite produces a bounded failure packet and an explicit decision.
- Do not run `Source/BuildAndPack.ps1` or `Source/Release.ps1`. Inspect any repository script before running it.
- Stop before persistence, deletion, overwrite, temp cleanup, process control, executable selection, download, native ABI, solution mapping, packaging, or release changes unless the user has approved that exact boundary.
- Keep generated, vendored, mirrored, binary, bundled-tool, and local evidence outputs out of broad edits.
- Do not begin production implementation until the Architecture Document, Engineering Document, and `SLICE-001` are audited and approved.

## 13. Observability

The typed `ReadinessResult` is the feature's functional observability. Each item exposes a stable id, outcome, severity, message key, safe bounded arguments, and order. The first slice adds no analytics, telemetry SDK, remote event, persistent history, or default readiness log entry.

- Expected readiness outcomes do not call `Log.Write*`, `Debug.Write*`, `Trace.*`, exception dialogs, or message-box error paths.
- Source, target and temp paths; user and media names; titles; scripts; commands; profile or template names; external output; and exception prose remain outside result, UI Automation, clipboard, and benchmark output.
- Local verification may report stable fixture ids, aggregate durations, counts, process handles, exit status, and the tested commit.
- If a later support feature includes readiness, it must use a reviewed field allowlist and explicit user review. It must not scrape existing raw logs.
- The readiness adapter runs only after the existing source-opening transaction has completed successfully. Expected missing facts are typed outcomes. An unexpected evaluator exception is caught at that adapter, leaves the loaded project untouched, and renders one privacy-safe `Readiness unavailable` state. It never reports `Ready` and does not copy the exception into logs or UI.
- The forced-unavailable branch needs separate activation and outcome evidence. A later diagnostic event requires a new logging and privacy decision.

Existing source-opening logs can contain full paths, media summaries, generated scripts, and arbitrary errors. This is verified context for the strict new boundary, not a claim that existing logging is private or fully audited. A scoped source scan found no telemetry or analytics SDK use in the managed UI candidates; whole-product and runtime absence remain unknown.

DECISION: Readiness observability and failure boundary

- **STATUS:** Confirmed
- **CHOICE:** Use the typed transient result as the only readiness observability. Add no readiness logging or telemetry. Invoke readiness after successful source opening, and convert an unexpected evaluator failure at the thin adapter to a privacy-safe `Unavailable` state without changing the loaded project.
- **BECAUSE:** The user needs inspectable status, but raw logs and the current source-opening exception path carry privacy and recovery risks that the first slice must not inherit.
- **OPTIONS CONSIDERED:** Typed result with an isolated unavailable state, bounded and recoverable. Reuse existing logs and exception dialogs, easy but private and potentially fatal. Add local or remote telemetry, more trend data but new collection and retention duties.
- **REVISIT WHEN:** Users need exportable readiness diagnostics and a separate slice defines fields, consent, retention, deletion, and failure handling.

## 14. Operations and Deployment

- **Development environment:** Windows x64, the documented Visual Studio or Build Tools prerequisites, restored existing application packages, synthetic fixtures, and an isolated portable runtime tree.
- **Source integration:** Merge bounded commits into the fork only after the evidence ladder passes. Record any upstream delta that overlaps the touched path.
- **Automation:** The first slice adds no hosted CI, bot, secret, privileged workflow, scheduled task, installer, updater behavior, or release automation.
- **Deployment:** None. `SLICE-001` ends with source and local verification evidence. It does not create or publish a portable archive or binary.
- **Migration:** None. Readiness is transient and does not change projects, settings, templates, profiles, jobs, caches, logs, or file formats.
- **Rollback:** Revert the bounded feature commits. Because there is no persisted readiness state, rollback needs no data repair. Verify that the prior source-opening and ready-to-encode behavior is restored.
- **Operational ownership:** The solo maintainer owns triage and evidence. Public contributors provide bounded reproductions with synthetic or redacted data. Release support remains U-006.

## 15. Cost Discipline

- Required recurring service cost is zero.
- Use the existing local Windows, Visual Studio or Build Tools, MSBuild, .NET Framework, and repository dependencies. The test harness adds no package.
- Do not add hosted data, paid monitoring, SaaS, cloud compute, signing service, or analytics to the first slice.
- A new dependency requires an owner, license review, version and provenance rule, update cost, offline behavior, rollback plan, and explicit approval.
- Track effort in weeks per bounded slice. Reduce scope before adding infrastructure or recurring cost.

DECISION: Source-only operations and cost posture

- **STATUS:** Confirmed
- **CHOICE:** Keep `SLICE-001` source-only, local, manual, x64, and zero-recurring-cost. Add no CI, service, dependency, packaging step, or public artifact.
- **BECAUSE:** The slice can prove workflow value with existing tools while release provenance and automation remain unresolved boundaries.
- **OPTIONS CONSIDERED:** Local source verification, lowest cost and boundary count. Add CI now, useful but requires workflow and dependency design. Publish a manual portable build, faster feedback but crosses unresolved release and downgrade contracts.
- **REVISIT WHEN:** The slice passes its audit and either repeated manual cost justifies CI or the fork begins an approved release slice.

## 16. Risk Register and Unknowns

| ID | Risk | Confidence | Impact | Safeguard and evidence |
|---|---|---|---|---|
| RK-001 | The first catalog reads mutable or side-effecting state | inferred | High | Q-001 maps each field to an owner; reject checks that require execution, network, or mutation |
| RK-002 | GUI wiring enters the existing source-opening transaction or duplicates Assistant logic | verified | High | Q-002 and U-010 map the unknown safe seam and ownership; prove the adapter is not invoked on abort or failure |
| RK-003 | Added work regresses source-opening latency or leaks handles | unknown | Medium | U-004 closes with fixed stage timings, p95 and median gates, and 50-evaluation handle evidence |
| RK-004 | A visually clear surface is not keyboard or UI Automation accessible | verified | High | The source scan found no explicit accessibility-property precedent; require explicit names, menu route, keyboard review, Narrator inspection, high contrast, and 100 to 200 percent DPI checks |
| RK-005 | Private workflow values escape through visible text, accessibility properties, logs, clipboard, or tests | verified | High | Existing logs contain sensitive classes; require typed allowlists, sentinels across every new output, no new log, and manual bounded-output review |
| RK-006 | A source-linked harness passes while application integration fails | inferred | Medium | Pair L1 with direct managed builds, solution builds, fixed runtime fixtures, and GUI evidence |
| RK-007 | Public release, branding, or legacy publish-metadata work expands the slice | verified | High | U-001, U-006, and U-009 remain open; enforce the source-only stop gate before packaging, publication, bootstrapper cleanup, or branding claims |
| RK-008 | x86 or Win32 configuration returns through a merge or test addition | verified | Medium | The fork graph is x64-only; L0 asserts configuration declarations and any reintroduction needs a new decision and explicit approval |
| RK-009 | The summary is correct but does not make the workflow meaningfully clearer | inferred | High | A-001 and U-011 remain open; complete the human walkthrough before Done and rethink the slice if it does not support a confident proceed-or-correct decision |
| RK-010 | A readiness result remains visible after relevant state or project changes | verified | High | Q-007 and U-012 map every snapshot field to mutation owners and force stale-result tests before adapter and GUI implementation |

`../Unknowns/Planning-Unknowns.md` is canonical for unresolved facts. U-003, U-004, U-010, and U-012 block dependent `SLICE-001` work. U-011 blocks value validation and Done. U-001, U-002, U-005, U-006, and U-009 remain outside the slice's source-only completion boundary unless touched scope changes. D-024 closed U-008 by selecting test-harness ownership.

## 17. Definition of Done

`SLICE-001` is done only when all applicable items below have source-bound evidence:

1. The slice brief, architecture, engineering, requirements, decisions, and touched unknowns agree. Q-001 through Q-003 and Q-007 are closed before their dependent implementation.
2. One pure evaluator owns the approved catalog, ids, typed outcomes, precedence, bounds, and deterministic ordering. Forms contain no duplicate readiness rules.
3. Evaluation occurs after successful source opening and changes no effective or persisted project, settings, template, profile, job, script, command, tool, temp, target, process, or file behavior.
4. The L1 harness passes fixed, boundary, determinism, privacy, and mutation cases in x64. L4 presentation evidence separately covers forced `Unavailable`, stale-result prevention, rendering, and accessibility behavior.
5. The solution and direct managed project build in the documented x64 configurations. The existing Release solution mapping is reported, not silently changed.
6. Fixed synthetic sources produce equivalent before-and-after processing contracts. Both approved script-engine paths are exercised where the catalog touches them.
7. The readiness summary and details are usable with keyboard only, expose meaningful accessibility names and row semantics, preserve return focus, work at 100, 125, 150, and 200 percent DPI, and remain clear without color.
8. Performance and handle targets in ADD section 11 pass with the approved fixture and repetition protocol.
9. Sensitive sentinels are absent from results, rendering, accessibility output, clipboard paths, test output, and any changed logging surface. No new telemetry, network, or persistent readiness record exists.
10. `git diff --check`, project and solution parsing, x64-only configuration scan, bounded forbidden-boundary scan, and documentation-link checks pass.
11. No dependency, solution mapping, persistence format, native ABI, external command, tool selection, cleanup rule, release script, package, or public binary changed.
12. The close-out names checks run, untested boundaries, unknowns, privacy and logging impact, documentation, approvals, and rollback.

## 18. Change Control

- A new requirement, check category, output field, integration point, dependency, persistence rule, process probe, diagnostic, or distribution step enters the Decision Log before code changes.
- If repository evidence conflicts with a confirmed decision, stop, mark the contradiction, and ask for a superseding decision. Do not bend code or evidence to the plan.
- Protected boundaries in root `AGENTS.md` require the smallest proposed edit, rollback, verification, and explicit user approval.
- Keep commits single-purpose. Separate model, GUI, verification, documentation, and any later release work when rollback or review boundaries differ.
- Before merge, compare the touched files with current upstream and resolve overlap without restoring x86 or Win32 configuration or weakening fork safeguards.
- A test-only change cannot reduce assertions, widen accepted output, skip a branch, or loosen a performance threshold without a logged reason and independent review.
- Completion evidence is invalidated when the tested commit changes in a relevant path. Re-run the cheapest affected gates through the highest affected level.
- Rollback reverts bounded source commits. Any future persisted or distributed state needs a new rollback contract before implementation.

DECISION: Definition of done and change control

- **STATUS:** Confirmed
- **CHOICE:** Accept the slice only through the requirement-traced evidence ladder and explicit close-out above. Route scope or contract changes through the Decision Log, preserve x64-only configuration, and stop at protected boundaries.
- **BECAUSE:** A visible readiness surface is useful only if its read-only, compatible, accessible, private, and measurable claims remain reviewable after upstream and fork changes.
- **OPTIONS CONSIDERED:** Requirement-traced gates with bounded commits, slower but auditable. Build-only completion, quick but weak on behavior. Manual visual acceptance alone, useful for polish but not deterministic.
- **REVISIT WHEN:** Repeated slices show a stable smaller gate set or approved automation can produce equivalent evidence.

---

*Sections filled: 18 of 18. Unknowns carried: 12. See `DECISION-LOG.md` for reasoning.*
