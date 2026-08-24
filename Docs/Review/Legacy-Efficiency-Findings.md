# Legacy Efficiency and Correctness Findings

Version: 1.0. Date: 2026-08-22. Scope: the shipping Windows application under `Source/`.

Every entry below was read from committed source on the date above and carries the line
citations that support it.

**Status as of 2026-08-22:** F-001 and F-002 are FIXED, under the maintainer's explicit
approval given that day for these named `Source/` edits. F-003 is deliberately not fixed;
its entry explains why. Each entry still states which approval gate its fix crosses.

**The fixes are not on this branch, and cannot be.** They live on
`agent/vulkan-probe-and-md5-waste`, branched from `master`. The first attempt applied them
here and the static gate refused the tree with `scope-source-unchanged`: this branch
asserts that `Source/` is byte-identical to the fork base, which is the additive-portability
rule from `AGENTS.md` enforced by a check rather than left to discipline. That is the gate
working. A Windows application bug fix and a Linux port are different changes with
different reviewers and different build requirements, and mixing them would have made both
harder to review while quietly voiding the invariant every other gate on this branch
depends on. This file records the findings; that branch carries the code.

**Verification limit on the two fixes, stated plainly.** The legacy project does not
build in this environment: `Source/packages.config` requires DirectN 1.5.0,
ManagedCuda-100, and the PowerShell reference assemblies, none of which are restored, and
`AGENTS.md` forbids installing dependencies to satisfy a verification command. What was
done instead is a diagnostic comparison. Building with and without the two edits produces
byte-identical error sets, 14 errors both times, every one of them a missing DirectN type
in `Source/Video/VideoRenderer.vb` and none in the edited files. Because the VB compiler
binds the whole compilation unit and emits diagnostics for all of it, a syntax error or an
`Option Strict` violation in the edited files would appear in that list beside the DirectN
errors. It does not. That is real evidence the edits parse and bind, and it is **not** a
successful build, a run, or a behavioral test. Neither fix should be considered verified
until the packages are restored and the project compiles.

Two claims that were investigated and did **not** survive are recorded at the end. They
are kept deliberately, so they are not raised again as though they were new.

None of these findings is a performance measurement. The repository has no performance
baseline at all, recorded as P-014, so no entry here claims a speedup. They are defects
with a cost argument, not benchmarked wins.

## F-001: The Vulkan support probe never caches success and leaks an instance per call

Status: FIXED 2026-08-22. Severity: high. Class: native resource leak. Gate crossed: none
of the listed gates directly, but the probe feeds `RequirementsFunc` entries in the
package catalogue, so a behavior change there touches executable selection.

`Vulkan.IsSupported` (`Source/General/General.vb:1524-1553`) memoizes into a shared
field declared as `Private Shared _result As VkResult = Nothing`
(`Source/General/General.vb:1511`) and guards its work with `If _result = Nothing`
(`:1527`). `VkResult.Success` is `0` (`Source/General/Misc.vb:4533`), and the `Nothing`
initializer for an enum is also `0`. The success assignment at `:1546` therefore writes
the exact value the guard treats as "not yet computed".

The consequence is that the cache works only for failure. On a machine without Vulkan the
probe runs once, stores `ErrorInitializationFailed`, and short-circuits forever after. On
a machine **with** Vulkan, every single read re-enters the block, resolves
`vkCreateInstance`, and creates a fresh `VkInstance` at `:1536`. `vkDestroyInstance`
appears nowhere in the tree, so no instance is ever destroyed. Each successful read of a
property leaks a Vulkan instance and its driver-side allocations, and the users who leak
are exactly the users whose hardware works.

The property is read from four places, none of which look like a one-time probe:
`Source/General/Project.vb:55` initializes `CropWithTonemapping` from it, so every
`Project` constructed runs it; `Source/Forms/MainForm_ShowOptions.vb:116` and `:118` read
it twice while building one options page; and
`Source/General/Package.vb:1404` and `:1414` read it inside `RequirementsFunc` lambdas
for the two libplacebo plugins, which run on requirement checks.

The smallest correct fix is a sentinel that cannot collide with a valid result, such as a
separate `Boolean?` or an explicit `NotProbed` member outside the `VkResult` value space,
plus destroying the instance once the device count has been read. Both halves are needed:
the sentinel alone would stop the leak growing but would still leak the one instance, and
destroying alone would leave the redundant probing.

**Fix as applied.** The memoized field is now `Private Shared _isSupported As Boolean?`,
a type in which "not probed yet" is representable and cannot be confused with any verdict.
The probe body moved out of the `If` and the property returns early when the value is
already known, so the guard no longer depends on comparing a result against a sentinel at
all. `vkDestroyInstanceDelegate` was added and the instance handle now lives outside the
`Try` so a `Finally` can release it on every path, including the throws that mean the
probe failed after the instance already existed. The destroy call is itself wrapped,
because a failed teardown must not convert a good verdict into an exception, and must not
overwrite the verdict: losing one instance is the old behavior, and losing the answer
would be worse than the bug.

