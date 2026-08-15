# StaxRip Community Decision Log

Version: 0.1 Draft. Date: 2026-08-15.
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
| D-006 | 2026-08-13 | Product shape and platforms | Confirmed | |
| D-007 | 2026-08-13 | Interface and compatibility posture | Confirmed | |
| D-008 | 2026-08-13 | Client technology | Confirmed | |
| D-009 | 2026-08-13 | Implementation languages | Confirmed | |
| D-010 | 2026-08-13 | Backend approach | Confirmed | |
| D-011 | 2026-08-13 | Storage approach | Confirmed | |
| D-012 | 2026-08-13 | Authentication | Confirmed | |
| D-013 | 2026-08-13 | Notification channels | Confirmed | |
| D-014 | 2026-08-13 | Build and distribution path | Confirmed | |
| D-015 | 2026-08-13 | Performance targets | Confirmed | |
| D-016 | 2026-08-13 | Deployment posture | Confirmed | |
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
| D-030 | 2026-08-15 | SLICE-001 shape and timebox | Confirmed | |
| D-031 | 2026-08-15 | Readiness refresh and invalidation | Confirmed | |
| D-032 | 2026-08-15 | Initial readiness catalog breadth | Confirmed | |
| D-033 | 2026-08-15 | SLICE-001 build approval | Confirmed | |
| D-034 | 2026-08-15 | Conservative Ready authority | Confirmed | |
| D-035 | 2026-08-15 | Interactive-only readiness activation | Confirmed | |
| D-036 | 2026-08-15 | Readiness adapter failure boundary | Confirmed | |

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
Status: Confirmed
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
Status: Confirmed
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
Status: Confirmed
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
Status: Confirmed
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
Status: Confirmed
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
Status: Confirmed
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
Status: Confirmed
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
Status: Confirmed
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

Decision: Evaluate once after a verified successful source-opening return. Use an explicit `Refresh readiness` command for recomputation. Invalidate or hide the current result on a new open attempt, project replacement, or any mapped input change. Exclude a candidate check when no safe invalidation trigger can be proven. Add no background refresh or worker.

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
Status: Confirmed
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

Consequences: Q-008 and U-014 close in M0 only after an ignored disposable probe demonstrates the seam design for both fault branches. M2 and L4 own production activation and outcome proof. If the seam needs a package, solution mapping, global flag, or broader harness scope, stop for another decision.

Revisit when: Readiness joins a typed application-wide nonfatal error boundary with equivalent privacy and activation evidence.
