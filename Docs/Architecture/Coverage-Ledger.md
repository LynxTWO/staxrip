# StaxRip Community Coverage Ledger

Version: 0.1 Draft. Date: 2026-08-15. Repository base: `9fc6255a`.

This ledger records risk-ranked review coverage. It does not convert partial inspection, a clean build, or one workflow into a whole-repository claim. Confidence uses only `verified`, `inferred`, or `unknown`.

| Area | Risk | Confidence | Evidence covered | Boundary not covered | Next check and owner |
|---|---|---|---|---|---|
| x64 solution and project graph | High | verified | Project XML parsed; configuration declarations are x64-only; direct managed Debug and Release x64 builds and solution Debug and Release x64 builds passed at the fork baseline | Publish targets and remaining ClickOnce metadata | U-009 release-slice owner maps publish behavior before cleanup |
| Source-opening transaction | High | verified | `Source/Forms/MainForm.vb:2289-2342` and `2469-2889` map entry routing, state changes, tools, events, and the outer exception boundary | A safe call site after the whole transaction and branch activation for every exit | U-010 seam spike proves success, abort, and failure activation before adapter work |
| Shared source-opening activation | High | verified | `Source/General/GlobalClass.vb:561` invokes `OpenVideoSourceFiles` with `isEncoding := True` during `ProcessJob`; the shared overload begins at `Source/Forms/MainForm.vb:2477` | Complete interactive, job, batch, recovery, and encoding call graph; the pre-job clear or hide owner; and an isolated synthetic job-path evidence protocol that stops before processing, tool launch, or output work | U-013 call-path spike closes these boundaries before adapter work; M2 and L3 later prove production activation and outcomes |
| Readiness catalog and snapshot mapping | High | unknown | Architecture and Engineering define a read-only typed target; D-032 selects a five-to-eight-check posture with one correctable blocker; D-034 forbids `Ready` when an authoritative condition is unchecked | Final fields, owners, side effects, severity, precedence, lifecycle, bounds, and complete overall-status authority | U-003 catalog spike closes before model implementation |
| Readiness invalidation and refresh | High | unknown | `Source/Forms/MainForm.vb:4693-4738` and `4931-4942` show relevant state can change after source opening; D-031 selects explicit refresh and mandatory invalidation | Trigger ownership, project replacement, failed later open, and stale-result safeguards | U-012 lifecycle spike closes before adapter or GUI implementation |
| Current fatal UI exception route for readiness integration | High | verified | Uncaught UI exceptions can reach the global fatal handler through `Source/Forms/MainForm.vb:993` and `Source/General/GlobalClass.vb:1591,1650-1655`; D-036 selects a narrower coordinator target for future snapshot and evaluator work | The coordinator does not exist; mapper and evaluator production activation remain untested; publication, invalidation, refresh-command wiring, and rendering recovery remain outside the D-036 catch | U-014 fault-seam spike demonstrates the design in an ignored disposable probe before adapter work; M2 and L4 later prove production activation and outcomes |
| Unexpected source-opening failure | High | verified | `Source/Forms/MainForm.vb:2881-2883` calls the global handler; `Source/General/GlobalClass.vb:1569-1591` attempts recovery and diagnostics and terminates for a non-abort exception | Retained project, settings, recovery-file, and log state at injected failure points | U-005 recovery-slice owner performs separate failure injection before recovery changes |
| Project, settings, template, profile, and job persistence | High | unknown | Planning guardrails name these as compatibility surfaces and exclude changes from `SLICE-001` | Format readers, writers, migrations, repair, and downgrade behavior | Map only when a separately approved persistence slice touches them |
| External commands and process control | High | unknown | Planning maps `Proc`, `ProcController`, and `Package` as protected owners; `SLICE-001` forbids new execution or selection | Escaping, cancellation, retry, inherited environment, and outcome behavior across tools | A later command or process slice owns focused mapping and deterministic probes |
| Native FrameServer boundary | High | verified | `Source/FrameServer/FrameServer.vcxproj` is x64-only and built in both solution configurations | ABI, registration, script-engine ownership, inter-process lifetime, and failure injection | Separate native-boundary approval and harness before behavior changes |
| Existing WinForms layout and accessibility precedents | High | verified | Scoped source review found current layout, menu, `ButtonEx`, `DataGridViewEx`, and scaling precedents, and found no explicit accessibility-property precedent in managed UI candidates | The readiness GUI does not exist; runtime UI Automation, Narrator, focus, high contrast, and 100 through 200 percent DPI behavior remain untested | U-010 prototype owner performs L4 inspection before production form edits |
| Existing logging exposure and readiness privacy decision | High | verified | Selected source-opening paths write full paths, media summaries, generated scripts, and arbitrary errors; D-026 forbids new readiness logs and raw exception output | The readiness feature does not exist; whole-repository runtime flow of debug, trace, tool, and support content is not covered | Privacy sentinels and bounded output review cover `SLICE-001`; broader logging audit remains separate |
| Test-harness inventory and ownership decision | Medium | verified | Scoped project scan found no MSTest, NUnit, xUnit, or existing automated unit project; D-024 approves a standalone source-linked x64 VB harness | The harness does not exist or run yet; presentation and integration sit outside its pure boundary | `SLICE-001` verification owner builds L1 after U-003 closes and pairs it with L2 through L5 |
| Source-opening timing and handle baseline | Medium | unknown | Numeric p95, median-regression, and 50-evaluation handle targets are confirmed | Fixture representativeness, stage boundaries, warmup, repetitions, and current measurements | U-004 timing spike records the pre-change protocol and baseline |
| Build, packaging, and public release | High | unknown | Local source builds and source-only deployment posture are verified; protected release scripts were not run | Reproducible portable assembly, tool provenance, signing, publication, and downgrade | U-006 and U-009 remain release-slice blockers |
| Planning and repository steering | Medium | verified | Root `AGENTS.md` is tracked; Architecture and Engineering sections are filled; Decision Log index and entries are consistent through D-036; D-033 through D-036 and `../Planning/SLICE-001.md` have human approval; `../Planning/PHASE-6-AUDIT.md` records the final pass | M0 evidence and later runtime behavior remain unverified | Begin M0 discovery; its gates block dependent production implementation |