Deliberately not changed: the property is still not thread-safe, exactly as before. Two
concurrent first readers can both probe, and with the fix both now destroy what they
created, so the race wastes work rather than leaking. Adding synchronization would be a
behavior change beyond this finding and belongs to whoever measures the contention.

## F-002: `MD5Hash` computes the hash twice and discards the first result

Status: FIXED 2026-08-22. Severity: low. Class: wasted work. Gate crossed: none.

`Source/General/Extensions.vb:896-901`:

```vbnet
Function MD5Hash(instance As String) As String
    Using m = MD5.Create()
        Dim inputBuffer = Encoding.UTF8.GetBytes(instance)
        Dim hashBuffer = m.ComputeHash(inputBuffer)
        Return BitConverter.ToString(m.ComputeHash(inputBuffer))
    End Using
End Function
```

`hashBuffer` is assigned and never read. The `Return` calls `ComputeHash` a second time
on the same input. The function is correct, and exactly twice as expensive as it needs to
be.

This is small, and it is included because it is unambiguous, it is a one-line fix with no
behavioral risk, and it is the kind of thing that a first-time contributor can land
safely. It is not a performance claim: no caller has been measured.

**Fix as applied.** The dead local is gone and the single surviving `ComputeHash` call
feeds the `Return` directly. The output is identical by construction: same algorithm, same
input bytes, same formatting call. No caller changes.

## F-003: `MediaInfo.ClearCache` has no callers, and a memory-pressure workaround sits nearby

Status: NOT FIXED. Measured 2026-08-22, and the measurement changed what the fix is worth.
Severity: **low**, reduced from medium once the cost was known. Class: dead invalidation
path. Gate a fix would cross: process coordination and shared resources, because the
memory workaround is part of process lifetime management.

The approval to change `Source/` covered this finding. It was left alone pending
measurement rather than fixed on a guess, and that was the right call: the measurement
refuted the reason the finding looked important. The cache leaks 57.7 KB per entry and
`ClearCache` would reclaim 91 percent of it, so a fix is cheap and would work. It is also
worth far less than this entry originally implied, because the cache is not what drives the
1500 MB recycling. Wiring it up remains a reasonable small improvement; presenting it as a
fix for the recycling workaround would be false.

`Shared Sub ClearCache()` is declared at `Source/General/MediaInfo.vb:432`. A search of
the entire `Source/` tree for `ClearCache` returns exactly one hit, that declaration.
Nothing calls it. The media-info cache therefore only grows for the life of the process.

**MEASURED 2026-08-22, and the hypothesis below is refuted.** The measurement F-003 was
waiting for has been taken, so the entry now reports numbers instead of a guess.

What the cache retains, read from `MediaInfo.vb:414-438`: a `ConcurrentDictionary` keyed on
path concatenated with `LastWriteTime.Ticks`, holding `MediaInfo` instances that each own a
native handle from `MediaInfo_New`. `Dispose` closes and deletes that handle and a
finalizer calls it, but the static dictionary roots every instance, so the finalizer can
never run. The key means a rewritten file does not replace its entry, it adds one.

Measured by retaining 300 opened native handles, since the product's own class cannot be
loaded in isolation (see below):

| | Result |
|---|---|
| Private memory per retained entry | **57.7 KB** |
| 300 entries | +17,312 KB |
| OS handle count | **unchanged**, so this is native heap, not a Win32 handle leak |
| Reclaimed by close and delete, which is what `ClearCache` does | **91 percent** |
| Entries needed to reach the 1500 MB recycle threshold from the cache alone | **about 26,600** |

**The hypothesis is refuted by that last row.** A job would have to probe roughly 26,600
distinct path-and-timestamp pairs before this cache alone reached the threshold the
process-recycling workaround exists to survive. A large batch might produce a few hundred
entries, which is tens of megabytes, not fifteen hundred. So the cache is a real leak and
is **not** the explanation for the recycling. Whatever drives that growth is still
unidentified, and this entry no longer claims otherwise.

That changes the recommendation rather than settling it. Calling `ClearCache` somewhere
principled would reclaim 91 percent of a cost that is small, which is a modest and safe
win; it would not remove the recycling workaround, and anyone who wires it up expecting
that will be disappointed. Finding what actually drives the growth needs a memory profile
over a long batch and is separate work.

**Incidental finding, recorded because it is a portability fact.** `StaxRip.MediaInfo`
cannot be loaded and called in isolation: its static graph reaches `StaxRip.Package`, whose
type initializer throws outside a real application environment. That is why the numbers
above were taken against the native library directly rather than through the product class.
A port that expects to lift media inspection out on its own will meet this first, and it is
the same entangled-static-state problem P-001 records for the workflow boundary.

What follows is the original context, and the hypothesis the measurement above refuted.

The context is verified. `Source/General/GlobalClass.vb:516-519` recycles the whole
process between jobs: when `PrivateMemorySize64` exceeds 1500 MB, the application
launches a fresh copy of itself with `-StartJobs -NoFocus`, saves the project, and closes
the running instance. Restarting the program is the application's answer to its own
memory growth, and it is on the normal batch path, not an error path.

