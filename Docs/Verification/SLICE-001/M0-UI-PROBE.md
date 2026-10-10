# SLICE-001 M0 UI Probe

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Historical limited-font and fixed-span pass; final row height and Hidden-state span are superseded by the expanded M3 production probe.

## Scope

The inspected standalone .NET Framework 4.8 x64 probe lives below ignored `Source/obj/ProjectCheckUiProbe/`. It reproduces the approved four-column bottom layout, permanent summary cell, fixed-menu rebuild, details grid, geometric tab ordering, position-persistence opt-out, and bounded presentation states. It has no package, solution entry, application project entry, or tracked reference.

The probe is a source-matched design model. It is not production UI or runtime evidence.

## Build and run

The Debug x64 build succeeded. PE machine inspection returned `0x8664`. The original 84-logical-pixel row failed 56 fit assertions after the exact D-037 counts and caveat were applied. The smallest passing shape in this limited-font model used a 112-logical-pixel row and a 70/30 text/action split. Two final launches of that historical shape exited 0 with identical bounded output:

```text
OBS tab_sequence=SourceControl>AssistantControl>ProjectChecksDetails>ProjectChecksRefresh
OBS live_device_dpi=96 high_contrast=False x64=True
OBS simulated_layout_scenarios=16 source_width_multiples=48,64,80 dpi_percent=100,125,150,200 ui_scale=0.75,1.00,1.50
UNKNOWN physical DPI 100/125/150/200%, high-contrast palette, Narrator/UIA order, and physical-keyboard behavior require human observation
RESULT PASS assertions=1786 failures=0
```

## Automated observations

- **verified:** The summary remains attached at cell `(3, 4)` and the Assistant spans three columns.
- **verified for this model:** All approved states, all five counts, exact action labels, and the full Add Job and encode-time non-authorization copy fit its 16 simulated scenarios in the 112-logical-pixel row.
- **verified:** Repeated custom-menu disposal and rebuild leaves one fixed stable-name menu and preserves a user item with matching visible text.
- **verified:** The modeled tab path reaches summary Details and Refresh. Refresh retains focus. Up and Down traverse all nine modeled detail rows.
- **verified:** The grid is read-only, non-sortable, single-select, full-row, no-resize, no-tooltip, no-copy, and uses standard tab behavior.
- **verified:** Escape and Alt+F4 close details, and focus returns to the invoking control.
- **verified:** Every new modeled control has explicit accessibility metadata.
- **verified:** A default form restores and saves placement once. The details opt-out restores and saves placement zero times. The opt-out assignment appears once.
- **verified:** Source inspection found no file, directory, process, package, settings, log, network, or Clipboard API boundary.

## Probe identity

```text
ProjectCheckUiProbe.vbproj  0BC369534D0DBCE391B4182639385F01EAEFFFE20C6380DBECCB5EC560B09225
Program.vb                  5CE050BBAA4BAF941682713ABEEE23E2A1D973149885CD02EADA4A21D2701F17
app.config                  16339CD2498AE642B97C7C5573149ED12D07790D7DD4FC6DD0D0FD4CF8A9E928
app.manifest                9C61EE321169438E661EC39FD04E4597397226D1C5EA1ACE02E37B41C1A610B6
```

Compiler-generated executable identity changed across rebuilds even when the input and bounded output stayed stable. The source and manifest hashes above are the retained probe identity.

The former 1,823-assertion result is superseded. It graded shorter contract-incomplete copy and the rejected 84-pixel geometry. The 1,786 assertions are not a reduced version of the same matrix; they enforce the exact D-037 summary for this model.

The later M3 production audit loads 141 selectable bundled Default font families across ten combined scale factors. Ninety-six families fail at least one case with 112 logical pixels. `M3-PRESENTATION.md` supersedes this probe's row-height selection with the first expanded-matrix passing height, 177 logical pixels. The final production refinement also restores the Assistant's four-column span while project checks are Hidden and uses three-plus-one only for visible states. The ownership, menu, focus-model, attached-control, and position-opt-out observations in this file remain useful M0 design evidence.

## Remaining boundary

- **unknown:** Physical Windows DPI runs at 100, 125, 150, and 200 percent.
- **unknown:** High-contrast rendering; the observed machine reported high contrast False.
- **unknown:** Narrator and UI Automation reading order.
- **unknown:** Physical-keyboard behavior.

M3 implements the refined production source shape and exercises the expanded matrix with production controls. L4 and M4 own the complete MainForm, operating-system, and human observations. The automated M0 ownership and position-persistence design gate passes; this file no longer defines the final row height or Hidden-state Assistant span.
