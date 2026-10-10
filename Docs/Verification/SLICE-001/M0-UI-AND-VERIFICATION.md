# SLICE-001 M0 UI and Verification Design

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: D-037 design and strict ignored model complete; M3 supersedes the fixed Hidden-state span and limited-font row selection; operating-system and human evidence pending.

## Summary placement

The original smallest tested Assistant-adjacent layout is **verified** as M0 design-model evidence:

- Add a feature-owned `ProjectChecksSummaryControl` to `tlpMain` cell `(3, 4)` after `InitializeComponent` and the component-container guard at `Source/Forms/MainForm.vb:1023-1031`.
- Reduce `gbAssistant` column span from four to three before startup `OpenProject`.
- Keep the existing four columns and five rows. Increase the final row to 177 logical pixels (`531.0!` at the designer baseline). The 84-pixel strict-copy shape failed, and the 112-pixel shape failed expanded selectable-font coverage.
- Keep the summary attached even in `Hidden` state. The M0 model used one permanent three-plus-one bottom layout. Keep state, rendering, Details, and Refresh ownership outside Assistant.

Evidence: Assistant layout is defined at `Source/Forms/MainForm.vb:176-208`; `tlpMain` has four columns, places Assistant at row 4, and has five rows at `Source/Forms/MainForm.vb:890-916`.

The final production refinement keeps the summary attached in cell `(3, 4)` but restores the Assistant's four-column span while project checks are `Hidden`. Visible states use the tested three-plus-one layout. Initialization briefly uses the three-column span to attach the summary, and the first Hidden render restores four columns. This supersedes the M0 model's permanent three-column span while preserving its ownership and placement findings.

The visible shape adds no vertical row. A new control cannot safely share the already four-column-spanning Assistant cell without changing the span first. The expanded audit covers 141 bundled selectable Default font families and ten combined scale factors, or 1,410 font/scale cases. Ninety-six families fail at least one case with the former 112-pixel row; 177 is the first tested row height that passes the full matrix. Physical runtime fit remains unverified.

Assistant is not a safe owner. It synchronizes scripts, can create a frame server, changes project and control state, and suppresses exceptions at `Source/Forms/MainForm_Assistant.vb:8-28,33-126,465-484`.

## Menu ownership

Do not add this command to persisted `s.CustomMenuMainForm`.

- The custom menu is settings-owned and version-reset at `Source/General/ApplicationSettings.vb:302-304`.
- Menu editing saves settings at `Source/Forms/MainForm.vb:4121-4130`.
- `CustomMenu` clears the strip when it rebuilds at `Source/UI/Menu.vb:292-300`.

Approved fixed route:

1. Install one top-level `Source chec&ks` menu after `CustomMainMenu.BuildMenu()` at `Source/Forms/MainForm.vb:1051-1065`.
2. Reinstall a fresh standard `ToolStripMenuItem` after `CustomMainMenu.Edit()` at `Source/Forms/MainForm.vb:4121-4129`. Identify it by stable `Name`, never visible text, and never delete a user-created similarly named menu.
3. Add `&View details...` and `&Refresh project checks` items with native mnemonics and no persisted shortcut.

`CustomMenu.BuildMenu` disposes every current strip item at `Source/UI/Menu.vb:292-300` and `Source/General/Extensions.vb:1461-1469`, so the fixed menu object cannot be reused across a rebuild.

Every visible summary state must end with: `Add Job and encode-time checks still run later. This result does not authorize encoding.`

## Details surface and accessibility

The confirmed D-025 shape is a `DialogBase` details form with:

- DPI-scaled `TableLayoutPanel`.
- Read-only `DataGridViewEx`.
- Text columns for Status, Check, and Explanation.
- Full-row, single selection, no row headers, and no clipboard route.
- A visible non-authorization notice and labeled Close `ButtonEx` with Cancel result for Escape.
- Explicit `AccessibleName`, `AccessibleDescription`, and `AccessibleRole` for every new control.
- Keyboard access through summary, Details, Refresh, rows, Escape, Alt+F4, and focus return.

The grid is read-only, full-row single-select, non-sortable, no add/delete/resize, no row headers, no tooltips, no clipboard, and `StandardTab = True`. It explicitly selects the first current cell so Up and Down reach every row. Grid precedents exist at `Source/Forms/MuxerForm.vb:692-699,750-759`. The Escape/Cancel close pattern exists at `Source/Forms/DataForm.Designer.vb:54-72`. `ButtonEx` exposes focus cues at `Source/UI/Controls/Controls.vb:2183-2187`.

Capture the invoking control before `ShowDialog(Me)` and restore focus afterward. Refresh updates the existing summary control instance without moving focus.

A scoped scan of 147 VB files found no explicit `AccessibleName`, `AccessibleDescription`, or `AccessibleRole` assignments. New properties are a deliberate hardening step, not a copied verified pattern.

