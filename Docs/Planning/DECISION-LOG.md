# StaxRip Community Decision Log

Version: 0.2 Draft. Date: 2026-08-16.
Companion documents: `ARCHITECTURE.md`, `ENGINEERING.md`, and the slice briefs (`SLICE-001` onward).

## Rules

1. Every Decision Block in the ADD and EDD gets a sequential entry here.
2. A changed decision gets a new entry. The old entry becomes Superseded and links to its replacement.
3. Stubs and shortcuts are decisions with a written payback trigger.
4. Work that conflicts with a logged decision must surface the conflict before implementation.
5. Each document audit checks whether a revisit trigger has fired.

## Index

| ID | Date | Decision | Status | Superseded by |
|---|---|---|---|---|
| D-001 | 2026-08-13 | Public fork identity | Confirmed | |
| D-002 | 2026-08-13 | Compatibility posture | Confirmed | |
| D-003 | 2026-08-13 | Planning mode | Confirmed | |
| D-004 | 2026-08-13 | Initial workflow direction | Confirmed | |
| D-005 | 2026-08-13 | Privacy depth | Confirmed | |
| D-006 | 2026-08-13 | Product shape and platforms | Superseded | D-038 |
| D-007 | 2026-08-13 | Interface and compatibility posture | Confirmed | |
| D-008 | 2026-08-13 | Client technology | Superseded | D-039 |
| D-009 | 2026-08-13 | Implementation languages | Superseded | D-039 |
| D-010 | 2026-08-13 | Backend approach | Superseded | D-039 |
| D-011 | 2026-08-13 | Storage approach | Confirmed | |
| D-012 | 2026-08-13 | Authentication | Superseded | D-040 |
| D-013 | 2026-08-13 | Notification channels | Confirmed | |
| D-014 | 2026-08-13 | Build and distribution path | Superseded | D-041 |
| D-015 | 2026-08-13 | Performance targets | Confirmed | |
| D-016 | 2026-08-13 | Deployment posture | Superseded | D-041 |
| D-017 | 2026-08-13 | Failure and recovery posture | Confirmed | |
| D-018 | 2026-08-13 | Architecture guardrails | Confirmed | |
| D-019 | 2026-08-13 | Engineering goal priority | Confirmed | |
| D-020 | 2026-08-13 | Readiness data model | Confirmed | |
| D-021 | 2026-08-13 | Local security boundary | Confirmed | |
| D-022 | 2026-08-13 | Readiness privacy posture | Confirmed | |
| D-023 | 2026-08-13 | Code and repository organization | Confirmed | |
| D-024 | 2026-08-14 | Verification harness and evidence ladder | Confirmed | |
| D-025 | 2026-08-14 | Readiness UI and accessibility pattern | Confirmed | |
| D-026 | 2026-08-14 | Readiness observability and failure boundary | Confirmed | |
| D-027 | 2026-08-14 | Source-only operations and cost posture | Confirmed | |
| D-028 | 2026-08-14 | Definition of done and change control | Confirmed | |
| D-029 | 2026-08-13 | Remove legacy x86 bootstrapper prerequisites | Confirmed | |
| D-030 | 2026-08-15 | SLICE-001 shape and timebox | Superseded | D-037 |
| D-031 | 2026-08-15 | Readiness refresh and invalidation | Confirmed | |
| D-032 | 2026-08-15 | Initial readiness catalog breadth | Confirmed | |
| D-033 | 2026-08-15 | SLICE-001 build approval | Confirmed | |
| D-034 | 2026-08-15 | Conservative Ready authority | Superseded | D-037 |
| D-035 | 2026-08-15 | Interactive-only readiness activation | Confirmed | |
| D-036 | 2026-08-15 | Readiness adapter failure boundary | Confirmed | |
| D-037 | 2026-08-15 | M0 source-project-check pivot | Confirmed | |
| D-038 | 2026-08-16 | Additive Linux and macOS platform expansion | Confirmed | |
| D-039 | 2026-08-16 | Cross-platform engine and first clients | Confirmed | |
| D-040 | 2026-08-16 | Local HTTP security boundary | Confirmed | |
| D-041 | 2026-08-16 | SLICE-002 build and artifact boundary | Confirmed | |
| D-042 | 2026-08-16 | Native desktop client posture | Confirmed | |
| D-043 | 2026-08-16 | Portability evidence and anti-dark-code feedback | Confirmed | |
| D-044 | 2026-08-16 | Isolated subtree and Linux runtime-pack restore | Confirmed | |

## Entries

## D-001: Public fork identity

Date: 2026-08-13
Status: Confirmed
Area: Triage

Context: The project is moving from upstream-only contributions to a maintained public fork.

Decision: Use the working name StaxRip Community and plan for public users.

Because: The name keeps the relationship to StaxRip visible while distinguishing the fork's direction.

Options considered:
- StaxRip Community: clear continuity and fork identity.
- StaxRip: no immediate rename, but ambiguous ownership.
- New codename: distinct identity, but weak discoverability and migration clarity.

Consequences: Public documentation, attribution, support, privacy, and release expectations apply. Trademark or naming permission remains an external legal unknown.

Revisit when: Maintainer feedback, trademark review, or distribution planning requires a different public name.

## D-002: Compatibility posture

Date: 2026-08-13
Status: Confirmed
Area: Triage

Context: StaxRip users own settings, projects, templates, profiles, scripts, jobs, and external-tool choices.

Decision: Preserve strict upstream compatibility by default.

Because: Existing user data and generated processing contracts have a larger blast radius than an ordinary UI refactor.

Options considered:
- Strict compatibility: lowest migration risk, more constraints on design.
- Saved-data compatibility only: more UI and command freedom, higher workflow risk.
- Fork-native breaks with migrations: most freedom, highest support and rollback cost.

Consequences: Breaking changes need explicit migration, verification, rollback, and approval work.

Revisit when: A specific measured user benefit cannot be delivered through an additive change.

## D-003: Planning mode

Date: 2026-08-13
Status: Confirmed
Area: Triage

Context: This is a mapped existing codebase with a solo team and a weeks-per-slice cadence.

Decision: Use fast-run with standard explanations and explicit veto checkpoints.

Because: Filled defaults reduce interview time while keeping irreversible, risk, slice, and audit decisions with the human.

Options considered:
- Fast-run, standard depth: less interview time with visible defaults.
- Full interview: more discussion, slower start.
- Expert terse mode: faster text, less context at unfamiliar boundaries.

Consequences: Silence never confirms a batch. Proposed defaults become Confirmed only after an explicit continue.

Revisit when: A batch contains repeated corrections or the user requests more depth.

## D-004: Initial workflow direction

Date: 2026-08-13
Status: Confirmed
Area: Triage and future ADD 15

Context: The fork needs one visible workflow improvement before broad GUI or feature work.

Decision: Shape the first slice around source opening through ready-to-encode.

Because: This is an end-to-end user path that crosses intake, project state, scripts, tool selection, validation, and GUI feedback.

Options considered:
- Source opening through ready-to-encode: broad enough to prove the workflow, still sliceable.
- Job execution and retry: valuable, but begins at a higher-risk concurrency boundary.
- Encoder configuration: focused, but does not prove the intake path.
- Template management: useful, but persistence-heavy for the first fork slice.

Consequences: Exact slice scope remains open until the architecture and engineering rules expose the safest valuable cut.

Revisit when: Mapping shows that a smaller adjacent workflow produces more user value with less compatibility risk.

## D-005: Privacy depth

Date: 2026-08-13
Status: Confirmed
Area: Triage and future EDD security/privacy sections

Context: Local diagnostics can contain user names, paths, media metadata, scripts, settings, and complete commands.

Decision: Run the privacy sections at full depth now.

Because: The fork is public, and diagnostic improvements are part of the current baseline. Privacy rules must exist before new workflow telemetry or support behavior appears.

Options considered:
- Full depth now: more planning, lowest chance of publishing unsafe diagnostics.
- Full depth before public beta: faster early work, delayed safeguard.
- Ordinary T2 scope: least planning, insufficient for the known log boundary.

Consequences: New diagnostics use explicit allowlists, bounded content, synthetic fixtures, and manual review where required.

Revisit when: The diagnostic data boundary materially shrinks or expands.

## D-006: Product shape and platforms

Date: 2026-08-13
Status: Superseded by D-038
Area: ADD 3

Context: The existing product is a portable Windows desktop application that coordinates native and external processing tools.

Decision: Preserve the portable Windows x64 architecture and external-tool model. Do not begin with an installer or platform rewrite.

Because: It reaches current users and keeps the first workflow slice inside known runtime boundaries.

Options considered:
- Preserve the portable Windows app: lowest compatibility risk.
- Add an installer: easier onboarding, new release and machine-state risks.
- Cross-platform rewrite: wider reach, breaks present GUI and tool contracts.

Consequences: The fork can improve the workflow now. Installer and platform expansion remain separate future decisions.

Revisit when: A measured user need cannot be served by the portable x64 application.

## D-007: Interface and compatibility posture

Date: 2026-08-13
Status: Confirmed
Area: ADD 5

Context: The current product combines typed managed calls, events, native exports, generated scripts, persisted files, PowerShell, and external command lines.

Decision: Keep the mixed interface style, add typed owners and adapters around touched paths, and preserve named compatibility surfaces.

Because: This enables bounded workflow improvements without requiring a high-risk rewrite first.

Options considered:
- Preserve and isolate current seams: slower cleanup, lowest user risk.
- Layered internal rewrite first: cleaner structure, delayed value and larger regression surface.
- New application rewrite: maximum freedom, incompatible with the confirmed goal.

Consequences: Each slice must map its touched seam and attach verification to the actual persisted, generated, native, or external contract.

Revisit when: A mapped seam prevents a slice from being tested or extended without duplicate behavior.

## D-008: Client technology

Date: 2026-08-13
Status: Superseded by D-039
Area: ADD 8.1

Context: The current GUI, controls, serialization, and Windows integration use VB.NET Windows Forms on .NET Framework 4.8.

Decision: Keep the current client technology for the initial fork slices.

Because: It preserves current runtime behavior while workflow ownership and tests are established.

Options considered:
- Existing WinForms: fastest compatible route.
- Modern .NET WinForms migration: newer runtime, broad compatibility work.
- WPF or cross-platform rewrite: more layout freedom, new application boundary.

Consequences: Workflow and visual improvements must fit current controls at first. Runtime migration remains separate.

Revisit when: A supported platform, toolchain, or measured UI need cannot be served safely on .NET Framework 4.8.

## D-009: Implementation languages

Date: 2026-08-13
Status: Superseded by D-039
Area: ADD 8.2

Context: VB.NET owns the app and AutoCrop, C++17 owns FrameServer, and PowerShell is a user extension surface.

Decision: Keep the current language ownership. Require a slice-specific reason before adding another language.

Because: A new language adds build, debugging, packaging, and contributor cost.

Options considered:
- Preserve current languages: lowest integration cost.
- Gradual C# introduction: broader familiarity, mixed managed ownership.
- Rewrite: highest cost and compatibility risk.

Consequences: New managed workflow code remains VB.NET unless a later decision establishes an isolated boundary.

Revisit when: A bounded component has verification and a measured need the current language cannot serve.

## D-010: Backend approach

Date: 2026-08-13
Status: Superseded by D-039
Area: ADD 8.3

Context: The current product is portable, offline-capable, and local-first.

Decision: Add no application backend in the initial roadmap.

Because: A service adds accounts, operations, privacy, availability, and cost without serving source readiness.

Options considered:
- Local only: preserves portability.
- Optional community service: enables shared features, adds a control plane.
- Required service: central management, breaks offline use.

Consequences: Shared community features must wait or use explicit file exchange.

Revisit when: A confirmed feature requires shared remote state.

## D-011: Storage approach

Date: 2026-08-13
Status: Confirmed
Area: ADD 8.4

Context: Existing projects, settings, profiles, jobs, and templates use local serialized formats and selected Registry values.

Decision: Preserve current storage and add no database in initial workflow slices.

Because: Strict compatibility makes existing formats authoritative. A database needs migration, backup, repair, and rollback contracts.

Options considered:
- Existing local storage: compatible, careful ownership required.
- Embedded database: stronger queries, migration boundary.
- Remote database: shared access, incompatible with local-first use.

Consequences: New readiness state must be derived or additive, not a competing persisted truth.

Revisit when: A confirmed feature needs transactions or queries existing formats cannot safely provide.

## D-012: Authentication

Date: 2026-08-13
Status: Superseded by D-040
Area: ADD 8.5

Context: There is no product backend or multi-user data store.

Decision: Add no product authentication. Windows and filesystem permissions remain the authority for local data.

Because: Accounts would add sensitive credentials without protecting local files from the current user.

Options considered:
- No authentication: fits the local application.
- Optional sign-in: useful only with a future service.
- Required sign-in: breaks offline and portable use.

Consequences: Any future service must make its authentication and data boundary explicit.

Revisit when: An approved remote service stores user-specific data.

## D-013: Notification channels

Date: 2026-08-13
Status: Confirmed
Area: ADD 8.7

Context: Users interact with a local desktop workflow and already receive dialogs, processing views, Assistant guidance, and logs.

Decision: Use in-app feedback only for the initial slices.

Because: The first slice needs consistent visible state, not a remote channel.

