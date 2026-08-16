# SLICE-001 M0 Source Project Checks Catalog

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Approved for M1 under Confirmed D-037.

## Contract

This catalog describes three selected in-memory project checks. It is not an Add Job, encode, package, disk, event, job, output, tool, or file-existence preflight.

`Selected checks passed` means only that every applicable check in this file passed. The available summary must state: `Add Job and encode-time checks still run later. This result does not authorize encoding.`

The evaluator and result contain no path, file name, media title, script, command, exception, external output, or arbitrary string. Snapshot construction may read a legacy path string long enough to classify it into a bounded enum, then discards the string.

## Approved checks

| Order | Stable id | Snapshot state | Result | Current source oracle |
|---:|---|---|---|---|
| 100 | `project.source-target-text-distinct` | `Distinct` or `Identical` | Fact when distinct; Blocker when identical | `Source/Forms/MainForm_Assistant.vb:176-177` |
| 200 | `target.path-characters-valid` | `Valid` or `Invalid` | Fact when valid; Warning when empty or invalid | `Source/General/Extensions.vb:141-157`; `Source/Forms/MainForm_Assistant.vb:309-312` |
| 300 | `muxer.cover-convention-valid` | `NotApplicable`, `Valid`, `Invalid`, or `Unknown` | Not applicable for no cover or a non-MKV muxer; Fact when valid; Blocker when invalid; Unknown when bounded parsing cannot classify the legacy value | `Source/Forms/MainForm_Assistant.vb:136-143` |

### `project.source-target-text-distinct`

- **verified:** The current Assistant compares `p.SourceFile = p.TargetFile` and blocks when the text is identical at `Source/Forms/MainForm_Assistant.vb:176-177`.
- **verified:** The project uses binary string comparison at `Source/StaxRip.vbproj:22`. The check does not claim case-insensitive Windows file identity, canonical identity, link identity, or file existence.
- **verified:** The mapper can return only `Distinct` or `Identical`. It need not normalize, open, or retain either path.
- **verified:** The existing target textbox binding at `Source/Forms/MainForm.vb:1710-1728` supplies the walkthrough correction route.

### `target.path-characters-valid`

- **verified:** `IsValidPath` rejects empty text, framework-invalid path characters, and control characters at `Source/General/Extensions.vb:141-157`.
- **verified:** The predicate reads framework character tables and one in-memory string. It performs no existence, canonicalization, filesystem, process, package, or tool operation.
- **verified:** The mapper returns only `Valid` or `Invalid`. It emits no target text or message argument.
- **verified:** The `TargetFile` setter also rejects some invalid names at `Source/General/Project.vb:289-294`. The mapper reads current state and never invokes that setter.

### `muxer.cover-convention-valid`

- **verified:** The current rule applies only when `CoverFile` is nonempty and the selected muxer is `MkvMuxer`. Accepted basenames are `cover`, `small_cover`, `cover_land`, and `small_cover_land`; accepted extensions are `jpg` and `png`. Evidence: `Source/Forms/MainForm_Assistant.vb:136-143`.
- **verified:** Extension comparison is lowercase invariant; basename comparison remains binary. Evidence: `Source/General/Extensions.vb:289-317,433-437` and `Source/StaxRip.vbproj:22`.
- **verified:** The new classifier must not call `Muxer.Init`, `File.Exists`, a package, MediaInfo, or a tool. It reads the selected muxer kind and legacy cover text, returns one bounded enum, and discards the text.
- **inferred:** A malformed legacy value that the bounded parser cannot classify returns `Unknown`. It never exposes the value or exception text.
- **verified:** This check describes the stored naming convention only. It does not claim the cover file exists or can be read.

## Result and presentation states

The pure result uses this precedence:

1. `BlockersFound`
2. `WarningsFound`
3. `ChecksIncomplete`
4. `SelectedChecksPassed`

`NotApplicable` does not raise the overall state. An invalid snapshot enum becomes an Unknown check and prevents `SelectedChecksPassed`.

`Hidden`, `RefreshRequired`, and `Unavailable` belong to `ProjectCheckPresentationState`, not the evaluator. `Unavailable` contains no exception or arbitrary string.

Production names are:

- `ProjectCheckSnapshot`
- `ProjectCheck`
- `ProjectCheckResult`
- `ProjectCheckCatalog`
- `ProjectCheckEvaluator`
- `ProjectCheckActivationContext`
- `ProjectCheckActivationPolicy`
- `ProjectCheckCoordinator`
- `ProjectCheckPresentationState`
- `ProjectChecksSummaryControl`
- `ProjectChecksDetailsForm`

No new type, stable id, menu, message, or control uses `Readiness` or `Ready`.

## Mutation and invalidation owners

