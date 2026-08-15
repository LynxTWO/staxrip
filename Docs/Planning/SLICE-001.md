# StaxRip Community Slice Brief: SLICE-001 Source Readiness Summary

Version: 0.1 Draft. Date: 2026-08-15. Status: Approved for M0 discovery.
Companion documents: `ARCHITECTURE.md`, `ENGINEERING.md`, `DECISION-LOG.md`, `../Unknowns/Planning-Unknowns.md`, and `../Architecture/Coverage-Ledger.md`.

This document is the build boundary. If work is not named here, it does not enter this slice. Exactly one slice is active at a time.

## 1. What the slice proves

- **Central claim:** After a source opens successfully, a user can tell without reading logs whether the current effective project is ready to encode, what needs attention, and whether the result is fresh, without changing processing behavior.
- **The slice in one line:** A user opens a source, receives one accessible readiness summary and bounded details, corrects an existing setting when needed, refreshes, and makes a confident proceed-or-correct decision.
- **Honest stakes:** If the completed walkthrough does not make that decision materially clearer to the human reviewer, the fork should rethink the readiness direction before adding repair, progress, or release work.

M0 must prove that the approved small catalog supports the claimed overall labels under D-034. If an authoritative required condition remains unchecked or unknown, the evaluator cannot emit `Ready`. If the pure catalog cannot support an honest ready-to-encode claim, the slice stops for a new decision.

## 2. The walkthrough

1. The user starts a verified local x64 source build and opens a supported synthetic or user-chosen source through an existing entry point.
2. Existing source opening runs unchanged on the approved interactive `isEncoding = False` path. Only after the whole transaction returns successfully does the readiness coordinator take a bounded snapshot and evaluate it.
3. A separately owned textual summary shows overall state and counts. It never presents a prior result as current. The user can reach it through normal keyboard navigation and a menu command.
4. The user opens a read-only details surface by button, menu, or keyboard. Each row exposes status, check name, and explanation without relying on color or private workflow values.
5. If a blocker or warning refers to an existing editable setting, the user closes details and changes that setting through the existing StaxRip control. The old result becomes hidden or explicitly requires refresh; it cannot remain visibly ready.
6. The user activates `Refresh readiness`. A new snapshot and result replace the prior state. The user then proceeds through the existing encode workflow or continues correcting the project. Starting an encode is outside this slice.

If source opening aborts or fails, the readiness adapter is not invoked and no prior ready claim remains visible. Existing source-opening error and recovery behavior stays authoritative.

If source opening runs with `isEncoding = True` or through job processing, no readiness snapshot, evaluation, or new summary or details presentation activates. The only permitted readiness action is a mapped synchronous clear or hide of prior transient state before job processing. Existing job behavior remains authoritative.

## 3. In scope, with build order

| Item | Notes |
|---|---|
| Spike-approved readiness catalog | Target five to eight pure post-success checks, including at least one safely reproducible blocker corrected through an existing control; exact fields and count require M0 evidence and approval |
| Immutable readiness model | `ReadinessSnapshot`, `ReadinessCheck`, and `ReadinessResult` in production shape, with stable ids, enums, bounds, ordering, and precedence |
| Read-only snapshot mapper | Reads only approved current state; no mutable `Project` reference escapes the mapping call |
| Lifecycle coordinator and presentation adapter | Runs only after proven interactive success, owns the snapshot-construction and evaluation failure boundary, invalidates on mapped changes and job transitions, supports explicit refresh, and presents bounded `Unavailable` behavior |
| Accessible GUI | Compact textual summary, labeled details button, menu route, read-only details form, explicit accessibility properties, and visible focus |
| Standalone deterministic harness | .NET Framework 4.8 x64 VB project outside the solution, source-linking only approved pure production files and adding no package |
| Compatibility and performance evidence | L0 through L5 recorded runs, fixed synthetic fixtures, before-and-after contract comparisons, privacy sentinels, and close-out |