Update this ledger when a touched path gains or loses evidence. A higher confidence in one row does not imply coverage of adjacent rows.

## Anti-dark-code audit slices

This section carries the slice ledger from the anti-dark-code passes. It separates verified observations from configured, inferred, and unbounded behavior. Evidence is current for upstream base `198223ea`, the private integrated x64 candidate described in `Docs/Verification/Portable-X64-Validation.md`, and the fork tree named in each row.

| Slice | Evidence | Status | Re-run trigger |
| --- | --- | --- | --- |
| Main solution Debug/Release x64 | direct isolated rebuilds | verified | solution, project, dependency, or shared source change |
| AutoCrop Debug/Release x64 | direct isolated rebuilds | verified | AutoCrop project/source change |
| x86/Win32 configuration retirement | solution parsing, property evaluation, rejection checks, six x64 builds | verified on Phase 1 | solution/project configuration change |
| x64 runtime branch cleanup | diff audit, IL and compatibility probes, integrated build/runtime | verified on Phase 2 | package/update/startup architecture change |
| FrameServer controlled lifecycle | missing runtime, retry, script failure, overlap, sequential cases | verified | native lifetime/loader change |
| Packaged AviSynth/VapourSynth | real runtimes, plugins, scripts, representative frames | verified for fixtures | runtime, Python, plugin, or ABI change |
| StaxRip GUI startup | isolated settings, changelog dismissal, responsive main form, clean exit | verified for v2.52.5 candidate | startup, settings, TaskDialog, or main-form change |
| GUI media opening | AVC/AAC, VP9/Opus, 10-bit FFV1/PCM, VFR FFV1 | verified for fixtures | source opening, MediaInfo, demux, script generation, or template change |
| Lifecycle/resource soak | 5,000 sessions per engine, flat handles, bounded memory | verified for fixtures | FrameServer/runtime/plugin change |
| Release copy/exclusion contract | exact filtered scratch copy and sentinel paths | verified | `Release.ps1`, Apps layout, or exclusions change |
| Full and EXE archive integrity | exact 7-Zip parameters, test, manifest closure, hashes | verified in scratch | binary/package/archive setting change |
| Release publication | no external upload or release command | not tested | maintainer-controlled release rehearsal |
| Hardware encoding | no NVENC/QSV/AMF encode on physical devices | not tested | dedicated hardware matrix |
| Arbitrary media/plugins/scripts | synthetic representative corpus only | unbounded | curated regression additions |
| Network and tool updates | static source review only | configured/inferred | isolated update sandbox |
| Failure recovery | selected invalid-script/loader paths only | partial | cancellation, disk-full, process-crash harness |
| Persistence and jobs | source mapping and mutex/retry review | inferred/partial | deterministic state-model harness |
| Approved gate runs on the fork tree | `adc.py gates --allow-exec` at levels 1 and 3 on 2026-09-06 (runs under `.anti-dark-code/runs/`): whitespace, AutoCrop Debug x64, main solution Debug and Release x64 passed on `603db71d`; AutoCrop Release x64 was marked stale because it rewrites tracked binaries (finding F-001) | verified for that tree | any change to the bound solution or project files, which also requires a gate rebind |

The absence of a checked-in test project and CI workflow remains a maintenance risk.
Private probes and evidence improve confidence but do not replace a small upstream
verification harness.

The absence of a checked-in test project and CI workflow remains a maintenance risk. Private probes and evidence improve confidence but do not replace a small upstream verification harness; `Docs/Review/CI-Proposal.md` proposes the first step.
