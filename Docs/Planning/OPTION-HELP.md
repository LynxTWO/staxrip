# StaxRip Design: Plain-English Option Help

Version: 0.1 Draft. Date: 2026-08-26. Status: Awaiting maintainer review before an implementation plan is written.
Branch: `worktree-option-help` off `origin/master` `eb8c33c9`.
Companion documents: `../../AGENTS.md`, `ENGINEERING.md`, `DECISION-LOG.md`.

This document is the build boundary for the first slice of option help. If work is not named here, it does not enter the slice.

## 1. What this proves

- **Central claim:** A person with no video-encoding knowledge can point at any option in an encoder dialog and learn, in one or two plain sentences, what it does to their video and when to change it, without leaving the dialog and without reading the encoder's own manual.
- **The slice in one line:** Every option in the SVT-AV1 dialog shows a plain-English summary on hover, in a description strip above the command line, and in a details window on right-click; the text lives in Markdown files that a non-programmer can edit on GitHub; a script proves that no option is left without text and that coverage never goes backwards.
- **Honest stakes:** If the maintainer reads the SVT-AV1 text on the real dialog and it does not read as clearly better than the encoder's `--help` output, the fork should fix the writing rules before authoring the remaining ~600 stanzas for the other encoders.

## 2. The walkthrough

1. The user opens the SVT-AV1 options dialog from the encoder section of the main window.
2. Pointing at the `Preset` label, its dropdown button, or any other control shows a tooltip: one or two sentences, followed by the line `Right-click for details`.
3. At the same time the description strip above the command-line preview shows the option's name, the same summary, and a `When to change` line. Moving keyboard focus to a control updates the strip the same way, so the feature works without a mouse.
4. Opening the `Preset` dropdown and pointing at `6: Medium` shows a short note for that value.
5. Right-clicking the label opens a details window: what the option does, when to change it, an example with numbers, a table of the values, related options, a link to the encoder's documentation, and a link that opens the encoder's own `--help` text for that switch, which is what right-click does today.
6. Typing `grain` or `dark` into the search box at the bottom left finds options whose help text mentions those words, not only options whose switch contains them.
7. Options without reviewed text behave exactly as they do today.
8. The generated command line is identical before and after this change for every encoder.

## 3. Current behavior, verified

| Fact | Evidence |
| --- | --- |
| Every option already has `Help`, `HelpSwitch`, and `URLs` properties | `Source/Video/VideoEncoderCommandLine.vb:195-215` |
| `CommandLineParams.Add` fills `HelpSwitch` with the first switch when it is empty | `Source/Video/VideoEncoderCommandLine.vb:39-45` |
| For any option with a `HelpSwitch`, the dialog attaches only a right-click action that opens the encoder's console `--help` text; the assembled help string, including `.Help`, is discarded. No hover tooltip exists for these options | `Source/Forms/CommandLineForm.vb:212-218`, `231-236`, `253-259`, `297-302`; `ShowConsoleHelp` at `Source/Video/VideoEncoderCommandLine.vb:74-110` |
| 24 of 2,261 parameters set `.Help`; four x265 strings on switch-bearing options are never shown because of the rule above | `Source/Encoding/x265Enc.vb:1368`, `1569`, `1570`, `1585` |
| Tooltip text longer than 80 characters is replaced by `Right-click for help`; the same rule applies to menu items | `Source/UI/TipProvider.vb:87-88`, `Source/UI/Menu.vb:623-627` |
| Per-dropdown-value tooltips are already supported by `MenuButton.Add(path, obj, tip)`; the dialog passes no tip | `Source/UI/Controls/Controls.vb:1844`, `Source/Forms/CommandLineForm.vb:275` |
| A rich HTML help window exists (`HelpForm` over `HelpDocument`); it intercepts only `http` links | `Source/Forms/HelpForm.vb:108-113`, `Source/General/General.vb:439` |
| The search box already searches `Param.Help` | `Source/Forms/CommandLineForm.vb:413` |
| Text files ship as embedded resources through `<EmbeddedResource Include="..\CHANGELOG.md"><Link>CHANGELOG.md</Link>` and are read with `GetManifestResourceStream` | `Source/StaxRip.vbproj`, `Source/Forms/MainForm.vb:6206-6208` |
| No Markdown, YAML, or JSON library is referenced | `Source/packages.config` |
| 2,261 parameters collapse to 674 distinct switches; the five SVT-AV1 variants share 108 switches; x264 and x265 share 60; NVEnc, QSVEnc, and VCEEnc share 51 | `grep -oh '\.Switch = "[^"]*"' Source/Encoding/*.vb \| sort -u`, counted 2026-08-26 |
| SVT-AV1 mainline declares 101 live parameters (two are commented out); 13 have no switch and are keyed by `Name` or `Text` | `Source/Encoding/SvtAv1Enc.vb:437-1360`, dialog title `(101 options)` |
| The Linux line's web shell is 266 lines of plain JavaScript with no options UI yet | `fork/linux-foundation:CrossPlatform/src/StaxRip.Server/Web/app.js` |
| StaxRip is MIT licensed; x264 and x265 documentation is GPL | `License.txt` |