Options considered:
- In-app only: direct and offline.
- Windows notifications: useful for long jobs, more OS behavior.
- Remote messaging: requires a service and personal data.

Consequences: Long-running background notification remains a future measurement-driven feature.

Revisit when: In-app completion and failure signals prove insufficient for real workflows.

## D-014: Build and distribution path

Date: 2026-08-13
Status: Superseded by D-041
Area: ADD 8.8

Context: X64 source builds are verified, while packaging inputs and checked-in release scripts retain unresolved machine-specific and destructive behavior.

Decision: Keep Visual Studio and MSBuild source builds, use GitHub for collaboration, and defer public release automation to an approved slice.

Because: This permits verified development without pretending the distribution boundary is settled.

Options considered:
- Manual verified source builds now: lowest immediate risk.
- Source-build CI: useful guardrail with dependency work.
- Public release automation now: faster distribution, unresolved packaging and provenance risk.

Consequences: The first workflow slice can build and test, but it does not publish a community release.

Revisit when: The first slice is stable and the fork is ready to define reproducible artifacts.

## D-015: Performance targets

Date: 2026-08-13
Status: Confirmed
Area: ADD 11

Context: Total source-opening time depends on media, storage, selected tools, scripts, plugins, and hardware. No representative fork baseline exists yet.

Decision: Limit added readiness work to 100 ms at the 95th percentile, prevent a median total-flow regression above 5 percent or 100 ms, whichever allowance is larger, and require no net handle growth across 50 unchanged-project evaluations.

Because: These targets measure what the slice controls without inventing a universal source-opening time.

Options considered:
- Relative regression and added-overhead targets: honest before a baseline.
- Fixed total-open target: simple, unsupported across environments.
- No number: easy to claim success, unable to verify speed.

Consequences: The slice needs a fixed synthetic fixture set and separate timing for existing work and new work.

Revisit when: A representative baseline covers fast local media, slow storage, multiple sources, and both frame-server engines.

## D-016: Deployment posture

Date: 2026-08-13
Status: Superseded by D-041
Area: ADD 12

Context: Source builds are verified. Portable assembly, bundled-tool provenance, machine-specific release scripts, artifact publication, and downgrade behavior retain open contracts.

Decision: Develop and test the first slice in source and isolated portable fixtures. Publish no community binary until a release slice is approved.

Because: This prevents an incomplete build contract from becoming a public distribution promise.

Options considered:
- Source-only development first: bounded, slower public access.
- Manual binary upload: faster, weak reproducibility.
- Automated release now: useful only after the artifact contract exists.

Consequences: Public users can inspect source progress, but the initial slice does not ship as an official community archive.

Revisit when: The first slice passes its audit and release-boundary planning is explicitly approved.

## D-017: Failure and recovery posture

Date: 2026-08-13
Status: Confirmed
Area: ADD 13

Context: Source opening already spans recovery snapshots, requirements, external tools, temp files, scripts, and events. For a non-abort unexpected exception, the global handler attempts recovery and diagnostics and then terminates the process; the following blank-project call is not a verified recovery outcome.

Decision: Make the readiness slice observe and explain existing outcomes without changing recovery, cancellation, temp-file, process, or cleanup semantics.

Because: A read-only result improves clarity without changing what the source-opening transaction commits or rolls back.

Options considered:
- Observe and report only: smallest safe boundary.
- Repair selected failures in the same slice: mixed recovery behavior.
- Rewrite source opening first: broad risk and delayed value.

Consequences: Recovery defects may be recorded but remain separate approval-gated work.

Revisit when: One frequent blocker has a deterministic recovery harness and a separate approved brief.

## D-018: Architecture guardrails

Date: 2026-08-13
Status: Confirmed
Area: ADD 14

Context: The first user-visible change touches a long legacy workflow near persistence, native code, external processes, temp data, and private diagnostics.

Decision: Implement readiness as a typed, read-only interpretation and presentation layer over existing post-open state.

Because: This keeps the first slice outside persistence, command, native, tool, cleanup, concurrency, and release behavior.

Options considered:
- Read-only slice: narrowest compatibility surface.
- Readiness plus automatic repair: more immediate help, protected-state mutation.
- Broad source-opening refactor: cleaner target, too many unverified branches.

Consequences: The GUI consumes one readiness result. Automatic fixes and workflow restructuring remain future slices.

Revisit when: The read-only slice has evidence and a later brief selects one guarded boundary.

## D-019: Engineering goal priority

Date: 2026-08-13
Status: Confirmed
Area: EDD 3

Context: The fork has more desirable qualities than one weeks-long slice can optimize at once.

Decision: Protect compatibility and reliability first, workflow clarity and accessibility second, and measured performance third.

Because: A fast or attractive workflow is not successful if it changes user-owned processing behavior. Clear readiness is the selected user value, and performance claims require a baseline.

Options considered:
- Compatibility, clarity, then performance: fits the confirmed fork posture.
- Visual redesign first: visible progress, weak behavior proof.
- Performance first: useful only after stages and fixtures are measurable.

Consequences: The slice may defer visual polish or optimization when either conflicts with verified compatibility.

Revisit when: Compatibility gates are automated and measured user feedback identifies a different primary constraint.

## D-020: Readiness data model

Date: 2026-08-13
Status: Confirmed
Area: EDD 5

Context: The readiness slice needs deterministic state without changing serialized projects or embedding rules in a form.

Decision: Use immutable transient snapshot, check, and result types. Keep stable ids and typed outcomes separate from rendered English.

Because: This supports deterministic tests, prevents legacy-state mutation, and leaves a localization seam.

Options considered:
- Typed transient model: clear ownership and no migration.
- Direct form reads: fewer files, duplicated rules and mutation risk.
- Persisted readiness: faster reload, compatibility and invalidation work.

Consequences: A mapping spike must approve every snapshot field and check id. No readiness state is saved.

Revisit when: A later feature needs readiness history and defines persistence, privacy, and migration.

## D-021: Local security boundary

Date: 2026-08-13
Status: Confirmed
Area: EDD 6 and 7

Context: The desktop application already opens untrusted inputs and can run scripts and tools with the user's Windows authority.

Decision: Keep readiness pure, local, read-only, dependency-free, and process-free. Treat loaded project and tool state as untrusted snapshot input.

Because: The slice can add clarity without expanding authority or adding an entry point.

Options considered:
- Pure local evaluation: smallest security change.
- Live tool probes: fresher facts, process and privacy risk.
- Remote validation: shared rules, network and data exposure.

Consequences: A fact that requires execution or network access is excluded until a later approved boundary.

Revisit when: A required readiness fact cannot be established from bounded current state.

## D-022: Readiness privacy posture

Date: 2026-08-13
Status: Confirmed
Area: EDD 8

Context: Paths, media metadata, scripts, commands, settings, tool output, and exceptions can disclose personal or confidential information.

Decision: Keep readiness transient and local. Use safe typed facts and message keys rather than raw user or diagnostic content.

Because: Readiness does not need to become another private log.

Options considered:
- Minimal transient facts: lowest disclosure risk.
- Reuse raw logs: easy, private and unbounded.
- Persist detailed history: useful trends, new retention and deletion duties.

Consequences: Public sharing and history remain separate future decisions.

Revisit when: A confirmed feature requires history or sharing and defines data, retention, deletion, and consent.

## D-023: Code and repository organization

Date: 2026-08-13
Status: Confirmed
Area: EDD 9 and 10

Context: The legacy layout is mixed, `MainForm` already owns a long source-opening transaction, and the fork baseline does not yet track its canonical steering file.

Decision: Add one feature-owned pure evaluator, keep GUI wiring thin, track reviewed steering before implementation, and approve any build-configuration test harness separately.

Because: This fits the repository without spreading new rules through event handlers or hiding project changes.

Options considered:
- Feature owner plus thin adapter: clear boundary.
- Put logic in `MainForm`: fewer files, deeper coupling.
- Broad reorganization: cleaner target, unrelated churn.

Consequences: Q-005 closed through D-024 before slice implementation. Q-006 closed on 2026-08-13 when the user confirmed the x64-only graph and approved the corrected tracked steering file.

Revisit when: Mapping identifies an existing typed owner for the same responsibility.

## D-024: Verification harness and evidence ladder

Date: 2026-08-14
Status: Confirmed
Area: EDD 11

Context: The repository has no automated test framework. Adding a conventional test dependency or solution project would change protected build configuration.

Decision: Add a standalone .NET Framework 4.8 x64 VB console harness that source-links only the pure readiness files. Keep it outside `Source/StaxRip.sln`, add no package or application project reference, put outputs below ignored `Source/obj`, and pair it with product builds and higher-level runtime gates.

Because: This provides deterministic edit-loop evidence without changing the existing solution mapping or adding a dependency.

Options considered:
- Standalone source-linked VB harness: smallest deterministic fit.
- Reflection harness against `StaxRip.exe`: stronger integration, slower and name-brittle.
- MSTest in the solution: better discovery, new dependency and mappings.

Consequences: The user approved the new standalone test project but not a solution mapping, package, CI workflow, or release change. Q-005 and U-008 are closed. Direct x64 product builds remain required.

Revisit when: Multiple suites need common discovery, coverage reporting, or approved CI.

## D-025: Readiness UI and accessibility pattern

Date: 2026-08-14
Status: Confirmed
Area: EDD 11

Context: Existing forms provide useful layout and keyboard pieces, but a scoped source review found no explicit accessibility properties and no form that is safe to copy unchanged.

Decision: Prototype a separately owned compact summary near the Assistant, a labeled `ButtonEx` and menu route, and a read-only `DataGridViewEx` details form with explicit accessibility properties and keyboard, high-contrast, and DPI verification.

Because: This composes current controls without inheriting Assistant side effects, color-only status, or unverified task-dialog behavior.

Options considered:
- Composite summary and details form: compact and testable.
- Reuse Assistant logic: visually close, side-effecting and exception-coupled.
- Task dialog only: quick, accessibility behavior unverified.
- Broad main-window redesign: useful later, too large for the slice.

Consequences: Q-004 closes. Q-002 remains open until a prototype proves exact placement and navigation. Explicit accessibility properties and runtime inspection are required.

Revisit when: The ownership spike rejects adjacent placement or runtime inspection rejects the controls.

## D-026: Readiness observability and failure boundary

Date: 2026-08-14
Status: Confirmed
Area: EDD 13

Context: Existing source-opening logs and exception paths can contain private values or terminate the process. Readiness needs inspectable results without inheriting those contracts.

Decision: Use the typed transient result as the only readiness observability. Add no readiness logging or telemetry. Invoke readiness after successful source opening and convert an unexpected evaluator failure at the thin adapter to a privacy-safe `Unavailable` state without changing the loaded project.

Because: The feature remains useful and recoverable without copying private logs or making readiness failure a source-opening failure.

Options considered:
- Typed result and isolated unavailable state: bounded and recoverable.
- Existing logs and exception dialogs: easy, private and potentially fatal.
- New local or remote telemetry: more trend data, new collection and retention duties.

Consequences: Expected outcomes are typed. Unexpected failures never report ready or expose exception prose. The unavailable branch needs forced activation and outcome evidence.

Revisit when: A separate diagnostics slice defines export fields, consent, retention, deletion, and failure handling.

## D-027: Source-only operations and cost posture

Date: 2026-08-14
Status: Confirmed
Area: EDD 14 and 15

Context: The fork has verified local source builds, near-zero budget, and unresolved release provenance and automation contracts.

Decision: Keep `SLICE-001` source-only, local, manual, x64, and zero-recurring-cost. Add no CI, service, dependency, packaging step, or public artifact.

Because: Existing tools can prove the workflow slice without expanding operations or distribution boundaries.

Options considered:
- Local source verification: lowest cost and boundary count.
- Add CI now: useful, requires workflow and dependency design.
- Publish a manual portable build: faster feedback, unresolved provenance and rollback.

Consequences: Completion produces source and evidence only. Public distribution remains U-006 and needs another approved slice.

Revisit when: Repeated manual cost justifies CI or a release slice is approved.

## D-028: Definition of done and change control

Date: 2026-08-14
Status: Confirmed
Area: EDD 17 and 18

Context: A clean build alone cannot prove source-opening compatibility, accessibility, privacy, performance, or absence of x86 configuration drift.

Decision: Accept the slice only through the requirement-traced evidence ladder and explicit close-out. Route scope or contract changes through this log, preserve x64-only configuration, and stop at protected boundaries.

Because: The fork needs durable, reviewable proof for a visible feature on a high-risk legacy workflow.

Options considered:
- Requirement-traced gates and bounded commits: auditable and reversible.
- Build-only completion: quick, weak behavior evidence.
- Manual visual acceptance only: useful for polish, not deterministic.

Consequences: Relevant commit changes invalidate affected evidence. Test weakening requires a logged reason and review. Rollback remains commit-bounded because the slice persists no state.

Revisit when: Repeated slices establish a smaller equivalent gate set or approved automation provides the same evidence.

## D-029: Remove legacy x86 bootstrapper prerequisites

Date: 2026-08-13
Status: Confirmed
Area: Fork baseline build metadata

Context: The fork supports x64 only. After the x86 solution and project configurations were removed, `Source/StaxRip.vbproj` still declared .NET Framework 2.0 and 3.0 x86 bootstrapper prerequisites. The user explicitly confirmed that legacy x86 project entries should be removed.

