# Remediation Backlog

This backlog covers the bounded FrameServer warning and build-output investigations at commit `198223ea`. It does not claim coverage of the rest of the native component or the complete release process.

## Items

### Make Win32 string conversion results explicit

- **Bucket:** approval-gated
- **Area or slice:** `Source/FrameServer/Common.cpp:6-49`
- **Risk level:** medium
- **Why it matters:** Script paths and native error text currently depend on unchecked Win32 conversion results.
- **Evidence found:** A Release x64 rebuild reported seven C4267 warnings in `Common.cpp`. The baseline probe showed that both wide-to-multibyte helpers returned payload bytes after `WideCharToMultiByte` returned 0 with `ERROR_INSUFFICIENT_BUFFER`; an embedded NUL was not preserved. `GetWinErrorMessage` returned a 2,048-byte string with NUL padding. Commit `d8dfc00f` fixed the probe and removed all seven warnings in draft pull request #1987.
- **Confidence:** verified
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** Use a checked `int` source length for both conversion calls, use the same source-length mode for sizing and writing, verify the returned count, and resize the error string to the count returned by `FormatMessageA`.
- **Verification capability ids:** V03, V08, V10, V11, V19, V20
- **Reproducer:** `.anti-dark-code/scratch/common-baseline-probe.cpp`; differential output in `.anti-dark-code/scratch/results/frameserver-warning-baseline/common-current-probe-run.log` and `.anti-dark-code/scratch/results/fix-string-conversions/common-current-probe-run.log`
- **Verification plan:** Completed for ASCII, Unicode, embedded NUL, empty input, and Windows error text. FrameServer and the main solution passed Debug and Release x64; only the three independent VapourSynth warnings remained on this branch.
- **Failure packet:** `.anti-dark-code/scratch/results/frameserver-warning-baseline/`
- **Invalidation trigger:** Changes to `Common.cpp`, `Common.h`, native project language settings, or a caller's string-encoding contract.
- **Rollback note:** Revert the single `Common.cpp` change.
- **Observability note:** Error text is now an exact-length string instead of a fixed buffer with NUL padding. No logging changed.
- **Owner:** StaxRip maintainer
- **Status:** fixed

### Reject VapourSynth metadata that does not fit the managed ABI

- **Bucket:** approval-gated
- **Area or slice:** `Source/FrameServer/VapourSynthServer.cpp:109-113`, `Source/FrameServer/VapourSynthServer.cpp:169-199`, `Source/FrameServer/FrameServer.h:11-29`, `Source/Video/FrameServer.vb:81-97`
- **Risk level:** high
- **Why it matters:** A frame-rate component or stride above `Int32.MaxValue` wraps negative before managed callers use it for arithmetic or bitmap construction.
- **Evidence found:** Release x64 reported three C4244 warnings. VapourSynth R79 declares frame-rate fields as `int64_t` and stride as `ptrdiff_t`; the StaxRip COM layout uses `int`. The target-toolchain probe converted `2147483648` to `-2147483648`. Commit `74e15053` rejected both overflow paths and removed all three warnings in draft pull request #1988.
- **Confidence:** verified
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** Preserve the COM layout, reject frame-rate components or stride that exceed `Int32.MaxValue`, retain an exact error, and release the acquired frame before returning a stride-range failure.
- **Verification capability ids:** V03, V08, V10, V11, V19, V20
- **Reproducer:** `.anti-dark-code/scratch/frameserver-boundary-probe.cpp` and `.anti-dark-code/scratch/vapoursynth-fake-runtime.cpp`; differential output under `.anti-dark-code/scratch/results/fix-vapoursynth-narrowing/`
- **Verification plan:** Completed with normal, frame-rate-overflow, and stride-overflow branches in separate x64 processes. FrameServer and the main solution passed Debug and Release x64. Real VapourSynth runtime and x86 coverage remain unknown.
- **Failure packet:** `.anti-dark-code/scratch/results/frameserver-warning-baseline/`
- **Invalidation trigger:** Changes to `ServerInfo`, `IFrameServer`, the managed interop declarations, the VapourSynth API level, or frame ownership in `GetFrame`.
- **Rollback note:** Revert the single `VapourSynthServer.cpp` change. The ABI layout remains unchanged either way.
- **Observability note:** Rejected values retain fixed `GetError` text without a path, script, or media value. No logging changed.
- **Owner:** StaxRip maintainer
- **Status:** fixed

