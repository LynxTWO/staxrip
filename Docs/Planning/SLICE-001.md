# StaxRip Community Slice Brief: SLICE-001 Source Project Checks

Version: 0.1 Draft. Date: 2026-08-15. Status: M2 and M3 deterministic evidence and M4 paired runtime evidence pass; remaining production accessibility, branch, and human evidence is in progress under Confirmed D-037.
Companion documents: `ARCHITECTURE.md`, `ENGINEERING.md`, `DECISION-LOG.md`, `../Unknowns/Planning-Unknowns.md`, and `../Architecture/Coverage-Ledger.md`.

This document is the build boundary. If work is not named here, it does not enter this slice. Exactly one slice is active at a time.

## M0 decision and continuation

M0 source mapping fired the approved stop gates before production work:

- **verified:** D-034 cannot permit `Ready`. `BeforeJobAdding` can run future user PowerShell and configured commands, while package, disk, job, and output authority is live or side-effecting. Evidence: `../Verification/SLICE-001/M0-AUTHORITY-STOP.md`.
- **verified:** The successful real `ProcessJob` route cannot reach the proposed post-success guard and also stop before source-opening tool or output work. Evidence: `../Verification/SLICE-001/M0-ACTIVATION-LIFECYCLE.md`.
- **verified:** A new `FormBase` details form would persist a window-position entry without an approved opt-out. Evidence: `../Verification/SLICE-001/M0-UI-AND-VERIFICATION.md`.
- **verified:** The bounded mapper/evaluator dependency seam passed an ignored .NET Framework 4.8 x64 design probe. M2 now verifies the production composition through the source-linked harness and product-assembly probe. Loaded GUI outcomes remain L4 evidence. Evidence: `../Verification/SLICE-001/M0-FAULT-PROBE.md` and `../Verification/SLICE-001/M2-INTEGRATION.md`.

D-037 is Confirmed. It supersedes D-030 and D-034, authorizes the bounded source-project-check contract, replaces the unsafe successful-job evidence requirement, and approves the position-persistence opt-out. M0 and M1 are complete. M2 deterministic integration and x64 build evidence, M3 production-control evidence, and the M4 paired source-open, stale-state, refresh, and handle matrix pass. Q-003 and U-004 are Closed. Exact `Application.Run`, complete MainForm and operating-system accessibility, remaining abort and recovery branches, and human value still wait for their named gates. Evidence is indexed at `../Verification/SLICE-001/README.md`.

## 1. What the slice proves

- **Central claim:** After a source opens successfully, a user can inspect a bounded set of current project checks, understand what those selected checks found, and tell whether the result is fresh without reading logs or changing processing behavior.
- **The slice in one line:** A user opens a source, receives one accessible project-check summary and bounded details, corrects an existing setting when needed, refreshes, and understands that Add Job and encode-time checks still run later.
- **Honest stakes:** If the completed walkthrough does not make the current project easier to inspect without implying encode authorization, the fork should rethink this direction before adding repair, progress, or release work.

The evaluator may emit `Selected checks passed` only for its approved pure catalog. That label does not cover package freshness, free disk space, event scripts, job collisions, output collisions, Add Job, or encode-time authority. No project-check result authorizes encoding.

## 2. The walkthrough

1. The user starts a verified local x64 source build and opens a supported synthetic or user-chosen source through an existing entry point.
2. Existing source opening runs unchanged on the approved interactive path. Only after the whole transaction returns successfully and the pure activation policy passes does the project-check coordinator take a bounded snapshot and evaluate it.
3. A separately owned textual summary shows overall state and counts and states that Add Job and encode-time checks run later. It never presents a prior result as current. The user can reach it through normal keyboard navigation and a menu command.
4. The user opens a read-only details surface by button, menu, or keyboard. Each row exposes status, check name, and explanation without relying on color or private workflow values.
5. If a blocker or warning refers to an existing editable setting, the user closes details and changes that setting through the existing StaxRip control. The old result becomes hidden or explicitly requires refresh; it cannot remain visibly current or passed.
6. The user activates `Refresh project checks`. A new snapshot and result replace the prior state. The user then proceeds through the existing workflow or continues correcting the project. Add Job and encoding remain authoritative and outside this slice.

