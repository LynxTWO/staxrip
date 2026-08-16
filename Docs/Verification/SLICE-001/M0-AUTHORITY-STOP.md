# SLICE-001 M0 Ready Authority Stop

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Stop resolved by Confirmed D-037; evidence retained.

## Result

**verified:** The approved five-to-eight-check pure catalog cannot emit the overall label `Ready` under D-034. Confirmed D-037 supersedes that decision and replaces the claim with bounded Source project checks and `Selected checks passed`.

The smallest contradiction is `BeforeJobAdding`:

1. Normal Add Job runs it after the Assistant and disk gates at `Source/Forms/MainForm.vb:4195-4198`.
2. `RaiseAppEvent` can execute a user `BeforeJobAdding.ps1` and configured commands at `Source/General/GlobalClass.vb:1363-1402`.
3. A pure post-open snapshot cannot know whether that later code will complete or change relevant state.
4. An external event script can change without an in-memory invalidation event. Checking it would require the filesystem probing D-021 and D-032 forbid.
5. D-034 requires event authority and all other required authority to be known before `Ready`.

No source-backed current-state condition removes this contradiction.

## Independent blockers

| Authority | Evidence | Why a pure durable result cannot own it | Confidence |
|---|---|---|---|
| Package requirements | `Source/General/GlobalClass.vb:861-877`; `Source/General/Package.vb:2973-3069,3510-3546` | Verification reads live package status and timestamps, may read imported scripts, opens modal UI, and can throw. No typed result or complete invalidation event exists. | verified |
| Assistant pass | `Source/Forms/MainForm_Assistant.vb:16-28,124-126,481-484`; `Source/Forms/MainForm.vb:3485-3488` | The routine performs script and frame-server work, swallows exceptions, and another command can force the flag true. | verified |
| Disk policy | `Source/Forms/MainForm.vb:3458-3482,4195-4198` | Free space is live external state and the user can Continue or Abort at action time. | verified |
| Job collision | `Source/Forms/MainForm.vb:4200-4207`; `Source/General/JobManager.vb:108-138` | It reads persisted job state and can prompt. | verified |
| Output collisions | `Source/Forms/MainForm.vb:4209-4263` | It reads video and audio output files and mutates skip flags after a user choice. | verified |
| Final Add Job | `Source/Forms/MainForm.vb:4290-4315`; `Source/General/JobManager.vb:79-105` | It rechecks requirements, serializes project state, updates Jobs, and raises another event. | verified |

## Existing authority map

| Order | Normal Add Job authority | Pass effect | Failure or choice effect |
|---:|---|---|---|
| 1 | `CanIgnoreTip` | Continue | Warn and return |
| 2 | Add current Assistant tip to skipped tips | Continue with changed project state | None |
| 3 | `VerifyRequirements` | Continue | Return, show Apps UI, warn, or abort |
| 4 | `AssistantPassed` | Continue | Run Assistant and return |
| 5 | `AbortDueToLowDiskSpace` | Continue | User aborts or method bypasses on UNC, empty path, or caught error |
| 6 | `BeforeJobAdding` | Continue after arbitrary configured work | Event or command can fail or mutate state |
| 7 | Active job collision | Continue after approval | User cancels |
| 8 | Video output collision | Set reuse or overwrite state | User cancels |
| 9 | Audio output collision | Set reuse or overwrite state | User cancels |
| 10 | Inner requirements and Assistant checks | Save and add job | Return |

Evidence: `Source/Forms/MainForm.vb:4177-4316`.

`StartEncoding` is a different command path. It forces `AssistantPassed = True`, calls the inner Add Job overload, and then runs the queue at `Source/Forms/MainForm.vb:3484-3489`. This confirms that current encode entry does not expose one shared side-effect-free authority.

## Assistant breadth