## 4. Content model

### 4.1 Files and layering

All content lives under `Docs/OptionHelp/`. One file per encoder, plus two shared files.

| File | Holds | Fallback order |
| --- | --- | --- |
| `<encoder>.md`, for example `svt-av1.md` | Every option of that encoder, with the numbers that are true for it | first |
| `<variant>.md` with `Inherits: <base>`, for example `svt-av1-psyex.md` | Only the variant's additions and any stanza it needs to override | before its base |
| `staxrip.md` | The nine controls StaxRip adds to every encoder dialog: Decoder, Pipe, Custom, Override Target File Name, Target File Name, Preview, Chunks, Comp. Check, Aimed Quality | after the encoder chain |
| `concepts.md` | Text that is true for every encoder, keyed by switch where switches are shared, plus glossary entries keyed by a plain word | last |

Lookup walks the chain encoder, `Inherits` chain, `staxrip`, `concepts` and stops at the first reviewed stanza. Text with numbers belongs in the encoder file; `concepts.md` holds only what is true everywhere. A new encoder is one new VB class plus one new file with a header; a new variant is one file with `Inherits`.

Files are embedded into `StaxRip.exe` as resources and read from the repository by the Linux server. The file grammar is the contract between the two; see section 7.

### 4.2 File grammar

The grammar is a strict subset of Markdown so that GitHub renders it and a 60-line parser reads it. Anything outside the subset is a validator error, not a rendering surprise.

- Encoding: UTF-8 without BOM, LF line endings, ASCII printable characters only (tab, LF, and 0x20 to 0x7E).
- An optional first line `# <title>` is ignored by parsers.
- Single-line HTML comments `<!-- ... -->` are ignored anywhere.
- Blank lines are ignored.
- **Header:** every `Key: value` line before the first `## ` line. Keys are listed in 4.3.
- **Stanza:** starts at a line `## <key>` and ends at the next `## ` line or end of file. `<key>` is the rest of the line, trimmed.
- **Field line:** `<Field>: <text>`. Text continues on following lines that are not blank, not a field line, not a bullet, and not a heading; continuation lines join with a single space.
- **Values list:** the field line `Values:` has no text and is followed by bullet lines `- <value>: <note>`. `<value>` is the literal command-line value; the first `: ` separates it from the note.
- **Inline markup**, the only two forms allowed: backticks for a literal switch or value, and `[text](url)` for a link. Tooltips and the description strip show plain text (backticks removed, link text kept); the details window renders code and links.

### 4.3 Header keys and stanza fields

Header keys:

| Key | Required | Rule |
| --- | --- | --- |
| `Encoder` | yes | `[a-z0-9-]+`; equals the file name without `.md` |
| `Title` | yes | Display name, for example `SVT-AV1` |
| `Source` | all but `concepts` and `staxrip` | Repository-relative path of the VB file that declares the parameters, for example `Source/Encoding/SvtAv1Enc.vb` |
| `Inherits` | no | Another `Encoder` id; chains must be acyclic; `staxrip` and `concepts` are implicit and never named |
| `Coverage` | all but `concepts` and `staxrip` | Integer percent; floor for (reviewed + draft) / total parameters, see 6.4 |
| `Reviewed` | all but `concepts` and `staxrip` | Integer percent; floor for reviewed / total parameters |

Stanza fields, in this order:

| Field | Required | Limit | Purpose |
| --- | --- | --- | --- |
| `Label` | no | 60 chars | The control's caption, for readers of the raw file; validator warns when it differs from the VB `.Text` |
| `Summary` | yes | 1 to 200 chars, one or two sentences, ends with `.` | Tooltip and description strip |
| `When to change` | for `reviewed` | 400 chars | Description strip second line and details window |
| `Example` | no | 300 chars | Details window |
| `Values` | no; option parameters only | 120 chars per note | Per-value dropdown tooltip and details table |
| `Related` | no | keys, comma separated | Details window links; each key must resolve in the chain or in `concepts` |
| `Source` | no | one URL | Details window link to the encoder's documentation |
| `Status` | yes | `draft` or `reviewed` | Only `reviewed` stanzas display in the application |