If source opening aborts or fails, the project-check adapter is not invoked and no prior current result remains visible. Existing source-opening error and recovery behavior stays authoritative.

If source opening runs with `isEncoding = True`, during job processing, in batch mode, or inside a nested source-open transaction, the pure activation policy rejects evaluation and presentation. The mapped source-entry and project-replacement owners may only clear or hide prior transient state. Existing job behavior remains authoritative. This slice does not run a successful real `ProcessJob` proof or claim runtime job equivalence.

## 3. In scope, with build order

| Item | Notes |
|---|---|
| Approved three-check source-project catalog | `project.source-target-text-distinct`, `target.path-characters-valid`, and `muxer.cover-convention-valid`, with exact semantics and owners in `../Verification/SLICE-001/M0-CATALOG.md` |
| Immutable project-check model | `ProjectCheckSnapshot`, `ProjectCheck`, and `ProjectCheckResult` in production shape, with stable ids, enums, bounds, ordering, and precedence |
| Read-only snapshot mapper | Reads only approved current state; no mutable `Project` reference escapes the mapping call |
| Lifecycle coordinator and presentation adapter | Runs only after proven interactive success, owns the snapshot-construction and evaluation failure boundary, invalidates on mapped changes and job transitions, supports explicit refresh, and presents bounded `Unavailable` behavior |
| Accessible GUI | Compact textual summary, labeled details button, menu route, read-only details form, explicit accessibility properties, and visible focus |
| Standalone deterministic harness | .NET Framework 4.8 x64 VB project outside the solution, source-linking only approved pure production files and adding no package |
| Compatibility and performance evidence | L0 through L5 recorded runs, fixed synthetic fixtures, before-and-after contract comparisons, privacy sentinels, and close-out |

The five-week posture is a maximum for a solo maintainer, not permission to skip a gate. A failed spike causes reassessment before dependent work.

| Milestone | Timebox | Contents and success test |
|---|---|---|
| M0: Close blocking unknowns | Week 1 | Discovery only. Approve the safe interactive post-success seam, complete repository caller map, pure activation-policy inputs, project-replacement and source-entry clear owners, catalog semantics, every retained field owner and invalidation trigger, UI ownership and placement, fixed fixtures, timing protocol, and bounded coordinator fault seam. Use ignored disposable probes for the mapper/evaluator dependency shape and UI layout. Identify one pure blocker corrected through an existing control. Do not run a successful real `ProcessJob` proof. M1 owns the source-linked policy vectors; M2 through L4 own production clear, activation, and outcome evidence inside the approved interactive boundary. Close each unknown before its dependent milestone rather than widening the boundary to force evidence. |
| M1: Pure model and harness | Week 2 | Add the transient model, evaluator, precedence, bounds, privacy rules, and standalone x64 VB harness. Fixed and boundary vectors pass deterministically. No application adapter or form change occurs here. |
| M2: Snapshot and lifecycle integration | Week 3 | Add the approved read-only mapper and narrow interactive coordinator. Initial evaluation, explicit refresh, invalidation, project replacement, new-open, failed-open, policy rejection, and forced mapper and evaluator `Unavailable` paths have activation and outcome evidence. Source-linked policy tests cover job, encoding, batch, and nesting inputs. No successful real-job equivalence claim is made. |
| M3: Accessible presentation | Week 4 | Add the approved summary, menu route, details form, status text, accessibility properties, keyboard path, focus return, high-contrast behavior, and 100 through 200 percent DPI behavior. The result stays private and non-color-only. |
| M4: Evidence and human walkthrough | Week 5 | Run L0 through L5, fixed workflow comparisons, both applicable script-engine paths, privacy and stale-state challenges, clean-environment walkthrough, performance and handle gates, documentation close-out, and the LynxTWO value review. |

