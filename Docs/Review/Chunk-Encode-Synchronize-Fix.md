# Fix record: the chunk-encode `Script.Synchronize()` race

`Chunk-Encode-Synchronize-Concurrency.md` established the defect by reading source.
`Chunk-Encode-Synchronize-Runtime-Confirmation.md` observed it against the shipping
binary. This is the fix and its verification. Applied 2026-08-24.

## What changed

One file, `Source/Video/VideoScript.vb`. Three lines of behavior plus a comment.

The guard at the top of the rewrite block is a cache check. It compared the
**macro-expanded** script text against `LastCode`. `%current_time%`, `%current_time24%`
and `%random%` expand to a new value on every call, so the comparison could never hold: a
cache keyed on a value that changes on every read can never hit. The key is now the script
text **before** expansion. The expanded text is still what gets written; only the
comparison key changed.

`LastCode` and `LastPath` are `<NonSerialized()>` and have no reader outside `Synchronize`,
so no on-disk format, no project compatibility, and no other call site is affected.

## Why not a lock

The first proposal was a `SyncLock` around the guarded body. A reachability trace, recorded
in `Evidence-Gap-Check.md`, established that such a lock would **not** deadlock. It was
withdrawn anyway, for what the same trace found instead:

- The guarded body can open two modal dialogs, `Package.VerifyOK` at `Package.vb:2976` and
  the retry-exhaustion path in `Extensions.WriteFile` at `Extensions.vb:634`.
- It can block for an entire external indexing run at `Proc.vb:320`.

A lock held across those freezes every UI-thread caller of `Synchronize` until a human
dismisses a dialog or the indexing finishes. It also addresses only two of the four
consequences. Repairing the cache key stops worker threads entering the body at all, which
closes all four with no lock and no new blocking.

That the dialogs are real was confirmed by accident: the first probe run held the script
file for 4 s, longer than the 1.5 s retry budget, and raised eight `IOException` dialogs
from worker threads. The successor probe holds the file for 500 ms for that reason.

## Verification

Two gates, under `Docs/Review/probes/`. Both are required; neither is sufficient alone.

### Gate 1: `chunk-sync-guard-probe.cs` (runtime)

Drives a built `StaxRip.exe` by reflection, eight threads released from a barrier. Body
entry is detected by holding the script file with `FileShare.None`: nothing before the
guard touches that file, so a blocked thread has necessarily passed the guard.

It checks two invariants, because either alone can be satisfied by a wrong fix.

- **Guard A**, no race: with the cache primed as a completed synchronization leaves it,
  concurrent callers must not enter the body.
- **Guard B**, still fresh: a genuinely changed script must still be rewritten. Without
  this, a fix that disables the guard passes Guard A while leaving a stale script on disk.

| check | before the fix | after the fix |
|---|---|---|
| A1 control, plain script, primed raw | 0 of 8 | 0 of 8 |
| A2 control, plain script, primed expanded | 0 of 8 | 0 of 8 |
| **A3 volatile macro, primed raw** | **8 of 8 FAIL** | **0 of 8 PASS** |
| B1 changed script, stale cache | 8 of 8 | 8 of 8 |
| B2 changed script, stale cache, volatile macro | 8 of 8 | 8 of 8 |

The probe was run against an unmodified local build first and reproduced the published
result, so the later green is a change in the code and not a change in the harness.

### Gate 2: `chunk-sync-static-check.ps1` (static)

Asserts that the identifier compared against `LastCode` is the identifier assigned to it,
and that it is not the macro-expanded variable.

This gate exists because of a surviving mutant, described below. It is not redundant.

### Mutation results

Each mutation was applied to the committed tree, rebuilt, gated, and reverted.

| mutation | Gate 1 | Gate 2 |
|---|---|---|
| M1 compare the expanded text again | caught | caught |
| M2 store the expanded text in the cache | **survived** | caught |
| M3 disable the guard entirely | caught (B1, B2) | not applicable |
| original pre-fix state | caught (A3) | caught |

**M2 is a missing test, not an equivalent mutant.** `LastCode = code` while the guard
compares the unexpanded key means the cache never hits in production, so `Synchronize`
rewrites on every call and the race returns, yet Gate 1 stays green. Gate 1 cannot see it:
the assignment sits after the frame-server round-trip, which a reflection probe can never
complete, so the probe always throws before reaching the line. Gate 2 was written to close
exactly that gap and was confirmed to fail on M2, on M1, and on the original pre-fix state.

The session closed with a green run of both gates on the exact tree that ships, after the
last mutation was reverted and the project rebuilt.

### Builds

`Source/StaxRip.vbproj` Debug x64 and Release x64, both exit 0 with zero warnings and zero
errors. Package restore of DirectN 1.5.0, ManagedCuda-100 10.0.31, and
Microsoft.PowerShell.5.ReferenceAssemblies 1.1.0 was approved by the user on 2026-08-24 and
removes the build blocker recorded in `Docs/Unknowns/Remediation-Pass.md`.

The native `Source/FrameServer` project was not built. It needs VapourSynth headers staged
into the ignored runtime tree, and this change does not touch it.

## What this fix does not do

- **It does not run a real chunked encode.** There is no source video here and the native
  frame server was not built. That chunk workers call `Synchronize` concurrently remains
  established by source reading, not by execution.
- **The `Error <> ""` trigger was traced on 2026-08-24 and is not reachable here**, so this
  is no longer an open gap. `ProcessJob` throws at `GlobalClass.vb:590-592` if the script
  reports an error, only closure construction happens between that gate and
  `Parallel.Invoke` at `:651`, and `Error` has a single assignment inside `Synchronize` that
  requires the guard to have already failed. Before this fix the term amplified the macro
  trigger rather than acting alone: a volatile macro let `:633` enter the body, where a
  frame-server error could set `Error` with no gate before `:651`.
- **It does not fix the cross-thread Windows Forms access.** `g.MainForm.Indexing()` at
  `VideoScript.vb:310` and `ProcController.vb:914-916` still touch controls with no
  marshalling. The guard now keeps worker threads out of that path, so the defect is much
  harder to reach, but it is not repaired. It stays open as its own backlog item. Note that
  `ProcessJob` runs on the UI thread and `Parallel.Invoke` uses its calling thread as one of
  the workers, so one chunk action runs on the UI thread and the rest do not. That defect
  would therefore present intermittently rather than reliably.
- **It does not measure how often users hit this.** The probe injects the trigger. Nothing
  here says how common a volatile macro in filter code is.