Decision: Remove the two x86 bootstrapper package entries. Retain the Visual C++ `Win32Proj` keyword because it identifies the C++ project type and does not create a Win32 build configuration.

Because: The x86 prerequisite entries contradict the confirmed x64-only product and project contract. The C++ keyword has different semantics and is required project metadata.

Options considered:
- Remove only the two verified x86 prerequisite entries: matches the approval and keeps unrelated publish metadata unchanged.
- Remove all legacy ClickOnce and bootstrapper metadata: broader release behavior with unknown ownership.
- Keep the entries: contradicts the x64-only fork contract.

Consequences: Normal Debug and Release x64 builds must remain clean. Publish and bootstrapper behavior is untested and remains blocked by U-009 and the release approval gate.

Revisit when: The release-boundary slice maps and replaces or retires the remaining legacy publish metadata.

## D-030: SLICE-001 shape and timebox

Date: 2026-08-15
Status: Superseded by D-037
Area: SLICE-001 sections 1 and 3

Context: The slice growth tally showed that accessibility, privacy, deterministic verification, performance, safe integration, and stale-result prevention had enlarged the original one-summary concept.

Decision: Keep one full end-to-end source-readiness slice with five spike-first milestones and a maximum planning posture of five solo weeks. Reassess scope if the first milestone cannot prove a safe seam, lifecycle, catalog, and fixture protocol.

Because: The slice must prove user value through the real GUI and architecture. A model-only first slice would not test whether users can make a confident proceed-or-correct decision.

Options considered:
- Full end-to-end proof: strongest central-claim test and the selected option.
- Split model and GUI: smaller changes, but the first part has no real-user result.
- One-shot summary only: faster, but creates stale-state and accessibility debt.

Consequences: Discovery spikes close before dependent implementation. The timebox controls scope rather than weakening evidence or crossing protected boundaries.

Revisit when: Milestone M0 cannot prove a safe read-only path within the confirmed constraints.

## D-031: Readiness refresh and invalidation

Date: 2026-08-15
Status: Confirmed
Area: SLICE-001 sections 2, 7, and 8

Context: Relevant project and requirement state can change after source opening. A retained `Ready` result can become false unless every input has an invalidation owner.

Decision: Evaluate once after a verified successful source-opening return. Use an explicit `Refresh project checks` command for recomputation. Invalidate or hide the current result on a new open attempt, project replacement, or any mapped input change. Exclude a candidate check when no safe invalidation trigger can be proven. Add no background refresh or worker. D-037 supplies the renamed feature contract; the lifecycle semantics in this entry remain active.

Because: Explicit refresh keeps recomputation predictable while mandatory invalidation prevents a stale ready claim.

Options considered:
- Explicit refresh plus mandatory invalidation: selected, bounded, and visible.
- Automatic recomputation on every event: smoother, more coupling and event-order risk.
- One-shot result: smallest, but can mislead after changes.

Consequences: Q-007 and U-012 close only when the lifecycle spike maps every approved field, project transition, failed later open, and forced stale-result scenario.

Revisit when: A later slice has a typed project-change stream with proven ordering and safe automatic recomputation.

## D-032: Initial readiness catalog breadth

Date: 2026-08-15
Status: Confirmed
Area: SLICE-001 sections 3 and 7

Context: The final catalog is unknown, but a broad first catalog would multiply state ownership, invalidation, copy, and verification work.

Decision: Target five to eight pure post-success checks. The mapping spike may shrink the count. Every accepted check needs a stable id, owner, bounded input, severity, precedence, invalidation trigger, and deterministic test. No live probe, process, network, log parse, or mutation enters the catalog.

Because: A small proven catalog can demonstrate the workflow without hiding unsafe checks behind a larger count.

Options considered:
- Five to eight pure checks: selected balance of usefulness and proof.
- All available pure facts: more coverage, larger ownership and UI surface.
- One overall boolean: small, but does not explain warnings or blockers.

Consequences: Q-001 and U-003 remain open until the catalog artifact is approved. Count is not a success metric. At least one retained blocker must be safely reproducible and correctable through an existing StaxRip control so the complete walkthrough is real; every retained check must support the central claim.

Revisit when: User walkthrough evidence identifies a missing fact that can satisfy the same purity and lifecycle rules.

## D-033: SLICE-001 build approval

Date: 2026-08-15
Status: Confirmed
Area: SLICE-001 complete brief

Context: The final slice shape has been selected and written into a complete brief. Production implementation still requires the human to approve that exact document as the build boundary.

Decision: Approve `Docs/Planning/SLICE-001.md` as the only active build slice, including its milestones, exclusions, no-stub posture, data subset, acceptance criteria, evidence, stop gates, and human walkthrough requirement.

Because: The brief makes the full cost and boundary reviewable before product files change.

Options considered:
- Approve the brief: begins M0 discovery only.
- Revise the brief: keeps planning active until the boundary agrees with user intent.
- Split or cancel the slice: replaces D-030 through a new decision.

Consequences: While Proposed, no production feature implementation starts. Confirmation authorizes M0 discovery, not later milestones before their named spike gates close.

Revisit when: Repository evidence contradicts the brief or the user changes the selected workflow.

## D-034: Conservative Ready authority

Date: 2026-08-15
Status: Superseded by D-037
Area: SLICE-001 sections 1, 7, and 8

Context: Existing encode entry uses requirement verification, Assistant state, disk checks, and events at `Source/Forms/MainForm.vb:4187,4195-4198`. Assistant evaluation also performs script and frame-server work at `Source/Forms/MainForm_Assistant.vb:19-28`. A five-to-eight-check catalog may not observe every authoritative condition without side effects.

Decision: Do not emit overall `Ready` until M0 maps every authoritative condition required by that label and proves each condition is known and satisfied. An excluded, unknown, stale, or unverified authoritative condition prevents `Ready`. If the pure catalog cannot support that rule, stop and revisit D-030 before implementation rather than weakening the label.

Because: A partial catalog must not present a stronger claim than the existing encode gate can support.

Options considered:
- Conservative `Ready` authority: selected option, honest but may stop the slice in M0.
- Rename success to `Selected checks passed`: accurate for partial coverage, but does not prove the selected ready-to-encode claim.
- Emit `Ready` from only the small catalog: simple, but can mislead users.

Consequences: S-017 and the catalog artifact must trace `VerifyRequirements`, Assistant state, disk checks, encode events, and any other mapped authority. No test count substitutes for this coverage record.

Revisit when: The authoritative encode gate becomes a typed side-effect-free contract shared by both workflows.

## D-035: Interactive-only readiness activation

Date: 2026-08-15
Status: Confirmed
Area: SLICE-001 sections 2, 6, and 8

Context: Job processing calls the shared source-opening overload with `isEncoding := True` at `Source/General/GlobalClass.vb:561`; the overload starts at `Source/Forms/MainForm.vb:2477`. The first slice is an interactive GUI feature and excludes job execution changes.

Decision: Evaluate and present readiness only for the approved interactive `isEncoding = False` path. On `isEncoding = True` and job-processing paths, snapshot, evaluation, and new summary or details presentation counts stay zero. The only permitted readiness action is a mapped synchronous clear or hide of prior transient state before job processing. Existing job behavior remains unchanged.

Because: Reusing a shared method does not authorize injecting GUI work, latency, or failure handling into the job runner.

Options considered:
- Interactive-only activation: selected option and smallest job boundary.
- Evaluate silently during jobs: more reuse, but adds latency and failure behavior without user value.
- Present readiness during jobs: visible but conflicts with the excluded job-execution scope.

Consequences: M0 maps every call path, names the pre-job clear owner, and approves an isolated synthetic job-path verification protocol with a stopping point before processing, tool launch, or output work. S-018 later proves production branch activation and outcome separately. If no safe protocol exists without changing job behavior, stop for a new decision.

Revisit when: A later job-readiness slice defines non-GUI consumption and processing semantics.

## D-036: Readiness adapter failure boundary

Date: 2026-08-15
Status: Confirmed
Area: SLICE-001 sections 3, 8, and 9

Context: Planned snapshot construction runs before the evaluator. Catching evaluator failures alone leaves mapper failure coupled to the current UI exception route registered at `Source/Forms/MainForm.vb:993`, handled at `Source/General/GlobalClass.vb:1650-1655`, and terminated at line 1591 for the mapped non-abort path.

Decision: One narrow readiness coordinator owns snapshot construction and evaluation. A failure from either operation produces the same privacy-safe `Unavailable` state, leaves the loaded project and prior processing contracts unchanged, exposes no exception prose, and adds no log. M0 must approve a deterministic dependency or fault-injection seam that activates both branches without a global switch, environment trigger, or production-only failure.

Because: The feature needs one testable failure boundary around all readiness evaluation work, not a partial catch after mapping has already succeeded. Publication, invalidation, refresh-command wiring, and rendering remain separate presentation paths.

Options considered:
- Coordinator catches mapper and evaluator failures: selected option, consistent and testable.
- Catch evaluator failures only: leaves an unowned fatal mapper path.
- Use the existing global exception path: observable, but can terminate the process and expose private exception text.

Consequences: Q-008 and U-014 close in M0 only after an ignored disposable probe demonstrates the seam design for both fault branches. M2 owns deterministic production composition and L4 owns loaded GUI outcome proof. `../Verification/SLICE-001/M2-INTEGRATION.md` now records the M2 result. If the seam needs a package, solution mapping, global flag, or broader harness scope, stop for another decision.

Revisit when: Readiness joins a typed application-wide nonfatal error boundary with equivalent privacy and activation evidence.

## D-037: M0 source-project-check pivot

Date: 2026-08-15
Status: Confirmed
Area: SLICE-001 M0 stop findings

Context: M0 found three source-backed contradictions in the approved brief. First, a pure post-open catalog cannot know the later `BeforeJobAdding` PowerShell and command result, live package status, free disk space, persisted job state, or output collisions. D-034 therefore forbids `Ready`. Second, the real `ProcessJob` source-open route can perform package, demux, metadata, muxer, and process work before `BeforeProcessing`, so current S-018 cannot run a successful production job path and also stop before all tool or output work. Third, every `FormBase` persists window placement, so the planned details form would add settings state. Evidence: `../Verification/SLICE-001/M0-AUTHORITY-STOP.md`, `../Verification/SLICE-001/M0-ACTIVATION-LIFECYCLE.md`, and `../Verification/SLICE-001/M0-UI-AND-VERIFICATION.md`.

Decision:

1. Rename the slice and feature to `Source project checks`. Replace overall `Ready` with `Selected checks passed`. The summary must state that Add Job and encode-time checks still run later. No result authorizes encoding.
2. Retain typed fact, warning, blocker, unknown, not-applicable, unavailable, and refresh-required behavior for only the approved pure catalog. Every accepted field still needs a complete invalidation owner.
3. Replace S-018 successful real-job runtime proof with the complete static caller map, a source-linked pure activation-policy test, and production checks at the mapped project-replacement and source-entry clear owners. Do not claim successful `ProcessJob` runtime equivalence. A later isolated tool-boundary approval owns that evidence.
4. Add a protected `FormBase.RememberPosition As Boolean = True` guard around existing position restore and save. Set it to `False` only in the new details form. Existing forms retain current persistence behavior; the new form writes no placement state.
5. Keep generated fixture bytes under an ignored isolated verification root. Track their manifest, generator recipe, byte length, SHA-256, generator identity, expected media facts, script engine, and template hash. Record that arbitrary generator builds may not reproduce identical bytes.

Because: This keeps a useful, truthful, accessible workflow summary without duplicating side-effecting encode authority, touching a real user queue, or silently persisting readiness state.

Options considered:

- Bounded source project checks: smallest safe continuation and the recommended choice.
- Build a shared side-effect-free encode preflight: preserves `Ready`, but must own packages, Assistant, disk policy, events, jobs, outputs, freshness, and every encode entry. It exceeds this first slice.
- Move the result to action time after existing Add Job gates: observes more authority, but is too late for the selected post-source correction loop and crosses persistence and event boundaries.
- Stop this direction and select another workflow slice: avoids a weaker success label but discards the mapped UI and pure-model work.

Consequences: D-030 and D-034 are Superseded. The Slice Brief central claim, S-016, S-017, and S-018 use the bounded contract in this entry. `../Verification/SLICE-001/M0-CATALOG.md` closes Q-001, Q-007, U-003, and U-012 for design with three pure checks and exact repository-owned invalidation owners. `../Verification/SLICE-001/M0-UI-PROBE.md` closes Q-002 for design. At confirmation time, Q-003 and U-004 still needed isolated runtime and measurements. The later reviewed v6 paired matrix closes both under `../Verification/SLICE-001/M0-RUNTIME-PLAN.md`. Completed M0 through M4 evidence is indexed at `../Verification/SLICE-001/README.md`. The `FormBase.RememberPosition` guard is approved only for preserving existing behavior and opting the new details form out of placement persistence.

Revisit when: A shared side-effect-free preflight with freshness tokens becomes the canonical authority for every Add Job and Start Encoding path.

## D-038: Additive Linux and macOS platform expansion

Date: 2026-08-16
Status: Confirmed
Area: ADD 1 through 4 and portability roadmap

