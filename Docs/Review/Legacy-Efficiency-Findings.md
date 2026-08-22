# Legacy Efficiency and Correctness Findings

Version: 1.0. Date: 2026-08-22. Scope: the shipping Windows application under `Source/`.

Findings only. Every entry below was read from committed source on the date above and
carries the line citations that support it. Nothing here has been changed: edits to
`Source/` cross the approval gates in `AGENTS.md`, and three of these findings sit
directly on gated ground, so each entry states which gate its fix would cross.

Two claims that were investigated and did **not** survive are recorded at the end. They
are kept deliberately, so they are not raised again as though they were new.

None of these findings is a performance measurement. The repository has no performance
baseline at all, recorded as P-014, so no entry here claims a speedup. They are defects
with a cost argument, not benchmarked wins.

## F-001: The Vulkan support probe never caches success and leaks an instance per call

Severity: high. Class: native resource leak. Gate a fix would cross: none of the listed
gates directly, but the probe feeds `RequirementsFunc` entries in the package catalogue,
so a behavior change there touches executable selection.

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

## F-002: `MD5Hash` computes the hash twice and discards the first result

Severity: low. Class: wasted work. Gate a fix would cross: none.

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

## F-003: `MediaInfo.ClearCache` has no callers, and a memory-pressure workaround sits nearby

Severity: medium. Class: dead invalidation path, with a probable downstream symptom.
Gate a fix would cross: process coordination and shared resources, because the memory
workaround is part of process lifetime management.

`Shared Sub ClearCache()` is declared at `Source/General/MediaInfo.vb:432`. A search of
the entire `Source/` tree for `ClearCache` returns exactly one hit, that declaration.
Nothing calls it. The media-info cache therefore only grows for the life of the process.

That is a fact. What follows is context, then a hypothesis.

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
source on 2026-08-22. Neither holds. They are recorded so the same wrong lead does not
get re-opened.

**Claimed: `x264Enc` calls `Script.Synchronize()` unconditionally from parallel chunk
workers while `x265Enc` guards it.** Not supported. `Source/Encoding/x264Enc.vb:101` and
`Source/Encoding/x265Enc.vb:126` sit at the same position in their respective `Encode`
overloads and do the same thing, and the same call appears at the head of essentially
every encoder in `Source/Encoding/`. There is no asymmetry between the two encoders. The
underlying question of whether chunk workers can call `Synchronize` concurrently is a
real one and remains open; it is separate from this claim, and answering it means tracing
`GetChunkEncodeActions`, not comparing these two files.

**Claimed: `MainForm.Indexing()` writes WinForms controls with no `Invoke` from
`Parallel.Invoke` workers.** Not supported as stated. `Parallel.Invoke` does not appear
in `Source/Forms/MainForm.vb` at all. `Indexing()` is at `:3833` and does write
`tbSourceFile.Text` at `:3848` and `:3866`, but nothing establishes that it runs off the
UI thread. The application's one `Parallel.Invoke` is at
`Source/General/GlobalClass.vb:651`; whether `Indexing()` is reachable from it has not
been traced, so there is no cross-thread finding here, only an untraced path.

## Related records

- P-014 in `Docs/Unknowns/Portability-Unknowns.md`: no performance baseline exists, which
  is why nothing here is stated as a speedup.
- `Source/General/GlobalClass.vb:622-651`: audio processing, subtitle cutting, and video
  chunk encoding are all appended to one `actions` list and run under a single
  `Parallel.Invoke` bounded by `s.ParallelProcsNum`, default `3`
  (`Source/General/ApplicationSettings.vb:70`). That shared budget is a candidate lever
  recorded in P-014, not a finding here, because it has not been measured.