### 4.4 Keys and lookup order

A parameter's keys, in order, mirror the runtime: `HelpSwitch` as it stands after `CommandLineParams.Add` (an explicit `.HelpSwitch`, else `.Switch`, else `.NoSwitch`, else the first `.Switches` entry), then `.Switch`, `.NoSwitch`, each `.Switches` entry, `.Name`, and `.Text`, with duplicates removed. The loader tries each file in the chain and, within a file, each key in that order. The validator counts a parameter as covered when any of its keys resolves.

Consequences that authors must know:

- Parameters that share a switch share one stanza. In SVT-AV1: `--keyint` (two controls that alternate by rate-control mode), `--pass` (two `Passes` controls), and `--content-light` (Maximum CLL, Maximum FALL, and a hidden combined field). The stanza explains the switch, not one control.
- Switch-less controls are keyed by their caption, for example `## Chunks`, `## Comp. Check`, `## Pipe`, `## Custom`; the four `Custom` text boxes share one stanza.
- Headings are matched exactly after trimming; switches are case-sensitive.

### 4.5 Writing rules

These rules are the whole style guide; `Docs/OptionHelp/README.md` repeats them next to a copyable template.

1. The first sentence says what the option does to the user's video, in words a newcomer knows.
2. The second sentence, or `When to change`, names a concrete situation and a number: "use 4 or 5 for something you will keep".
3. Say what the default does. When the honest advice is "leave it alone", say that.
4. Hedge numbers ("roughly", "might") and verify each one against the encoder's documentation or a test encode before marking the stanza `reviewed`.
5. No acronym or jargon without a glossary entry in `concepts.md` reachable through `Related`.
6. Original wording only. Link to upstream documentation; never paste it. x264 and x265 documentation is GPL and StaxRip is MIT.
7. ASCII only; straight quotes; hyphens, not dashes.
8. Prose is written or rewritten by the strongest model available (Claude Fable 5 at the time of writing) or by a person. Mechanical work may use any tool. This is a standing instruction from the maintainer (2026-08-26).

### 4.6 Example stanzas

Illustrative. Every number below is re-verified during authoring before the stanza is marked `reviewed`.

```markdown
# SVT-AV1 option help

Encoder: svt-av1
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Coverage: 0%
Reviewed: 0%

## --preset
Label: Preset
Summary: How hard the encoder works on each frame. Slower presets make smaller files at the same quality but take much longer.
When to change: Leave it at 6 for most videos. Use 4 or 5 for something you will keep and watch again; use 8 to 10 for quick tests or when time matters more than file size.
Example: A two-hour film at preset 6 might take about an hour on a modern desktop; preset 4 might take three hours for a file roughly 5 to 10 percent smaller.
Values:
- 0: Research-grade. Hours per minute of video; not practical.
- 6: The sweet spot for most people.
- 13: Testing only; quality suffers.
Related: --crf, --tune
Source: https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/master/Docs/Parameters.md
Status: reviewed

## --tune
Label: Tune
Summary: Tells the encoder which idea of "looks good" to aim for. The default aims at a mathematical score; VQ aims at what people actually see.
When to change: Most people encoding film or TV should pick 0: VQ. Keep PSNR only when you are comparing encodes by metric scores.
Values:
- 0: Visual quality. Keeps more detail and grain at the cost of metric scores. Usually best for watching.
- 1: Optimizes for the PSNR score. The default; tends to look slightly smoother.
- 2: Optimizes for the SSIM score.
- 3: For single still images (AVIF).
- 4: Optimizes for the MS-SSIM and SSIMULACRA2 scores.
- 5: Optimizes for the VMAF score. Video only.
Related: --preset, --crf
Status: reviewed

## --lp
Summary: How many CPU threads the encoder may use. 0 lets it decide.
Status: draft
```

## 5. Windows implementation

### 5.1 Loader: `Source/General/OptionHelp.vb`

New file, namespace `StaxRip`, no new dependency.

