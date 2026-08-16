# SLICE-001 M3 Presentation

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Production implementation compiles and the production-control probe passes; full GUI, human, and UI Automation evidence remains pending.

## Production shape

The production presentation adds:

- a permanently attached `ProjectChecksSummaryControl` in `tlpMain` cell `(3, 4)`;
- a four-column Assistant span while checks are `Hidden`, a three-plus-one layout for visible project-check states, and a 177-logical-pixel bottom row (`531.0!` at the designer's 288-DPI baseline);
- exact `&Details...` and `&Refresh` summary actions;
- a fixed `Source chec&ks` menu with `&View details...` and `&Refresh project checks` children, identified only by stable `Name` values;
- a read-only three-row `ProjectChecksDetailsForm` with Status, Check, and Explanation columns;
- explicit accessibility names, descriptions, and roles, with current result and notice text exposed dynamically;
- focus capture and return around the modal details form;
- automatic details-form closure when its exact result becomes stale;
- a default-preserving `FormBase.RememberPosition` guard, set to `False` only by the new details form; and
- theme handling with an explicit `SystemColors` high-contrast palette and visible system-color button borders.

The summary uses the pure `ProjectCheckPresentationText` renderer. Its exact available-state shape is:

```text
<Overall>. Fact N; Warning N; Blocker N; Unknown N; N/A N. Add Job and encode-time checks still run later. This result does not authorize encoding.
```

The four approved overall labels are `Blockers found`, `Warnings found`, `Checks incomplete`, and `Selected checks passed`. Presentation code does not echo raw ids, message keys, paths, or exception arguments.

## Strict presentation probes

The earlier 84-logical-pixel row used shorter copy and failed 56 copy-fit assertions after the exact D-037 count and non-authorization text was applied. A 112-logical-pixel row passed the first limited font matrix but failed the expanded selectable-font audit: 96 of 141 bundled selectable Default font families failed at least one combined scale case. The first row height that passed all 1,410 inspected font/scale cases is 177 logical pixels. This is a tested lower bound for the inspected matrix, not a claim about every installed font or layout.

The final ignored package-free .NET Framework 4.8 Release x64 probe loaded the Debug x64 production assembly and exercised the actual production presentation text, `LabelEx`, `ButtonEx`, details form, compiled MainForm wiring, tracked source contracts, position guard, dynamic Assistant span, source and mutation balance before process cleanup, mutation-Begin self-balance, and control construction and disposal. It did not construct MainForm or open a project. Two launches passed the same 193,784 assertions, two declared skips, identities, complete font matrix, and resource baseline. Every measured resource delta was zero:

```text
RUN 1 RESOURCE iterations=50 handles_before=376 handles_after=376 delta=0
RUN 1 RESOURCE gdi_before=24 gdi_after=24 delta=0 user_before=10 user_after=10 delta=0
RUN 2 RESOURCE iterations=50 handles_before=376 handles_after=376 delta=0
RUN 2 RESOURCE gdi_before=24 gdi_after=24 delta=0 user_before=10 user_after=10 delta=0
RESULT PASS assertions=193784 skips=2
FONT_MATRIX families=141 scales=10 states=6 widths=3 cases=25380
FONT_SCALES 0.75,0.9375,1,1.125,1.25,1.5,1.875,2,2.25,3
PROCESS x64=True machine=0x8664
BOUNDARY skips=2
```

The font input contains 108 bundled TTF files and 155 raw family names. After the probe's explicit selectable-family exclusions, 141 unique Regular families remain. The 25,380 production-control cases cover those families, ten scale factors, six visible states, and three widths. They assert actual production geometry, exact copy fit, accessibility text, action-button fit, and non-overlap. The resource block covers 50 create, render, native-handle, and dispose cycles. Its zero deltas are focused presentation-control evidence, not the full application refresh and process-handle result that later closes U-004 under `M0-RUNTIME-PLAN.md`.

Each complete probe launch took approximately 97 seconds. That is the verification matrix runtime, not project-check latency or evidence for the application performance target.

A separate compiled dynamic-span exercise uses an uninitialized MainForm owner with the real production layout and controls. The actual render method changes Hidden to an invisible summary with a four-column Assistant, Available to a visible three-plus-one layout, Unavailable to the same visible layout, and a final Hidden transition back to four columns. This is bounded product-assembly behavior, not normal MainForm construction or a loaded workflow.

The two declared skips are complete MainForm construction, project opening, modal display, and focus restoration because they cross the live settings and project boundary; and physical DPI, high contrast, Narrator, and real keyboard traversal because they require the human walkthrough.

The historical 1,823-assertion and 1,786-assertion model results are not directly comparable to this production-control probe. `M0-UI-PROBE.md` preserves the limited-font ownership, menu, focus-model, and position evidence while this M3 probe supersedes its 112-pixel row selection.

Probe input identity:

```text
StaxRip.exe                              D41F6CCF86EAA67849CE4205C5629046784826BDEE783636284CF5D6C5A7177E
Program.cs                               F607CCF082F8B225775E638945B85A569A8E395015B3D24B96C674E30A61C941
ProjectCheckProductionUiProbe.csproj     15094389BC546AEA14CAC6CB6091AF6E56991FA7F3078BCC988DE1E2E8F6EE56
ProjectCheckProductionUiProbe.exe        3FCB4437B3F4C4FB7CD11E8F84003DBF82D9141B110270744197810DC63C924F
production_source_manifest               A2CC44F44C751F5435E6C91AB7732FFC9B34AF40FF8AA2F302201E0760A1FC13
bundled_font_manifest                     D728C7D79BE53E5F5439F1FDBBCB4E8A800728CC6A1E520F819B39A5A5E012E8
```

The executable hashes bind these runs to exact binaries. The source and font manifests retain reviewable input identity when a later rebuild produces a different executable hash.

## Production-source evidence

The 87-assertion production-source contract in `M2-INTEGRATION.md` verifies the actual row size, four-column Hidden and three-plus-one visible Assistant spans, summary placement, fixed menu rebuild, labels, strict count text, later-check caveat, available-only Details action, non-hidden Refresh action, dynamic result accessibility text, stale-details closure, high-contrast button borders, mutation balance, read-only and no-clipboard grid, sole position opt-out, production compile entries, and prohibited boundaries.

This source contract and the production-control probe prove the bounded compiled and rendered control shape they exercise. They do not prove a loaded MainForm, source-opening publication, modal focus restoration, or the operating system's assistive-technology outcome.

## Security, privacy, logging, and persistence impact

- The controls render fixed allowlisted English selected by enums, stable ids, and stable message keys.
- No project-check control calls a log, process, package, file, directory, network, settings writer, or clipboard API.
- Accessibility values contain fixed descriptions, not project or media data.
- Existing forms retain position restore and save by default. The details form writes no placement key.
- Details contains exactly the three current catalog rows. The nine-row design probe exercised all modeled outcome classes and was not a production row-count claim.

## Remaining boundary

- **unknown:** Physical Windows DPI behavior at 100, 125, 150, and 200 percent.
- **unknown:** Actual high-contrast palette and focus-cue rendering.
- **unknown:** Narrator and UI Automation reading order and row semantics.
- **unknown:** Physical keyboard Tab, Shift+Tab, arrow, mnemonic, Escape, Alt+F4, and return-focus behavior.
- **unknown:** Complete production main-window layout interaction with user-customized menus and settings.
- **unknown:** Loaded-project modal display, automatic stale-dialog closure, and focus restoration in the complete MainForm.

M4 and L4 own those observations. No accessibility, performance, or user-value completion claim is made by the production-control probe or static source check.
