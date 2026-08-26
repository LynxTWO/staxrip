# Runtime confirmation: chunk-encode workers and `Script.Synchronize()`

`Docs/Review/Chunk-Encode-Synchronize-Concurrency.md` established the defect by reading
source and closed with an explicit limit: *"the race is demonstrated by construction from
the source, not observed."* This is the observation. It was run on 2026-08-24.

**Result: confirmed, and one claim in the source reading was wrong.** The correction is in
"What the run changed" below and has been applied to the original document.

## What was actually run, and against what

The probe drives the **shipping v2.52.5 x64 release binary** —
`StaxRip.exe`, `StaxRip, Version=2.52.5.0` — by reflection. Nothing was compiled from
source, and no file under `Source/` was modified.

That was not the original plan. The plan was to add a thread-id log line at
`VideoScript.vb:290` and rebuild. **The legacy project cannot be built in this
environment**: `Source/packages` is not restored, `Source/packages.config` requires
DirectN 1.5.0 and ManagedCuda-100, and `AGENTS.md:53` forbids installing dependencies to
satisfy a verification command. Driving the released binary is the stronger evidence
anyway — it tests the artifact users actually run, not a locally patched build.

- Probe source: `Docs/Review/probes/chunk-sync-probe.cs`
- Full output: `Docs/Review/probes/chunk-sync-probe-run.log`
- Binary under test:
  `.anti-dark-code/scratch/portable-validation/release-extracted/StaxRip-v2.52.5-x64/StaxRip.exe`
- Built with Roslyn `csc.exe` from VS 2022 BuildTools, `-platform:x64`, referencing the
  release binary; run with that release directory as the working directory so its
  dependencies resolve.

The globals `p`, `s`, and `g` are public static fields on `StaxRip.ShortcutModule`, and
`LastCode`, `LastPath`, `Error`, and `Info` are public instance fields on
`StaxRip.VideoScript`. No private state had to be forced.

### How body entry is detected without instrumenting the body

The guarded body begins by writing the script file and, a few statements later, calls
`g.MainForm.Indexing()`. `g.MainForm` is null in the probe process, so any thread that
reaches the body faults. A thread that short-circuits returns silently. **No exception
means the guard held; a fault or a file write means it did not.** That is the entire
signal, and it needs nothing injected into `Synchronize`.

Each run primes the cache exactly as the real pre-synchronize at `GlobalClass.vb:633`
leaves it — `Error = ""`, `LastCode` = the expanded script text, `LastPath` = `Path` —
and then calls `Synchronize(False, True, False)`, the same argument triple the chunk
workers use via `Encode`.

Every experiment is run twice: once with a plain script (**control**) and once with the
same script plus a volatile macro (**treatment**). Only that one token differs.

## Experiment A — is `Macro.Expand` stable across calls?

The guard compares freshly expanded code against `LastCode`, so a value that changes
between calls defeats it permanently. Two calls, ~1.1s apart:

| script text | call 1 | call 2 | stable |
|---|---|---|---|
| `BlankClip()` | `BlankClip()` | `BlankClip()` | **yes** |
| `BlankClip() # %current_time%` | `# 12-23-38` | `# 12-23-39` | **no** |
| `BlankClip() # %random:6%` | `# 865108` | `# 398401` | **no** |

Confirmed on the shipping binary. `LastCode` can only ever hold a previous call's value,
so with either macro present `code <> LastCode` is true on every call, forever.

## Experiment B — do concurrent callers enter the guarded body?

Four threads released from a barrier simultaneously.

**Control — 0 of 4 entered. Script file not written.**

```
thread 0..3: no exception -> guard SHORT-CIRCUITED
```

**Treatment — 4 of 4 entered. Script file written.**

```
thread 0..3: ENTERED BODY (past the write, threw at the Package.VerifyOK check)
```

All four got past the guard, executed the file write, and faulted at the
`Package.AviSynth.VerifyOK` check at `VideoScript.vb:296` — which is inside the body,
after the write. The control proves the detector is not simply reporting an unrelated
failure: the identical setup without the macro produces silence and no file.