The five-week posture is a maximum for a solo maintainer, not permission to skip a gate. A failed spike causes reassessment before dependent work.

| Milestone | Timebox | Contents and success test |
|---|---|---|
| M0: Close blocking unknowns | Week 1 | Discovery only. Map and approve the safe interactive post-success seam, every interactive, job, batch, recovery, and encoding caller, the pre-job clear owner, an isolated synthetic job-path verification protocol with a stopping point before processing, tool launch, or output work, catalog and overall-status semantics, every field owner and invalidation trigger, UI ownership and placement, fixed fixtures, timing protocol, and a bounded coordinator fault seam. Source-trace that the selected hook is unreachable from `isEncoding = True`, job, abort, and failure paths. Use an ignored disposable probe to demonstrate that the proposed seam design can force snapshot-mapper and evaluator faults. Prove no `Ready` state with an unchecked authoritative condition and identify one pure blocker corrected through an existing control. M2 through L4 own final production activation and outcome proof. Close Q-001, Q-002, Q-003, Q-007, Q-008, Q-009, U-003, U-004, U-010, U-012, U-013, and U-014 before M1 through M3 touch dependent production paths. If the job-path protocol cannot avoid real user jobs and processing boundaries without changing job behavior, stop for a new decision. |
| M1: Pure model and harness | Week 2 | Add the transient model, evaluator, precedence, bounds, privacy rules, and standalone x64 VB harness. Fixed and boundary vectors pass deterministically. No application adapter or form change occurs here. |
| M2: Snapshot and lifecycle integration | Week 3 | Add the approved read-only mapper and narrow interactive coordinator. Initial evaluation, explicit refresh, invalidation, project replacement, new-open, failed-open, job-path non-activation, and forced mapper and evaluator `Unavailable` paths have activation and outcome evidence. Existing effective processing and job state remains equivalent. |
| M3: Accessible presentation | Week 4 | Add the approved summary, menu route, details form, status text, accessibility properties, keyboard path, focus return, high-contrast behavior, and 100 through 200 percent DPI behavior. The result stays private and non-color-only. |
| M4: Evidence and human walkthrough | Week 5 | Run L0 through L5, fixed workflow comparisons, both applicable script-engine paths, privacy and stale-state challenges, clean-environment walkthrough, performance and handle gates, documentation close-out, and the LynxTWO value review. |

M0 evidence selects the final files and owners inside the modules in section 6. It may shrink the catalog or move the presentation within the existing desktop shell. It may not widen protected boundaries without a new decision and approval.

M0 may use bounded disposable probes or UI prototypes only under ignored local evidence paths. Inspect every probe before running it. A scratch prototype is not production code or final UI evidence and never enters packaging.

## 4. Out of scope, on purpose

| Excluded | Where it may connect later | Log entry |
|---|---|---|
| Automatic blocker repair or setting changes | Guided blocker repair extension after a typed readiness result | D-018, D-021 |
| Source-selection, probe, script-open, process, cancellation, or recovery behavior changes | Source-opening progress or recovery slice with failure injection | D-017, D-018 |
| Live tool probing, downloads, substitution, launches, or executable selection | Approved tool-boundary slice | D-021 |
| Project, settings, template, profile, job, or readiness persistence | Future persistence decision with migration, retention, and rollback | D-020, D-022 |
| Generated command, script, filter, temp, target, output, or native FrameServer behavior changes | Separately mapped command, workflow, or native slice | D-007, D-018 |
| Background refresh, worker, retry, polling, or new concurrency | Future typed project-change stream | D-018, D-031 |
| Optimization of existing source-opening stages | Workflow performance extension after a baseline identifies cost | D-015, D-018 |
| Readiness logging, support export, analytics, telemetry, or history | Separate diagnostics and privacy decision | D-022, D-026 |
| Localization infrastructure | Existing stable message-key seam | D-020 |
| Test-framework package, solution test mapping, hosted CI, or coverage service | Later verification-infrastructure decision | D-024, D-027 |
| Packaging, installer, updater change, release script, portable archive, or public binary | Release-boundary slice after U-006 and U-009 close | D-016, D-027 |
| Encoding or output validation | Existing encode workflow and a later processing-result slice | D-004, D-030 |
| x86 or Win32 build configuration | No connection planned; reintroduction requires a new decision and explicit approval | D-006, D-029 |