`FormBase.SetTabIndexes` rewrites order geometrically during load at `Source/UI/Misc.vb:106-180`. Runtime traversal must be observed. Designer order is not evidence.

## Position-persistence decision

Every `FormBase` restores position on load and saves it on close at `Source/UI/Misc.vb:149-167`. `WindowPositions.Save` always writes a location and window-state key at `Source/UI/Misc.vb:269-287`. The store belongs to application settings at `Source/General/ApplicationSettings.vb:114,220-226`.

**verified:** A new details `FormBase` would add persisted project-check settings state without an opt-out.

Smallest proposed change:

```text
FormBase.RememberPosition As Boolean = True
```

Guard only the existing restore and save calls with this protected property. `ProjectChecksDetailsForm`, which inherits `DialogBase`, sets it to `False`. Existing forms keep the default and retain current behavior. The new form writes no position or state key. `DialogBase` already sets `SaveAndLoadSize = False` and `StartPosition = CenterParent` at `Source/UI/Misc.vb:194-206`.

Rejected choices:

- Accept the new settings entry: conflicts with the no-persistence rule.
- Inherit raw `Form`: conflicts with D-025 and loses common StaxRip form behavior.
- Reuse `DataForm`: its key includes form type and text at `Source/UI/Misc.vb:318-336`; it does not remove persistence.
- Override close without calling the base: risks dropping unrelated base behavior.

Confirmed D-037 approves this default-preserving base-class guard. The design model verifies that a default probe form restores and saves position and that the opted-out form creates no placement key. The production source contract verifies one default, two guards, and `RememberPosition = False` only in the new details form. Loaded runtime persistence remains an L4 boundary.

## Fixture proposal

| Id | Shape | Purpose | State |
|---|---|---|---|
| `FX-AVS-01` | AviSynth BlankClip, 320x180, 120 frames, 24000/1001, YUV420P8 | AviSynth script path | exact ignored bytes and SHA-256 recorded in `M0-FIXTURE-MANIFEST.json` |
| `FX-VPY-01` | VapourSynth BlankClip with the same facts | VapourSynth script path | exact ignored bytes and SHA-256 recorded in `M0-FIXTURE-MANIFEST.json` |
| `FX-MP4-01` | 3 seconds, 640x360 CFR H.264/AAC, no title, tags, or chapters | Common container path | exact ignored bytes and SHA-256 recorded in `M0-FIXTURE-MANIFEST.json` |
| `FX-MKV-01` | Same video, two synthetic audio streams, one synthetic subtitle | Bounded multi-stream slow case | exact ignored bytes and SHA-256 recorded in `M0-FIXTURE-MANIFEST.json` |
| `FX-BAD-01` | Fixed malformed MP4 | Pre-success failure and stale-result case | exact ignored bytes and SHA-256 recorded in `M0-FIXTURE-MANIFEST.json` |

Script and container support is source-backed at `Source/General/Misc.vb:1914,1925,1929,1933` and `Source/Forms/MainForm.vb:2754-2766`.

The manifest must record fixture id, byte length, SHA-256, generator arguments, generator executable SHA-256 and version, expected MediaInfo facts, expected script engine, and template hash. It must not contain a user path or media name.

Current repository facts:

- Existing code uses FFmpeg synthetic generation at `Source/General/Audio.vb:669-681`.
- `Package.ffmpeg` has no pinned version at `Source/General/Package.vb:117-128`.
- The tracked build is not a complete runtime at `Docs/Contribution/README.md:9,99-101`.
- Contributor guidance says not to commit media at `Docs/Contribution/README.md:105-112`.

Confirmed D-037 keeps generated fixture bytes under an ignored isolated verification root and tracks only their manifest, generator recipe, byte length, SHA-256, generator identity, expected media facts, script engine, and template hash. This avoids adding media to the public fork. It binds local evidence to specific bytes but does not claim that an arbitrary generator build reproduces identical bytes.

The first tracked recipe parameter declaration rejected the intentional blank lines in the VPY and SRT arrays. The narrow correction adds `AllowEmptyString` to that array parameter. A fresh replay into an empty, isolated `Source/obj/ProjectCheckFixtures` root with the manifest-pinned PowerShell and FFmpeg executables reproduced the byte length and SHA-256 of all six artifacts. The corrected recipe is 7,484 bytes with SHA-256 `DF5FDCF6DADA54CC68AA4619382DFEDE7DD9B06B5E00B248D05A8791A413E051`. This closes recipe replay for the pinned toolchain only. It does not close template, script-runtime, source-opening, performance, or arbitrary-toolchain boundaries.

## Timing and handle protocol

### Full source flow

