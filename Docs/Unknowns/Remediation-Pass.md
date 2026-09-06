# Remediation Pass Unknowns

### Policy for VapourSynth frame-rate values above Int32

- **Area or file:** `Source/FrameServer/VapourSynthServer.cpp:109-113`, `Source/FrameServer/FrameServer.h:11-20`
- **Concern:** VapourSynth exposes a 64-bit rational, while the StaxRip ABI stores both components as 32-bit integers.
- **Why it matters:** Truncation can report a negative or incorrect frame rate to managed callers.
- **Evidence found so far:** VapourSynth R79 declares `fpsNum` and `fpsDen` as `int64_t` and requires a nonnegative reduced fraction. StaxRip assigns both directly to `int`. A target-toolchain probe reproduced negative results above `Int32.MaxValue`.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Obtain maintainer review of deterministic rejection in draft pull request #1988.
- **Risk level:** medium
- **Status:** open
- **Notes:** The user approved rejection without changing the COM layout. Commit `74e15053` passed the controlled overflow branch. Saturation would preserve neither the exact rational nor a reliable frame rate.

### Policy and test seam for VapourSynth stride above Int32

- **Area or file:** `Source/FrameServer/VapourSynthServer.cpp:169-199`, `Source/FrameServer/FrameServer.h:23-29`, `Source/Video/FrameServer.vb:81-97`
- **Concern:** VapourSynth returns `ptrdiff_t` stride, while the native and managed StaxRip interfaces expose a 32-bit pitch.
- **Why it matters:** A wrapped negative pitch reaches bitmap constructors and native drawing interfaces.
- **Evidence found so far:** The R79 API declares a positive `ptrdiff_t` stride. StaxRip assigns it directly to `int`. The target-toolchain probe converted `2147483648` to `-2147483648`.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Obtain maintainer review of the tested cleanup policy in draft pull request #1988. Keep the controlled oversized-stride branch because real runtimes do not provide a practical oversized frame fixture.
- **Risk level:** high
- **Status:** open
- **Notes:** The controlled double verified that the new branch frees the acquired frame once, clears the pointer and pitch, and returns `E_FAIL`. Normal R73 and R79 cases passed the representative runtime matrix.

### Exact real-runtime smoke tuple

- **Area or file:** `Source/FrameServer`, `Source/Video/FrameServer.vb`, and the ignored `Source/bin/Apps` runtime tree
- **Concern:** Compile checks and a controlled VSScript double verify native branches, but they do not establish compatibility with the runtime files shipped to users.
- **Why it matters:** Loader behavior, Python integration, plugin discovery, script evaluation, frame ownership, and error propagation depend on the exact staged runtime and host layout.
- **Evidence found so far:** The exact v2.52.5 release archive was downloaded from GitHub and matched GitHub's SHA-256 digest. It supplied AviSynth+ 3.7.5, VapourSynth R73, Python 3.13.9, AutoCrop, and the production directory layout. The official R79 archive also matched its published digest; its ABI3 wheel was paired with the packaged Python 3.13.9 runtime as a separate compatibility fixture. Native and packaged AutoCrop cases passed for both engine families.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Obtain maintainer review of draft pull requests #1987, #1988, and #1993. Re-run the recorded matrix when FrameServer, runtime versions, Python, LibP2P, or the packaged AutoCrop host changes.
- **Risk level:** medium
- **Status:** resolved
- **Notes:** Follow-up integration validation now covers portable startup, changelog dismissal, four representative GUI media workflows, ten bundled script/plugin cases, 5,000 lifecycle iterations per engine, and scratch release-equivalent packaging. It remains representative rather than exhaustive and does not cover arbitrary plugins/media/scripts, every GUI command, hardware encoders, live updates, or release publication.

### Whether the script synchronization body can block on the UI thread