## 5. Stubs and their debts

None. Everything inside the boundary is production quality for its stated scope. The small catalog, English renderer, explicit refresh command, no-history behavior, and source-only delivery are confirmed scope choices, not partial stand-ins. Future capabilities in section 4 remain absent rather than simulated.

## 6. Modules touched

| ADD module or repository boundary | Allowed touch |
|---|---|
| Source intake | One proven interactive success-only hook plus transient invalidation at approved project and job transitions; `isEncoding = True` and job paths get zero snapshot, evaluation, or new summary or details presentation activation, with one mapped synchronous clear or hide permitted; no source-opening decision, job, or recovery change |
| Project and profile state | Read-only mapping of approved in-memory facts; no writer, serializer, migration, or format change |
| Tool orchestration requirement readers | Read only already available bounded requirement state; no process, filesystem probe, network, selection, or package action |
| Desktop shell | Separately owned summary, menu command, details form, explicit refresh, invalidation presentation, and accessibility properties |
| Feature-owned readiness module | Pure model, evaluator, stable catalog constants, precedence, bounds, safe message arguments, and one narrow coordinator around snapshot construction and evaluation |
| Build metadata | Normal explicit compile entries in `Source/StaxRip.vbproj`; no solution mapping or existing configuration change |
| Deterministic test seam | `Source/Tests/Readiness/ReadinessEvaluatorTests.vbproj` and runner outside `Source/StaxRip.sln`, with outputs below ignored `Source/obj/ReadinessTests/` |
| Documentation and evidence | Planning decisions, catalog artifact, coverage and unknowns updates, and bounded evidence under `Docs/Verification/SLICE-001/` |

The slice does not touch FrameServer implementation, AutoCrop behavior, job execution, persistence writers, command constructors, cleanup, package update, release, or publication code. Reading a protected owner during M0 does not authorize editing it.

## 7. Data subset

### `ReadinessSnapshot`

- Immutable input for one evaluation.
- Contains a schema version and only M0-approved flags, enums, bounded primitives, stable owner ids, and bounded collections.
- Holds no mutable `Project`, form, path, script, command, exception, log, external output, credential, or arbitrary string reference.
- Every field has one source owner, one invalidation trigger, a bound, a privacy classification, and a fixed test.
- Discarded after evaluation. Never serialized.

### `ReadinessCheck`

- Contains a stable lowercase ASCII id, category, outcome, severity, stable message key, ordered safe primitive arguments, optional stable evidence code, and integer sort order.
- Ids are unique. Argument count and length are bounded. No display text determines functional truth.
- Supports fact, warning, blocker, unknown, and not-applicable outcomes selected by the approved catalog.
- Belongs to one result and is discarded with it.

### `ReadinessResult`

- Contains a schema version, overall typed status, and ordered read-only checks.
- Overall status derives from one tested precedence function and a documented catalog-coverage rule. `Ready` is forbidden when an authoritative required condition is unchecked or unknown.
- Functional equality excludes time, duration, culture, rendered text, and control state.
- Replaced by explicit refresh or hidden by invalidation. Never persisted.

### Presentation-only lifecycle

The thin adapter may expose only `Hidden`, `Available`, `Refresh required`, and `Unavailable` presentation states. `Available` contains the current result. The other states do not expose a stale result. `Unavailable` contains no exception prose. These states are transient UI behavior, not project data.

