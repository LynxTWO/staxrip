# SLICE-001 M0 Activation and Lifecycle Map

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Static map complete; evidence contract revised by Confirmed D-037.

## Source-opening overloads

| Symbol | Behavior | Confidence |
|---|---|---|
| `OpenVideoSourceFile(fp, demux, timeout)` | Forwards to the three-argument multi-file wrapper | verified: `Source/Forms/MainForm.vb:2469-2470` |
| `OpenVideoSourceFiles(files, demux, timeout)` | Forwards to the shared overload with `isEncoding = False` | verified: `Source/Forms/MainForm.vb:2473-2474` |
| `OpenVideoSourceFiles(files, demuxSource, isEncoding, timeout)` | Owns the shared source transaction | verified: `Source/Forms/MainForm.vb:2477-2890` |

Static `rg` enumeration found every repository call in `MainForm.vb`, `GlobalCommands.vb`, and `GlobalClass.vb`. Public or reflection consumers outside the repository remain unknown.

## Caller classification

| Route | Context | `isEncoding` | Evidence | Confidence |
|---|---|---:|---|---|
| `OpenAnyFile` video and fallback routes | Command-line file, file drop, source double-click, or direct UI routing | False | `Source/Forms/MainForm.vb:2289-2356,5013-5053,5437-5457,6017-6029` | verified |
| Single-file dialog | Interactive, optional template selection | False | `Source/Forms/MainForm.vb:5088-5113` | verified |
| Multiple-file dialog | Interactive, optional template selection | False | `Source/Forms/MainForm.vb:5115-5141` | verified |
| Merge dialog, MPEG or VOB | Interactive direct open | False | `Source/Forms/MainForm.vb:5201-5216` | verified |
| Merge dialog, other input | Interactive open after `mkvmerge` work | False | `Source/Forms/MainForm.vb:5217-5258` | verified |
| eac3to result | Interactive open after an external demux, with `demux = False` | False | `Source/Forms/MainForm.vb:5390-5415` | verified |
| Source text change | Foreground control route; project/source updates suppress the handler | False | `Source/Forms/MainForm.vb:5801-5806,1824-1826,2821-2823` | verified |
| Four `GlobalCommands.LoadSource*` wrappers | Command-manager route; may run from UI, command line, script, or event command | False | `Source/General/GlobalCommands.vb:551-575` | verified |
| Batch job `ProcessJob` | Non-interactive shared transaction | True | `Source/General/GlobalClass.vb:542-572` | verified |
| Extra-source child process | Shared source opening starts another StaxRip with `-NoFocus -LoadSourceFiles`; the child wrapper supplies False | False in child | `Source/Forms/MainForm.vb:2850-2858,5013-5053,6059-6071`; `Source/General/GlobalCommands.vb:565-575` | verified |
| Batch job creation | Serializes a cloned project; does not open the media at creation time | Not applicable | `Source/Forms/MainForm.vb:1607-1635,5261-5290` | verified |
| Abort and recovery | Internal to the shared source transaction; replaces project state | Retains caller context | `Source/Forms/MainForm.vb:2480-2496,2871-2883` | verified |

## Hidden job reentrancy

`isEncoding` is not sufficient for D-035.

1. The default global source commands always call the wrapper that supplies `False` at `Source/General/GlobalCommands.vb:551-575`.
2. MainForm registers those commands in the shared command manager at `Source/Forms/MainForm.vb:1054-1057`.
3. `RaiseAppEvent` can invoke registered commands at `Source/General/GlobalClass.vb:1369-1402`.
4. Job processing sets `g.IsJobProcessing = True` before loading and processing a job at `Source/General/GlobalClass.vb:492-503`.
5. Job events run at `Source/General/GlobalClass.vb:549,572` and later stages.

**verified:** A configured job event can invoke a default source command whose local `isEncoding` argument is `False` while the application is still processing a job.

Completion-only flags are not sufficient. `WhileProcessing` can dispatch an event command with `Task.Run` at `Source/General/ProcController.vb:686-693`; command reflection does not marshal at `Source/General/General.vb:1130-1144`. A command can start during a job and complete after job flags reset. Source events can also load a replacement project before the outer transaction publishes.

The final pure activation policy takes only these primitive inputs:

```text
transactionSucceeded
remainingSourceOpenDepth
isEncoding
enteredOnUiThread
jobProcessingAtEntry
jobProcessingAtCompletion
batchModeAtEntry
batchModeAtCompletion
startupNoFocusCommandSuppressed
sameProjectAtCompletion
```