The hypothesis, which is not a finding: an unbounded metadata cache with no reachable
invalidation is a plausible contributor to the growth that recycling exists to survive.
Confirming or refuting that link needs the P-014 measurement harness plus a memory
profile over a long batch; it cannot be settled by reading.

The recycle is also a portability item independent of the cache. Relaunching by
`ShellExecute` on the executable path and handing off through saved project state is a
Windows-shaped mechanism, and any portable engine has to either reproduce that handoff or
remove the need for it.

The right sequence is measurement first. Wiring up `ClearCache` without knowing what the
cache actually costs would be a change justified by a guess, and if the hypothesis is
wrong it would add invalidation bugs while leaving the real growth in place.

## Investigated and not supported

Both entries below came from an earlier informal inventory and were checked against the
source on 2026-08-22. Neither holds *as stated*. They are recorded so the same wrong lead
does not get re-opened.

Read the 2026-08-24 updates inside each entry before skipping this section. Both claims
were wrong about their mechanism but pointed at something real, and the follow-up trace
confirmed a concurrency defect in the shipping application. "Not supported as stated" was
the correct verdict on the wording; it was not a verdict on the underlying behaviour.

**Claimed: `x264Enc` calls `Script.Synchronize()` unconditionally from parallel chunk
workers while `x265Enc` guards it.** Not supported. `Source/Encoding/x264Enc.vb:101` and
`Source/Encoding/x265Enc.vb:126` sit at the same position in their respective `Encode`
overloads and do the same thing, and the same call appears at the head of essentially
every encoder in `Source/Encoding/`. There is no asymmetry between the two encoders. The
underlying question of whether chunk workers can call `Synchronize` concurrently is a
real one; it is separate from this claim, and answering it means tracing
`GetChunkEncodeActions`, not comparing these two files.

**Update, 2026-08-24: that question is now answered — yes, they can.** The trace is
`Docs/Review/Chunk-Encode-Synchronize-Concurrency.md` on branch
`agent/chunk-encode-synchronize-race` (not on this branch). Summary: `CanChunkEncode()`
returns `Chunks > 1`, so the chunk branch only runs with two or more actions, and each
calls `Encode`, whose first statement is `p.Script.Synchronize()` on the one shared
`VideoScript`. `Synchronize` is an unsynchronized check-then-act over five plain public
fields. A guard normally makes each worker's call a no-op — which is why this has never
been reported — but the compared value is recomputed through `Macro.Expand` on every
call, so a volatile macro (`%current_time%`, `%random:N%`) in user script or filter code
defeats it permanently. No shipped default contains such a macro, which bounds severity.
The finding is a source reading, not an execution; it has not been reproduced at runtime.

**Claimed: `MainForm.Indexing()` writes WinForms controls with no `Invoke` from
`Parallel.Invoke` workers.** Not supported as stated. `Parallel.Invoke` does not appear
in `Source/Forms/MainForm.vb` at all. `Indexing()` is at `:3833` and does write
`tbSourceFile.Text` at `:3848` and `:3866`, but nothing establishes that it runs off the
UI thread. The application's one `Parallel.Invoke` is at
`Source/General/GlobalClass.vb:651`; whether `Indexing()` is reachable from it has not
been traced, so there is no cross-thread finding here, only an untraced path.

**Update, 2026-08-24: the path is now traced, and it is reachable.** The claim was right
about the destination and wrong about the route, which is why searching `MainForm.vb` for
`Parallel.Invoke` found nothing — the call arrives indirectly:
`GlobalClass.vb:651` -> chunk-encode action -> `x264Enc.Encode` -> `p.Script.Synchronize()`
-> `VideoScript.vb:303` -> `g.MainForm.Indexing()`. So `Indexing()` does run on a
`Parallel.Invoke` worker whenever the guard inside `Synchronize` does not short-circuit.
The conditions for that, and the reason it is rarely hit, are in
`Docs/Review/Chunk-Encode-Synchronize-Concurrency.md` on branch
`agent/chunk-encode-synchronize-race`. Not reproduced at runtime.

## Related records

- `Docs/Review/Chunk-Encode-Synchronize-Concurrency.md` on branch
  `agent/chunk-encode-synchronize-race`: the trace that closed both entries in
  "Investigated and not supported". Read-only; no fix proposed; not reproduced at runtime.
- P-014 in `Docs/Unknowns/Portability-Unknowns.md`: no performance baseline exists, which
  is why nothing here is stated as a speedup.
- `Source/General/GlobalClass.vb:622-651`: audio processing, subtitle cutting, and video
  chunk encoding are all appended to one `actions` list and run under a single
  `Parallel.Invoke` bounded by `s.ParallelProcsNum`, default `3`
  (`Source/General/ApplicationSettings.vb:70`). That shared budget is a candidate lever
  recorded in P-014, not a finding here, because it has not been measured.