M0 evidence selects the final files and owners inside the modules in section 6. It may shrink the catalog or move the presentation within the existing desktop shell. It may not widen protected boundaries without a new decision and approval.

M0 may use bounded disposable probes or UI prototypes only under ignored local evidence paths. Inspect every probe before running it. A scratch prototype is not production code or final UI evidence and never enters packaging.

## 4. Out of scope, on purpose

| Excluded | Where it may connect later | Log entry |
|---|---|---|
| Automatic blocker repair or setting changes | Guided blocker repair extension after a typed project-check result | D-018, D-021 |
| Source-selection, probe, script-open, process, cancellation, or recovery behavior changes | Source-opening progress or recovery slice with failure injection | D-017, D-018 |
| Live tool probing, downloads, substitution, launches, or executable selection | Approved tool-boundary slice | D-021 |
| Project, settings, template, profile, job, or project-check persistence | Future persistence decision with migration, retention, and rollback | D-020, D-022, D-037 |
| Generated command, script, filter, temp, target, output, or native FrameServer behavior changes | Separately mapped command, workflow, or native slice | D-007, D-018 |
| Background refresh, worker, retry, polling, or new concurrency | Future typed project-change stream | D-018, D-031 |
| Optimization of existing source-opening stages | Workflow performance extension after a baseline identifies cost | D-015, D-018 |
| Project-check logging, support export, analytics, telemetry, or history | Separate diagnostics and privacy decision | D-022, D-026 |
| Localization infrastructure | Existing stable message-key seam | D-020 |
| Test-framework package, solution test mapping, hosted CI, or coverage service | Later verification-infrastructure decision | D-024, D-027 |
| Packaging, installer, updater change, release script, portable archive, or public binary | Release-boundary slice after U-006 and U-009 close | D-016, D-027 |
| Add Job, encoding, or output authorization and validation | Existing workflow and a later processing-result slice | D-004, D-037 |
| x86 or Win32 build configuration | No connection planned; reintroduction requires a new decision and explicit approval | D-006, D-029 |

## 5. Stubs and their debts

None. Everything inside the boundary is production quality for its stated scope. The small catalog, English renderer, explicit refresh command, no-history behavior, and source-only delivery are confirmed scope choices, not partial stand-ins. Future capabilities in section 4 remain absent rather than simulated.

## 6. Modules touched

| ADD module or repository boundary | Allowed touch |
|---|---|
| Source intake | One proven interactive success-only hook plus transient clears at shared source entry and project replacement; the pure policy rejects `isEncoding = True`, job, batch, and nested paths; no source-opening decision, job, or recovery change |
| Project and profile state | Read-only mapping of approved in-memory facts; no writer, serializer, migration, or format change |
| Desktop shell | Separately owned summary, menu command, details form, explicit refresh, invalidation presentation, and accessibility properties |
| Feature-owned project-check module | Pure model, evaluator, stable catalog constants, activation policy, precedence, bounds, safe message arguments, and one narrow coordinator around snapshot construction and evaluation |
| Build metadata | Normal explicit compile entries in `Source/StaxRip.vbproj`; no solution mapping or existing configuration change |
| Deterministic test seam | `Source/Tests/ProjectChecks/ProjectCheckEvaluatorTests.vbproj` and runner outside `Source/StaxRip.sln`, with outputs below ignored `Source/obj/ProjectCheckTests/` |
| Documentation and evidence | Planning decisions, catalog artifact, coverage and unknowns updates, and bounded evidence under `Docs/Verification/SLICE-001/` |

The slice does not touch FrameServer implementation, AutoCrop behavior, job execution, persistence writers, command constructors, cleanup, package update, release, or publication code. Reading a protected owner during M0 does not authorize editing it.

## 7. Data subset

### `ProjectCheckSnapshot`