| Type | Responsibility |
| --- | --- |
| `OptionHelpStanza` | `Key`, `Label`, `Summary`, `WhenToChange`, `Example`, `Values` (ordered value/note pairs), `Related`, `Source`, `Status`, `File` |
| `OptionHelpFile` | `Encoder`, `Title`, `Inherits`, `Stanzas` (ordinal, case-sensitive dictionary), `Errors` |
| `OptionHelpParser` | `Shared Function Parse(text, name) As OptionHelpFile`; pure; implements exactly the grammar in 4.2; records grammar errors with line numbers instead of throwing |
| `OptionHelpCatalog` | `Shared Function Get(encoderId) As OptionHelpCatalog`, cached per id, `Nothing` when no resource exists; `Function Find(param) As OptionHelpStanza` walking the chain from 4.1 and returning reviewed stanzas only; `Function FindValueNote(stanza, value) As String`; `Function PlainText(text) As String` for tooltips |

Resources are discovered by enumerating `GetManifestResourceNames()` for names that contain `.OptionHelp.` and end with `.md`; the id is the segment between them. Discovery does not hard-code the manifest naming of a linked file, so a naming quirk with the hyphen in `svt-av1.md` cannot break loading (see U-OH-1). Files load lazily on first dialog open, under a lock, once per process. Parse errors go to the existing debug log path and never to a dialog; valid stanzas in a file with errors still load.

### 5.2 Encoder binding

`CommandLineParams` gains `Overridable ReadOnly Property OptionHelpId As String` returning `Nothing`. `SvtAv1EncParams` (`Source/Encoding/SvtAv1Enc.vb:437`) overrides it to return `"svt-av1"`. Encoders that do not override keep today's behavior exactly. The validator checks that each `Source:` file overrides the property with the file's `Encoder` id (rule E9).

### 5.3 `CommandLineForm` changes

All changes are in `Source/Forms/CommandLineForm.vb` and its designer file; no parameter class other than the property in 5.2 changes, and command-line generation is untouched.

| Change | Where | Behavior |
| --- | --- | --- |
| Resolve stanzas | `InitUI`, before the loop | `catalog = OptionHelpCatalog.Get(Params.OptionHelpId)`; per parameter `stanza = catalog?.Find(param)`; stored on the existing `Item` class as `Stanza` |
| Hover tooltip | the four branches at lines 212, 231, 253, 297 | When a stanza exists: `TipProvider.SetTip(text, allowLong:=True, controls)` with `Summary` plus a second line `Right-click for details`. The new `allowLong` overload skips the 80-character substitution and does not register the right-click handler, so it cannot double-fire with `HelpAction`. Without a stanza the current branch runs unchanged |
| Right-click details | same branches | When a stanza exists: `HelpAction = Sub() ShowOptionHelp(param, stanza)`. Without a stanza: unchanged (console help when a `HelpSwitch` exists) |
| Dropdown value notes | option branch, line 275 | `Dim item = menuBlock.Button.Add(text, x2)`; when the stanza has a note for that value, `item.ToolTipText = note` set directly so the 80-character rule in `Menu.vb` does not apply. The value string is `oParam.Values(x2)` when `Values` exists, else the index for `IntegerValue` options, else the lower-cased option text as `GetArgs` computes it |
| Description strip | designer plus `InitUI` | `lblDescription As LabelEx` in `tlpMain` at a new row 1 spanning all four columns; `tlpRTB` moves to row 2 and the button row to row 3; `AutoSize = False`, height `FontHeight * 3` plus padding, `AutoEllipsis = True`, `UseMnemonic = False`, anchored left and right. `LabelEx` themes itself. `MouseEnter` and `Enter` on each parameter's label, control, and menu button call `SetDescription(param, stanza)`, which shows `<caption>: <Summary>` and, on the next line, `When to change: <text>` when present. The strip keeps the last text on `MouseLeave`. Initial text: `Point at an option, or move focus to it, to see what it does. Right-click an option for details.` |
| Details window | new `ShowOptionHelp` | `HelpForm` with `HelpDocument`: title = caption; paragraph with the switch names; `What it does`; `When to change it`; `Example`; values table; `Related`; `Source` link; final link `Show the encoder's own help for <switch>` with URL `staxrip:console-help`, handled through 5.4 by calling `Params.ShowHelp(param.GetSwitches)` |
| Search | `cbGoTo_TextChanged`, line 413 | Also matches `Stanza.Summary` and every value note, case-insensitive |

### 5.4 `HelpForm` link hook

