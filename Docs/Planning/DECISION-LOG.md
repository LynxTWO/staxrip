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