- **Area or file:** `Source/Video/VideoScript.vb:289-317`, `Source/Forms/MainForm.vb:3763-3790`, `Source/General/GlobalClass.vb:1493-1506`
- **Concern:** The proposed fix for the chunk-encode race takes a lock around the guarded body. If anything inside that body waits on the UI thread, and the UI thread can call `Synchronize` and block on the same lock, the two deadlock.
- **Why it matters:** This decides whether the recommended smallest safe edit is safe at all. A deadlock here freezes the application during an encode, which is worse than the defect being fixed.
- **Evidence found so far:** The body calls `g.MainForm.Indexing()` at `VideoScript.vb:303`, which calls `g.ffmsindex` at `MainForm.vb:3780`, which runs an external process through `Proc`. Whether `Proc.Start` marshals to, or blocks on, the UI thread was not traced. UI-thread callers of `Synchronize` do exist: `PreviewForm.vb:304`, `CropForm.vb:282`, and `MainForm.vb:3760`. `SyncLock` uses `Monitor`, which is reentrant on the same thread, so the re-entry through `MainForm.vb:3765` is not itself a deadlock source.
- **Confidence:** verified for the enumerated call set; `inferred` for the whole program, because reachability was read from named call sites rather than produced by a call-graph tool.
- **Likely owner:** StaxRip maintainer
- **Next best check:** Done 2026-08-24. Full trace and scope limits in `Docs/Review/Evidence-Gap-Check.md`.
- **Risk level:** high
- **Status:** resolved
- **Notes:** **No deadlock cycle exists.** MainForm marshalling in `ProcController` is asynchronous (`BeginInvoke`, `ProcController.vb:873`). The one synchronous blocking `Invoke`, `ProcController.vb:934`, targets the `ProcessingForm` STA thread, and `ProcessingForm.vb` has no reference to `Synchronize`, `p.Script`, or `VideoScript`, so it cannot re-enter. `ProcController.vb` takes `SyncLock Procs` at six sites and likewise never calls `Synchronize`, so there is no AB-BA cycle. However, the same trace found two modal dialogs (`Package.vb:2976`, `Extensions.vb:634`) and one unbounded external wait (`Proc.vb:320`) inside the guarded body, so a lock held across the body freezes every UI-thread caller instead of deadlocking. That changed the recommended fix; see the revised backlog entry and approval packet.

### The secondary trigger for the synchronization guard is still untraced

- **Area or file:** `Source/Video/VideoScript.vb:289`
- **Concern:** The guard also fails when `Me.Error <> ""`, independently of the script text. No caller that leaves `Error` non-empty across a chunked encode has been traced.
- **Why it matters:** If that state is reachable during a chunked encode, the race triggers with no volatile macro present, which would make it far more common than the macro path suggests.
- **Evidence found so far:** The condition is the first term of the guard at `VideoScript.vb:289`. `Error` is assigned from `server.Error` at `VideoScript.vb:312` inside the same body. The probe primed `Error = ""` in every run and did not exercise this path.
- **Confidence:** unknown
- **Likely owner:** StaxRip maintainer
- **Next best check:** Done 2026-08-24. Full trace in `Docs/Review/Evidence-Gap-Check.md`.
- **Risk level:** low, reduced from medium
- **Status:** resolved
- **Notes:** **Not reachable in the chunk-encode window.** `ProcessJob` gates on `p.Script.Error <> ""` at `GlobalClass.vb:590-592` and throws before reaching the chunk path, only closure construction happens between that gate and `Parallel.Invoke`, and `Error` has one assignment inside `Synchronize` that requires the guard to have already failed. Before the cache-key fix the term acted as an amplifier rather than a trigger: a volatile macro let `:633` enter the body, where a frame-server error could set `Error` with no gate between `:633` and `:651`. That route is closed too.

### The managed application cannot be built in this environment

- **Area or file:** `Source/packages.config`, `Source/packages`, `Source/StaxRip.vbproj`
- **Concern:** No fix to the managed application can be compile-verified or probe-verified here, because the legacy project does not build.
- **Why it matters:** Every managed backlog item now depends on evidence that cannot be produced locally. Verification plans that assume a local build are not runnable, and saying so is part of the plan.
- **Evidence found so far:** `Source/packages` is not restored. `Source/packages.config` requires DirectN 1.5.0 and ManagedCuda-100. `AGENTS.md:53` forbids installing dependencies to satisfy a verification command. The runtime confirmation worked around this by driving the shipping v2.52.5 release binary by reflection, which proves defects in the shipped artifact but cannot verify a source change.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Done 2026-08-24. The user approved the restore. NuGet CLI 6.11.0 (SHA-256 `133b9c1efdc8d86bdccae9e296c9e4bc45a6d6472368611aa96b51b3e75fd2e3`) restored DirectN 1.5.0, ManagedCuda-100 10.0.31, and Microsoft.PowerShell.5.ReferenceAssemblies 1.1.0 into the ignored `Source/packages`. `Source/StaxRip.vbproj` then built Debug x64 and Release x64, both exit 0 with zero warnings.
- **Risk level:** medium
- **Status:** resolved
- **Notes:** The native FrameServer work was verifiable here because it builds independently of the managed package set. That is why earlier passes did not hit this wall. The native project still does not build here: it needs VapourSynth headers staged into the ignored runtime tree, which is a separate and still-open prerequisite.