Context: The user requested a Linux port now and a macOS port later. The architecture pass found that current StaxRip behavior is bound to .NET Framework WinForms, UI-owned global state, Windows process and registry APIs, BinaryFormatter persistence, and a COM frame server. Several important external tools have upstream Linux and macOS support, so an adapter-based port is feasible without replacing the current application first.

Decision: Preserve the supported Windows x64 application and add a separate cross-platform architecture. Target Linux x64 first. Target macOS after the Linux contracts and adapters are stable. Do not rewrite or migrate the Windows application as a prerequisite.

Because: An additive boundary gives the port a clean runtime and test surface while preserving current projects, settings, scripts, commands, and native behavior. Linux evidence can close the largest platform gaps before scarce macOS runtime and distribution work begins.

Options considered:
- Additive platform engine beside the current application: selected; preserves compatibility and permits small verified slices.
- Rewrite the complete application before shipping any Linux work: one codebase in theory, but too many unmapped persistence, process, UI, and native contracts at once.
- Run the Windows binary through Wine only: useful as a compatibility experiment, but not a Linux product architecture.

Consequences: D-006 is Superseded. The current supported application remains Windows x64 until a later release slice says otherwise. Platform support claims require real runtime evidence. `Docs/Architecture/Portability-System-Map.md` and `Docs/Architecture/Repo-Slices.md` own the staged boundary.

Revisit when: A verified portable contract cannot preserve a required Windows behavior, or user evidence changes the Linux-first order.

## D-039: Cross-platform engine and first clients

Date: 2026-08-16
Status: Confirmed
Area: ADD 4 and 8.1 through 8.3

Context: The user proposed a backend and web UI similar in operating shape to ComfyUI, alongside a future native GUI. The existing VB.NET WinForms application cannot run natively on Linux. The installed .NET 10 SDK can build a separate supported cross-platform host without changing the legacy project.

Decision: Add an isolated C# .NET 10 contracts, core, and local host subtree. Serve a first-party web shell as the first Linux client. Keep the API and core UI-neutral so the current WinForms app and a later native cross-platform client can become peers. Use the ComfyUI comparison only for local startup, browser access, visible work state, and extensibility boundaries; do not adopt arbitrary code nodes or a remote service.

Because: The server boundary exposes engine work early on Linux, supports deterministic contracts, and lets UI progress without putting workflow rules into another form layer. A separate subtree avoids a framework migration and leaves rollback as a bounded deletion.

Options considered:
- Local engine plus web shell, then native client: selected; fastest useful Linux surface and reusable contract.
- Native client first: better desktop integration, but delays proof of engine separation and makes UI framework choice an early dependency.
- Web-only replacement: smaller client count, but rejects the requested native-GUI direction and current Windows compatibility.
- Shared remote backend: enables multi-host control but adds authentication, TLS, privacy, operations, and cost outside current scope.

Consequences: D-008, D-009, and D-010 are Superseded. VB.NET, C++17, and PowerShell retain their current owners. C# owns only the new cross-platform subtree. The local host is an application boundary, not an Internet service. D-011 remains active; no database is added.

Revisit when: The capability and media-inspection slices reveal that the HTTP boundary cannot express required local workflows safely, or the native client needs a contract change.

## D-040: Local HTTP security boundary

Date: 2026-08-16
Status: Confirmed
Area: ADD 8.5 and SLICE-002

Context: A browser can issue requests to loopback services from an unrelated page. A local service that later reads media or starts encoders would act with the user's filesystem and process authority. Product accounts are not needed for a single-user offline host, but the browser-to-host edge still needs request authentication and cross-site controls.

Decision: Add no user account or remote authentication. Bind the first host to an unused IPv4 loopback port. Treat exactly the printed `http://127.0.0.1:<actual-port>` authority as valid. Establish a manual 256-bit process-local token through a per-instance HttpOnly SameSite cookie; do not use ASP.NET authentication or Data Protection. Require an exact first-party client header for API requests. Reject malformed, multiple, null, or mismatched Host and Origin values. Enable no CORS. Keep state-changing endpoints absent in SLICE-002.

Because: These controls make browser requests intentional without creating credentials, account recovery, a database, or a remote control plane. An HttpOnly cookie keeps the token out of URLs and JavaScript-readable storage.

Options considered:
- Process-local browser session and loopback checks: selected; bounded local protection without accounts.
- No session because the listener is loopback: simpler, but local cross-site requests remain an avoidable edge.
- Token in the startup URL: easy bootstrap, but URLs leak through history, logs, screenshots, and referrers.
- User accounts and TLS: needed for a future remote service, not for this local capability-only host.

Consequences: D-012 is Superseded. This session is not a user identity and grants no remote access. It protects the browser edge but does not defend against a hostile local process already running as the same user. Tokens, raw requests, paths, environment, commands, and exception text cannot enter logs or API output. Any LAN, remote, state-changing, upload, plugin, or multi-user capability requires a new threat model and approval.

Revisit when: A client cannot use the cookie model, a state-changing endpoint enters scope, or any listener leaves loopback.

## D-041: SLICE-002 build and artifact boundary

Date: 2026-08-16
Status: Confirmed
Area: ADD 8.8, 12, and 15

Context: The user explicitly authorized Linux build work alongside Windows work. The Windows host has .NET 10, and local WSL Ubuntu can execute a self-contained Linux artifact without a dependency install. The independent Ubuntu peer is online but currently refuses SSH. Existing build, package, and release scripts are protected and do not define this new artifact.

Decision: Approve `SLICE-002-LINUX-ENGINE-BOOTSTRAP.md` as the active additive portability build. Add a separate cross-platform solution under root-level `CrossPlatform/`. Build and test it on Windows, create an ignored self-contained local-test `linux-x64` publish output, and execute the exact output in WSL. Do not edit current solutions or projects, run protected package or release scripts, distribute a public artifact, publish media output, or claim Linux product support. Repeat the artifact on the independent Ubuntu host when P-007 is resolved.

Update 2026-08-17: The peer became reachable over Tailscale SSH and ran the artifact, passing 27 checks, though only while a host mitigation was temporarily relaxed and then restored; under its normal configuration the gate fails before the application starts. The blocker is now R-S2-039, an environment limitation, not access. The repeat instruction becomes: repeat the artifact on an independent host whose unprivileged user units can obtain a private network namespace. The context and decision above are preserved as written on the decision date; this dated note carries the later evidence, because a decision cannot be informed by evidence from the following day.

Because: This proves the runtime, HTTP, browser, and platform seams now while preserving every current Windows build and user-data boundary. Self-contained output avoids installing a Linux SDK or runtime solely for the test.

Options considered:
- Separate source and local-test artifact: selected; isolated and directly testable.
- Add new projects to `Source/StaxRip.sln`: easier discovery, but changes the protected current build graph before the port earns that coupling.
- Install a Linux SDK in WSL: workable, but unnecessary for the first runtime proof and not authorized as an automatic dependency change.
- Publish a preview release: faster feedback, but provenance, support, signing, update, branding, and rollback remain open.

Consequences: D-014 and D-016 are Superseded. Existing Windows build evidence remains distinct. The Linux output is a disposable local verification artifact below ignored paths. Public release remains blocked by U-001, U-006, U-009, and P-009.

Revisit when: The bootstrap passes WSL and independent-host gates and a media-inspection slice needs a repeatable contributor build or CI runner.

## D-042: Native desktop client posture

Date: 2026-08-16
Status: Confirmed
Area: Portability roadmap and S-PORT-08

Context: The user wants the backend and web shell alongside a main GUI port. .NET MAUI does not officially target Linux. Avalonia documents Windows, macOS, and Linux desktop support, but Linux display-server maturity, accessibility, packaging, and the StaxRip workflow fit need runtime evidence.

Decision: Preserve the WinForms client, build the web shell first, and keep a native cross-platform desktop client in the roadmap. Keep engine contracts UI-neutral. Treat Avalonia as the first candidate for a later representative-workflow prototype, not as a selected dependency today.

Because: A deferred framework choice keeps the Linux engine moving and prevents a UI toolkit from becoming the new rule authority before media inspection and workflow contracts exist.

Options considered:
- Web shell first with later Avalonia proof: selected; early Linux value and an evidence-based native decision.
- Avalonia immediately: possible, but adds display, accessibility, packaging, and design work before the engine can perform a useful media flow.
- .NET MAUI: official platform set does not include Linux.
- Keep only the web shell: simpler, but does not meet the requested long-term native-client direction.

Consequences: The bootstrap adds no desktop UI dependency. S-PORT-08 must verify one representative workflow on real Linux and Windows hosts before selection. macOS proof follows on actual macOS hardware.

Revisit when: Portable media inspection is stable enough to drive a representative accessible desktop workflow.

## D-043: Portability evidence and anti-dark-code feedback

Date: 2026-08-16
Status: Confirmed
Area: Verification and maintenance

Context: Porting exposes hidden operating-system, process, persistence, tool, native, and UI contracts. The user wants those lessons to improve the anti-dark-code workflow rather than remain one-off review notes.

Decision: Keep repository-specific portability invariants, gates, coverage, findings, and replay references in a calibrated local anti-dark-code skill. Record general lessons as upstream candidates with concrete StaxRip evidence. Do not copy product-specific paths or unproven rules into the shared skill automatically.

Because: Local calibration makes repeat work cheaper and more consistent. A reviewed candidate queue separates reusable workflow improvements from StaxRip-specific facts.

Options considered:
- Local calibration plus evidence-backed upstream candidates: selected; reusable and reviewable.
- Change only shared instructions: loses repository binding and risks overgeneralizing one codebase.
- Keep lessons only in PR prose: low setup cost, but difficult to replay or measure.

Consequences: SLICE-002 close-out includes calibrated gates and an upstream candidate review. Shared-skill changes remain a separate bounded edit with their own tests.

Revisit when: A candidate is reproduced in another repository or a shared-skill test can express the rule without StaxRip-specific assumptions.

## D-044: Isolated subtree and Linux runtime-pack restore

Date: 2026-08-16
Status: Confirmed
Area: SLICE-002 build preflight

Context: The adversarial pass found two build assumptions that needed correction. First, `Source/Build.ps1`, `Source/BuildAndPack.ps1`, and `Source/Release.ps1` recursively inspect selected files below `Source/`; a nested cross-platform solution or PowerShell script would enter the current build preflight. Second, the installed Windows SDK and NuGet cache do not contain Linux x64 .NET and ASP.NET Core runtime and host packs, while WSL has no .NET runtime.

Decision: Put the port in root-level `CrossPlatform/`, outside the current `Source/` build tree. Allow the approved Linux publish to restore only required Microsoft .NET 10 Linux x64 runtime and host packs from the scoped official NuGet source into ignored `CrossPlatform/artifacts/nuget/`. Require signed packages, map only `Microsoft.*` to the sole `nuget.org` source, pin the independently reviewed Microsoft author certificate fingerprint, and explicitly verify every retained archive against that fingerprint. Add no project `PackageReference`. Derive the final package closure from the exact five reviewed `project.assets.json` files and five matching `packages.lock.json` files, not from a package allowlist alone. Keep the NuGet registry `contentHash`, raw archive SHA-256 and SHA-512, signature identity, and extracted disk identity as separate fields. Record package ids, versions, source, five-project membership, exact download ranges, author fingerprint, verified archive count, and a canonical complete extracted disk inventory digest, count, and total bytes. Install no SDK or runtime into WSL or the operating system.

Because: The root-level subtree removes a verified legacy-build coupling. A repository-local pack cache makes the necessary cross-publish dependency visible, disposable, and separate from the user's global NuGet cache.

Options considered:
- Root subtree plus scoped repository-local runtime-pack restore: selected; smallest current-build and host-state impact.
- Keep the subtree below `Source/`: superficially tidy, but current build scripts inspect it.
- Install .NET in WSL: enables framework-dependent output, but changes the test host and adds an unnecessary system dependency.
- Call the publish offline or package-free: contradicted by the missing Linux runtime packs.

Consequences: The first uncached Linux publish uses the network and is not hermetic. The evaluated SLICE-002 closure is exactly `Microsoft.AspNetCore.App.Runtime.linux-x64`, `Microsoft.NETCore.App.Host.linux-x64`, and `Microsoft.NETCore.App.Runtime.linux-x64` at 10.0.11. The five reviewed asset files must expose only `net10.0` and `net10.0/linux-x64`, project-only transitive libraries, and those exact three `PackageDownload` ranges at `[10.0.11, 10.0.11]`; the five lock files must match that project-only policy. All three archives are retained in the ignored cache and pass Microsoft author signature verification against fingerprint `566A31882BE208BE4422F7CFD66ED09F5D4524A5994F50CCC8B05EC0528C1353`. Static checks allow only this closure and trust shape. Dependency schema v2 stores the distinct registry hash, raw archive digests and length, signature identity, archive-to-extraction binding, and canonical complete disk inventory SHA-256, file count, and total bytes. Canonical inventory rows sort ordinal relative paths and encode `path<TAB>decimal-length<TAB>lowercase-sha256<LF>` as UTF-8 without BOM. The final auditor recomputes the graph and disk inventory rather than trusting Restore's summary. A future signer, pack, project input, target, or inventory change fails closed and requires review; no alternate historical fingerprint is trusted in advance. `NuGetAudit=false` keeps this fixed restore surface deterministic, so the slice makes no vulnerability-audit claim. The cache and publish output stay ignored and can be removed without changing user or system state. Public artifact provenance remains unresolved under P-009.