D-036 ends at snapshot construction and evaluation. It does not create a broad catch around publication, invalidation, refresh-command wiring, or rendering. Those paths retain existing application exception behavior and receive their named normal, boundary, stale-state, privacy, and accessibility checks. If M0 evidence shows that the central claim requires a wider nonfatal UI boundary, stop for a new decision.

There is no database, migration, serialization, retention, user-data deletion, cache, or readiness-history work in this slice.

## 8. Acceptance criteria

| ID | Criterion | EDD requirement | Verified by |
|---|---|---|---|
| S-001 | Given an approved supported fixture on the approved interactive `isEncoding = False` path, when existing source opening returns successfully, then exactly one current readiness evaluation becomes available through the approved success-only adapter. | R-001, R-002 | M0 seam proof, L3 walkthrough, activation counter |
| S-002 | Given a fixed approved snapshot, repeated evaluation returns the same stable ids, typed outcomes, severity, precedence, and order. | R-002, R-010 | L1 fixed vectors and repetition |
| S-003 | Given synthetic fact, warning, blocker, unknown, and not-applicable outcomes, the model and GUI preserve their meaning and never rely on color alone. | R-003 | L1 evaluator cases and L4 presentation checks |
| S-004 | Given a displayed result, when a mapped input changes, a new open starts, the project is replaced, or a later open fails, then the prior result is hidden or marked `Refresh required` and cannot remain visibly ready. | R-001, R-004 | L4 lifecycle state table and forced stale-result scenarios |
| S-005 | Given an invalidated result, when the user activates `Refresh readiness`, then one new bounded snapshot replaces the prior state without starting background work. | R-002, R-004 | L4 explicit-refresh activation and outcome evidence |
| S-006 | Given every fixed workflow fixture, source opening before and after the slice produces equivalent effective project, script, command, tool, temp, and target contracts apart from transient readiness state. | R-001, R-004 | L3 canonical before-and-after comparisons |
| S-007 | Given network denial and a configured local fixture, readiness evaluates and renders without a remote call, process launch, tool substitution, download, or new filesystem probe. | R-005, R-006 | L0 prohibited-boundary scan and L3 denied-network walkthrough |
| S-008 | Given sensitive sentinels in paths, names, metadata, scripts, commands, settings, external output, and exception text, none appears in results, rendering, accessibility properties, clipboard routes, test output, or a new log. | R-007 | L1 result sentinels, L4 presentation sentinels, bounded diff review |
| S-009 | Given keyboard-only use, the user can reach summary, refresh, details, every row, and close; focus is visible and returns correctly; names and row semantics are meaningful at 100, 125, 150, and 200 percent DPI and in high contrast. | R-008 | L4 keyboard script, accessibility inspection, Narrator walkthrough |
| S-010 | Given a deterministic forced exception from either snapshot construction or evaluation after a loaded project exists, the coordinator shows the same privacy-safe `Unavailable` state, never `Ready`, leaves the project unchanged, and emits no readiness log or exception prose. The activation uses the bounded M0-approved dependency seam, not a global flag, environment trigger, or user switch. | R-004, R-007 | L4 mapper and evaluator branch activation plus project-state comparison |
| S-011 | Given a missing or unsupported source or a forced media-probe failure that aborts opening, the readiness adapter is not invoked, no prior ready result remains visible, and existing failure behavior is unchanged. | R-001, R-004 | L3 pre-adapter failure activation and outcome evidence |
| S-012 | Given the approved timing protocol, readiness evaluation and rendering add at most 100 ms at p95, median full-flow regression stays within 5 percent or 100 ms whichever allowance is larger, and 50 unchanged evaluations show no net process-handle growth. | R-009 | L5 recorded aggregate measurements |
| S-013 | The standalone harness builds and passes in x64 outside the solution with no package or application project reference and with all outputs under ignored `Source/obj/ReadinessTests/`. | R-010 | L0 project inspection and L1 recorded run |
| S-014 | `Source/StaxRip.sln` and direct `Source/StaxRip.vbproj` Debug and Release x64 gates pass, and configuration declarations remain x64-only. | R-010, R-012 | L0 XML and configuration scan, L2 build records |
| S-015 | The completed slice adds no persistence, migration, dependency, solution mapping, CI, release-script execution, package, portable archive, public binary, or x86 or Win32 configuration. | R-004, R-011, R-012 | L0 bounded diff and repository-status review |
| S-016 | In the human walkthrough, LynxTWO can identify current state, inspect reasons, correct one existing setting, refresh, and make a confident proceed-or-correct decision without reading logs. | A-001 | M4 human approval and U-011 closure |
| S-017 | Given the approved catalog coverage record, every overall status has bounded documented meaning and the evaluator never emits `Ready` while an authoritative required condition is unchecked or unknown. | R-001, R-002, R-003 | M0 catalog-coverage approval and L1 precedence vectors |
| S-018 | Given `isEncoding = True` or the existing `ProcessJob` source-opening path under the M0-approved isolated synthetic protocol, readiness snapshot, evaluation, and new summary or details presentation counts stay zero; the mapped pre-job action clears or hides any prior interactive result; existing job behavior and effective processing state remain equivalent; and the check stops before processing, tool launch, or output work. | R-001, R-004 | M0 call-path map, clear-owner and isolation-protocol approval, L3 production branch activation and outcome comparison |