- Immutable input for one evaluation.
- Contains a schema version and only three bounded enums: source-target text comparison, target path-character state, and muxer cover-convention state.
- Holds no mutable `Project`, form, path, script, command, exception, log, external output, credential, or arbitrary string reference.
- Every field has one source owner, one invalidation trigger, a bound, a privacy classification, and a fixed test.
- Discarded after evaluation. Never serialized.

### `ProjectCheck`

- Contains a stable lowercase ASCII id, category, outcome, severity, stable message key, optional stable evidence code, and integer sort order. The approved first catalog uses no message arguments.
- Ids are unique. Argument count and length are bounded. No display text determines functional truth.
- Supports fact, warning, blocker, unknown, and not-applicable outcomes selected by the approved catalog.
- Belongs to one result and is discarded with it.

### `ProjectCheckResult`

- Contains a schema version, overall typed status, and ordered read-only checks.
- Overall status derives from one tested precedence function and the approved selected catalog. `Selected checks passed` means only that every applicable selected check passed. It never means Add Job or encoding is authorized.
- Functional equality excludes time, duration, culture, rendered text, and control state.
- Replaced by explicit refresh or hidden by invalidation. Never persisted.

### `ProjectCheckActivationContext`

- Contains only transaction success, remaining source-open depth, remaining project-check mutation depth, encoding, UI-thread entry, entry and completion job/batch state, scoped startup `-NoFocus` suppression, and same-project-at-completion primitives.
- The pure policy accepts only a successful zero-source-depth, zero-mutation-depth interactive UI-thread transaction with every suppressor false and the captured project identity unchanged.
- Holds no project, form, thread, path, command line, exception, or arbitrary string. Discarded immediately after the policy decision.

### `ProjectCheckRefreshContext`

- Contains only current presentation kind, source-open depth, project-check mutation depth, UI-thread entry, current job and batch state, and scoped startup `-NoFocus` suppression.
- The pure policy accepts only `Available`, `Refresh required`, or `Unavailable` with both depths zero and every suppressor false. The coordinator separately rejects active mutations and `Hidden`.
- Holds no result, project, form, path, command line, exception, or arbitrary string. Discarded immediately after the policy decision.

### Presentation-only lifecycle

The thin adapter may expose only `Hidden`, `Available`, `Refresh required`, and `Unavailable` presentation states. `Available` contains the current result. The other states do not expose a stale result. `Unavailable` contains no exception prose. These states are transient UI behavior, not project data.

D-036 ends at snapshot construction and evaluation. It does not create a broad catch around publication, invalidation, refresh-command wiring, or rendering. Those paths retain existing application exception behavior and receive their named normal, boundary, stale-state, privacy, and accessibility checks. If M0 evidence shows that the central claim requires a wider nonfatal UI boundary, stop for a new decision.

There is no database, migration, serialization, retention, user-data deletion, cache, or project-check-history work in this slice. The approved `FormBase.RememberPosition` default-preserving guard prevents the new details form from adding a window-placement setting; existing forms keep current restore and save behavior.

## 8. Acceptance criteria