| Input or transition | Repository-owned mutation evidence | Required clear or invalidation |
|---|---|---|
| Project replacement | Global `p` is assigned at `Source/Forms/MainForm.vb:1751,1754,1786` | Clear before the string overload's first assignment and before the object overload assignment. The clear tolerates startup before feature construction. |
| New source attempt | Every mapped repository source route enters `Source/Forms/MainForm.vb:2477-2890` | Clear at shared source-entry before source work. |
| Target text | `TargetFileValue` is assigned only by `Project.TargetFile` at `Source/General/Project.vb:283-299`; the active project subscription is `Source/Forms/MainForm.vb:1710-1721` | Invalidate in `ProjectPropertyChanged` when `e.PropertyName = NameOf(Project.TargetFile)`, before the existing Assistant call. |
| Source text after publication | `VideoScript.Synchronize` can call `MainForm.Indexing` at `Source/Video/VideoScript.vb:289-305`; Indexing writes `p.SourceFile` at `Source/Forms/MainForm.vb:3771,3784,3813,3846` | Invalidate immediately before each actual Indexing source assignment. Source-entry or project-replacement clears cover all other repository-owned assignments. |
| Cover convention during source opening | `Muxer.Init` discovers and assigns `CoverFile` at `Source/General/Muxer.vb:157-268`; source opening invokes muxer initialization before publication | No extra clear; the source-entry clear already owns the transaction. The new mapper never invokes `Init`. |
| Active muxer configuration commit | A clone is committed at `Source/Encoding/VideoEncoder.vb:358-368` | Before the successful assignment, invalidate only when `Me Is p.VideoEncoder`. |
| Active muxer profile replacement | `VideoEncoder.LoadMuxer` assigns and initializes the muxer at `Source/Encoding/VideoEncoder.vb:379-389` | Invalidate before assignment only when `Me Is p.VideoEncoder`. |
| Active video encoder replacement | `GlobalClass.LoadVideoEncoder` replaces or transfers the active muxer at `Source/General/GlobalClass.vb:1204-1218` | Invalidate before the active encoder assignment. |

`CoverFile` is a public auto-property at `Source/General/Muxer.vb:15`. Repository enumeration found one direct assignment, in `Muxer.Init`. Muxer configuration edits a clone through `Source/Forms/MuxerForm.vb:917-920` and commits through the active encoder owner above.

## Deterministic enumeration record

The scan scope was all 147 `*.vb` files returned by `rg --files Source -g '*.vb'` at `c26e0fa6`.

| Query | Result | Classification |
|---|---:|---|
| `(?:\.CoverFile|CoverFile)\s*=` | 1 occurrence in 1 file | The `Muxer.Init` assignment above |
| `TargetFileValue\s*=` | 1 occurrence in 1 file | The `Project.TargetFile` setter above |
| `^\s*p\s*=` | 5 occurrences in 2 files | 3 global project assignments in `MainForm.vb`; 2 unrelated local-string assignments in `DolbyVisionMetadataFile.vb` |
| `^\s*(?:If .* Then )?p\.SourceFile\s*=` | 7 occurrences in 1 file | Project load, source open, demux, and four Indexing assignments |

This proves repository-owned occurrences for those exact syntactic shapes. It does not prove the absence of reflection, external plugin mutation, generated code, native writes, or a different assignment shape. No retained catalog field depends on an external filesystem freshness event.

## Rejected candidates

- `script.first-filter-source`: rejected. `VideoScript.Filters` is a public mutable list, change notification is opt-in, and direct activation commands can mutate without one complete invalidation owner. Fixing that collection contract would widen the slice into filter behavior. Evidence: `Source/Video/VideoScript.vb:22,27-31,151-157` and `Source/General/GlobalCommands.vb:501-528`.
- `video.muxer-accepts-output`: rejected. Polymorphic output getters can reach MediaInfo, and encoder parameter mutation has no complete event owner. Evidence: `Source/Encoding/VideoEncoder.vb:801-827` and `Source/General/Muxer.vb:514-524`.
- Separate source-present and target-present rows: rejected as padding. The post-success boundary owns source presence, and an empty target is already classified by `target.path-characters-valid`.

## Claim boundary

- **verified:** All repository-owned mutation sites for the three selected inputs are mapped above.
- **unknown:** Arbitrary out-of-repository reflection or hostile in-process plugin code could directly mutate legacy public members. No complete repository event contract covers that external code-execution boundary.
- **inferred:** This does not block the selected catalog because D-037 and S-018 use complete repository caller and mutation maps, not a whole-process sandbox claim.
- **verified:** M2 generation, mutation-scope, and policy interleaving tests cover deterministic event-order hazards for repository-owned hooks.
- **unknown:** Real loaded-project event ordering and the GUI correction walkthrough remain L3, L4, and M4 evidence.
