# Chunk-encode workers and `Script.Synchronize()`

This closes the open question recorded under "Investigated and not supported" in
`Docs/Review/Legacy-Efficiency-Findings.md`: *whether chunk workers can call
`Synchronize` concurrently*. That entry declined to answer it and named the trace
required — `GetChunkEncodeActions`. This is that trace.

Read-only analysis of `Source/` at commit `198223ea` (branch
`agent/chunk-encode-synchronize-race`, branched from `master`). Nothing was built, run,
or edited *for this document*; the runtime confirmation that followed is a separate
document and is noted below. No fix is proposed here.

## Answer

**Yes.** Chunk-encode workers call `p.Script.Synchronize()` concurrently on one shared
`VideoScript` instance, and the method is not thread-safe. The call happens on every
worker unconditionally; what is conditional is whether it *does* anything. A guard
normally makes it a no-op, which is why this has not surfaced as a reported defect. The
guard is defeated by a documented, user-reachable feature: non-deterministic macros.

Confidence: the call graph and the absence of synchronization are **verified** by reading
the source. The trigger condition is **verified as reachable in principle** but was not
executed — see "What is not established".

> **Status update, 2026-08-24 — confirmed at runtime.** The guard failure and concurrent
> entry into the body have since been reproduced against the shipping v2.52.5 release
> binary: eight threads were observed simultaneously inside the guarded body, against a
> control in which none were. That run also **corrected consequence 1 below**. See
> `Docs/Review/Chunk-Encode-Synchronize-Runtime-Confirmation.md`. The "What is not
> established" section at the end of this document has been narrowed accordingly.

## The call graph

`Source/General/GlobalClass.vb:632-651` builds one `actions` list and runs it under a
single `Parallel.Invoke`:

```text
GlobalClass.vb:633   p.Script.Synchronize()          <- once, on the calling thread
GlobalClass.vb:635   p.VideoEncoder.BeforeEncoding()
GlobalClass.vb:636   For Each i In p.VideoEncoder.GetChunkEncodeActions() : actions.Add(i)
GlobalClass.vb:651   Parallel.Invoke(MaxDegreeOfParallelism = s.ParallelProcsNum, actions.ToArray)
```

Each action produced by `x264Enc.GetChunkEncodeActions()`
(`Source/Encoding/x264Enc.vb:240-278`) is a closure that calls `Encode(...)`. The first
statement of that overload is the shared-state call:

```text
Source/Encoding/x264Enc.vb:100-101
    Overloads Sub Encode(passName As String, commandLine As String, priority As ...)
        p.Script.Synchronize()
```

`Encode` then calls `p.Script.GetFrameCount` (`x264Enc.vb:107`), which is
`GetInfo()` -> `Synchronize(False, False)` (`Source/Video/VideoScript.vb:720-737`) — a
second concurrent entry per worker, with different arguments.

Concurrency is guaranteed, not incidental:

- `x264Enc.CanChunkEncode()` returns `Chunks > 1` (`x264Enc.vb:232-234`), so the branch at
  `GlobalClass.vb:632` is only taken when there are **at least two** chunk actions.
- `s.ParallelProcsNum` defaults to `3` (`Source/General/ApplicationSettings.vb:70`).

So two or more actions calling `Synchronize` on the same object run at once by design.
The same `GetChunkEncodeActions` / `Encode` shape appears in `x265Enc.vb:330`,
`AOMEnc.vb:118`, `VvencffappEnc.vb:121`, and the five `SvtAv1*Enc` encoders.

## Why the method is not thread-safe

`Source/Video/VideoScript.vb:194-317`. The mutable state is five plain public fields on
the shared instance, with no lock, no `Volatile`, and no `Interlocked`
(`Source/Video/VideoScript.vb:14-18`):

```vb
<NonSerialized()> Public [Error] As String
<NonSerialized()> Public Info As ServerInfo
<NonSerialized()> Public OriginalInfo As ServerInfo
<NonSerialized()> Public LastCode As String
<NonSerialized()> Public LastPath As String
```