- Preserve a baseline build at `c26e0fa6` and the candidate build.
- Record executable, runtime, tool, template, and fixture hashes.
- For each successful fixture, discard three warmups.
- Run 20 measured fresh-state opens in paired alternating AB/BA order.
- Measure from the interactive open call after selection to the first idle UI turn after presentation publication.
- Report the median per fixture. Do not pool fixtures.
- Pass when each candidate median delta is no more than the larger of 5 percent of its baseline median or 100 ms.

### New evaluation and rendering

- Load the slowest successful fixture.
- Discard five explicit refreshes.
- Measure 50 unchanged refreshes on the UI thread from snapshot start through the first idle turn after publication.
- Sort the 50 values and use sample 48 as nearest-rank p95.
- Require p95 no greater than 100 ms.

### Process handles

- After the same five warmups, drain UI work and record `Process.HandleCount`.
- Run 50 refreshes without opening details.
- Drain UI work with the same GC and finalizer policy and record the final count.
- Require final minus initial no greater than zero.
- Repeat the whole block once if the first block is nonzero. Do not add tolerance.

Record only OS build, CPU and logical-core count, RAM, storage class, power plan, .NET release, display scaling, `s.UIScaleFactor`, configuration, commit, hashes, counts, and aggregate timing values. Omit paths, user names, and media names.

## Production ownership and exact edit sites

| Owner | Responsibility | Source edit site |
|---|---|---|
| `ProjectChecksSummaryControl` | Render the current presentation state and expose Details and Refresh events only | New programmatic control; no designer or resource file |
| `ProjectChecksDetailsForm` | Render immutable rows and the non-authorization notice only | New programmatic `DialogBase` form |
| `MainForm_SourceProjectChecks` | Mount the summary, route refresh and details, restore focus, install the fixed menu, and apply a feature-only high-contrast palette if the prototype requires it | New `MainForm` partial |
| `FormBase` | Preserve current placement behavior by default and permit one protected runtime opt-out | `Source/UI/Misc.vb:15,149-163` |
| MainForm constructor | Initialize feature state before startup project replacement; install fixed menu after the custom menu build | `Source/Forms/MainForm.vb:1023-1065` |
| Main menu editor | Reinstall the fixed menu after the custom menu has disposed and rebuilt strip items | `Source/Forms/MainForm.vb:4121-4129` |

Presentation files must not call Assistant, Add Job, Start Encoding, a process, file, package, settings writer, log, or clipboard API. They render the typed presentation state and raise feature events only.

## Ignored UI prototype plan

Use `Source/obj/ProjectCheckUiProbe/`, which `.gitignore:12` excludes. The inspected project must be a standalone .NET Framework 4.8 x64 WinForms executable with no package or solution entry and a PerMonitorV2 manifest matching `Source/My Project/app.manifest:23-29`.

The historical M0 probe reproduces the four-column grid, fixed bottom-row height, minimum and restored main-window sizes, geometric tab ordering, attached summary cell, fixed three-plus-one span, disposable menu rebuild, and details form. It exercises Hidden, fact, warning, blocker, unknown, not-applicable, Unavailable, Refresh required, and the longest truthful selected-check copy. M3 supersedes its Hidden-state span and final row-height choices with production-control evidence.

Automated assertions cover no clipping or overlap, one fixed menu after repeated rebuilds, exact tab sequence, row traversal, Escape, Alt+F4, focus return, non-stealing Refresh, accessibility metadata, and no clipboard route. Human observation covers UI Automation or Narrator order, high contrast, and Windows DPI 100, 125, 150, and 200 percent with synthetic strings only.

The stop condition is a fourth column that cannot hold the truthful non-authorization copy at supported minimum width and scale. Do not shorten away the Add Job or encode caveat to make it fit.

## Current evidence state

| Question | Result |
|---|---|
| Q-008 / U-014 | Design and deterministic production composition close through the ignored delegate probe and `M2-INTEGRATION.md`; loaded GUI runtime evidence remains L4 |
| Q-002 / U-010 | Ownership closes through the strict ignored x64 model in `M0-UI-PROBE.md`; M3 supersedes its fixed Hidden-state span and limited-font row height through the refined production layout and expanded matrix; physical DPI, high contrast, Narrator/UIA, keyboard, and loaded behavior remain L4 |
| Q-003 / U-004 | Closed by the reviewed v6 matrix under `M0-RUNTIME-PLAN.md`: four routes pass three discarded warmups and 20 alternating pairs, malformed-later-open ends Hidden, refresh p95 is 1.311 ms, handles change 625 to 624, and independent postflight finds zero task processes and mappings |

No protected build, package, or release script was run while producing this M0 design artifact. Later direct and solution x64 builds are recorded in `M2-INTEGRATION.md`. `Source/Build.ps1` is a Release x64 build wrapper, while `BuildAndPack.ps1` and `Release.ps1` delete, copy, or package files. None is a timing command for this work.