A deterministic text count over `Source/Forms/MainForm_Assistant.vb` found 42 `ProcessTip` calls, 21 `Return Block` calls, and 21 `Return Warn` calls. The conditions span tags, cover files, filters, source and target paths, audio, muxer compatibility, crop, cut ranges, compressibility, target existence, timestamps, Dolby Vision, encoder parameters, colorspace, dimensions, subtitles, script errors, and bit depth. Evidence ranges: `Source/Forms/MainForm_Assistant.vb:128-479`.

Warnings can be skipped by message hash at `Source/Forms/MainForm.vb:3316-3350`. Blocks set `CanIgnoreTip = False` and disable Next at `Source/Forms/MainForm.vb:3369-3381`.

Duplicating these rules would create a second authority and still would not cover packages, disk, events, jobs, or outputs.

## Candidate pure detail checks

These are source-supported candidates for a renamed bounded project-check feature. The final three-check selection, rejected candidates, and complete repository-owned invalidation map are in `M0-CATALOG.md`. None can support `Ready`.

| Candidate id | Bounded input | Proposed outcome | Existing oracle | Invalidation status |
|---|---|---|---|---|
| `project.source-target-distinct` | Equality Boolean only | Blocker when equal; fact otherwise | `Source/Forms/MainForm_Assistant.vb:176-177` | Target setter has a change event; source and project lifecycle also required |
| `target.path-characters-valid` | Existing character predicate result | Warning when empty or invalid; fact otherwise | `Source/General/Extensions.vb:142-157`; `Source/Forms/MainForm_Assistant.vb:309-312` | Target setter plus project lifecycle |
| `script.first-filter-source` | Enum: missing, inactive, wrong category, valid | First three block; valid is fact | `Source/Forms/MainForm_Assistant.vb:163-169` | Existing script/filter events cover common UI changes; direct mutations remain unknown |
| `video.muxer-accepts-output` | Compatible, incompatible, unknown | Incompatible blocks; unknown prevents a strong claim | `Source/Forms/MainForm_Assistant.vb:210-213` | Encoder and muxer owners need a complete audit |
| `muxer.cover-convention-valid` | Applicable plus approved-name and extension flags | Invalid blocks; absent is not applicable | `Source/Forms/MainForm_Assistant.vb:136-143` | Muxer commit and replacement owners need a complete audit |

`project.source-target-distinct` is the best walkthrough blocker. The existing target binding writes `Project.TargetFile` at `Source/Forms/MainForm.vb:1710-1728`; the setter raises property change at `Source/General/Project.vb:285-299`; Assistant blocks equality at `Source/Forms/MainForm_Assistant.vb:176-177`. The result can expose only equality, never either path. This is a source-backed design, not observed runtime evidence.

## Rejected alternatives

- Use `AssistantPassed` as the result: rejected because it is mutable, side-effect-derived, forceable, and unsafe across swallowed early exceptions.
- Call `VerifyRequirements` from the mapper: rejected because it probes, shows UI, and can abort.
- Move disk or event work earlier: rejected because it changes action-time behavior and crosses protected boundaries.
- Duplicate Assistant: rejected because it creates rule drift and does not cover later gates.
- Emit `Ready` only for default settings: rejected because external event, package, disk, job, and output state stays unchecked or stale.
- Keep `Ready` with a disclaimer: rejected because the functional label remains false under D-034.

## Decision resolution

On 2026-08-15, LynxTWO confirmed D-037. The feature and success state are `Source project checks` and `Selected checks passed`. The UI must state that Add Job and encode-time checks still run later. D-030 and D-034 are Superseded, and the Slice Brief central claim, S-016, S-017, and S-018 use the bounded replacement contract.

A larger alternative is a later side-effect-free preflight contract shared by every Add Job and Start Encoding route. That work must own package freshness, Assistant rules, disk policy, events, jobs, outputs, invalidation, and compatibility. It exceeds this slice.

Q-001 and U-003 were Open at this stop. `M0-CATALOG.md` later closed both for design, and `M1-PURE-MODEL.md` plus `M2-INTEGRATION.md` record current deterministic implementation evidence. This file retains the rejected-authority evidence and does not claim encode authorization.