It returns true only when the transaction succeeded, remaining depth is zero, `isEncoding` is False, entry occurred on the MainForm UI thread, job and batch flags were False at entry and completion, the startup `-NoFocus` command scope was not active, and `ReferenceEquals(projectAtEntry, p)` is true at completion.

The policy began as an M0 design result. The current M1 harness covers 8,192 activation vectors across source and mutation depths `-1`, `0`, `1`, and `2`. M2 production-source assertions verify the seam and clear owners. Real interactive activation remains L3 evidence.

## Success-only seam

No current event marks completion of the whole source transaction:

- `AfterSourceOpened`, Assistant, `AfterSourceLoaded`, `AfterProjectOrSourceLoaded`, and `Log.Save` all run inside the main `Try` at `Source/Forms/MainForm.vb:2865-2870`.
- Abort recovery is in the following `Catch` at `Source/Forms/MainForm.vb:2871-2880`.
- Unexpected failure calls the fatal route at `Source/Forms/MainForm.vb:2881-2883` and `Source/General/GlobalClass.vb:1564-1592`.
- The interactive abort branch returns normally from this `Sub`, so an outer caller cannot infer success from return alone.

The smallest proposed seam is **inferred**:

1. Clear or hide a prior transient result at shared-overload entry, before save cancellation or source work.
2. After the save-cancel gate, capture project identity, `isEncoding`, UI-thread affinity, job state, batch state, and the scoped startup suppression flag.
3. Increment an instance source-open depth with `Interlocked.Increment` immediately before the existing main `Try`.
4. Set a local success Boolean only after existing `Log.Save` at line 2870.
5. Decrement source depth and end the clearing mutation in the existing `Finally`, before `ProcController.Finished`. Keep process cleanup in an inner `Finally` so cleanup cannot skip feature-owned balance.
6. After the complete `Try/Catch/Finally`, capture completion job, batch, depth, and project-identity facts and call the coordinator only when the pure policy passes.

M2 also hardens each mutation Begin wrapper: if its immediate presentation render throws before the caller can enter the normal `Try/Finally`, the wrapper ends the exact mutation it began and rethrows. This preserves coordinator depth without widening the mapper/evaluator catch.

An `Exit Sub` in the existing batch branch at `Source/Forms/MainForm.vb:2700-2703` executes `Finally` and skips the post-transaction coordinator. Abort and failure leave success false. Snapshot mapping and evaluation occur outside the source-opening catch, which preserves D-036.

The atomic depth condition matters because source events can synchronously dispatch another source command and processing events can dispatch on a worker. A nested or overlapping transaction must not publish while another transaction remains active. `enteredOnUiThread` rejects the mapped worker-event route even if job flags later reset.

## Startup child suppression

The extra-source child already receives `-NoFocus` at `Source/Forms/MainForm.vb:2852-2858`. Startup commands run synchronously in `ProcessCommandLine` at `Source/Forms/MainForm.vb:5013-5053`, which `OnShown` calls at lines 6059-6071.

The smallest conservative design uses no new command-line argument:

1. At `ProcessCommandLine` entry, scope an instance Boolean in `Try/Finally` from whether the parsed arguments contain exact `-NoFocus` text, case-insensitive.
2. Capture that Boolean at shared source entry and pass it to the pure policy.
3. Restore its prior value when `ProcessCommandLine` exits.

This suppresses the initial child load, `-StartJobs -NoFocus`, and a user's explicit initial `-NoFocus` source command. It does not suppress later GUI opens in that process, an ordinary command-line file open without `-NoFocus`, or the `s.StartWithoutFocus` preference. Treating `-NoFocus` as a process-lifetime flag or using the setting would suppress unrelated later interactive work.

## Lifecycle invalidation owners