`Browser_Navigating` (`Source/Forms/HelpForm.vb:108`) gains: when `e.Url.Scheme = "staxrip"`, cancel navigation and invoke a new `Property LinkAction As Action(Of String)` with the URL. Existing `http` handling is unchanged.

### 5.5 Build metadata

`Source/StaxRip.vbproj` gains one `<Compile Include="General\OptionHelp.vb" />` and, for each content file, `<EmbeddedResource Include="..\Docs\OptionHelp\<file>.md"><Link>OptionHelp\<file>.md</Link></EmbeddedResource>`, mirroring the existing `CHANGELOG.md` item. This is the "normal explicit entries" touch that `SLICE-001.md` section 6 already allows; no configuration, solution mapping, or packaging script changes. Because `AGENTS.md` lists build files as approval-gated, the maintainer's approval of this document is the approval for exactly these entries.

### 5.6 Failure handling

| Failure | Behavior |
| --- | --- |
| No resource for the encoder | `Get` returns `Nothing`; dialog behaves as today |
| Grammar error in a file | Error logged with file and line; the rest of the file loads; the validator is the place that fails |
| Stanza key not found | Control behaves as today |
| `Values` note for a value the option no longer has | Ignored at runtime; validator error E4 |
| Details window cannot open | Existing `HelpForm` error path; no new handler |

## 6. Validator and ratchet: `Source/Tools/OptionHelp/Check-OptionHelp.ps1`

A deterministic PowerShell 7 script. It reads text; it does not build or run StaxRip, so it runs the same on Windows and Linux and fits the `AGENTS.md` rule to use parsers and diffs for facts they can settle exactly.

### 6.1 Interface

| Parameter | Effect |
| --- | --- |
| `-RepoRoot <path>` | Defaults to the script's repository |
| `-Encoder <id>` | Check one file |
| `-Json` | Machine-readable report on stdout |
| `-RaiseFloors` | Rewrite `Coverage` and `Reviewed` headers up to the computed values; never lowers them |
| `-SelfTest` | Run the fixture suite in 6.5 and exit non-zero on any mismatch |

Exit code 0 when no error rule fires; 1 otherwise. Output: one table row per encoder file (total, reviewed, draft, missing, both floors, pass or fail), the list of missing keys with their captions, and every error as `file:line: E<n> <message>`.

### 6.2 Parameter extraction from VB

For each `Source:` file: drop lines whose first non-space character is `'`; find every `New OptionParam`, `New NumParam`, `New BoolParam`, or `New StringParam` followed by `With {`; take the initializer up to the matching `}` counting braces outside double-quoted strings; inside it read `.HelpSwitch`, `.Switch`, `.NoSwitch`, `.Switches`, `.Name`, `.Text`, `.Values`, `.Options`, and `.IntegerValue`. Build the key list per 4.4 and the value list per 5.3. This is the same text-level approach as `ConsolAppTester` (`Source/General/Test.vb`), made exact per parameter.

Known blind spots, recorded in the script's README: parameters declared but never added to `Items` count toward totals (in SVT-AV1 this is the hidden `--content-light` field, which shares a key and is covered anyway); parameters built outside these four patterns are invisible. Verification step V5 reconciles the count against the dialog title.

### 6.3 Rules

| Id | Level | Rule |
| --- | --- | --- |
| E1 | error | Grammar violation from 4.2, including non-ASCII bytes, unknown header key, missing required header key, `Encoder` not equal to the file name, `Inherits` cycle or unknown target |
| E2 | error | `Summary` missing, empty, over 200 characters, or not ending with `.`; `When to change` missing on a `reviewed` stanza; any field over its limit |
| E3 | error | Unknown field name, or fields out of the order in 4.3 |
| E4 | error | `Values` on a non-option parameter, or a value key that is not one of the option's values |
| E5 | error | Orphan stanza: a key in an encoder file that matches no parameter of that encoder or of any encoder that inherits from it; `staxrip.md` and `concepts.md` are exempt |
| E6 | error | `Related` key that resolves nowhere in the chain or in `concepts` |
| E7 | error | Computed coverage or reviewed percent below the file's floor |
| E8 | error | Duplicate key within one file |
| E9 | error | The `Source:` file does not override `OptionHelpId` with this file's `Encoder` id |
| E10 | error | A parameter with no usable key (no switch, `Name`, or `Text`) |
| W1 | warning | An encoder VB file under `Source/Encoding/` with no help file; reported as 0 percent, never fails |
| W2 | warning | `Label` differs from the VB `.Text` |

### 6.4 Floors and the ratchet