| ID | Criterion | EDD requirement | Verified by |
|---|---|---|---|
| S-001 | Given an approved supported fixture on the approved interactive path, when existing source opening returns successfully and the pure activation policy passes, then exactly one current project-check evaluation becomes available through the approved success-only adapter. | R-001, R-002 | M0 seam proof, L3 walkthrough, activation counter |
| S-002 | Given a fixed approved snapshot, repeated evaluation returns the same stable ids, typed outcomes, severity, precedence, and order. | R-002, R-010 | L1 fixed vectors and repetition |
| S-003 | Given synthetic fact, warning, blocker, unknown, and not-applicable outcomes, the model and GUI preserve their meaning and never rely on color alone. | R-003 | L1 evaluator cases and L4 presentation checks |
| S-004 | Given a displayed result, when a mapped input changes, a new open starts, the project is replaced, or a later open fails, then the prior result is hidden or marked `Refresh required` and cannot remain visibly current or passed. | R-001, R-004 | L4 lifecycle state table and forced stale-result scenarios |
| S-005 | Given an invalidated result, when the user activates `Refresh project checks`, then one new bounded snapshot replaces the prior state without starting background work. | R-002, R-004 | L4 explicit-refresh activation and outcome evidence |
| S-006 | Given every fixed workflow fixture, source opening before and after the slice produces equivalent effective project, script, command, tool, temp, and target contracts apart from transient project-check state. | R-001, R-004 | L3 canonical before-and-after comparisons |
| S-007 | Given network denial and a configured local fixture, project checks evaluate and render without a remote call, process launch, tool substitution, download, or new filesystem probe. | R-005, R-006 | L0 prohibited-boundary scan and L3 denied-network walkthrough |
| S-008 | Given sensitive sentinels in paths, names, metadata, scripts, commands, settings, external output, and exception text, none appears in results, rendering, accessibility properties, clipboard routes, test output, or a new log. | R-007 | L1 result sentinels, L4 presentation sentinels, bounded diff review |
| S-009 | Given keyboard-only use, the user can reach summary, refresh, details, every row, and close; focus is visible and returns correctly; names and row semantics are meaningful at 100, 125, 150, and 200 percent DPI and in high contrast. | R-008 | L4 keyboard script, accessibility inspection, Narrator walkthrough |
| S-010 | Given a deterministic forced exception from either snapshot construction or evaluation after a loaded project exists, the coordinator shows the same privacy-safe `Unavailable` state, never `Selected checks passed`, leaves the project unchanged, and emits no project-check log or exception prose. The activation uses the bounded M0-approved dependency seam, not a global flag, environment trigger, or user switch. | R-004, R-007 | L4 mapper and evaluator branch activation plus project-state comparison |
| S-011 | Given a missing or unsupported source or a forced media-probe failure that aborts opening, the project-check adapter is not invoked, no prior current result remains visible, and existing failure behavior is unchanged. | R-001, R-004 | L3 pre-adapter failure activation and outcome evidence |
| S-012 | Given the approved timing protocol, project-check evaluation and rendering add at most 100 ms at p95, median full-flow regression stays within 5 percent or 100 ms whichever allowance is larger, and 50 unchanged evaluations show no net process-handle growth. | R-009 | L5 recorded aggregate measurements |
| S-013 | The standalone harness builds and passes in x64 outside the solution with no package or application project reference and with all outputs under ignored `Source/obj/ProjectCheckTests/`. | R-010 | L0 project inspection and L1 recorded run |
| S-014 | `Source/StaxRip.sln` and direct `Source/StaxRip.vbproj` Debug and Release x64 gates pass, and configuration declarations remain x64-only. | R-010, R-012 | L0 XML and configuration scan, L2 build records |
| S-015 | The completed slice adds no project-check persistence, migration, dependency, solution mapping, CI, release-script execution, package, portable archive, public binary, or x86 or Win32 configuration. The default-preserving `FormBase.RememberPosition` guard is the only settings-boundary edit, and the new form writes no placement state. | R-004, R-011, R-012 | L0 bounded diff, focused base-class checks, and repository-status review |
| S-016 | In the human walkthrough, LynxTWO can identify the current selected-check state, inspect reasons, correct one existing setting, refresh, and explain that Add Job and encode-time checks still run later, without reading logs. | A-001 | M4 human approval and U-011 closure |
| S-017 | Given the approved catalog record, every overall status has bounded documented meaning. The evaluator emits `Selected checks passed` only when every applicable selected check passes, and the GUI states that the result does not authorize Add Job or encoding. | R-001, R-002, R-003 | M0 catalog approval, L1 precedence vectors, and L4 copy inspection |
| S-018 | Given the complete repository caller map and source-linked activation-policy vectors, the policy accepts only a successful outermost interactive source open and rejects `isEncoding = True`, job-processing, batch, nested, abort, and failure inputs. Production source checks place synchronous clears at the mapped shared source-entry and project-replacement owners. No successful `ProcessJob` runtime equivalence is claimed or required. | R-001, R-004 | M0 static caller map, L1 pure policy vectors, and L2/L3 focused production-source and interactive activation checks |

