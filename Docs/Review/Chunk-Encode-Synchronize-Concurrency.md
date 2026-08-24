# Chunk-encode workers and `Script.Synchronize()`

This closes the open question recorded under "Investigated and not supported" in
`Docs/Review/Legacy-Efficiency-Findings.md`: *whether chunk workers can call
`Synchronize` concurrently*. That entry declined to answer it and named the trace
required — `GetChunkEncodeActions`. This is that trace.

Read-only analysis of `Source/` at commit `198223ea` (branch
`agent/chunk-encode-synchronize-race`, branched from `master`). Nothing was built, run,
or edited. No fix is proposed here.

## Answer

**Yes.** Chunk-encode workers call `p.Script.Synchronize()` concurrently on one shared
`VideoScript` instance, and the method is not thread-safe. The call happens on every
worker unconditionally; what is conditional is whether it *does* anything. A guard
normally makes it a no-op, which is why this has not surfaced as a reported defect. The
guard is defeated by a documented, user-reachable feature: non-deterministic macros.

Confidence: the call graph and the absence of synchronization are **verified** by reading
the source. The trigger condition is **verified as reachable in principle** but was not
executed — see "What is not established".

## The call graph

`Source/General/GlobalClass.vb:632-651` builds one `actions` list and runs it under a
single `Parallel.Invoke`:

```
GlobalClass.vb:633   p.Script.Synchronize()          <- once, on the calling thread
GlobalClass.vb:635   p.VideoEncoder.BeforeEncoding()
GlobalClass.vb:636   For Each i In p.VideoEncoder.GetChunkEncodeActions() : actions.Add(i)
GlobalClass.vb:651   Parallel.Invoke(MaxDegreeOfParallelism = s.ParallelProcsNum, actions.ToArray)
```

Each action produced by `x264Enc.GetChunkEncodeActions()`
(`Source/Encoding/x264Enc.vb:240-278`) is a closure that calls `Encode(...)`. The first
statement of that overload is the shared-state call:

```
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

1. **Concurrent writes to one file.** Both workers write the same `Path` — the active
   AviSynth/VapourSynth script — via `WriteFileUTF8`/`WriteFile`. This is the script the
   encoder processes are simultaneously reading.
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

- **Not executed.** No chunk encode was run with a volatile macro in the script. The race
  is demonstrated by construction from the source, not observed. The distinction matters:
  a real run could reveal an outer guard not visible on this path.
- **No timing evidence.** Whether the concurrent window is wide enough to be hit reliably,
  or is merely possible, is unmeasured. The body performs file I/O and creates a frame
  server, so the window is not narrow, but that is an inference.
- **Observable symptom not characterized.** Item 2 would normally raise
  `InvalidOperationException`, but only once the handle is created and illegal
  cross-thread calls are being checked; whether this surfaces as a crash, a corrupted
  script file, or silently wrong `Info` was not determined.
- **Other encoders assumed, not read line-by-line.** The eight non-x264 encoders were
  confirmed to override `GetChunkEncodeActions`; they were not each traced through their
  own `Encode` overloads.
- **No fix is proposed.** Adding a lock inside `Synchronize` would serialize workers and
  interacts with the `g.MainForm.Indexing()` call and the shared `ParallelProcsNum`
  budget discussed under P-014. That design decision is not made here.

## Suggested next step

Confirm by execution before treating this as actionable: configure a chunked x264 encode
(`Chunks > 1`), add `# %current_time%` to a filter body or `CodeAtTop`, and observe
whether the guarded body runs on more than one thread — a breakpoint or a thread-id log
line at `VideoScript.vb:290` is sufficient. That converts this from a construction to an
observation, and it is the evidence a fix should be justified by.

## Related records

- `Docs/Review/Legacy-Efficiency-Findings.md`, "Investigated and not supported" — the two
  open items this closes.
- P-014 in `Docs/Unknowns/Portability-Unknowns.md` — no performance baseline exists; the
  shared `ParallelProcsNum` budget is recorded there.