Coverage percent is `floor(100 * (reviewed + draft) / total)`; reviewed percent is `floor(100 * reviewed / total)`. Each is compared with the file's header floor; falling below either is E7. Adding a parameter to an encoder therefore fails the check until the author adds at least a `draft` stanza, which is the mechanism that keeps the help current when new settings arrive. `-RaiseFloors` is the only way floors move, and the resulting header diff is reviewed like any other change. A file at `Coverage: 100%` and `Reviewed: 100%` is complete: any new parameter without a reviewed stanza fails. Nothing else marks completeness.

### 6.5 Self-test fixtures

`Source/Tools/OptionHelp/fixtures/` holds a small fake VB file exercising every extraction pattern (property declarations, inline `New ... With {` inside `Add(...)`, nested braces in `.Config`, quoted braces, commented-out declarations, shared switches, switch-less controls) and one Markdown file per rule E1 to E10, plus a clean pair. `expected.json` records the report for each; `-SelfTest` compares and prints the first difference as a bounded failure packet.

### 6.6 Not in this slice

An upstream drift mode that diffs the tool's cached `--help` text against implemented switches. `ConsolAppTester` already does this inside the application; a script version is a follow-up.

## 7. Linux and web contract

The grammar in 4.2 and 4.3 is the contract. The Linux line implements its own small parser in JavaScript or C# when its options UI is built, serves the files as `GET /api/v1/option-help/{encoder}` returning `{ encoder, title, inherits, stanzas: [{ key, summary, whenToChange, example, values: [{ value, note }], related, source, status }] }`, and renders `summary` in a hover popover and the stanza in a side panel. The validator runs there under `pwsh` unchanged and is the only grammar authority; the two parsers are never linked at build time. Nothing on the Linux line is built in this slice.

## 8. First slice: scope and build order

In scope, in build order:

| Step | Contents | Success test |
| --- | --- | --- |
| 1. Grammar and validator | `Check-OptionHelp.ps1`, fixtures, `expected.json`, `Docs/OptionHelp/README.md` with the writing rules and template | `-SelfTest` passes; running on the repository reports SVT-AV1 at 0 percent with W1 for every other encoder and no errors |
| 2. Loader | `OptionHelp.vb` parser and catalog; `OptionHelpId` property and the SVT-AV1 override; vbproj entries | Debug x64 build; a throwaway probe parses the fixture files with results equal to the validator's |
| 3. Dialog | Tooltip overload, right-click details, value notes, description strip, `HelpForm` hook, search | Manual checklist V4 on the SVT-AV1 dialog; V6 command-line equivalence |
| 4. Tier 1 content | `svt-av1.md` for every key in section 9, `staxrip.md` for the nine StaxRip-owned controls, `concepts.md` glossary entries that Tier 1 stanzas link to | Validator reports `svt-av1` at `Coverage: 100%`, `Reviewed: 100%` with floors raised; maintainer reads the text on the real dialog |

Steps 1 and 2 can proceed in parallel; step 4 can start as soon as step 1 exists, since the validator is what authors run.

Out of scope, on purpose:

| Excluded | Where it may connect later |
| --- | --- |
| Content for any encoder other than SVT-AV1 mainline | Tier 2 (SVT-AV1 variants, x264, x265) and Tier 3 (NVEnc, QSVEnc, VCEEnc, aomenc, rav1e, vvenc, ffmpeg) after the tone review |
| Linux parser, API, and web rendering | A slice on `fork/linux-foundation` when its options UI exists |
| Showing `draft` stanzas, even marked | Never; drafts exist so that coverage can be counted, not shown |
| Translations | Sibling files such as `svt-av1.de.md` with English fallback; the grammar already allows it |
| Changing `ShowConsoleHelp` or the `Help about <package>` menu | None; both stay reachable |
| Upstream drift report in the script | Follow-up, see 6.6 |
| Any change to persisted formats, command-line generation, tool selection, or process execution | None |

## 9. Tier 1 content: every SVT-AV1 key

Keys as the validator will derive them from `Source/Encoding/SvtAv1Enc.vb`, grouped by dialog page in `Items` order (`Source/Encoding/SvtAv1Enc.vb:1290`). Controls that share a key are listed once. Counts: 93 stanzas, of which 9 live in `staxrip.md` and 84 in `svt-av1.md`.