The method is a check-then-act over exactly those fields (`VideoScript.vb:289-316`):

```vb
If Me.Error <> "" OrElse code <> LastCode OrElse (comparePath AndAlso Path <> LastPath) Then
    If Path.Dir.DirExists Then
        ModifyScript(code, Engine).WriteFileUTF8(Path)   ' or WriteFile
        g.MainForm.Indexing()
        Using server = FrameServerFactory.Create(Path)
            Info = server.Info
            If Not convertToRGB Then OriginalInfo = Info
            Me.Error = server.Error
        End Using
        LastCode = code
        LastPath = Path
    End If
End If
```

There is no mutual exclusion between the test and the writes, and `LastCode`/`LastPath`
are only assigned *inside* the body. If two workers evaluate the condition before either
reaches the assignments, both proceed. Concurrent execution of that body means:

1. **Colliding writes to one file.** Both workers write the same `Path` — the active
   AviSynth/VapourSynth script — via `WriteFileUTF8`/`WriteFile`.
   **Corrected 2026-08-24 after the runtime run:** this does *not* corrupt the file.
   `WriteFile` (`Source/General/Extensions.vb:622-639`) retries ten times at 150 ms and
   then calls `g.ShowException(ex)`, so a collision costs up to ~1.5 s and, if it outlasts
   the retry budget, raises an exception dialog **from a non-UI worker thread** — the same
   cross-thread defect as item 2, by a second route. See
   `Docs/Review/Chunk-Encode-Synchronize-Runtime-Confirmation.md`.
2. **Cross-thread WinForms access.** `g.MainForm.Indexing()` at `VideoScript.vb:303` runs
   on a `Parallel.Invoke` worker. `Indexing()` writes `tbSourceFile.Text` at
   `Source/Forms/MainForm.vb:3773`, `:3786`, `:3815`, and `:3848` with no `Invoke`/`BeginInvoke`
   (`Indexing()` begins at `:3763`). Note these differ from the line numbers in the legacy
   findings, which were taken on a different branch.
3. **Torn shared state.** `Info`, `OriginalInfo`, `Error`, `LastCode`, and `LastPath` are
   written unsynchronized while other workers read them, including through
   `GetFrameCount`, which every worker calls.

Item 2 also **closes the second open item** in `Legacy-Efficiency-Findings.md`, which
recorded that `Indexing()` had "not been traced" to a `Parallel.Invoke` worker and was
therefore "only an untraced path". The path is
`GlobalClass.vb:651` -> chunk action -> `x264Enc.Encode` -> `p.Script.Synchronize()` ->
`VideoScript.vb:303` -> `MainForm.Indexing()`. It is now traced. Note it reaches
`Indexing()` *via* `Synchronize`, not via any direct call in `MainForm.vb` — which is why
the earlier search for `Parallel.Invoke` inside `MainForm.vb` found nothing.

## What normally prevents it, and what defeats it

The pre-synchronize at `GlobalClass.vb:633` runs on one thread and, when the body
executes, leaves `LastCode = code` and `LastPath = Path`. Workers then recompute `code`,
find it equal, and short-circuit. **In the ordinary case every worker's call is a
no-op.** That is why this is not a routinely-observed crash.

The guard depends on `code` being *stable across calls*. It is not guaranteed to be.
`VideoScript.vb:287` computes:

```vb
code = Macro.Expand(code)
```

`Macro.Expand` (`Source/General/Macro.vb:345`) resolves macros that return a different
value on each invocation:

- `%current_time%` and `%current_time24%` -> `Date.Now.ToString(...)`, seconds resolution
  (`Macro.vb:354-355`)
- `%current_date%` -> `Date.Now.ToString("yyyy-MM-dd")` (`Macro.vb:353`)
- `%random%` / `%random:digits%` -> `New Random()` per call (`Macro.vb:600-613`)

If the script text contains any of these, `code <> LastCode` is true on **every** call.
The guard never short-circuits, and every chunk worker enters the body concurrently —
all three consequences above, on every chunk, for the whole encode.