## 9. Verification evidence required

Before Done, the source-bound evidence set under `Docs/Verification/SLICE-001/` contains or links:

- [x] M0 catalog, repository caller map, lifecycle design, revised S-018 scope, and coordinator fault-seam design are recorded in the M0 evidence set.
- [x] M0 strict UI prototype, fixture identity, complete recipe, and isolated-runtime protocol close their design gates.
- [x] The isolated runtime, template identity, and baseline measurements close before performance-dependent completion.
- [ ] L0 static results for diff hygiene, XML, x64 configuration, prohibited boundaries, dependencies, logging, privacy fields, and documentation references.
- [x] L1 standalone Debug and Release x64 harness runs cover pure model, activation, refresh, coordinator, mutation-interleaving, privacy, and presentation-text branches.
- [x] L2 solution and direct managed Debug and Release x64 rebuilds pass. The existing Release solution mapping builds managed StaxRip as Debug x64; the separate direct Release x64 project rebuild passes, and no mapping changed.
- [ ] L3 exact-`Application.Run` clean-environment walkthrough remains open. The reviewed production-equivalent lifecycle completes canonical before-and-after contract comparisons for all approved source fixtures.
- [ ] L3 branch evidence remains open for abort, recovery, and every permitted clear or hide owner. The reviewed runtime proves successful outermost activation and malformed-later-open Hidden state without running a successful real `ProcessJob` path.
- [x] The complete static source-open caller map, 8,192 source-linked activation-policy vectors, and 87 focused production-source assertions required by revised S-018.
- [ ] L4 deterministic snapshot-mapper and evaluator `Unavailable` activation, complete invalidation and project-replacement presentation, keyboard, focus, accessibility, high-contrast, DPI, and privacy evidence. The runtime matrix already passes explicit refresh and malformed-later-open Hidden state.
- [x] L5 p95 overhead, median full-flow regression, and 50-evaluation handle results with aggregate machine facts and no private paths.
- [x] Both approved script-engine paths are covered by workflow compatibility fixtures; no retained catalog field branches on script engine.
- [ ] EDD section 17 close-out with checks, untested boundaries, unknowns, privacy, logging, approvals, documentation, and rollback.
- [ ] Human walkthrough completed and approved by LynxTWO.

Recorded local runs satisfy this source-only slice. Hosted CI is not required and is outside scope. An agent statement without the named artifact is not evidence.

## 10. Agent guardrails for this build