| Page | Keys |
| --- | --- |
| Input/Output | `Decoder`*, `Pipe`*, `--progress`, `--frames`, `--skip`, `--color-format`, `--enable-stat-report`, `--asm`, `--lp`, `--pin`, `--ss` |
| Basic | `--preset`, `--profile`, `--level`, `--tune`, `--fast-decode`, `--adaptive-film-grain`, `--max-tx-size` |
| Rate Control | `--rc`, `--crf`, `--cqp`, `--qp`, `--tbr`, `--mbr`, `--max-qp`, `--min-qp`, `--tf-strength`, `--luminance-qp-bias`, `--sharpness`, `--pass`, `--aq-mode`, `--hbd-mds`, `--qp-scale-compress-strength`, `--ac-bias`, `--recode-loop`, `--enable-qm`, `--qm-max`, `--qm-min` |
| GOP size/type | `--keyint`, `--irefresh-type`, `--scd`, `--lookahead`, `--hierarchical-levels`, `--pred-struct`, `--enable-dg`, `--startup-mg-size` |
| AV1 Specific 1 | `--tile-rows`, `--tile-columns`, `--enable-dlf`, `--enable-cdef`, `--enable-restoration`, `--enable-tpl-la`, `--enable-mfmv`, `--enable-tf`, `--enable-kf-tf`, `--enable-overlays`, `--scm`, `--enable-intrabc`, `--film-grain`, `--film-grain-denoise`, `--fgs-table` |
| AV1 Specific 2 | `--superres-mode`, `--superres-denom`, `--superres-kf-denom`, `--superres-qthres`, `--superres-kf-qthres`, `--sframe-dist`, `--sframe-mode`, `--resize-mode`, `--resize-denom`, `--resize-kf-denom`, `--frame-resz-events`, `--frame-resz-denoms`, `--frame-resz-kf-denoms`, `--lossless`, `--avif` |
| Color Description | `--color-primaries`, `--transfer-characteristics`, `--matrix-coefficients`, `--color-range`, `--chroma-sample-position`, `--mastering-display`, `--content-light` |
| Variance Boost Options | `--enable-variance-boost`, `--variance-boost-strength`, `--variance-octile` |
| Custom | `Custom`* |
| Other | `Override Target File Name`*, `Target File Name`*, `Preview`*, `Chunks`*, `Comp. Check`*, `Aimed Quality`* |

`*` lives in `staxrip.md` because the same control appears in every encoder dialog. The two commented-out `--input-depth` declarations are excluded by the comment rule in 6.2.

Authoring sources: the SVT-AV1 `Docs/Parameters.md` and `Docs/CommonQuestions.md` in the SVT-AV1 repository, the tool's `--help` text as cached by `Package.CreateHelpfile`, and the StaxRip code for the StaxRip-owned controls. Numbers in examples are checked against those sources or a short test encode before `Status: reviewed`.

## 10. Verification

| Id | Check | Evidence kept |
| --- | --- | --- |
| V1 | `Check-OptionHelp.ps1 -SelfTest` passes | Command and compact output in the pull request |
| V2 | `Check-OptionHelp.ps1` on the repository: no errors; `svt-av1` at 100 / 100 after step 4 | Report table |
| V3 | Debug x64 build of `Source/StaxRip.sln` with a direct `msbuild` invocation succeeds with no new warnings in touched files. `Source/Build.ps1` is a packaging script that copies to a release share and is not run | Build summary; configuration and platform recorded per `AGENTS.md` |
| V4 | Manual checklist on the SVT-AV1 dialog: tooltip on label, control, and menu button; `Right-click for details` line; strip updates on hover and on keyboard focus; strip keeps text on leave; value note on a dropdown entry; details window content; encoder-help link opens the console help at the switch; search finds `grain`; x265 dialog unchanged; both themes; 100 and 150 percent DPI | Screenshots with synthetic paths only |
| V5 | Validator parameter count for `svt-av1` reconciled with the dialog title `(101 options)` and the known hidden field | One line in the close-out |
| V6 | Command-line equivalence: for a saved SVT-AV1 template and an x265 template, `Copy Command Line` before and after the change is byte-identical | Two diffs, empty |
| V7 | `git diff --stat` on the branch touches only the files named in this document | Diff stat in the pull request |

Untested boundary, stated: the description strip on displays above 200 percent DPI, and tooltip behavior under Narrator.

## 11. Risks, unknowns, rollback, privacy