| Transition or candidate input | Existing mutation owner | Proposed invalidation owner | Confidence and limit |
|---|---|---|---|
| New source-open attempt | All routes converge on the shared overload | Shared-overload entry before `SetLastModifiedTemplate` | verified owner |
| Project replacement, failure reset, job load, or job restore | The string overload assigns global `p` at lines 1751 and 1754; the object overload assigns it at line 1786 | Clear after the string overload's save-cancel gate and before its first assignment; clear again immediately before the object-overload assignment | verified owners; must tolerate startup and repeated fallback calls, `Source/Forms/MainForm.vb:1023-1061,1739-1786` |
| Failed or aborted later source open | New-open clear plus project replacement | No success publication; replacement clears again | verified path, runtime outcome unknown |
| Source identity used by the final catalog | Project load, shared source transaction, demux, and later Indexing | New-open and project-replacement owners cover project load, source open, and demux; invalidate immediately before each actual Indexing assignment | verified repository writes: `Source/Forms/MainForm.vb:1821,2522-2523,3738-3744,3771,3784,3813,3846`; Indexing is reachable from `Source/Video/VideoScript.vb:289-305` |
| Script and filter state | `VideoScript.Changed` flows through `FiltersListView.Changed` | Existing MainForm filter-change subscription | verified common route: `Source/Video/VideoScript.vb:81-139`, `Source/Controls/FiltersListView.vb:30-34,250-316`, `Source/Forms/MainForm.vb:1086-1088`; direct mutations still need audit |
| Target path | `Project.TargetFile` raises `PropertyChanged` | `ProjectPropertyChanged` for `TargetFile` | verified: `Source/General/Project.vb:277-299`, `Source/Forms/MainForm.vb:1710-1721` |
| Video encoder selection | `g.LoadVideoEncoder` | Before encoder assignment | verified: `Source/General/GlobalClass.vb:1204-1218` |
| Muxer selection or accepted configuration | `VideoEncoder.LoadMuxer` and `OpenMuxerConfigDialog` | Before muxer assignment | verified: `Source/Encoding/VideoEncoder.vb:358-390` |
| In-app package and tool changes | Apps and Settings dialogs | Dialog-close invalidation is possible | inferred: `Source/Forms/MainForm.vb:3959-3980`, `Source/Forms/MainForm_ShowSettings.vb:464-496`; external tool changes remain unobservable |
| Assistant state | `Assistant` and `StartEncoding` | No complete safe owner | unknown: `Source/Forms/MainForm_Assistant.vb:8-28,124-127,465-484`, `Source/Forms/MainForm.vb:3485-3488` |
| Free disk space | Windows drive state | None | verified live external state: `Source/Forms/MainForm.vb:3458-3481` |

The final catalog and exact repository-owned mutation map are approved in `M0-CATALOG.md`. Script/filter, package, disk, job, output, and polymorphic muxer-compatibility candidates are excluded.

## Pre-job clear

A job-specific edit to `GlobalClass.ProcessJobs` is unnecessary:

- `ProcessJobsRecursive` sets `g.IsJobProcessing = True` and calls `OpenProject(jobPath, False)` before `ProcessJob` at `Source/General/GlobalClass.vb:492-503`.
- General project-replacement invalidation therefore clears a prior result before job source work.
- Shared source-open entry invalidation clears again for the batch source call at `Source/General/GlobalClass.vb:561`.

Both actions are synchronous state clears. They construct no snapshot, run no evaluator, and publish no new summary or details.

## Job evidence stop

No safe real-job protocol meets the superseded S-018:

- The real call enters full source opening at `Source/General/GlobalClass.vb:561`.
- That transaction can verify packages, demux, extract metadata, run subtitle work, initialize the muxer, spawn another StaxRip process, or run a compressibility check at `Source/Forms/MainForm.vb:2603-2605,2723-2743,2811-2863`.
- `BeforeProcessing` occurs only after source opening returns at `Source/General/GlobalClass.vb:572`.

**verified:** A successful real `ProcessJob` trip cannot both reach the proposed post-success policy and stop before source-opening tool or output work.

Confirmed D-037 revises S-018 to use the complete static caller map, a source-linked pure activation-policy test, and focused production checks at the mapped project-replacement and source-entry clear owners. These checks do not prove production runtime counts or job-state equivalence, and the slice makes no such claim. U-013 closes for the M0 evidence contract. Actual successful job execution needs a later isolated tool-boundary approval.

The deterministic production-source check must assert that:

- all three global `p` assignments remain behind the mapped project clear;
- the shared four-argument source overload starts with a no-throw clear;
- the false wrapper still passes `False` and `ProcessJob` still passes `True`;
- the extra-source child command still contains `-NoFocus`;
- transaction success is assigned only after the existing final `Log.Save`;
- evaluation remains after the entire `Try/Catch/Finally`;
- the scoped startup suppression is restored in `Finally`.

## Result

- Static caller enumeration is complete for repository source.
- The success seam and activation predicate are source-backed designs, not runtime proof.
- Pre-job clear ownership is mapped without a job-specific edit.
- A safe successful real-job protocol is not available under current constraints and is no longer required by revised S-018.
- Production source files were unchanged during this M0 mapping pass. Current production changes and their deterministic evidence are in `M2-INTEGRATION.md`.