- **Boundary:** Only section 6 modules, section 7 transient data, and M0-approved files may change.
- **M0 stop gate:** Do not edit a dependent production path until its catalog, post-success seam, lifecycle, UI ownership, or fixture design gate is evidenced and logged. Those design gates are closed. The reviewed v6 matrix also closes the isolated-runtime and timing gate for L5; remaining L3 and L4 boundaries stay binding for their named behavior and presentation claims.
- **Catalog stop gate:** Exclude any candidate fact that needs process execution, network, a new filesystem probe, log parsing, mutable access, or an unowned invalidation trigger. Ask before changing this rule.
- **Authority stop gate:** Never label a project-check result `Ready`, ready to encode, safe to encode, or equivalent. `Selected checks passed` covers only the approved catalog and must be paired with the later-checks statement.
- **Integration stop gate:** Do not use an in-transaction source-loaded event as proof of successful completion. Ask if no safe post-return owner exists.
- **Job-path stop gate:** The pure policy must reject `isEncoding = True`, job-processing, batch, nested, abort, and failure inputs. The only permitted project-check action on these paths is a mapped synchronous clear or hide. Stop if the shared call graph cannot preserve this boundary and existing job behavior.
- **Job-evidence stop gate:** Do not use a real user job, queue, path, temp tree, or output for this slice's branch evidence. Revised S-018 uses the complete static caller map, pure policy vectors, and production checks at the two clear owners. A successful `ProcessJob` runtime claim needs separate tool-boundary approval.
- **Failure-seam stop gate:** Do not implement the coordinator until M0 approves one bounded dependency seam that deterministically forces both snapshot-mapper and evaluator failures without a global flag, environment trigger, user switch, package, or solution mapping.
- **Failure-scope stop gate:** Do not widen D-036 into a broad catch around publication, invalidation, refresh-command wiring, or rendering. If M0 evidence requires that behavior, record the existing path and obtain a new decision.
- **Protected boundaries:** Ask before persistence, deletion, overwrite, temp cleanup, process control, cancellation, retry, executable selection, download, command construction, native ABI, solution mapping, dependency, packaging, publication, or release work.
- **Build boundary:** D-024 permits normal production compile entries and the standalone test project only. It does not permit a solution project, package, configuration mapping, CI workflow, or release change.
- **Privacy boundary:** Add no project-check log. Do not copy paths, media names, titles, scripts, commands, exception prose, or arbitrary external output into the result, GUI, accessibility values, clipboard, fixtures, or failure packets.
- **Mode separation:** Run M0 discovery, each implementation milestone, and each verification level as separate work. A discovery result that changes scope returns to the Decision Log before implementation.
- **Conflict rule:** If source evidence contradicts this brief, stop, mark the specific contradiction as `verified`, `inferred`, or `unknown`, update the decision path, and obtain approval.
- **Script rule:** Do not run `Source/BuildAndPack.ps1` or `Source/Release.ps1`.

## 11. Slice definition of done

- [x] D-033 through D-037 have one valid status; D-030 and D-034 are Superseded by Confirmed D-037.
- [x] M0 closes Q-002 and U-010 for GUI ownership through the strict ignored x64 model; M3 supersedes its limited-font row height and fixed Hidden-state span through the expanded production matrix and refined layout. Q-001, Q-007 through Q-009, U-003, and U-012 through U-014 are also closed for M0 design or evidence scope.
- [x] Q-003 and U-004 close through the reviewed v6 paired source-open, stale-state, refresh, timing, and handle evidence.
- [ ] S-001 through S-018 pass with source-bound evidence.
- [ ] No unlabeled shortcut or stub exists inside the boundary.
- [ ] Root steering, Architecture, Engineering, Decision Log, Unknowns, Coverage Ledger, catalog, evidence index, and slice status agree.
- [ ] Security, privacy, logging, accessibility, failure, performance, compatibility, and rollback reviews are complete for touched paths.
- [ ] No public binary or release asset exists from this slice.
- [ ] LynxTWO completes the walkthrough and confirms that the project-check result clarifies the current project without implying encode authorization.
- [ ] Status changes to `Done with evidence`, ADD section 15 is updated, and the next slice remains unopened until close-out.

## 12. What this unlocks

- **Guided blocker repair:** Use stable project-check ids to route one approved corrective action without placing mutation in the evaluator.
- **Source-opening stage and progress model:** Use the timing protocol and safe lifecycle knowledge to expose progress, then optimize only measured stages.

These are candidates, not commitments. Release work remains separate until U-006 and U-009 close.

---

*Approved for M0 discovery by: LynxTWO, 2026-08-15. D-037 was confirmed by LynxTWO on 2026-08-15 and authorizes the bounded Source project checks continuation, revised evidence contract, and default-preserving position opt-out. M0 and M1 are complete; M2 and M3 deterministic evidence and the M4 paired runtime matrix pass within their claim limits. Production accessibility, remaining branch evidence, and human value remain open. When section 11 closes with evidence, mark the status Done and update ADD section 15 before opening another brief.*