## 9. Verification evidence required

Before Done, the source-bound evidence set under `Docs/Verification/SLICE-001/` contains or links:

- [ ] M0 catalog, interactive seam, full call-path, lifecycle, UI ownership, coordinator fault seam, fixture, and timing decisions with success tests and closed blocking unknowns.
- [ ] L0 static results for diff hygiene, XML, x64 configuration, prohibited boundaries, dependencies, logging, privacy fields, and documentation references.
- [ ] L1 standalone harness build and run covering each pure-model acceptance branch.
- [ ] L2 solution and direct managed Debug and Release x64 build records, with the existing Release solution mapping stated.
- [ ] L3 clean-environment walkthrough and canonical before-and-after contract comparisons for the approved fixed fixtures.
- [ ] L3 branch evidence for an aborted pre-readiness path, a failed later open with no stale ready result, zero snapshot, evaluation, or new presentation activation during `isEncoding = True` and the isolated synthetic job path, and the permitted pre-job clear or hide outcome. The evidence records the stopping point before processing, tool launch, or output work.
- [ ] L4 deterministic snapshot-mapper and evaluator `Unavailable` activation, explicit refresh, invalidation, project replacement, keyboard, focus, accessibility, high-contrast, DPI, and privacy evidence.
- [ ] L5 p95 overhead, median full-flow regression, and 50-evaluation handle results with aggregate machine facts and no private paths.
- [ ] Both approved script-engine paths where any retained catalog field depends on them.
- [ ] EDD section 17 close-out with checks, untested boundaries, unknowns, privacy, logging, approvals, documentation, and rollback.
- [ ] Human walkthrough completed and approved by LynxTWO.

Recorded local runs satisfy this source-only slice. Hosted CI is not required and is outside scope. An agent statement without the named artifact is not evidence.

## 10. Agent guardrails for this build