Revisit when: The SDK feature band, reviewed project set, target or RID, pack version, source, package id, Microsoft signer, archive layout, or extracted-inventory contract changes; the build moves to a pinned runner image with the required packs already present; or public release work defines a stronger dependency mirror, audit, and provenance contract.

## D-045: S-PORT-02 inspection adapter and the first tool-execution authority

Date: 2026-08-18
Status: Confirmed. Ratified by the maintainer on 2026-08-18: MediaInfo CLI selected as
the primary portable authority, ffprobe JSON retained as the named backup.
Area: S-PORT-02 media inspection; P-003 process semantics; P-004 tool matrix, ffprobe row

Context: The fact-authority map (`../Architecture/Media-Inspection-Map.md`) established
that the current Windows application reads media facts from MediaInfo.dll at 135
literal-parameter call sites over 36 unique parameters, with user policy fused into the
stream getters, and consumes ffprobe only through a regex over its human-readable stderr
banner invoked with a string-interpolated command line. The agreed-facts list
(`../Architecture/Media-Inspection-Agreed-Facts.md`) defines the exposed fact set,
canonicalization, and accepted divergences. The portable bootstrap currently starts no
external tool by verified design; S-PORT-02 is the slice whose scope includes FFprobe
execution, bounded progress, and cancellation.

Decision: Adopt the MediaInfo CLI with `--Output=JSON`, out of process, as the sole
implemented portable fact authority for S-PORT-02, under the execution bounds below,
which are tool-agnostic. The maintainer selected it over the drafted ffprobe
recommendation for near-zero naming divergence against the 36 Windows facts, making the
comparison corpus same-authority-both-sides. ffprobe JSON is the named backup, with a
precise meaning: it is not implemented in version 1, no dual-authority code ships, and
it activates only when one of three triggers fires: a required fact MediaInfo cannot
supply; a MediaInfo version or schema break that the pinned range cannot absorb; or the
arrival of the ffmpeg family in an encoding slice, at which point ffprobe becomes the
second authority for cross-checking rather than a replacement. The adapter contract must
keep the authority swappable behind the typed fact payload, so a backup activation
changes the adapter, not the API. Because the CLI JSON serializes display fields, the
existing privacy rule is load-bearing at the adapter boundary: `UniqueID`,
`Encoded_Library_Settings`, and equivalent identifier fields are stripped before any
payload leaves the adapter, and a self-test proves the stripping the same way the
SLICE-002 redaction guards do.
Retain MediaInfo on Windows unchanged, as comparison baseline only. Do not port the
banner regex, the string-interpolated invocation, the policy fusion, the silent
defaults, or the identifier synthesis; each is recorded in the agreed-facts list as an
accepted divergence or a deliberate non-port. Grant the portable server its first
external-process authority under these bounds: the executable is resolved from an
explicit configured path against the P-004 ffprobe version matrix, never from PATH
search; arguments are an argv vector with the media path as a single argument, never an
interpolated string; the child runs with bounded captured output, a hard timeout, and
kill-on-cancel with process-group termination; readiness of the feature is reported
through the existing capability contract and remains `unavailable` until the resolver,
matrix row, and gates exist; no file is written, no network is touched, and the API
surface stays read-only behind the existing session model.

Because: Out-of-process probing keeps an untrusted-media parser outside the server
process, the JSON interface is the machine contract the current code never adopted, and
a single external tool with a pinned version range is the smallest possible first
execution authority, matching the P-004 plan that already names FFprobe first.

Options considered:
- ffprobe JSON with MediaInfo comparison baseline: recommended; schema engineered as a
  machine API, aligns with the ffmpeg-family stack the encoding slices will need anyway,
  honest divergence ledger.
- MediaInfo CLI with JSON output, out of process: the named alternate, viable on every
  target platform per the upstream download matrix the maintainer cited. Same trust
  boundary as ffprobe, near-zero naming divergence against the 36 Windows facts, so the
  comparison corpus becomes same-authority-both-sides. Costs: its JSON is a serialization
  of display fields whose names shift more between versions than ffprobe's API schema,
  it emits `UniqueID`-class identifiers that the existing privacy rule must filter, and
  it adds a second tool family to the version matrix before the first one lands.
- Port a MediaInfo binding in process: parameter parity, but moves an untrusted-media
  native parser into the server process; dominated by the CLI option and rejected.
- Both authorities on both platforms: maximal comparability, double the surface and the
  version matrix before a single fact ships.
- Defer execution and expose only Windows-imported facts over HTTP: no new authority,
  but the Linux server would present facts it cannot produce, which misstates capability.

Consequences: The portable server gains a process-execution boundary that did not exist,
and every SLICE-002 claim of the form "starts no external tool" becomes scoped to the
tested workload of that slice rather than the server forever; the affected sentences in
the SLICE-002 records stay true as written because they describe that slice's verified
workload. The exit criteria of S-PORT-02 bind the new boundary: golden argv and output
fixtures, hostile-path and malformed-output corpora, cancellation leaving no process, and
a Windows comparison recording agreed facts. The verification harness gains a
port-inspection gate before any UI presents a fact. R-S2-039 is unaffected; inspection
runs in the ordinary server sandbox that already passes.

Revisit when: The selected tool's version range or JSON schema changes; a fact is
needed that the selected authority cannot supply and the other can; the
execution framework generalizes beyond one tool; or encoding slices need write authority,
which this decision does not grant.

## D-046: Path acceptance policy for read-only inspection

Date: 2026-08-18
Status: Confirmed. Ratified by the maintainer on 2026-08-19 together with tool
acquisition approval for the comparison harness and the range-first resolution of the
version skew: pin `[24.01, 26.05]` and prove schema stability with fixtures from both
ends before considering the upstream-parity alternative.
Area: S-PORT-02 media inspection; the server's request boundary

Context: The bootstrap's confirmed security rules include that the server accepts no
user path, upload, or URL. Read-only inspection cannot exist without accepting a path to
inspect, so S-PORT-02 must replace that rule with a deliberate policy rather than erode
it through an exception. This is the slice's real new attack surface: a local page that
defeats the session model, or a confused client, must not be able to turn the inspector
into a filesystem probe.

Decision: Accept a path only under all of the following. The server holds a
maintainer-configured list of media root directories, empty by default, so a fresh
install inspects nothing. A request path must be absolute, must canonicalize with all
symbolic links resolved to a location strictly inside one configured root, must be a
regular file, and must survive the same reparse-point and canonical-path checks the
verification harness already applies to its own trees. Device paths, UNC paths on
Windows, alternate data streams, and any path whose canonical form differs from its
requested form in a way that crosses a root boundary are rejected before the tool
resolver is consulted. Rejections return the typed error class only, never an existence
oracle: the same response shape for missing, denied, and outside-root, so the endpoint
cannot be used to enumerate the filesystem. The probe list, the roots, and every
rejection reason class are recorded in the capability payload so the shell can explain
itself without a second channel.

Amendment, 2026-08-21, adopted with the certification repair on the maintainer's
instruction: the capability payload carries availability and a reason code only, and
deliberately does not carry the configured roots, the probe list, or rejection reason
classes. Publishing absolute filesystem roots through the capability endpoint would
put operator paths on the wire the payload otherwise keeps clean, for a
diagnosability gain the operator already has by knowing their own configuration. The
sentence above requiring roots in the payload is superseded; the shell renders the
availability state honestly and explains configuration in operator terms, not path
terms. A privacy-bounded representation can be revisited if a native shell ever needs
machine-readable roots.

Because: A roots allowlist with canonical containment is the smallest policy that makes
the inspector useful and keeps it from becoming a read oracle over the whole disk. The
uniform rejection shape spends a little diagnosability to avoid building a filesystem
enumeration primitive into a loopback service.

Options considered:
- Configured roots with canonical containment and uniform rejection: selected.
- Accept any absolute path the OS user can read: matches the desktop application's
  authority, but the desktop app does not sit behind a browser session on a loopback
  socket; a session compromise would inherit whole-disk read reach.
- File-picker tokens minted by a future native shell: strongest containment, but there
  is no native shell yet and inspection should not wait for one.
- Per-request maintainer confirmation: safest, unusable for the first real workflow.

Consequences: A configuration surface is added, and configuration is state; the roots
list lives in memory for version 1, supplied at startup, persisted nowhere, so the
no-persistence claim of the bootstrap survives. The uniform rejection shape means a user
who mistypes a path inside a root gets the same answer as one probing outside it; the
shell compensates by showing the configured roots. The hostile-path corpus in the
adapter contract's gate plan is the enforcement evidence, and the no-process check on
rejection is what proves the policy runs before the resolver.

Revisit when: A native shell exists and can mint scoped tokens; multi-user or remote
access ever enters scope, which reopens the whole threat model; or persistence of
configuration is approved, which moves the roots list into a recorded, migratable
format.

## D-047: Corpus growth needs a fixture-authoring tool, and that needs approval

Date: 2026-08-21. Status: CONFIRMED, ratified by the maintainer 2026-08-21. Owner: P-004.

Context: The S-PORT-02 exit review left three agreed facts unexposed, recorded as
blocked by the fixture-first rule: chapters, subtitle commentary and hearing-impaired,
and subtitle stream size. An investigation established that the record's reason is
right for two of them and wrong for the third pair. Chapters and subtitle stream size
are genuinely blocked by fixture absence: both carriers are present and range-stable,
chapters as `Menu` track `extra` members named on an `_HH_MM_SS_mmm` grammar, subtitle
stream size as `Text/StreamSize`. Commentary and hearing-impaired are blocked by range
instability instead, recorded as P-012.

The remaining blocker for the first pair is not knowledge; it is authority. Committing
a fixture that carries chapters and subtitles means running a muxing tool to author
bytes that enter the repository, and the tool matrix's own rule is that no tool gains a
row until a slice needs it and a decision names it. The existing corpus was authored
the same way, under the maintainer's tool-acquisition approval recorded in the fixture
manifest, and its producing tool was never named, which is why the four committed
fixtures have no recorded recipe today.

Decision, ratified: one named fixture-authoring tool, recorded in the tool
matrix with its path, version, and SHA-256, used only to author committed fixtures and
never to run inside the product or a gate. The measured candidate is the ffmpeg build
bundled with the installed Windows product tree, identified because every committed
golden carries the writing-application string that build emits, which makes it the
authoring identity the existing corpus already has.

Because: fixture authoring is a provenance act. A committed fixture is an input to
every golden, every test, and every comparison, so the tool that produced it belongs in
the same matrix as the tool that reads it, at the same confidence bar.

What approval unlocks, in one unit: a tracked, re-runnable recipe script pinned to the
tool hash, producing byte-reproducible fixtures under bit-exact flags, verified by
running it twice and comparing hashes; two new fixtures carrying chapters, subtitle
tracks, and subtitle stream size; four new goldens at both range ends; the agreed-facts
list amended first to name the real chapter carrier, per its own extension rule; then
the payload, normalizer, tests, pins, mutation proofs, and a sweep.

Options considered:
- Approve the bundled product ffmpeg as the named authoring tool: recommended. It is
  already the corpus's de facto authoring identity, it needs no download, and bit-exact
  flags make its output reproducible, which the current corpus is not.
- Approve a separately acquired ffmpeg pinned in the artifacts tools tree: cleaner
  provenance boundary, but a new download and a new acquisition approval for a tool
  that is already present.
- Use the bundled MKVToolNix instead: rejected on measurement. Its output is not
  reproducible; two runs of the same command produced different bytes because it writes
  a random segment identifier and a wall-clock date.
- Ship the facts without a carrying fixture: refused by the fixture-first rule.
- Leave the corpus as it is: the three facts stay unexposed and the delta stays
  recorded, which is honest but permanent.

Consequences: the tool matrix gains an authoring row, a class it does not have today,
and the distinction between an authority that reads and a tool that authors becomes
explicit in it. The new fixtures would be the first with a recorded, re-runnable
recipe; the original four remain unreproducible, which the manifest must say plainly
rather than implying the whole corpus is recipe-reproducible.

Revisit when: the range floor moves, which would reopen the commentary and
hearing-impaired facts; or a container family outside the current three is needed.

## D-048: The subtitle disposition facts stay deferred, and the deferral is enforced

Date: 2026-08-22. Status: CONFIRMED. Owner: P-004. Closes unknown P-012.

Context: The agreed-facts list carries a subtitle row for commentary and hearing
impaired. Measurement established that the CLI carrier is `ServiceKind`, with values
`C` and `HI`, that the range ceiling reports it, and that the range floor does not
report it at all. The exit review had recorded these two facts as blocked by the
fixture-first rule; that was wrong, and a committed fixture now carries both
dispositions, so the blocker is visible in the corpus rather than only in prose.

Decision: the two facts stay out of version 1 of the payload, and the pinned range
stays `[24.01, 26.05]`. The deferral is enforced by a test rather than by a note:
CT-045 asserts, from the committed goldens, that the ceiling reports the carrier and
the floor does not, and that no disposition member reaches the payload. When the floor
moves to a version that reports the carrier, that case goes red and names this
decision, so the exclusion cannot quietly outlive its reason.