The script text is user-authored: filter bodies and `p.CodeAtTop` are concatenated by
`GetScript()` (`VideoScript.vb:51+`) and macro-expanded, and macros in filter code are a
supported feature (the shipped defaults use `%crop_left%`, `%target_width%`, and similar
at `VideoScript.vb:742-757`).

Severity is bounded by this: **no shipped default script or filter contains a volatile
macro.** A search of `Source/**/*.vb` for `current_time`, `current_date`, and `%random`
found matches only in `Macro.vb` itself — the definitions. Reaching the condition
requires a user to place one of those macros into their own script or filter code. That
is a supported thing to do, not a misuse, but it is not the default state.

A second, macro-independent trigger exists in principle: `Me.Error <> ""` is the first
term of the guard, and it is sticky. `GlobalClass.vb:590` checks `Error` and throws, but
that check runs *before* the `Synchronize()` at `:633`; if that later call sets `Error`
non-empty (`VideoScript.vb:312`), nothing re-checks it before `Parallel.Invoke`, and every
worker's guard is then true. Whether the `:633` body can actually run and fail at that
point was not traced to a conclusion.

## What is not established

Stated plainly, because the trigger analysis above is a source reading, not an execution:

- ~~**Not executed.**~~ **Resolved 2026-08-24.** Reproduced against the shipping release
  binary; see the runtime confirmation document. What remains unexecuted is the *full
  chunked encode* — the confirmation drives `Synchronize` directly with the cache primed
  as `GlobalClass.vb:633` primes it, rather than going through `Parallel.Invoke` and
  `GetChunkEncodeActions`. That the chunk workers call it concurrently is still a source
  reading.
- ~~**No timing evidence.**~~ **Resolved 2026-08-24.** Eight of eight threads were
  simultaneously inside the guarded body, against zero of eight in the control. The window
  is not narrow.
- **Observable symptom still not fully characterized.** The runtime run reached the file
  write and the `Package.VerifyOK` check but never reached `g.MainForm.Indexing()`,
  because the probe process has no initialized package catalogue. Item 2 therefore remains
  a source-level finding. Item 1's symptom *is* now characterized — a stall and an
  off-thread exception dialog, not corruption.
- **The trigger was injected, not encountered.** Nothing measures how often real projects
  contain a volatile macro; only that doing so is supported and defeats the guard.
- **Other encoders assumed, not read line-by-line.** The eight non-x264 encoders were
  confirmed to override `GetChunkEncodeActions`; they were not each traced through their
  own `Encode` overloads.
- **No fix is proposed.** Adding a lock inside `Synchronize` would serialize workers and
  interacts with the `g.MainForm.Indexing()` call and the shared `ParallelProcsNum`
  budget discussed under P-014. That design decision is not made here.

## Suggested next step

~~Confirm by execution before treating this as actionable.~~ **Done, 2026-08-24** — by a
different route than proposed here. Building a patched binary turned out to be impossible
in this environment (`Source/packages` unrestored; `AGENTS.md:53` forbids restoring
dependencies for a verification command), so the confirmation drives the shipping release
binary by reflection instead. That is better evidence, not worse: it tests the artifact
users run. See `Docs/Review/Chunk-Encode-Synchronize-Runtime-Confirmation.md`.

The remaining gap is a full end-to-end chunked encode, which needs a source video and a
buildable tree. That would close the last source-only link — that `Parallel.Invoke` over
`GetChunkEncodeActions` is what supplies the concurrent callers.

## Related records

- `Docs/Review/Chunk-Encode-Synchronize-Runtime-Confirmation.md` — the 2026-08-24 run that
  confirmed this against the shipping binary and corrected consequence 1. Probe source and
  output are under `Docs/Review/probes/`.
- `Docs/Review/Legacy-Efficiency-Findings.md`, "Investigated and not supported" — the two
  open items this closes.
- P-014 in `Docs/Unknowns/Portability-Unknowns.md` — no performance baseline exists; the
  shared `ParallelProcsNum` budget is recorded there.