## Experiment C — were they inside *at the same time*?

Experiment B shows each thread entered the body, but entries could in principle have been
serialized. To force the question, the probe holds the script file open with
`FileShare.None` for the whole concurrent window, then counts threads still blocked.

Nothing before the guard touches that file — the pre-guard work is string manipulation
(`GetScript`, `Macro.Expand`) and a directory-existence test. So a thread blocked on that
file has necessarily passed the guard and is inside the body. Eight threads:

| | entered `Synchronize` | blocked inside, lock held |
|---|---|---|
| control | 8 of 8 | **0 of 8** |
| treatment | 8 of 8 | **8 of 8** |

**Eight threads were simultaneously inside the guarded body.** The control blocks nobody
and every thread short-circuits, so the blocking is attributable to the volatile macro and
not to setup, contention, or an unrelated lock.

This is the claim the original document could not make.

## What the run changed

**Consequence 1 in the source reading was overstated, and the probe caught it.** That
document said concurrent workers "write the same `Path` … the script the encoder processes
are simultaneously reading", implying a corruption risk. The actual write path is
`Extensions.vb:622-639`:

```vbnet
Sub WriteFile(instance As String, path As String, encoding As Encoding)
    Dim counter = 0
    While True
        Try
            File.WriteAllText(path, instance, encoding)
            Exit While
        Catch ex As Exception
            Thread.Sleep(150)
            counter += 1
            If counter > 9 Then
                g.ShowException(ex)
                Exit While
            End If
        End Try
    End While
End Sub
```

Colliding writers do not interleave into a corrupt file. They **retry ten times at 150 ms
and then give up**, and on giving up they call `g.ShowException` — raising an exception
dialog **from a non-UI worker thread**. This is why the treatment threads in Experiment C
never returned after the lock was released: each was stuck in that terminal path.

So the accurate consequence is not file corruption. It is a per-collision stall of up to
~1.5 s, and, when a collision outlasts the retry budget, a modal dialog raised off the UI
thread — which is the same cross-thread defect as the `Indexing()` call, reached by a
second route. That is a real bug and a different one from what was written.

The other two consequences are unchanged and still hold: torn unsynchronized reads and
writes of `Info`, `OriginalInfo`, `Error`, `LastCode`, and `LastPath`; and
`g.MainForm.Indexing()` executing on a `Parallel.Invoke` worker.

## What is still not established

- **The trigger was injected, not encountered in a real project.** The probe sets the
  script text directly. Nothing here measures how often users put a volatile macro in
  filter code — only that doing so is supported and that it defeats the guard completely.
- **No full chunked encode was run.** There is no source video in this environment and the
  project cannot be built here. The probe drives `Synchronize` on the shipping binary with
  the cache primed the way `GlobalClass.vb:633` primes it; it does not drive
  `Parallel.Invoke` through `GetChunkEncodeActions`. That the chunk workers call
  `Synchronize` concurrently remains established by source reading — `CanChunkEncode()`
  requires `Chunks > 1` and `ParallelProcsNum` defaults to 3 — not by execution.
- **`g.MainForm.Indexing()` was never reached.** Execution faults earlier, at the
  `Package.VerifyOK` check, because the probe process has no initialized package
  catalogue. The cross-thread call remains a source-level finding.
- **The `Error <> ""` secondary trigger is still untraced**, exactly as before.
- **Still no fix proposed.** The correction above changes what a fix must address: the
  `g.ShowException` path matters as much as the write itself.

## Reproducing

```
csc.exe -platform:x64 -r:<release>/StaxRip.exe -out:probe.exe chunk-sync-probe.cs
cd <release> && probe.exe <release>/StaxRip.exe <scratch-dir>
```

Run from the release directory so `DirectN.dll` and `ManagedCuda.dll` resolve. The probe
leaves eight background threads parked in `g.ShowException`; the process exits regardless
because they are background threads.