Because: exposing a fact that exists at one end of a supported range and not the other
would make the payload's own range-stability claim false, and the payload's stability
assertion compares whole sections, so the field would fail the comparison by
construction. Moving the floor to reach two display flags would invalidate every
committed floor golden, require re-capture on two hosts, and acquire a new tool under
the acquisition gate, all for facts no consumer has asked for yet. The cost is
disproportionate to the benefit today, and the tripwire makes the deferral cheap to
revisit.

Options considered:
- Defer both facts and enforce the deferral with a range tripwire: selected.
- Move the range floor to a version reporting `ServiceKind`: rejected today on cost.
  It reopens tool acquisition, invalidates four floor goldens, and re-runs the
  independent-host capture, for two flags with no consumer.
- Expose the facts as ceiling-only, absent at the floor: rejected. It publishes a
  field whose presence depends on which supported tool version answered, which is the
  silent-variability class the payload exists to prevent.
- Read the Windows wrapper's `Commentary` and `HearingImpaired` parameter names:
  rejected on measurement. Neither name exists in the pinned ceiling's own parameter
  enumeration; the wrapper reads them through a different interface.

Consequences: the exposed set trails the agreed tables by exactly this pair, recorded
in the verification record and in the agreed-facts row itself. The committed fixture
carries the dispositions permanently, so the day the floor moves the evidence is
already in the corpus and the work is a normalizer read plus two members.

Revisit when: CT-045 turns red, which is the floor gaining the carrier; or a consumer
needs the facts, which would justify the floor move on its own merits.

## D-049: The tool matrix gets tiers, and the bottom tier may not be executed

Date: 2026-08-22. Status: CONFIRMED, ratified by the maintainer 2026-08-22. Owner:
P-004. Binding on S-PORT-04.

Context: the tool matrix carries one rule for every tool: no row until a slice needs it
and a decision names it, with path, version, SHA-256, fixture, failure-path result, both
range ends, and an independent-host capture. That bar is right, and it is expensive.
Two tools have crossed it. D-045 took a full slice for MediaInfo CLI. D-047 took a
second approval cycle for a tool that only authors fixture bytes and never runs.

The legacy catalogue is larger than that bar can absorb. Measured in
`Source/General/Package.vb` on 2026-08-22, 3547 lines declaring exactly two classes,
`Package` and `PluginPackage`:

- 299 catalogue entries: 62 `New Package` and 237 `New PluginPackage`.
- Two registration forms. 145 entries are `Shared Property <Name> As ... = Add(New ...)`,
  reachable by name. 154 are a bare `Add(New ...)` statement inside the single
  `Shared Sub New` at line 1441, spanning lines 1442 to 2724, reachable only through the
  dictionary. 145 plus 154 accounts for all 299.
- Both forms land in `Items`, a `SortedDictionary(Of String, Package)` declared at line
  45, keyed by `pack.ID`, through `Add` at line 2741.
- Two entries bind a location to a Windows registry read at declaration: line 88 reads
  the Haali muxer CLSID `InprocServer32`, line 465 reads MPC-BE `ExePath`. Separately,
  the resolver has registry-backed discovery that applies catalogue-wide at lines 3209
  to 3417, covering the Python install path, `MuiCache`, and
  `Applications\<file>\shell\open\command`.

The enumeration split is the fact that matters for porting. A port that walks named
properties reaches 145 of 299, just under half, and would report a catalogue that looks
complete and is not. The only complete enumeration is `Items`, and populating `Items`
means running the shared constructor.

Decision: the matrix gains three tiers, distinguished by what claim a row makes.

- **Tier A, execution authority.** Any tool the portable side launches. The current bar,
  unchanged: named in a decision, full row, fixture, failure path, both range ends,
  independent-host capture. Today: MediaInfo CLI.
- **Tier B, authoring.** Produces committed bytes, never runs in the product or a gate.
  Row with path, version, SHA-256, and a re-runnable recipe. No support matrix, no range
  capture, because there is no runtime claim to support. Today: ffmpeg.
- **Tier C, catalogue record.** A legacy entry carried across as data. Records id,
  filename, kind, declared location strategy, and a portability verdict read from the
  declaration. It makes no claim that the tool exists, runs, is available, or is
  compatible on any platform.

**Amended 2026-08-22, same day, before any implementation.** The Tier C schema above says
`filename`, singular, and that is wrong. The upstream availability survey established that
the same tool ships under different executable names per platform: the three rigaya
hardware encoders are `NVEncC64.exe`, `QSVEncC64.exe`, and `VCEEncC64.exe` on Windows and
`nvencc`, `qsvencc`, and `vceencc` on Linux. A record carrying one filename would search
for the Windows name on Linux and report a correctly installed tool as absent, which is a
false negative produced by the schema rather than by the lookup. Tier C therefore records
a filename **per platform**, with the legacy value as the Windows entry and other
platforms absent until evidence fills them. Absent stays absent; it is never defaulted to
the Windows name, because that is precisely the failure being corrected. The survey is in
`Docs/Architecture/Linux-Tool-Availability.md`, section 5.

The load-bearing rule is that a Tier C entry may not be invoked, and that is enforced by
mechanism rather than by prose. The portable process boundary already refuses any
executable path that is not absolute and resolvable, and a Tier C entry has no approved
path to give it; the catalogue payload carries availability and reason only, never a
root and never an executable, which is the rule D-046 was amended to on 2026-08-21.
Promotion from C to A is one decision per tool, on demand, at the Tier A bar.

This decision does not touch tool acquisition. Downloading, installing, or updating any
tool stays fully approval-gated at every tier, per `AGENTS.md`. Tier C describes entries
already declared in committed legacy source; it is not permission to fetch anything.

Because: the single bar conflates three different claims. "We run this" needs the full
bar. "This made our fixtures" needs provenance and reproducibility but no support
matrix. "This appears in a menu" needs a record and nothing else. Charging all three the
same price means either 299 approval cycles, which is not a plan, or an unwritten
exception that lets a menu entry quietly become an execution path, which is the outcome
the matrix exists to prevent.

Options considered:
- Three tiers with a mechanically enforced no-invoke boundary: selected. The boundary
  reuses a constraint the process primitive already enforces, so it costs an assertion
  rather than a new mechanism.
- Keep one bar for all 299: rejected on measured cost. Two tools took two full cycles.
- Port the 62 executables at the full bar and drop the 237 plugins: rejected. Plugins
  are what the script generator names, so dropping them changes product behavior, and
  237 entries still exceed the budget by a wide margin.
- Port the 145 named entries and skip the 154 anonymous ones: rejected on measurement.
  It silently loses 51 percent of the catalogue, and the split reflects VB declaration
  style, not importance.
- Defer until S-PORT-04: rejected. The catalogue's shape constrains the portable project
  model's schema, and that is S-PORT-03, the next slice.

Consequences: the matrix gains a tier column, and every "does the port support tool X"
question gains a defined answer path, which is Tier C until a decision promotes it. The
299-entry catalogue becomes portable data carrying no support claims, which is both
honest and cheap. The risk is that Tier C's honesty depends on the no-invoke rule being
asserted rather than merely stated, so S-PORT-04 owes a gate assertion that no Tier C
record can reach the process boundary; until that assertion exists, the boundary is
inferred from the resolver's absolute-path rule, not verified for this purpose.

Revisit when: a Tier C entry needs to run, which is a promotion decision; or the
catalogue gains a runtime availability probe, which would give Tier C a claim it does
not have today and would need its own decision.

## D-050: VapourSynth is the Linux filtering path, and AviSynth+ is the expensive tail

Date: 2026-08-22. Status: **CONFIRMED**, ratified by the maintainer 2026-08-22. Owner:
P-004 and P-005. Binds S-PORT-05 onward.

This one was not mine to confirm. It chooses which half of the product's filtering surface
gets carried to Linux first, and it is visible to users as which filters work, so it was
written as a recommendation with its evidence and held as PROPOSED until ratified.

Context: the portable side has to pick an order for frameserver work, and the two
frameservers looked interchangeable from inside this repository. They are not, and the
difference is large enough to change the plan. Measurements, all dated 2026-08-22 and
recorded with sources in `Docs/Architecture/Linux-Tool-Availability.md`:

Our own catalogue, classified by which frameserver's filter names each entry declares:

- 132 entries declare AviSynth filter names only.
- 91 declare VapourSynth filter names only.
- 13 declare both.
- 63 declare neither, being executables, runtimes, and support entries.
- 26 entries additionally declare `.Dependencies`, pulling in further plugins by name.

So 145 entries expose AviSynth filters and 104 expose VapourSynth filters. On entry count
alone AviSynth looks like the bigger prize. On availability it is the opposite:

| | AviSynth+ | VapourSynth |
|---|---|---|
| Upstream Linux binary for the frameserver | None. Source build only | `pip install`, glibc and musl, x86-64 and aarch64, including `vspipe` and the SDK |
| In Debian, Ubuntu, Fedora | No | Core in Fedora; Debian and Ubuntu carry nothing |
| Plugin ABI | C++ vtable, crosses the MSVC-against-Itanium boundary | Plain versioned C ABI, platform-neutral by construction |
| Plugins with a published Linux binary | Effectively none. One project in a roughly 160-repository survey | About 40 percent in the platform-keyed index, about 93 percent of native projects on PyPI, a combined floor near 56 percent |
| Per-plugin Linux availability index | None exists, searched for | `vspackages3.zip`, platform-keyed, 254 KB |
| Linux packaging channel | 49 AUR source recipes, essentially one maintainer, most untouched since 2023 | PyPI, plus a build project covering 76 plugins |

Proposed decision: **VapourSynth is the portable side's first-class filtering path.**
AviSynth+ support on Linux is neither dropped nor promised; it is sequenced behind, and
each AviSynth plugin that matters is promoted individually with its own evidence, in the
same way Tier C entries are promoted under D-049.

Because: the two ecosystems differ by roughly an order of magnitude in how much work a
Linux user's filter graph requires, and that difference is in release engineering rather
than in capability, so it is not something this project can fix by trying harder. Choosing
VapourSynth first buys most of the filtering surface for close to the cost of a package
install. Choosing AviSynth first means building most of a plugin ecosystem from source
before a single filter runs, and inheriting four families that are architecturally
blocked rather than merely unported.

Options considered:
- VapourSynth first, AviSynth+ promoted per plugin: recommended, for the reasons above.
- Both at once: rejected on cost. It doubles the plugin surface at the moment the port
  can least afford it, and the AviSynth half has no index to plan against.
- AviSynth+ first, because 145 entries is more than 104: rejected on measurement. Entry
  count is the wrong metric when the two counts sit on ecosystems with such different
  availability; it measures what the legacy app offers, not what a Linux user could run.
- Drop AviSynth+ on Linux entirely: rejected. It is a larger promise than the evidence
  supports, the frameserver itself does build and is packaged by several distributions,
  the repository already vendors `Source/FrameServer/avs/posix.h`, and roughly two-thirds
  of sampled plugins do build from source. The problem is published binaries, not
  feasibility, and that can change.

Consequences if ratified: the portable filter surface starts at roughly the 104
VapourSynth-declaring entries rather than all 249, and the gap is visible and recorded
rather than discovered by users. Plugin availability becomes a lookup against an existing
index instead of a survey this project maintains. The AviSynth tail stays enumerated, so
"not yet" never quietly becomes "never".

Risks recorded with it: of the plugins the index reports as Linux-capable, 78 of 82 get
their binaries from a single volunteer build project, so that 40 percent figure is closer
to one upstream than to 82. The PyPI channel is more distributed and should be preferred
where both exist. Neither number should be treated as a stable platform property without
re-measuring.

**Foundation verified by execution, 2026-08-22.** This decision rested on documentation, so
the load-bearing claim was executed on the T540p rather than left cited. `pip install
vapoursynth` on bare-metal Ubuntu 24.04.4 with Python 3.12.3, no root, installed R79 from a
manylinux wheel carrying `libvapoursynth.so.4`, `libvsscript.so`, the filter libraries,
the Python module, all three SDK headers, `pkgconfig`, and `vspipe`, at 25 MB total. The
distribution claim holds. One correction: `vspipe` ships but is not immediately runnable,
failing until a documented one-time `vapoursynth config` writes a per-user TOML naming the
interpreter and libpython path. Delivery and readiness are different things and the survey
conflated them; an automated Linux setup needs both steps. Details in
`Docs/Architecture/Linux-Tool-Availability.md` section 3.

Revisit when: the AviSynth+ plugin ecosystem starts publishing Linux binaries, which one
pilot project is now doing; or a specific AviSynth-only filter becomes load-bearing for a
shipped feature, which is a promotion decision rather than a reversal of this one.

## D-051: Upstream contribution comes before recreation, and recipes ship before binaries

Date: 2026-08-22. Status: CONFIRMED, ratified by the maintainer 2026-08-22. Owner: P-004.
Depends on D-049 and D-050.

Context: the Linux tool survey established that most of what the port needs already
exists, and that the gap is release engineering rather than capability. Several plugin
projects build Linux artifacts in continuous integration on every change and attach none
of them to their releases, so the artifacts exist, are current, and are invisible to
anyone looking at a release page. That reframes the question from "what must we build" to
"what must we publish, and who should publish it".

The measured position, from `Docs/Architecture/Linux-Tool-Availability.md` and a join of
the catalogue against the published VapourSynth index on 2026-08-22:

- 27 of 33 named tools need no recreation, shipping upstream Linux binaries or sitting in
  distribution repositories.
- Of 168 catalogue `.dll` entries, 93 appear in the index by filename and 59 already have
  a Linux binary. 34 are Windows-only there and 75 are not indexed at all, the latter
  being mostly the AviSynth side, which the index does not cover. The 59 is a floor,
  because several of the 34 publish wheels the index has not picked up.

Decision, in four parts.

**One: do not fork upstream tools.** Anything an upstream maintains is pinned, never
vendored. A fork is a permanent maintenance liability, and the survey found upstream
health to be good in most cases. Forking is reconsidered only when an upstream is
demonstrably dead and the tool is load-bearing, which is a separate decision each time.

**Two: spend the first effort upstream, not on our own infrastructure.** Where a project
already builds a Linux artifact and does not publish it, the contribution is a small
change to its release workflow. That is cheaper than operating a build farm, it benefits
every consumer of that plugin rather than only this project, and it reduces the
concentration risk recorded in the survey, where 78 of 82 index packages with Linux
binaries come from one volunteer's project. Standing up a second single-maintainer farm
would reproduce that fragility rather than repair it.

**Three: recipes are public by default, binaries are per-tool and gated.** Publishing a
build recipe is publishing a script. Publishing a binary is redistribution, and
redistribution is where tool licences bind. This repository is MIT, which imposes nothing
on us, but the tools are not ours to relicense:

- fdkaac depends on non-free `libfdk-aac`, which is why Debian ships it in contrib. No
  binary publication.
- DEE is marked confidential to Dolby licensees. No publication of any kind.
- vvenc is Clear-BSD, which grants no patent rights, over a patent-encumbered codec.
  Legal review before any binary publication.
- x264 and x265 are GPL. Publishing binaries carries the corresponding source obligation.

Anything published carries the same provenance discipline as a tool-matrix row: pinned
upstream commit, recorded build, and SHA-256. A public artifact without provenance is
worse than no artifact, because it invites trust it has not earned.

**Four: upstream contributions disclose honestly and follow each project's policy.**
Before opening a pull request, read that project's `CONTRIBUTING.md` and any developer
certificate of origin requirement, and record which applies. A sign-off is an attestation
about the origin of the work, so it is made truthfully or not at all. Where a project has
a policy on tool-assisted contributions, that policy is followed as written; where a
project asks, the answer is honest; and where a policy rules us out, we do not contribute
there and build the recipe ourselves instead. Contributions are written in the project's
own conventions rather than this repository's, which means this repository's commit
trailers do not travel upstream, because they describe this repository's practice and
would be inaccurate elsewhere.

Because: the port's dependency on these ecosystems is long-lived, and it is a relationship
rather than a transaction. Every upstream that publishes a Linux artifact because we asked
is a dependency we no longer carry. Every maintainer who finds a contribution was
submitted under a false account of its origin is a dependency we have damaged, and the
damage lands on the whole effort rather than on one pull request. The technical case and
the honest case point the same way here, which is the ordinary situation and worth
recording as such.

Options considered:
- Fork what we need and maintain it: rejected. Permanent cost, no upstream benefit, and
  the survey shows most upstreams are healthy enough not to need it.
- Build a StaxRip-specific Linux artifact farm first: rejected as a first move. It
  duplicates existing infrastructure and recreates a known single point of failure. It
  remains the fallback for projects that cannot or will not publish.
- Publish binaries broadly for user convenience: rejected as a default. It is a
  redistribution act with per-tool licence consequences, at least two of which are hard
  prohibitions.
- Contribute without regard to project policy: rejected.

Consequences: the recreation list is much shorter than the catalogue size suggests, and
what remains is mostly recipes rather than code. A separate public recipes repository is
justified when the first recipe lands, kept outside the application repository because its
licence surface, build matrix, and release cadence all differ, and because being useful to
people who do not use this application is what would attract the co-maintainers the
existing farm lacks. That repository's creation is itself a distribution decision and
needs its own approval under `AGENTS.md`.

Revisit when: a load-bearing upstream goes dead, which reopens the forking question; or a
binary publication case arises that the licence analysis above does not cover.

## D-052: A server that closes a connection must say so

Date: 2026-08-22. Status: **CONFIRMED**, ratified by the maintainer 2026-08-22 and
implemented the same day. Owner: P-015. Approval-gated because it changes response headers
on the loopback HTTP endpoint, which is why it was held as PROPOSED until ratified.

Implemented in `CrossPlatform/src/StaxRip.Server/ServerApp.cs`, in the rejection path of
the request-law middleware. The header is set only when the rejected request declared a
body, and the predicate is `LoopbackRequestPolicy.IsBodyless`, the policy's own, so this
rule cannot drift from the law that decides whether a body is present.

Result, measured identically before and after, against a server started outside the gate:

| Measurement | Before | After |
|---|---|---|
| Oversized-then-chunked pairs, 200 | 198 clean, 1 SocketException, 1 HttpIOException | 200 clean, 0 failures |
| Chunked alone, 200 | 200 clean | 200 clean |
| Control with declared length, 200 | 200 clean | 200 clean |
| `Connection` on the two body-refusal 400s | absent | `close` |
| `Connection` on the 401 control | absent | absent, correctly, that body was accepted |

The gate then passed six consecutive runs, having previously failed about a third of the
time. Its check count rose from 5182 to 5196, which is the gate verifying a header that did
not exist before rather than new coverage appearing from nowhere.

Not yet done, and recorded so it is not forgotten: there is no regression guard. The fix is
proven by measurement but nothing fails if the header is removed again. A gate assertion
naming this header on a body-refusal response is owed, and until it exists this fix is
protected only by the intermittent failure returning.

Context: P-015 recorded an intermittent failure of the `port-http-windows` gate as an
`HttpIOException` with no status. Instrumentation identified the failing request, and
controlled measurement against a server started outside the gate identified the mechanism.
The chunked request the failure lands on is not the defect; it is the victim.

Measured on 2026-08-22:

- The chunked request alone, 60 times on one client: 60 clean HTTP 400s, no failures.
- The gate's real sequence, an oversized 1111-byte body followed immediately by the
  chunked request on the same client, 60 pairs: 59 clean, 1 `HttpIOException`.
- On every refusal path, the `Connection` response header is absent, over HTTP/1.1.

The server closes the connection after refusing a request body and does not announce the
close. A conforming client is entitled to treat the connection as reusable, pools it, and
sends the next request on it, which then races the close. Because POST is not idempotent,
a correct client will not silently retry, so the race reaches the caller as an I/O error.
Every conforming client is exposed to this, browsers included. The gate was not flaky; it
was reporting a real protocol defect, intermittently, because the defect is a race.

Proposed decision: on any response where the server will close the connection, send
`Connection: close`. In practice this is the body-refusal paths on the media-facts route,
and the rule is stated generally because the next such path should inherit it rather than
rediscover this.

Because: HTTP/1.1 connection reuse is a contract between both ends. A server that intends
to close and stays silent has not ended the exchange, it has left the client holding a
connection it reasonably believes is alive. The fix is to make the intent explicit, which
removes the race by construction rather than by timing. Nothing else in the request law
changes: chunked stays refused, the 1024-byte cap stays, and the status codes stay.

Options considered:
- Announce the close on refusal paths: recommended. It is the smallest change that makes
  a client's pooling decision correct, and it fixes every client rather than one caller.
- Drain the refused body and keep the connection alive: rejected. It would mean reading a
  body the endpoint has already decided to refuse, which is the opposite of a bounded
  read and reintroduces the exposure the 1024-byte cap exists to prevent.
- Accept the reset as a valid outcome in the gate: rejected. It converts a found defect
  into a suppressed one, and it would leave real clients hitting the same race with no
  record of why.
- Have the gate use a fresh connection per request: rejected. It hides the defect behind
  a test-only workaround and removes the gate's ability to notice connection reuse bugs
  at all, which is coverage worth keeping.

Consequences: one header on refusal responses. Connection reuse after a refusal is
deliberately given up, which is the correct trade because the alternative is an
unpredictable connection state. The gate should stop failing intermittently, and that is
a consequence rather than the goal.

Verification, before and after, already built: the paired oversized-then-chunked loop that
reproduced this outside the harness must show a nonzero failure rate before the change and
zero after, over enough pairs to be meaningful against a 1-in-60 base rate. A fix that
cannot be shown to move that number has not been demonstrated to work.

Revisit when: another endpoint gains a refusal path, which inherits this rule; or the
transport moves to HTTP/2, where connection semantics differ and this rule needs restating
rather than assuming.

## D-053: The clone helper is the first BinaryFormatter to replace, and it is not the easy one

Date: 2026-08-22. Status: **CONFIRMED**, ratified by the maintainer 2026-08-23. Owner:
P-002. Approval-gated: it changes `Source/` behavior across 85 call sites.

**The blocker is resolved, and it was far smaller than this entry claimed.** The entry said
a differential harness needed a host the application's static graph would tolerate, and
implied that was architectural. It is not. `Package`'s initializer fails only because
`Folder.Startup` resolves to `Application.StartupPath`, the **host** process's directory,
so it hunts for StaxRip's asset tree beside the wrong executable. Two further facts settle
it: `StaxRip.Folder` and `StaxRip.ObjectHelp` initialize cleanly in a foreign host, and
the clone path never needs `Package` at all. Pointing `Folder.StartupValue` at a scratch
directory is enough, and pointing it at a real installation is the wrong fix, which is how
P-016 was discovered.

**One constraint the entry did not anticipate:** the harness must run on .NET Framework.
`BinaryFormatter` is removed from modern .NET and throws `PlatformNotSupportedException`
there, so the reference implementation cannot execute under pwsh 7. Windows PowerShell 5.1
is Framework 4.8 and runs both sides. That removal is also first-hand confirmation of why
this decision exists, rather than a citation.

**The design is proven before entering the tree.** A reflection-based copier written to the
six behaviors was tested against a graph carrying all of them at once, plus both real
graphs:

| Requirement | Result |
|---|---|
| Distinct object | pass |
| Field values copied, including arrays | pass |
| `<NonSerialized>` left at default | pass |
| Aliasing preserved, two fields to one object | pass |
| Aliased target is the copy, not the original | pass |
| Cycle handled, self-reference points at the copy | pass |
| `OnDeserialized` invoked | pass |
| `Project` and `ApplicationSettings` versus their `BinaryFormatter` clones | 0 differences |

**The comparator was falsified rather than trusted**, because a differential reporting zero
proves nothing until it can report non-zero. Feeding it the same object twice yields
`SHARED reference with original`; feeding it a deliberately identity-losing copier yields
`ALIASING LOST`. Against the real copier it reports exactly one difference,
`CallbackRan: False vs True`, which is the callback legitimately mutating the copy, and
the `BinaryFormatter` clone shows the identical difference, so candidate against reference
is zero.

Context: the P-002 map sorted fourteen `BinaryFormatter` sites into five on-disk formats and
two in-memory clone helpers, and recommended the clone helper first because it carries no
file-format compatibility burden. That recommendation stands. The characterisation of it as
the easy piece does not, and this entry corrects it.

`ObjectHelp.GetCopy(Of T)` at `Source/General/Help.vb:78-84` round-trips an object through
`BinaryFormatter` over a `MemoryStream`. Measured on 2026-08-22:

- **85 call sites.**
- What it is asked to copy is not only small parameter objects: `ParamsStore` at 22 sites and
  `store` at 14, but also `Me` at 16, whole `Project` graphs at 5, and settings collections.
  These are the largest object graphs in the application.
- The tree contains **37 `<NonSerialized>` fields** and **41 serialization callbacks**
  (`OnDeserialized` and relatives, including `IDeserializationCallback`).

That last line is the reason this is not a small change. `BinaryFormatter` has semantics a
naive replacement silently breaks, and the breakage would not appear as an exception, it
would appear as an object that looks copied and behaves wrongly:

1. It copies **all fields**, including private and read-only ones.
2. It **skips** `<NonSerialized>` fields, leaving them at type default. 37 fields depend on
   this; a cloner that copies them would duplicate handles, caches, or parent links.
3. It **preserves reference identity within the graph**: an object referenced twice is
   copied once and referenced twice. A tree-walking copier duplicates it, and aliasing that
   the original relied on is silently gone.
4. It **handles cycles**. A naive recursive copier does not; it overflows the stack.
5. It **does not run constructors**, using uninitialized allocation instead.
6. It **invokes the serialization callbacks**. 41 of them exist, and objects that rely on
   one to rebuild transient state come back invalid if they are skipped.

Proposed decision: replace it with a reflection-based deep copier written to match those six
behaviors deliberately, rather than with a serializer that happens to round-trip. Uninitialized
allocation, field-wise copy including private fields, `<NonSerialized>` honored, a reference
map keyed by object identity for both aliasing and cycles, and callback invocation in the
order the formatter used.

Options considered:
- Reflection-based deep copier matching the six behaviors: recommended. It is portable, needs
  no attributes the types do not already carry, and is the only option that can reproduce
  reference identity and callbacks.
- A JSON round-trip: rejected. It loses type fidelity on polymorphic graphs, needs public
  setters the types do not have, cannot express cycles, and cannot preserve aliasing.
- A `Clone` method per type: rejected on volume. There are 133 `<Serializable>` types, and
  hand-written clones would drift from their types silently.
