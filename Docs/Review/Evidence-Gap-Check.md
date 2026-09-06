# Evidence Gap Check

## Can the script synchronization body block on the UI thread?

Asked because the proposed fix for the chunk-encode race takes a lock around the guarded
body at `Source/Video/VideoScript.vb:289-317`. A lock is only safe if the body cannot wait
on a thread that is itself waiting for the lock.

- **Claim under test:** Taking a lock around the guarded body can deadlock against a
  UI-thread caller of `Synchronize`.
- **Verdict: refuted. No deadlock cycle exists.** The lock will not deadlock.
- **Confidence:** verified for the enumerated call set below. `inferred` for the whole
  program, because reachability was traced by reading the named call sites rather than by
  a call-graph tool.

### What was traced

The guarded body makes four outbound calls. Each was followed to its leaves.

1. `Extensions.WriteFile` at `Extensions.vb:622-638`. Both engines route here;
   `WriteFileUTF8` at `Extensions.vb:612` delegates to it.
2. `Package.VerifyOK` at `Package.vb:2973-2990`.
3. `g.MainForm.Indexing()` at `MainForm.vb:3763`.
4. `FrameServerFactory.Create` at `FrameServer.vb:191-211`.

### Why there is no deadlock

- **MainForm marshalling is asynchronous.** `ProcController` reaches `g.MainForm` through
  `BeginInvoke` at `ProcController.vb:873`, which does not block the caller.
- **The one synchronous blocking `Invoke` cannot close a cycle.**
  `ProcController.vb:934` calls `g.ProcForm.Invoke(...)`, which blocks until the
  `ProcessingForm` STA thread pumps it. That thread cannot re-enter the lock:
  `Source/Forms/ProcessingForm.vb` contains no reference to `Synchronize`, `p.Script`, or
  `VideoScript`. Scope: one file, searched for three patterns, zero matches.
- **The nested lock creates no AB-BA cycle.** `ProcController.vb` takes `SyncLock Procs` at
  six sites, and the same file contains no reference to `Synchronize` or `p.Script`. So no
  thread holds `Procs` while wanting a script lock.
- **The spin-wait targets a thread it just created.** `ProcController.vb:929-931` spins on
  `ProcessingForm.WasHandleCreated` for a thread started three lines earlier, not for the
  main UI thread.

### Why the lock is still the wrong shape

Refuting deadlock does not make a coarse lock safe. The same trace found three blocking or
interactive operations inside the body. A lock held across any of them blocks every
UI-thread caller of `Synchronize`, which is `PreviewForm.vb:304`, `CropForm.vb:282`, and
`MainForm.vb:3760`.

- **Two modal dialogs.** `Package.VerifyOK` opens `AppsForm` and calls `form.ShowDialog()`
  at `Package.vb:2976` whenever `GetStatus()` is non-empty. `Extensions.WriteFile` calls
  `g.ShowException` at `Extensions.vb:634` after ten failed retries, which reaches
  `TaskDialog.Show()` at `GlobalClass.vb:1610`. Both are raised from the worker thread that
  holds the lock, and both hold it until a human dismisses them.
- **One unbounded external wait.** `Proc.Start` reaches `Process.WaitForExit()` at
  `Proc.vb:320`. On the indexing paths in `Indexing` that is a full ffmsindex or lwi run
  over the source file.

The result of locking is therefore a UI freeze lasting as long as a dialog goes unanswered
or an indexing job runs. It is recoverable, unlike a deadlock, but a user cannot tell the
two apart.

### Two consequences of the race that no earlier document records

Found by this trace, not by the earlier source reading or the runtime probe.

- **The process PATH is corrupted by lost updates.** `FrameServerFactory.Create` calls
  `g.AddToPath`, which reads `Environment.GetEnvironmentVariable("path")`, builds a new
  value, and writes it back with no synchronization. Concurrent callers lose each other's
  additions, so a frame server can start with a PATH missing a directory it needs.
  Confidence: `verified` by reading `GlobalClass.AddToPath`; the failure was not observed.
- **The cross-thread MainForm defect has two sites, not one.** Besides the
  `tbSourceFile.Text` writes in `Indexing`, `ProcController.vb:914-916` reads
  `g.MainForm.Visible` and calls `g.MainForm.Hide()` directly from the calling thread.
- **Still missing:** whether chunk encoders can read different script contents. With a
  volatile macro each worker writes a different script to the same path, so which content a
  given chunk's encoder reads is timing dependent. Confidence: `inferred`. Not observed,
  and it needs a real chunked encode to test.

### What is still missing

- Reachability was established by reading named call sites, not by a call-graph tool. A
  path through a delegate, an event handler, or reflection would not have been seen.
- No claim is made about `AppsForm` or `TaskDialog` behavior when constructed on a
  non-UI thread. They were traced as reachable, not executed.

## Is the `Error <> ""` trigger reachable during a chunked encode?

Asked because it is the guard's other term. If reachable, the race fires with no volatile
macro present and the cache-key fix would not prevent it.

- **Claim under test:** `VideoScript.Error` can be non-empty when chunk workers call
  `Synchronize`.