| Id | Item | Confidence | Handling |
| --- | --- | --- | --- |
| U-OH-1 | Manifest resource name for a linked file whose name contains a hyphen | inferred | Loader enumerates names instead of computing them; verified in step 2 |
| U-OH-2 | `ToolTip.AutoPopDelay` of 10 seconds in `TipProvider` may be short for a two-sentence tip | verified value, unknown feel | Judge in V4; raise for the `allowLong` path if needed |
| U-OH-3 | Strip height across DPI scales | inferred | `FontHeight`-based height; V4 at 100 and 150 percent |
| U-OH-4 | Text-level extraction misses parameters built outside the four patterns | verified for SVT-AV1 (none), unknown for other encoders | Recorded in the script README; V5 reconciles per encoder as each is added |
| RK-1 | Reviewed text contains a wrong number | inferred | Rule 4 in 4.5; `Source` links; the maintainer's tone review |
| RK-2 | Authors drift from the grammar | inferred | E1 to E3 fail the check with file and line |

Rollback: revert the dialog and vbproj commits and delete `Docs/OptionHelp/`. No project, template, settings, or job format changes; no persisted state is added.

Privacy and logging: the content is static text; no network access except a user's deliberate click on a `Source` link, which uses the existing `http` handling in `HelpForm`; the only log output is a parse error with a file name and line number.

## 12. Decisions staged for the Decision Log

`Docs/Planning/DECISION-LOG.md` on `master` ends at D-036 while `fork/linux-foundation` has reached D-059. The entries below are numbered after the higher line to avoid a collision and are appended to the log when this branch merges into a line whose log is current; renumber then if the log has moved.

### D-060: Option help is external, layered Markdown keyed by switch

Date: 2026-08-26. Status: Confirmed by the maintainer. Area: sections 4 and 5.

Context: 2,261 encoder options have no hover help; 24 have inline `.Help` strings, most of them discarded by the dialog. The Linux line needs the same text.

Decision: Help text lives in `Docs/OptionHelp/*.md` in the strict grammar of 4.2, one file per encoder with inheritance for variants and two shared files, embedded on Windows and read from the repository on Linux.

Because: Prose-first editing on GitHub with a rendered preview, no new dependency, a 60-line parser per side, and a layering that covers 2,261 controls with about 700 stanzas.

Options considered: inline `.Help` in VB (VB-only, rebuild per wording fix, no coverage check); generated from upstream documentation (expert prose, GPL text in an MIT project); YAML or JSON (escaping and indentation traps for non-programmer authors).

Consequences: The grammar becomes a cross-platform contract with a validator as its authority. Revisit when: a second consumer needs fields the grammar cannot express.

### D-061: Only reviewed text displays; coverage is a ratchet with floors in each file

Date: 2026-08-26. Status: Confirmed by the maintainer. Area: section 6.

Decision: `Status: reviewed` is the only displayed state. Each encoder file carries `Coverage` and `Reviewed` floors; the validator fails when either computed value falls below its floor, and only `-RaiseFloors` moves a floor.

Because: Adding a parameter must force at least a draft stanza without forcing a backfill of every encoder on day one; unvetted text must never reach users.

Options considered: hard fail on any missing stanza from day one (blocks every parameter addition until prose exists); warning only (never enforced).

Consequences: A file reaches hard-fail mode by reaching 100 percent, with no separate flag. Revisit when: a bulk parameter sync makes the draft requirement a burden.

### D-062: Three presentation surfaces, and the encoder's own help stays one click away

Date: 2026-08-26. Status: Confirmed by the maintainer. Area: section 5.3.

Decision: Hover tooltip, description strip above the command line updated by hover and keyboard focus, and a right-click details window with a link to the existing console help.

Because: Tooltips are what was asked for; the strip makes the text discoverable and keyboard-reachable; power users lose nothing.

Options considered: tooltips only (invisible to keyboard users); replacing console help (removes information power users rely on).

Consequences: About 90 pixels of dialog height at 100 percent DPI. Revisit when: V4 shows the strip crowding small screens.

### D-063: Independent parsers, one validator, strongest model for prose

Date: 2026-08-26. Status: Confirmed by the maintainer. Area: sections 4.5, 6, and 7.

Decision: The Windows and Linux parsers are written separately against the grammar; `Check-OptionHelp.ps1` is the grammar authority and runs on both; stanza prose is written by the strongest available model or by a person.

Because: Sharing a parser assembly would couple the net48 and net8 builds for 60 lines of code; the wording is the product, so it gets the best writer.

Consequences: A grammar change is a validator change first, then both parsers. Revisit when: the grammar grows past what a fixture suite can pin.