- **Boundary:** Only section 6 modules, section 7 transient data, and M0-approved files may change.
- **M0 stop gate:** Do not edit production feature files until the catalog, post-success seam, lifecycle, UI ownership, fixtures, and timing protocol are evidenced, logged, and approved.
- **Catalog stop gate:** Exclude any candidate fact that needs process execution, network, a new filesystem probe, log parsing, mutable access, or an unowned invalidation trigger. Ask before changing this rule.
- **Ready-claim stop gate:** Do not implement an overall `Ready` label until M0 proves the small catalog covers every authoritative condition required by that label. If it cannot, stop and revisit D-030.
- **Integration stop gate:** Do not use an in-transaction source-loaded event as proof of successful completion. Ask if no safe post-return owner exists.
- **Job-path stop gate:** Do not activate snapshot construction, evaluation, or new summary or details presentation from `isEncoding = True`, `ProcessJob`, or any M0-mapped non-interactive source-opening path. The only permitted readiness action is the M0-mapped synchronous clear or hide before job processing. Stop if the shared call graph cannot preserve this boundary and existing job behavior.
- **Job-evidence stop gate:** Do not use a real user job, queue, path, temp tree, or output for branch evidence. M0 must approve an isolated synthetic protocol and a stopping point before processing, tool launch, or output work. If no safe protocol exists without changing job behavior, do not run L3 job-path evidence and obtain a new decision.
- **Failure-seam stop gate:** Do not implement the coordinator until M0 approves one bounded dependency seam that deterministically forces both snapshot-mapper and evaluator failures without a global flag, environment trigger, user switch, package, or solution mapping.
- **Failure-scope stop gate:** Do not widen D-036 into a broad catch around publication, invalidation, refresh-command wiring, or rendering. If M0 evidence requires that behavior, record the existing path and obtain a new decision.
- **Protected boundaries:** Ask before persistence, deletion, overwrite, temp cleanup, process control, cancellation, retry, executable selection, download, command construction, native ABI, solution mapping, dependency, packaging, publication, or release work.
- **Build boundary:** D-024 permits normal production compile entries and the standalone test project only. It does not permit a solution project, package, configuration mapping, CI workflow, or release change.
- **Privacy boundary:** Add no readiness log. Do not copy paths, media names, titles, scripts, commands, exception prose, or arbitrary external output into the result, GUI, accessibility values, clipboard, fixtures, or failure packets.
- **Mode separation:** Run M0 discovery, each implementation milestone, and each verification level as separate work. A discovery result that changes scope returns to the Decision Log before implementation.
- **Conflict rule:** If source evidence contradicts this brief, stop, mark the specific contradiction as `verified`, `inferred`, or `unknown`, update the decision path, and obtain approval.
- **Script rule:** Do not run `Source/BuildAndPack.ps1` or `Source/Release.ps1`.

## 11. Slice definition of done

- [x] D-033 through D-036 are Confirmed and all later slice decisions have one valid status.
- [ ] M0 closes Q-001, Q-002, Q-003, Q-007, Q-008, Q-009, U-003, U-004, U-010, U-012, U-013, and U-014 before dependent production work.
- [ ] S-001 through S-018 pass with source-bound evidence.
- [ ] No unlabeled shortcut or stub exists inside the boundary.
- [ ] Root steering, Architecture, Engineering, Decision Log, Unknowns, Coverage Ledger, catalog, evidence index, and slice status agree.
- [ ] Security, privacy, logging, accessibility, failure, performance, compatibility, and rollback reviews are complete for touched paths.
- [ ] No public binary or release asset exists from this slice.
- [ ] LynxTWO completes the walkthrough and confirms that the readiness result supports a confident proceed-or-correct decision.
- [ ] Status changes to `Done with evidence`, ADD section 15 is updated, and the next slice remains unopened until close-out.

## 12. What this unlocks

- **Guided blocker repair:** Use stable readiness ids to route one approved corrective action without placing mutation in the evaluator.
- **Source-opening stage and progress model:** Use the timing protocol and safe lifecycle knowledge to expose progress, then optimize only measured stages.

These are candidates, not commitments. Release work remains separate until U-006 and U-009 close.

---

*Approved for M0 discovery by: LynxTWO, 2026-08-15. D-033 through D-036 are Confirmed. This approval does not authorize dependent production implementation before the M0 gates close. When section 11 closes with evidence, mark the status Done and update ADD section 15 before opening another brief.*