- **Verdict: refuted for the chunk-encode window.** It is gated to empty on entry and
  nothing in the window can make it non-empty.
- **Confidence:** `verified` for the `ProcessJob` path traced below. `inferred` program-wide,
  because reachability was read from call sites rather than produced by a call-graph tool.

### The chain

1. **There is exactly one chunk-encode entry point.** `Parallel.Invoke` occurs once in the
   whole repository, at `GlobalClass.vb:651`, and `GetChunkEncodeActions()` has exactly one
   caller, at `GlobalClass.vb:636`. Both are inside `Sub ProcessJob` at `GlobalClass.vb:542`.
2. **The window opens with `Error` empty, and that is enforced.** `ProcessJob` synchronizes
   at `GlobalClass.vb:589` and then throws `ErrorAbortException` at `:590-592` if
   `p.Script.Error <> ""`. A job with a script error never reaches the chunk path.
3. **Nothing between the gate and the window can change it.** `GlobalClass.vb:600-632`
   only constructs `actions.Add(...)` closures for audio and subtitles. None of them
   execute before `Parallel.Invoke`, and none touch `p.Script`.
4. **`Error` cannot bootstrap itself.** It has exactly one assignment inside `Synchronize`,
   at `VideoScript.vb:319`, reachable only by entering the guarded body, which requires the
   guard to have already failed for some other reason.
5. **The one external write is out of reach.** `MainForm_Assistant.vb:24` assigns
   `p.Script.Error` on the Assistant path, and `ProcessJob` hides the main form at
   `GlobalClass.vb:599` before the window opens.

### What this was before the fix

The term was not an independent trigger but an amplifier. With a volatile macro present,
`Synchronize` at `GlobalClass.vb:633` entered the body, and if the frame server reported an
error there, `Error` became non-empty with **no gate between `:633` and `:651`**. Every
worker would then fail the guard on the first term as well as the second. Post-fix `:633`
short-circuits, which closes that route too.

### A separate finding this trace produced

**`ProcessJob` runs on the UI thread.** All three callers put it there: `JobsForm.vb:444`
marshals with `g.MainForm.Invoke(Sub() g.ProcessJobs())`, and `MainForm.vb:3488` and
`GlobalCommands.vb:108` are ordinary UI handlers.

`Parallel.Invoke` uses the calling thread as one of its workers. So during a chunked encode
one chunk action runs **on the UI thread** and the rest run on thread-pool threads. Two
consequences worth recording, neither of which the cache-key fix addresses:

- The cross-thread Windows Forms defect fires for some chunks and not others, which would
  present in the field as an intermittent failure rather than a reliable one.
- It makes the withdrawn lock proposal worse rather than better. The UI thread is itself a
  participant in the parallel region, so it could block on a lock held by a worker parked in
  one of the two modal dialogs inside the guarded body.

Confidence: `verified` for the caller list and for `Parallel.Invoke` using the calling
thread, which is documented .NET behavior. Not observed in a running encode.

## Do the unmarshalled Windows Forms accesses actually throw?

Asked because the backlog claimed they do. **They do not, and the earlier claim was wrong.**

- **Claim under test:** `CheckForIllegalCrossThreadCalls` is absent from `Source/`, therefore
  it keeps a default of `True`, therefore the unmarshalled control accesses throw.
- **Verdict: refuted.** The premise about the default was incorrect.
- **Confidence:** `verified` by execution.

.NET Framework initialises the flag to `Debugger.IsAttached`, not to `True`. A measured run
on this machine reported `Debugger.IsAttached = False` and
`Control.CheckForIllegalCrossThreadCalls = False`. So for a user running StaxRip normally
the check is **off**.

Measured, with a positive control to prove the detector can see a throw:

| access, from a worker thread | flag off (how users run) | flag on (under a debugger) |
|---|---|---|
| write `.Text` | no throw | `InvalidOperationException` |
| call `.Hide()` | no throw | `InvalidOperationException` |
| read `.Visible` | no throw | no throw |

Probe sources: `winforms-crossthread.cs` and `winforms-crossthread2.cs` in the session
scratch directory. They use a bare `Form`, not StaxRip, because this is framework behaviour.

### What this changes

- **The defect is silent, not loud.** Unmarshalled control access from a worker is undefined
  behaviour in Windows Forms: it may work, corrupt control state, or stall in the message
  loop. It does not announce itself. Describing it as "throws `InvalidOperationException`"
  was wrong and would have sent someone hunting for an exception that never appears.
- **It reproduces differently for developers than for users.** Under a debugger the flag is
  `True`, so a developer can see an exception on a path where a user sees nothing.
- **The `ProcController` site is not reached in the chunk path anyway.** `ProcessJob` calls
  `g.MainForm.Hide()` on the UI thread at `GlobalClass.vb:599`, before `Parallel.Invoke` at
  `:651`. By the time a chunk worker reaches `ProcController.vb:914-916`, `Visible` is
  already `False`, so the `If` fails and the `Hide()` write never runs. The surviving access
  is the `Visible` read, which does not throw under either setting.

So the cross-thread item is **less urgent than recorded**, on both reachability and
severity, and its stated failure mode was incorrect.