- Keep `BinaryFormatter` here: rejected as a destination, since it is unavailable in modern
  .NET and this work exists to leave it. It remains the reference implementation for
  verification, which is a different role.

Verification, which must exist before the change lands: a differential test that clones the
same graphs through `BinaryFormatter` and through the replacement and compares them deeply,
including reference-identity structure rather than field values alone, over the real graph
shapes the call sites use, `ParamsStore` and `Project` at minimum. Equal field values with
different aliasing is a failure, and a comparison that only walks values will not see it.

Known obstacle, recorded because it blocks the obvious approach: the application's static
graph cannot be loaded in isolation. `StaxRip.MediaInfo` reaches `StaxRip.Package`, whose
type initializer throws outside a real application environment, which is how the F-003
measurement had to be taken against a native library instead. A differential harness will
meet the same wall, so where that harness can run needs establishing before the change is
scheduled, not after.

Consequences if ratified: the largest single block of `BinaryFormatter` usage leaves the
tree without touching a file format, and the five on-disk formats become the only remaining
users, which is the harder problem stated plainly rather than mixed in with this one.

Revisit when: the differential harness proves impossible to host, which would make a
per-type approach worth reconsidering despite its volume.

## D-054: Encoders are pinned and fully optimised, not latest and not fastest-looking

Date: 2026-08-23. Status: CONFIRMED, ratified by the maintainer 2026-08-23. Owner: P-004.
Binds every encoder the portable side gains.

Context: the question was whether the port should use the best, latest and most optimised
encoder builds. Two thirds of that is right and the middle third is a trap, so the policy is
written down before the first encoder row is added rather than after.

Decision, three parts.

**Optimised: yes, and it is not optional.** An encoder built without its assembly kernels is
not a slower version of the same thing, it is a different product. The x265 built on the
verification host on 2026-08-23 reports `[noasm]` and `using cpu capabilities: none!`
because no assembler was installed, and it is useless for any timing question. Every
encoder the port names must be built or acquired with its architecture-specific code paths
enabled, and any measurement must confirm that before reporting a number.

**Latest: no. Pin, and let users opt in.** Encoders change their output for identical
settings between versions, which is normal development and not a defect. If the port tracks
latest, a user re-encoding the same source with the same profile after an update gets a
different file, and any comparison they were running silently becomes invalid. This is the
same hazard D-045 already answered for the inspection authority by pinning a range with
recorded hashes, and it binds harder here because for an encoder the output **is** the
product. Record a version and a hash; make moving deliberate.

**Best: define it per tool, because it is three different things.** Fastest, smallest at a
given quality, and most compatible are different builds, and the survey produced measured
evidence that they conflict. SVT-AV1-HDR and SVT-AV1-Tritium publish PGO builds targeting
`x86-64-v3` and `znver2` with no generic baseline, so on an older processor they do not run
slowly, they fault. SVT-AV1-Essential renames and redefines options and forces 10-bit
output, so "better encoder" there also means "different interface". Maximum optimisation
and maximum compatibility are ends of one dial, and which end a given tool sits at is a
recorded decision, not a default.

Because: reproducibility is a correctness property for this product. A user comparing two
encodes, or reporting a bug, or re-running a job, is entitled to the same bytes from the
same inputs. Chasing latest trades that away for speed the user did not ask for, and
chasing maximum optimisation without recording the target trades it for a crash on hardware
the project never tested.

Consequences: each encoder row records a pinned version, a hash, and the CPU baseline its
build targets. A tool whose published builds are march-specific with no generic baseline is
flagged in its row, because that is a support decision rather than a packaging detail.

One thing this makes easier rather than harder. Because Linux users build from source
anyway, following the upstream advice recorded in `Linux-Tool-Availability.md`, they can
compile for their own machine. Per-machine optimisation is available to a source build and
is not available to any binary a project distributes, so the strategy that arrived as a
consolation is the better one on this axis.

**Measured on the T540p, 2026-08-23, after
asm was installed.** Both claims in this
decision were tested rather than asserted, and the second measurement found something this
entry did not anticipate.

*Optimisation is worth what the decision claims.* The same x265 source, 150 frames of
640x480 at `--preset medium`:

| Build | Run 1 | Run 2 |
|---|---|---|
| No assembly | 6,967 ms | 6,913 ms |
| Assembly enabled | 2,314 ms | 2,457 ms |

Roughly **2.9 times faster**, and the assembled build reports
`MMX2 SSE2Fast LZCNT SSSE3 SSE4.2 AVX FMA3 BMI2 AVX2` where the other reported
`cpu capabilities: none!`. Building x265 with assembly costs 172 seconds against 48.

*And output depends on the instruction set, which is the part worth acting on.* The same
binary, same input, same settings, differing only in which ISA the encoder is allowed to
use, produces **different bitstreams**:

| Configuration | MD5 prefix | Size |
|---|---|---|
| No assembly | `b190518c` | 515,102 |
| `--asm sse4` | `b9a8e5a5` | 515,102 |
| `--asm avx2` | `2529385e` | 515,102 |

Three distinct outputs at identical size. This is not run-to-run noise: three consecutive
runs of one configuration produced byte-identical files, so the encoder is deterministic
and the ISA is the variable.

**The consequence extends this decision.** Pinning a version and a build is not sufficient
for bit-exact reproducibility, because two users running the identical pinned binary on
different processors get different files from the same source and settings. That is
inherent to how the encoder dispatches, not a defect. Where bit-exactness actually matters,
to a regression fixture or a comparison, the ISA must be pinned too, with `--asm` or its
equivalent. Where it does not matter, which is most user encoding, nothing needs to change
and the fastest available path should be used. What must not happen is a fixture that
silently assumes reproducibility the encoder never promised, which would fail on the first
machine with a different processor and look like a code defect.

Revisit when: a pinned encoder acquires a security defect, which forces a move and is the
one case where speed of update outranks reproducibility.

## D-055: Admitted media is identity-bound, and a swapped file is refused publication

Date: 2026-08-26. Status: CONFIRMED, ratified by the maintainer 2026-08-26. Owner:
R-S2-050. Binds the media-facts pipeline.

Context: admission validates a pathname and the authority later opens that pathname,
and between the two the file can be replaced. The textbook stable-handle repair cannot
apply, because MediaInfo is an external process that re-opens by path; no handle this
process holds can be handed to it.

Decision: capture the file's identity at admission, volume and file id on Windows, device
and inode on Linux, and compare it after the probe returns. On mismatch the result is
discarded and the requester receives the uniform rejection, so facts from a file the
policy never admitted are never published. The residual is stated rather than hidden: the
tool may briefly read a swapped file whose content reaches nobody, and exploiting even
that requires write access inside a media root the maintainer explicitly configured, on a
loopback, session-gated server. That residual is the configured-root trust boundary. The
executable's own exists-then-start window is covered by D-058's startup identity probe
and the same trust boundary, and is not separately raced.

Because: refusing publication closes the consequence that matters without pretending to
close a window that an external-tool architecture cannot close.

Implementation note, 2026-08-26: the binding is a held handle rather than a captured
file id, because a dependency-free file id is not available on both platforms and the
package closure is pinned. On Windows the handle is opened without delete sharing, which
makes the swap impossible rather than detectable; on Linux the kernel is asked where the
descriptor points after the probe, through /proc/self/fd, and a renamed or replaced file
shows as a different target. The directory chain is re-walked for reparse points on both.
The decision's substance, identity-bound admission with refused publication and a stated
residual, is unchanged; only the mechanism is stronger than the text above proposed.

Revisit when: the authority stops being an external process, or a configured root stops
being maintainer-controlled.

## D-056: The child process gets a constructed environment, never an inherited one

Date: 2026-08-26. Status: CONFIRMED, ratified by the maintainer 2026-08-26. Owner:
R-S2-051. Binds the bounded-process launcher.

Context: the sole launcher inherited the parent's whole environment and working
directory, which admits secrets, proxy settings, loader overrides, and location-dependent
behavior; the configured Linux run only worked because the parent exported a loader path
by hand.

Decision: the environment is allowlist-by-construction. The child receives a cleared
environment plus a per-platform base set, SystemRoot, SystemDrive, TEMP and TMP on
Windows, LANG=C.UTF-8 on Linux for deterministic tool output, plus an optional loader
path that is an explicit field of the media-inspection configuration rather than an
inherited variable. The working directory is the executable's own directory, the portable
tool convention the legacy application already follows. Nothing else crosses.

Because: what a child needs is a contract, and a contract is written down and versioned,
not inherited from whatever the parent happened to carry.

Revisit when: a tool demonstrably needs a variable the base set lacks; the variable joins
the configuration, not the inheritance.

## D-057: No spawn without validated bounds, no exception without a reaped child

Date: 2026-08-26. Status: CONFIRMED, ratified by the maintainer 2026-08-26. Owner:
R-S2-052. Binds the bounded-process launcher and the server's lifetime.

Context: the timeout cancellation source is constructed after the process starts, so an
invalid bound or any other post-start exception can escape without killing the child; and
host shutdown's five-second budget cannot cancel a thirty-second probe it knows nothing
about.

Decision, four parts, one unit. Every bound is validated before the spawn and rejected as
a pre-spawn reason class. Everything after a successful start runs under a catch-all that
kills and reaps the child before any exception escapes, widening the existing
kill-and-reap from cancellation-only to always. The server links its application-stopping
signal into every probe's cancellation token, so shutdown cancels in-flight probes and
the five-second budget holds because the primitive already kills on cancel. And the unit
ships with an in-flight-shutdown contract test that covers descendants, red first.

Because: the primitive's own documentation promises that a throw carries a reaped
receipt; this makes the promise unconditional instead of path-dependent.

Revisit when: probes gain descendants that outlive a tree kill, which the test exists to
catch.

## D-058: Capability availability is a startup fact, proven by running the tool once

Date: 2026-08-26. Status: CONFIRMED, ratified by the maintainer 2026-08-26. Owner:
R-S2-053. Binds the composition root's activation judgment.

Context: availability required only nonempty roots and an executable that looks like a
regular file, so a tool with a broken loader dependency advertised available while every
request failed; the recorded Linux run hit exactly that.

Decision: the activation judgment stays where it is, made once at the composition root so
the published capability and the endpoint behavior can never disagree, and it becomes
real: activation executes the configured tool once through the bounded primitive with its
version flag, under the D-056 environment, and requires a supported version in the
answer. A loader failure, a wrong binary, or an out-of-range version is unavailable at
startup, with a verdict naming why. A tool that breaks mid-session still fails
per-request; that is the accepted meaning of a startup fact, stated in the capability's
documentation.

Implementation note, 2026-08-26: the verdict, inspection-unconfigured,
inspection-tool-unresolvable, inspection-tool-unready, or inspection-version-unsupported,
is recorded on the capability service in process and is not published. The first
attested sweep after implementation refused a published verdict twice, in the shipped
shell and in the Linux sandbox's capability contract, because both pin the wire
vocabulary for this feature to exactly inspection-configured or bootstrap-unavailable.
Widening that vocabulary is a contract decision touching the shell, the browser gate, and
the sandbox, so it is left for the maintainer; the wire keeps the bootstrap vocabulary.

Because: a capability claim someone can act on is a claim something was actually
executed, and the never-disagree invariant is worth more than mid-session freshness.

Revisit when: a session-length deployment makes mid-session tool loss common enough to
observe, which reopens the dynamic-invalidation question with evidence.

## D-059: The privacy matcher's law is a ratified adversarial table, not an opinion

Date: 2026-08-26. Status: CONFIRMED, ratified by the maintainer 2026-08-26; the table
itself awaits its own ratification before any matcher change. Owner: R-S2-054. Binds the
media-facts privacy guard and the authority error surface.

Context: the embedded-path detector misses mid-string rooted paths, key-prefixed and
scheme-prefixed forms, while stripping innocent doubled-separator text such as URLs; and
a future adapter's arbitrary exception message can reach the wire as a response reason.

Decision, two parts. The matcher is changed only against a ratified adversarial table of
must-match and must-not-match rows, drafted first, signed off by the maintainer, and then
committed as the contract corpus and mutation-proven the way CT-020 was. The law's agreed
shape: the drive-letter rule stays; rooted POSIX detection extends to mid-string
positions after a non-alphanumeric boundary; the bare doubled-separator rule narrows to a
UNC shape so scheme separators stop being collateral; single-segment absolutes stay
deliberately unmatched. Separately and immediately, the authority exception surface
becomes a typed reason vocabulary, so no adapter's free text reaches the wire.

Table ratified 2026-08-26, with one carve-out the maintainer chose over the plain draft:
prose references such as a documentation path or a forum board must survive. The
resulting rule for rooted POSIX paths, at the start or mid-string alike: three or more
segments always strip; two segments strip only when the first segment is a known
filesystem root family, currently home, Users, mnt, media, tmp, var, opt, data, Volumes,
private, root, srv, and etc. So a home directory and a system file strip, and a two-level
reference under any other name survives. The family list is table content and changes
only with a row. The table itself lives in the contract corpus as CT-044's rows.

Because: a privacy law enforced by regex is exactly as strong as the example set it was
tested against, so the example set is the law and the regex is its implementation.

Revisit when: a real leak or a real false positive lands outside the table; the row joins
the table first and the matcher follows.