### Put FrameServer x64 intermediates in the existing ignored tree

- **Bucket:** approval-gated
- **Area or slice:** `Source/FrameServer/FrameServer.vcxproj:74-99`, `.gitignore:10-11`
- **Risk level:** low
- **Why it matters:** A normal x64 build leaves compiler intermediates as untracked files, which obscures source changes and requires manual cleanup.
- **Evidence found:** The evaluated x64 `IntDir` values are `FrameServer\x64\Debug\` and `FrameServer\x64\Release\`. They created 42 untracked files under `Source/FrameServer/FrameServer/x64`. The Win32 configurations explicitly use `$(Platform)\$(Configuration)\`, and `.gitignore` already excludes `Source/FrameServer/x64`. Concrete `x64\Debug\` and `x64\Release\` command-line overrides produced the intended ignored paths. Both targeted builds passed and left the integration worktree clean. Commit `bf855df7` applies the two project values in draft pull request #1989.
- **Confidence:** verified
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** Add `<IntDir>$(Platform)\$(Configuration)\</IntDir>` to the Debug x64 and Release x64 property groups. Do not broaden `.gitignore`.
- **Verification capability ids:** V03, V10, V11
- **Reproducer:** Baseline files under `.anti-dark-code/scratch/build-v2.52.5/Source/FrameServer/FrameServer/x64`; concrete override builds in `.anti-dark-code/scratch/integration-native-fixes`
- **Verification plan:** Rebuild FrameServer in Debug and Release x64, confirm both evaluated `IntDir` values, confirm `FrameServer.dll` still targets `Source/bin`, and require a clean tracked and untracked status outside ignored output.
- **Failure packet:** `.anti-dark-code/scratch/results/frameserver-warning-baseline/` plus the retained baseline worktree
- **Invalidation trigger:** Changes to `FrameServer.vcxproj`, Visual C++ default intermediate paths, or the FrameServer ignore rules.
- **Rollback note:** Remove the two x64 `IntDir` elements.
- **Observability note:** None. The change only relocates compiler intermediates.
- **Owner:** StaxRip maintainer
- **Status:** fixed

### Preserve the AutoCrop artifact workflow until its staging policy is known

- **Bucket:** needs more evidence
- **Area or slice:** `Source/Tools/AutoCrop/AutoCrop.vbproj:42-75`, `Source/Tools/AutoCrop/bin/x64/Release`, `Source/*.ps1`
- **Risk level:** medium
- **Why it matters:** A Release x64 rebuild changes a tracked executable and PDB. Redirecting that output could stop deliberate artifact updates, while leaving the policy unexplained can lead contributors to commit unrelated binary changes.
- **Evidence found:** The Release x64 target path is the tracked `bin/x64/Release` directory, while Debug x64 targets the ignored portable Apps tree. A baseline Release rebuild changed the tracked executable and PDB blobs without changing their sizes. The binary pair was added with an AutoCrop source fix in 2024 and updated with five later AutoCrop feature commits. A scan of 275 tracked text files found the relevant build paths only in `AutoCrop.vbproj`; no tracked build or release script invokes `AutoCrop.sln` or stages its Release directory.
- **Confidence:** unknown
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** Keep the project and tracked binaries unchanged. Ask the maintainer whether the committed Release files are the canonical AutoCrop artifact and how they enter `Source/bin/Apps/Support/AutoCrop` before packaging.
- **Verification capability ids:** V03, V10, V11
- **Reproducer:** `.anti-dark-code/scratch/build-v2.52.5` and `.anti-dark-code/scratch/results/autocrop-direct-release/msbuild.log`
- **Verification plan:** Once the staging procedure is known, rebuild the intended configuration, bind source and artifact hashes, and compare the staged AutoCrop files with the package inputs. Keep the 738,815,433-byte official release archive comparison optional until it is needed.
- **Failure packet:** The retained detached baseline worktree contains the modified tracked blobs.
- **Invalidation trigger:** Changes to `AutoCrop.vbproj`, tracked AutoCrop binaries, package staging, or release scripts.
- **Rollback note:** No source edit is proposed. Revert only a separately approved future policy change.
- **Observability note:** None. AutoCrop was not executed.
- **Owner:** StaxRip maintainer
- **Status:** deferred

### Remove the unused updater architecture parameter

- **Bucket:** approval-gated
- **Area or slice:** `Source/General/StaxRipUpdate.vb:41`, `Source/General/GlobalCommands.vb:17`, `Source/Forms/MainForm.vb:6076`
- **Risk level:** low
- **Why it matters:** Both update-check callers still pass the process architecture, suggesting that release selection varies by architecture even though the callee ignores the value and only recognizes x64 archives.
- **Evidence found:** `CheckForUpdateAsync` declared an optional `x64` parameter that was never read. Its release-asset regular expression hard-codes `-x64`. A complete call-site search found only two callers, both passing `Environment.Is64BitProcess`. The current GitHub release inventory contained no asset named x86 or 32-bit. Commit `29a8ab27` removed the parameter and arguments in draft pull request #1990.
- **Confidence:** verified
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** Remove only the unused `x64` parameter and the second argument at its two call sites. Do not change the release regular expression, package architecture selection, project configurations, or other x86 remnants.
- **Verification capability ids:** V03, V10, V11
- **Reproducer:** `rg -n "CheckForUpdateAsync" Source` plus direct inspection of `Source/General/StaxRipUpdate.vb:41-114`
- **Verification plan:** Require a three-file source diff, confirm all remaining call sites match the simplified signature, and rebuild the main StaxRip project in Debug and Release x64. Record that no live GitHub update interaction was exercised.
- **Failure packet:** None. Both supported x64 compile gates passed.
- **Invalidation trigger:** Changes to `CheckForUpdateAsync`, its callers, the release filename convention, or a renewed 32-bit release policy.
- **Rollback note:** Restore the optional parameter and both explicit architecture arguments.
- **Observability note:** None. The removed value currently has no control-flow or data-flow use.
- **Owner:** StaxRip maintainer
- **Status:** fixed

### Clarify log attachment privacy in the bug form

- **Bucket:** safe-to-fix now
- **Area or slice:** `.github/ISSUE_TEMPLATE/01-bug_report.yml:52-55`
- **Risk level:** medium
- **Why it matters:** The current form points reporters to a raw job log without warning that it can contain paths, scripts, command lines, media details, external-tool output, and machine information.
- **Evidence found:** The central log writes raw text and the issue form pointed to that file. The UI offers `Save Obfuscated As`. A synthetic replay verified that this export replaces the current source directory and base name but retains an unrelated target path and machine detail. Commit `62ba4d86` updates the guidance in draft pull request #1991.
- **Confidence:** verified
- **Approval needed:** no
- **Recommended next pass:** 04, then 06
- **Smallest safe next step:** Change only the issue-form guidance. Direct users to `Project > Log File` and `Save Obfuscated As`, state its limit, and tell them to review the file before attachment.
- **Verification capability ids:** V03, V10, V11
- **Reproducer:** Synthetic path probe from the 2026-08-10 log-sharing audit; results summarized in `Docs/Security/Logging-Audit.md`.
- **Verification plan:** Parse the issue form as YAML, run `git diff --check`, and require a one-file documentation diff. Do not claim runtime redaction coverage.
- **Failure packet:** None.
- **Invalidation trigger:** Changes to `LogForm`, `ObfuscateLogFile`, log payloads, or the bug-report form.
- **Rollback note:** Restore the previous additional-information description.
- **Observability note:** None. The patch changes public guidance, not logging.
- **Owner:** StaxRip maintainer
- **Status:** fixed

### Keep the VapourSynth library alive for the process lifetime

- **Bucket:** approval-gated
- **Area or slice:** `Source/FrameServer/VapourSynthServer.cpp:4-109`, `Source/FrameServer/VapourSynthServer.cpp:262-284`, `Source/FrameServer/VapourSynthServer.h:17-29`
- **Risk level:** high
- **Why it matters:** Sequential frame-server use can terminate StaxRip after the first VapourSynth server releases its dynamic-library handle.
- **Evidence found:** `OpenFile` resolved `getVSScriptAPI` once into a process-wide pointer and set a process-wide `wasResolved` flag, but `Free` unloaded the library through a per-instance handle. The unchanged build failed all three controlled lifecycle cases. A first per-instance repair passed packaged R73 but failed R79 sequential initialization. Commit `eec333a3` retains one validated module and entry point for the process lifetime in draft pull request #1993.
- **Confidence:** verified
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** Serialize module initialization, retain one validated module and entry point until process exit, and keep failed loads or entry-point resolution retryable without changing the COM layout.
- **Verification capability ids:** V03, V08, V10, V11, V19, V20
- **Reproducer:** `.anti-dark-code/scratch/frameserver-reopen-probe.cpp`; executable under `.anti-dark-code/scratch/results/frameserver-reopen-probe/`; controlled runtime under `.anti-dark-code/scratch/results/fix-vapoursynth-narrowing/fake-runtime/`
- **Verification plan:** Completed four controlled lifecycle cases, including retry after a missing runtime becomes available; four isolated x64 builds; 10 packaged R73/AviSynth native cases; four packaged AutoCrop cases; five R79 native cases; two R79 AutoCrop cases; and the combined zero-warning build and runtime gates with pull requests #1987 and #1988.
- **Failure packet:** `.anti-dark-code/scratch/results/frameserver-reopen-probe/` plus the exact terminal result recorded in `Docs/Verification/FrameServer-Runtime-Gate.md`
- **Invalidation trigger:** Changes to `OpenFile`, `Free`, dynamic-library ownership, server creation, or the VSScript entry-point contract.
- **Rollback note:** Revert the two-file native lifetime change.
- **Observability note:** No logging change is proposed. Existing error reporting remains in place for load and initialization failures.
- **Owner:** StaxRip maintainer
- **Status:** fixed

## Holes and external boundaries

- The official VapourSynth R79 API and source establish the wide source types, but StaxRip does not pin R79.
- The exact v2.52.5 package supplied the production-like R73, AviSynth+ 3.7.5, Python 3.13.9, and AutoCrop host fixture. The R79 compatibility fixture was staged separately and is not a claim about shipped contents.
- The controlled runtime remains the branch-activation oracle for overflow and lifecycle failure paths that real fixtures do not produce on demand.
- The repository does not reveal how the committed AutoCrop Release files enter the ignored portable Apps tree or the published archive.
- The supported x64 release path is established, but the maintainer has not confirmed whether all retained x86 configuration and runtime branches should be removed.

## Changelog

- 2026-08-10 - Added the two findings reproduced during the FrameServer Release warning investigation.
- 2026-08-10 - Verified commits `d8dfc00f` and `74e15053`, opened draft pull requests #1987 and #1988, and confirmed that both commits together build Release x64 with zero warnings.
- 2026-08-10 - Verified the FrameServer x64 intermediate-path cause and deferred AutoCrop policy changes pending maintainer intent.
- 2026-08-10 - User approved the FrameServer build edit; commit `bf855df7` passed both x64 configurations and opened draft pull request #1989.
- 2026-08-10 - Mapped the unsupported x86 paths and isolated the unused updater architecture argument as the smallest behavior-preserving cleanup.
- 2026-08-10 - User approved the updater cleanup; commit `29a8ab27` passed both direct StaxRip x64 configurations and opened draft pull request #1990.
- 2026-08-10 - Completed the bounded log-sharing audit and prepared a one-file bug-form privacy clarification.
- 2026-08-10 - Commit `62ba4d86` passed YAML and patch-scope checks and opened draft pull request #1991.
- 2026-08-11 - Reframed the unbounded runtime-coverage statement as a representative smoke matrix and verified a separate sequential VapourSynth server lifetime failure.
- 2026-08-11 - User approved all three actions. Phase 1 opened as draft pull request #1992, the process-lifetime repair opened as #1993, and the pinned R73, AviSynth, R79, and managed-host runtime matrix passed.

### Serialize the script synchronization guard against concurrent chunk-encode callers

- **Bucket:** approval-gated
- **Area or slice:** `Source/Video/VideoScript.vb:287-317`, `Source/General/GlobalClass.vb:631-651`, `Source/General/Extensions.vb:622-638`
- **Risk level:** high
- **Why it matters:** During a chunked encode several encoder workers call `VideoScript.Synchronize` at the same time. A volatile macro anywhere in the script defeats the guard that normally makes those calls a no-op, so every worker runs the guarded body together. Four consequences follow. They write the same script file, which sends colliding writers into a ten-attempt retry at 150 ms and then a modal exception dialog raised from a worker thread. They read and write `Info`, `OriginalInfo`, `Error`, `LastCode`, and `LastPath` without synchronization. They call Windows Forms methods from a worker thread, at two separate sites. And they corrupt the process PATH: `FrameServerFactory.Create` calls `g.AddToPath`, which is a read-modify-write of the `path` environment variable with no synchronization, so concurrent callers lose each other's additions and a frame server can start without a directory it needs.
- **Evidence found:** `GlobalClass.vb:633` synchronizes once on the coordinating thread and then hands chunk actions to `Parallel.Invoke` at `GlobalClass.vb:651` with `MaxDegreeOfParallelism = s.ParallelProcsNum`. Each chunk action reaches `Synchronize(False, True, False)` through its encoder's `Encode`. The guard at `VideoScript.vb:289` short-circuits only while `Error = ""`, `code = LastCode`, and `Path = LastPath`. `code` is the output of `Macro.Expand` at `VideoScript.vb:287`, and `Macro.vb:354-355` and `Macro.vb:600-601` define three macros whose expansion changes between calls: `%current_time%`, `%current_time24%`, and `%random%` or `%random:N%`. With any of them present `code <> LastCode` holds on every call, so the guard can never short-circuit. A probe drove the shipping v2.52.5 x64 release binary by reflection. Experiment A confirmed the expansion is unstable across calls on that binary. Experiment B: 0 of 4 threads entered the body for a plain script, 4 of 4 entered with one macro added. Experiment C held the script file open with `FileShare.None` and counted 0 of 8 threads inside the body for the control and 8 of 8 for the treatment.
- **Confidence:** verified
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** **Revised 2026-08-24 after the reachability trace in `Docs/Review/Evidence-Gap-Check.md`. A lock is no longer the recommendation.** Make the guard's comparison deterministic instead. `LastCode` caches the output of `Macro.Expand` at `VideoScript.vb:287`, and the guard compares a freshly expanded value against that cache. When the script contains a time or random macro the two can never match, so the cache is keyed on a value that changes on every read. Fixing the key restores the short-circuit, which stops worker threads from entering the body at all and closes every consequence at once, with no lock and no new blocking. The earlier proposal, a `SyncLock` around `VideoScript.vb:289-317`, was traced and will not deadlock, but the body contains two modal dialogs and one unbounded external wait, so holding a lock across it freezes every UI-thread caller of `Synchronize` for as long as a dialog goes unanswered or an indexing job runs. Serializing also fixes only two of the four consequences. The exact form of the deterministic key is the maintainer's decision; three workable candidates and one that looks workable but is not are set out in the approval packet.
- **Verification capability ids:** V03, V10, V11, V19, V20, and V15. V15 is recorded as `deferred` in `calibration/verification-plan.json`; the barrier probe already exercises it for this item, so the plan entry should move to `selected` if this fix proceeds.
- **Reproducer:** `Docs/Review/probes/chunk-sync-probe.cs` and `Docs/Review/probes/chunk-sync-probe-run.log` on branch `agent/chunk-sync-runtime-proof`.
- **Verification plan:** Re-run the barrier probe against a build carrying the lock. Experiment C must report 0 of 8 threads simultaneously inside the body for the treatment case while the control stays at 0 of 8. Ship a revert-mutation check in the same change: remove the `SyncLock`, confirm the probe returns 8 of 8, restore it, confirm 0 of 8, and record the red run before the fix lands. Building StaxRip from source is currently blocked in this environment, so none of this can run here yet; see the unknowns entry.
- **Failure packet:** `Docs/Review/probes/chunk-sync-probe-run.log`
- **Invalidation trigger:** Changes to `Synchronize`, to the guard fields `Error`, `LastCode`, or `LastPath`, to the retry behavior in `Extensions.WriteFile`, to `GetChunkEncodeActions`, or to the `ParallelProcsNum` default.
- **Rollback note:** Depends on the chosen key form, but all candidates are confined to the guard expression and the `LastCode` assignment in one file.
- **Observability note:** Colliding callers stop reaching the ten-retry path in `Extensions.WriteFile:622-638`, so the exception dialog that path raises at line 634 from a worker thread no longer appears. No logging changes.
- **Owner:** StaxRip maintainer
- **Status:** fixed
- **Resolution:** Commit `b37202b2` on `agent/chunk-sync-guard-fix` keys the cache on the unexpanded script text. Two gates ship with it, `Docs/Review/probes/chunk-sync-guard-probe.cs` and `Docs/Review/probes/chunk-sync-static-check.ps1`. The race check went from 8 of 8 threads inside the body to 0 of 8, freshness checks stayed at 8 of 8, and Debug and Release x64 both build with zero warnings. One mutation survived the runtime probe and was closed by the static gate rather than waved through. Full record in `Docs/Review/Chunk-Encode-Synchronize-Fix.md`.

### Stop the synchronization body from touching Windows Forms controls on a worker thread

- **Bucket:** approval-gated
- **Area or slice:** `Source/Video/VideoScript.vb:303`, `Source/Forms/MainForm.vb:3763-3790`, `Source/General/ProcController.vb:914-916`
- **Risk level:** high
- **Why it matters:** The guarded body calls `g.MainForm.Indexing()`. That method assigns `tbSourceFile.Text` at `MainForm.vb:3773` and `MainForm.vb:3786` with no marshalling to the UI thread. During a chunked encode the caller is a `Parallel.Invoke` worker, so the assignment is a cross-thread control access.
- **Evidence found:** There are two unmarshalled sites, not one. Besides the `tbSourceFile.Text` writes in `Indexing`, `ProcController.vb:914-916` reads `g.MainForm.Visible` and calls `g.MainForm.Hide()` directly. **Correction, 2026-08-24:** an earlier version of this entry said these accesses throw `InvalidOperationException`, reasoning that `CheckForIllegalCrossThreadCalls` is absent from `Source/` and so keeps a default of `True`. That is wrong. The framework initialises the flag to `Debugger.IsAttached`, so it is `False` for users and the accesses are silent. Measured with a positive control; see `Docs/Review/Evidence-Gap-Check.md`. The real failure mode is undefined Windows Forms behaviour, which may work, corrupt control state, or stall the message loop, and which reproduces under a debugger but not for a user. It therefore keeps its framework default of `True`, under which a cross-thread control property write throws `InvalidOperationException`. `Indexing` also calls `p.Script.Synchronize(False, False)` at `MainForm.vb:3765`, so the guarded body can re-enter the method it is already inside. The probe never reached `Indexing`; execution faulted earlier at the `Package.AviSynth.VerifyOK` check at `VideoScript.vb:296` because the probe process has no initialized package catalogue.
- **Confidence:** inferred. The call reaching a worker thread is established from source and from the confirmed guard failure. The resulting throw was never observed, because the probe could not get that far.
- **Approval needed:** yes
- **Recommended next pass:** 11
- **Smallest safe next step:** No edit yet. This needs the maintainer to choose between marshalling the two control assignments inside `Indexing` to the UI thread and hoisting the `Indexing` call out of `Synchronize` for callers that have already run it. The two options differ in what they change for the roughly fifty other `Synchronize` call sites, so the choice is not a detail. Serializing the body, the item above, does not fix this: it makes the workers take turns, and each turn still runs on a worker thread.
- **Verification capability ids:** V03, V10, V11, V19, V20
- **Reproducer:** None yet. The existing probe stops short of this line. A reproducer needs an initialized package catalogue or a stub that satisfies `Package.VerifyOK`.
- **Verification plan:** Not yet designable. It depends on which of the two options is chosen, and on the build blocker recorded in the unknowns file.
- **Failure packet:** None. The path was never executed.
- **Invalidation trigger:** Changes to `Indexing`, to the `Synchronize` body, or to any explicit `CheckForIllegalCrossThreadCalls` assignment.
- **Rollback note:** No edit is proposed, so nothing to roll back.
- **Observability note:** None yet.
- **Owner:** StaxRip maintainer
- **Status:** open
- **Note added 2026-08-24:** Downgraded after two traces. The cache-key fix keeps worker threads out of the `Indexing` path, and the `Error <> ""` trigger was separately shown not to be reachable during a chunked encode, so that route is closed rather than merely narrowed. The `ProcController` site is not reached either: `ProcessJob` hides the main form at `GlobalClass.vb:599` before `Parallel.Invoke` at `:651`, so `Visible` is already `False` and the `Hide()` write is skipped. The surviving access is a `Visible` read, which does not throw under any setting. **Recommendation: do not fix now.** Both sites are latent rather than live, and a fix would be unverifiable against a path nothing currently reaches. Revisit if the main form ever stays visible during a job, or if another caller reaches `Indexing` off the UI thread.
- **Risk level revised:** medium, reduced from high.
