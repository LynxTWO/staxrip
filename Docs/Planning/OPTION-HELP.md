# StaxRip Design: Plain-English Option Help

Version: 0.2 Draft. Date: 2026-08-26. Status: Proposed. Revised after an external design review on 2026-08-26; awaiting maintainer approval before an implementation plan is written.
Branch: `worktree-option-help` off `origin/master` `eb8c33c9`.
Companion documents: `../../AGENTS.md`, `ENGINEERING.md`, `DECISION-LOG.md`.

This document is the build boundary for the first slice of option help. If work is not named here, it does not enter the slice.

Changes since 0.1, all from the review: exact counters replace percentage floors (6.4); a draft shadows inherited text (4.4); stable namespaced option IDs with switches as aliases (4.4, 5.2); `concepts.md` is glossary-only and shared prose is explicit (4.1); `Schema`, `Locale`, Unicode, and `eol=lf` (4.2); verification pinned to the bundled encoder build and facts generated from the live parameter (4.3, 5.3); file-level failures fail closed (5.6); an explicit HTML trust boundary, typed link routes, and per-window temp-file cleanup (5.4); several help targets per option, F1, accessible names, full-field search, defined strip truncation (5.3); `GetEmittedValue` as the one production value routine (5.2); validator rules E11 to E13, `-AdvanceRatchet`, security fixtures, and a runtime reconciliation export (6); a resolved, packaged Linux payload (7); and the writing guide rewritten around evidence instead of forced numbers (4.5).

## 1. What this proves

- **Central claim:** A newcomer can point to an encoder option and learn, in one or two plain sentences, what it changes in the encode or workflow, what tradeoff it introduces, and when it is worth touching. Basic guidance stays in the dialog, while the encoder's own documentation remains one action away.
- **The slice in one line:** Every option in the SVT-AV1 dialog shows a plain-English summary on hover, in a description strip above the command line, and in a details window on F1 or right-click; the text lives in Markdown files that a non-programmer can edit on GitHub; a script proves that every option has text, that the count of options without text never grows, and that reviewed text never shrinks.
- **Honest stakes:** If the maintainer reads the SVT-AV1 text on the real dialog and it does not read as clearly better than the encoder's `--help` output, the fork should fix the writing rules before authoring the remaining ~600 stanzas for the other encoders.

## 2. The walkthrough

1. The user opens the SVT-AV1 options dialog from the encoder section of the main window.
2. Pointing at the `Preset` label, its dropdown button, or any other control shows a tooltip: the option's summary, then the line `Press F1 or right-click for details`.
3. At the same time the description strip above the command-line preview shows the option's caption, the summary, and a `When to change` line, cut with an ellipsis when it does not fit three lines. Moving keyboard focus to a control updates the strip the same way, so the feature works without a mouse.
4. Opening the `Preset` dropdown and pointing at `6: Medium` shows a short note for that value. Not every value has a note; the notes mark the landmarks.
5. Pressing F1 on the focused option, or right-clicking its label, opens a details window. The top lines are generated from the live parameter: current value, StaxRip default, valid range, and the switch names. Below them come the authored text: what it does, when it is used, when to change it, an example, a table of every value with notes where they exist, related options that open their own details, references, and a link that opens the encoder's own `--help` text for that switch, which is what right-click does today. With no option focused, F1 opens the dialog help exactly as it does today.
6. Typing `grain` or `dark` into the search box at the bottom left finds options whose help text mentions those words anywhere, not only options whose switch contains them.
7. Options without reviewed text behave exactly as they do today, including the encoder's console help on right-click.
8. The generated command line is unchanged. The evidence is two representative equivalence tests plus the fact that command generation is not edited, not a proof over every possible command.

## 3. Current behavior, verified

| Fact | Evidence |
| --- | --- |
| Every option already has `Help`, `HelpSwitch`, and `URLs` properties | `Source/Video/VideoEncoderCommandLine.vb:195-215` |
| `CommandLineParams.Add` fills `HelpSwitch` with the first entry of `GetSwitches`, which enumerates a `HashSet`; the order is an implementation detail, not a contract | `Source/Video/VideoEncoderCommandLine.vb:39-45`, `224-241` |
| For any option with a `HelpSwitch`, the dialog attaches only a right-click action that opens the encoder's console `--help` text; the assembled help string, including `.Help`, is discarded. No hover tooltip exists for these options | `Source/Forms/CommandLineForm.vb:212-218`, `231-236`, `253-259`, `297-302`; `ShowConsoleHelp` at `Source/Video/VideoEncoderCommandLine.vb:74-110` |
| `helpControl` is declared before the parameter loop and never reset; a `LineParam` therefore receives an `Item` that points at the previous parameter's control | `Source/Forms/CommandLineForm.vb:134`, `205-207`, `310-317` |
| F1 already opens the dialog help | `Source/Forms/CommandLineForm.vb:337-341` |
| 24 of 2,261 parameters set `.Help`; four x265 strings on switch-bearing options are never shown because of the rule above | `Source/Encoding/x265Enc.vb:1368`, `1569`, `1570`, `1585` |
| Tooltip text longer than 80 characters is replaced by `Right-click for help`; the same rule applies to menu items; the tooltip display period is 10 seconds | `Source/UI/TipProvider.vb:24-27`, `87-88`, `Source/UI/Menu.vb:623-627` |
| Per-dropdown-value tooltips are already supported by `MenuButton.Add(path, obj, tip)`; the dialog passes no tip | `Source/UI/Controls/Controls.vb:1844`, `Source/Forms/CommandLineForm.vb:275` |
| `OptionParam.GetArgs` is the only place that knows which string a dropdown index emits | `Source/Video/VideoEncoderCommandLine.vb:653-676` |
| `HelpDocument` writes authored text with `WriteRaw`; text containing `[` or `'''` is converted to HTML links and bold; `ConvertChars` escapes only `<` and `>` | `Source/General/General.vb:537-550`, `553-570`, `572-610` |
| The help stylesheet imports Google Fonts; the imported face `Lato` is used nowhere else in the stylesheet | `Source/General/General.vb:457` |
| The help document has no `<meta charset>`; the writer is UTF-8 | `Source/General/General.vb:495-503` |
| `HelpForm` creates a temp `.htm` per window and deletes it only when the main form is disposed; links that do not start with `http` navigate inside the embedded browser | `Source/Forms/HelpForm.vb:55-60`, `108-113` |
| The encoder's `Params` object is `<NonSerialized>`; only `ParamsStore` persists, so a new property on `CommandLineParam` cannot change project or template files | `Source/Encoding/SvtAv1Enc.vb:25-38` |
| StaxRip's own default preset is 9 (`.Init = 9`), the option label marks 8 as `(default)`, and upstream documents 8 as the encoder default | `Source/Encoding/SvtAv1Enc.vb:528-544`; SVT-AV1 `Docs/Parameters.md` on `master`, fetched 2026-08-26 |
| StaxRip's tune label `4: MS-SSIM/SSIMULACRA2` differs from upstream `master`, which lists tune 4 as MS-SSIM; the bundled binary is Patman's PMod fork, not mainline, so upstream `master` is not the reference for the shipped build | `Source/Encoding/SvtAv1Enc.vb:650`, `Source/General/Package.vb:621-631` |
| Upstream documents `--lp` as a level from 0 to 6 that controls both thread creation and picture-buffer allocation, not a thread count | SVT-AV1 `Docs/Parameters.md` on `master`, fetched 2026-08-26 |
| The search box already searches `Param.Help` | `Source/Forms/CommandLineForm.vb:413` |
| Text files ship as embedded resources through `<EmbeddedResource Include="..\CHANGELOG.md"><Link>CHANGELOG.md</Link>` and are read with `GetManifestResourceStream` | `Source/StaxRip.vbproj`, `Source/Forms/MainForm.vb:6206-6208` |
| No Markdown, YAML, or JSON library is referenced; `.gitattributes` holds only `* text=auto`; there are no CI workflows | `Source/packages.config`, `.gitattributes`, `.github/` |
| `Build.ps1` already exempts `.md` files from its ASCII check | `Source/Build.ps1:36-49` |
| 2,261 parameters collapse to 674 distinct switches; the five SVT-AV1 variants share 108 switches; x264 and x265 share 60; NVEnc, QSVEnc, and VCEEnc share 51 | `grep -oh '\.Switch = "[^"]*"' Source/Encoding/*.vb \| sort -u`, counted 2026-08-26 |
| SVT-AV1 mainline declares 101 live parameters (two are commented out); 13 have no switch; three controls share `--content-light`, two share `--keyint`, two share `--pass` | `Source/Encoding/SvtAv1Enc.vb:437-1360`, dialog title `(101 options)` |
| The Linux line's web shell is 266 lines of plain JavaScript with no options UI yet; its existing payloads use strict key and size contracts | `fork/linux-foundation:CrossPlatform/src/StaxRip.Server/Web/app.js` |
| StaxRip is MIT licensed; x264 and x265 documentation is GPL | `License.txt` |

## 4. Content model

### 4.1 Files and layering

All content lives under `Docs/OptionHelp/`. One file per encoder, plus shared files.

| File | Holds | Lookup role |
| --- | --- | --- |
| `<encoder>.md`, for example `svt-av1.md` | Every option of that encoder, with the facts that are true for its bundled build | first |
| `<variant>.md` with `Inherits: <base>`, for example `svt-av1-psyex.md` | Only the variant's additions, and overrides for base stanzas that are wrong for the variant | before its base |
| `staxrip.md` | The nine controls StaxRip adds to every encoder dialog: Decoder, Pipe, Custom, Override Target File Name, Target File Name, Preview, Chunks, Comp. Check, Aimed Quality | after the encoder chain, then lookup stops |
| `concepts.md` | Glossary entries such as `concept.psnr`, reached only through `Related` | never a fallback |
| `shared.md` | Reusable option prose, reached only through an explicit `Use:` line in an encoder stanza | never a fallback; not created in this slice |

Lookup walks encoder, `Inherits` chain, `staxrip`, and stops. Nothing is substituted silently: a generic explanation of CRF is a glossary entry, not the help for every `--crf`. Facts with numbers belong in the encoder file. A new encoder needs a VB class with an `OptionHelpId` override, explicit `OptionHelpKey` values on its switch-less and shared-switch controls, one `.md` file with a header, and one resource entry in the project file; the validator checks all four. A new variant needs the same, with `Inherits`.

Translations, not built in this slice, are sibling files `<encoder>.<locale>.md` with the same `Encoder` and a different `Locale`; English falls back when a locale file lacks a stanza. The grammar below already accommodates them.

Files are embedded into `StaxRip.exe` as resources and packaged into the Linux server's publish output. The file grammar is the contract between the two; see section 7.

### 4.2 File grammar

The grammar is a strict subset of Markdown so that GitHub renders it and a small dependency-free parser reads it. Anything outside the subset is a validator error, not a rendering surprise.

- Encoding: UTF-8 without BOM. Unicode text is allowed. LF line endings, enforced by a new `.gitattributes` line `Docs/OptionHelp/** text eol=lf`. Parsers accept CRLF input anyway.
- File name: `<Encoder>.md` for English or `<Encoder>.<Locale>.md` for a translation; the header must agree with the name.
- An optional first line `# <title>` is ignored by parsers.
- Single-line HTML comments `<!-- ... -->` are ignored anywhere.
- Blank lines are ignored.
- **Header:** every `Key: value` line before the first `## ` line. Keys are listed in 4.3. A duplicate header key is a file-level error.
- **Stanza:** starts at a line `## <id>` and ends at the next `## ` line or end of file. `<id>` is a stable option ID from 4.4.
- **Field line:** `<Field>: <text>`. Text continues on following lines that are not blank, not a field line, not a bullet, and not a heading; continuation lines join with a single space. A duplicate field in one stanza is a stanza-level error.
- **Values list:** the field line `Values:` has no text and is followed by bullet lines `- <value>: <note>`. `<value>` is the literal command-line value; the first `: ` separates it from the note. The list is selective: it names the values worth explaining, not every value.
- **References list:** the field line `References:` has no text and is followed by bullet lines `- <url>`; only `http` and `https` URLs are accepted.
- **Inline markup**, the only two forms allowed: backticks for a literal switch or value, and `[text](url)` for an `http` or `https` link. Unmatched backticks, malformed links, and any other scheme are errors. Tooltips and the description strip show plain text (backticks removed, link text kept); the details window renders code spans and links from parsed nodes, never from raw text.

English authoring guidance, not grammar: straight quotes, hyphens rather than dashes, and plain ASCII where a choice exists.

### 4.3 Header keys and stanza fields

Header keys:

| Key | Required | Rule |
| --- | --- | --- |
| `Schema` | yes | `1`. A parser that does not know the number treats the file as invalid |
| `Encoder` | yes | `[a-z0-9-]+`; the file's namespace and the first part of the file name |
| `Locale` | yes | A BCP 47 language tag such as `en`; `en` for `<Encoder>.md`, otherwise the second part of the file name |
| `Title` | yes | Display name, for example `SVT-AV1` |
| `Source` | encoder files | Repository-relative path, exact case, inside the repository, of the VB file that declares the parameters |
| `Inherits` | no | Another `Encoder` id; chains must be acyclic; `staxrip` is implicit and never named |
| `Allowed-Missing` | encoder files | Integer; the count of parameters without any stanza may not exceed it, see 6.4 |
| `Minimum-Reviewed` | encoder files | Integer; the count of parameters resolved to reviewed text may not fall below it |
| `Reviewed-Complete` | encoder files | `true` or `false`; when true every parameter must resolve to reviewed text |
| `Verified-Encoder-Version` | once any stanza is `reviewed` | The version string printed by the bundled executable, for example the first line of `SvtAv1EncApp.exe --version` |
| `Verified-Encoder-Build` | once any stanza is `reviewed` | The release tag or commit of that build, from its download page |
| `Verified-Date` | once any stanza is `reviewed` | ISO date of the technical verification |
| `Documentation` | once any stanza is `reviewed` | One pinned URL, tag or commit rather than `master`, used as the review evidence |

Stanza fields, in this order:

| Field | Required | Limit | Purpose |
| --- | --- | --- | --- |
| `Label` | no | 60 chars | The control's caption, for readers of the raw file; validator warns when it differs from the VB `.Text` |
| `Use` | no | one stable ID | Alias stanza: the body is taken from the named stanza, which must be reviewed. A stanza with `Use` carries only `Label`, `Use`, and `Status` |
| `Summary` | yes unless `Use` | 1 to 200 chars, one or two sentences, ends with `.` | Tooltip, strip, and details |
| `Used when` | no | 200 chars | The mode or setting under which the option has any effect, for example "Rate Control Mode is Variable Bitrate or Constant Bitrate" |
| `When to change` | for `reviewed` unless `Use` | 400 chars | Strip second line and details |
| `Encoder default` | no | 40 chars | The bundled encoder's own default when it differs from what StaxRip sets; shown beside the generated StaxRip default |
| `Example` | no | 300 chars | Details |
| `Values` | no; option parameters only | 120 chars per note | Per-value dropdown tooltip and the notes column of the details table |
| `Related` | no | stable IDs, comma separated | Details links; each ID must exist; non-reviewed targets are omitted at display time |
| `References` | no | `http`/`https` URLs | Details links |
| `Status` | yes | `draft` or `reviewed` | Only `reviewed` stanzas display. A `draft` also shadows inherited text, see 4.4 |

### 4.4 Identity and lookup

Every parameter has one stable ID. Switches and captions are aliases for search and display, never identity.

- **Explicit:** `CommandLineParam.OptionHelpKey`, set in the VB declaration, for example `.OptionHelpKey = "svt-av1.content-light.max-cll"` or `.OptionHelpKey = "staxrip.chunks"`. Required for switch-less controls and for controls that share a switch but need different text. The literal `none` excludes a parameter from help and from coverage; the validator lists exclusions in its report so reviewers see them.
- **Derived:** for every other parameter, the local part is the primary switch without its leading dashes, in the encoder's own namespace: `svt-av1.preset`. Two controls that share a switch share one stanza.
- **Primary switch:** one documented routine, `CommandLineParam.PrimaryHelpSwitch()`, returns the explicit `.HelpSwitch`, else `.Switch`, else `.NoSwitch`, else the first `.Switches` entry, else nothing. The application and the validator both use this order; `GetSwitches` and its hash set are not involved.
- **Namespaces and inheritance:** an identity in the encoder's own namespace is resolved namespace-relative: each file in the chain is probed for `<that file's encoder>.<local part>`, the encoder's own file first, then each ancestor, then `staxrip`. An identity in any other namespace (`staxrip`, `shared`, `concept`, or another encoder's) is probed verbatim in each chain file. A variant overrides a base stanza by defining the same local part in its own namespace; it never repeats the base id.
- **Lookup:** the first stanza found wins. If it is `reviewed`, it displays. If it is `draft`, lookup stops and nothing displays; a draft is also a shadow that blocks inherited text a variant author has decided is wrong for the variant. If nothing matches, the control behaves as today.
- **Aliases for search:** every switch from `GetSwitches`, sorted ordinally, plus the caption.

SVT-AV1 explicit keys in this slice: `svt-av1.content-light.max-cll`, `svt-av1.content-light.max-fall`, `none` for the hidden combined `--content-light` field, and the `staxrip.*` keys on the thirteen switch-less controls (four `Custom` boxes share `staxrip.custom`; two `Pipe` dropdowns share `staxrip.pipe`).

### 4.5 Writing rules

These rules are the whole style guide; `Docs/OptionHelp/README.md` repeats them next to a copyable template and describes the drafting workflow.

1. The first sentence names the observable effect on picture quality, file size, encoding speed, decoding compatibility, resource use, or workflow.
2. `When to change` names the situation, the tradeoff, and a practical first action.
3. Current value, StaxRip default, and valid range come from the application; put them in prose only when they are stable and version-verified.
4. Use a number when it helps the decision. Never add a number to satisfy the template.
5. State exact ranges plainly. Label performance, time, size, and quality outcomes as measured examples and include enough test context to reproduce them.
6. Define an unfamiliar term inline or link it to a reviewed glossary entry through `Related`.
7. Say "leave it at the default" when that is the honest advice. Avoid "best", "sweet spot", and universal claims unless the evidence supports them.
8. Explain interactions and inactive modes. Use `Used when` to tell the user when an option is ignored.
9. Use original wording and link the evidence. x264 and x265 documentation is GPL and StaxRip is MIT.
10. A stanza becomes `reviewed` only after a human readability review in the real interface and technical verification against the bundled encoder version named in the file header.

Who or what drafts the prose is a workflow choice, not a property of the file. The maintainer's standing instruction, recorded in `AGENTS.md` and the README rather than here: draft the prose with whichever model or person writes the warmest, clearest friend-to-friend English, at the drafter's judgment; rule 10 is the gate.

### 4.6 Example stanzas

Illustrative. Every fact below is re-verified against the bundled build before the stanza is marked `reviewed`. The verification headers from 4.3 are omitted here for brevity; a real file with a reviewed stanza must carry them.

```markdown
# SVT-AV1 option help

Schema: 1
Encoder: svt-av1
Locale: en
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Allowed-Missing: 100
Minimum-Reviewed: 0
Reviewed-Complete: false

## svt-av1.preset
Label: Preset
Summary: Controls the tradeoff between encoding speed and compression. Lower numbers usually make a smaller file at similar quality, but the encode can take much longer.
When to change: StaxRip starts you at 9. Try 6 for a final encode when a smaller file is worth the extra time; use 10 or higher for quick tests.
Encoder default: 8
Example: Encode the same 60-second sample at presets 9, 6, and 4. Compare the time and file size before committing the whole video.
Values:
- 0: Extremely slow. Mainly useful for experiments.
- 4: High compression efficiency with a large encoding-time cost.
- 6: Slower than StaxRip's default, with better compression efficiency.
- 8: The encoder's own default.
- 9: StaxRip's default and a practical starting point.
- 13: Fastest, with the largest compression tradeoff.
Related: svt-av1.crf, concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v3.0.2/Docs/Parameters.md
Status: reviewed

## svt-av1.tune
Label: Tune
Summary: Changes what the encoder rewards when it decides where to spend bits. VQ is tuned for perceived visual quality, while the other modes target named quality scores.
When to change: For video you plan to watch, try 0: VQ. Keep 1: PSNR when PSNR is the score you are testing; choose another mode only when that specific metric is part of the comparison.
Example: Encode the same short scene with VQ and PSNR at the same quality setting. Compare the picture and file size, not only the reported score.
Values:
- 0: VQ. Tuned toward perceived visual quality.
- 1: PSNR. The encoder default; targets a pixel-error score.
- 2: SSIM. Targets a structural-similarity score.
- 3: Still-image quality. Not for ordinary video.
- 4: The StaxRip label and upstream documentation disagree. Verify against the bundled build before review.
- 5: VMAF. Video only; use when VMAF is the metric being tested.
Related: concept.vq, concept.psnr, concept.ssim, concept.vmaf
Status: draft

## svt-av1.lp
Label: Level Of Parallelism
Summary: Controls how much parallel work SVT-AV1 creates, including threads and picture buffers. 0 lets the encoder choose for your CPU.
Used when: Always; the effect is larger on machines with many cores.
When to change: Leave it at 0 for a single encode. Set a low explicit level when you need to reduce CPU or memory use, or when several encodes are running at once.
Related: svt-av1.pin, svt-av1.ss, concept.parallelism
Status: reviewed

## svt-av1.color-primaries
Label: Color Primaries
Use: shared.color-primaries
Status: reviewed
```

The last stanza shows the alias form; `shared.md` is not created in this slice, so `svt-av1.md` will carry its own color stanzas until a second encoder needs them.

## 5. Windows implementation

### 5.1 Loader: `Source/General/OptionHelp.vb`

New file, namespace `StaxRip`, no new dependency.

| Type | Responsibility |
| --- | --- |
| `OptionHelpStanza` | `Id`, `Label`, `Use`, `Summary`, `UsedWhen`, `WhenToChange`, `EncoderDefault`, `Example`, `Values` (ordered value/note pairs), `Related`, `References`, `Status`, `File`, plus the parsed inline nodes of each text field |
| `OptionHelpFile` | Header values, `Stanzas` (ordinal dictionary by ID), `FileErrors`, `StanzaErrors` |
| `OptionHelpParser` | `Shared Function Parse(text, name) As OptionHelpFile`; pure; implements exactly the grammar in 4.2; records errors with line numbers instead of throwing; separates file-level from stanza-level errors per 5.6 |
| `OptionHelpCatalog` | `Shared Function Get(encoderId) As OptionHelpCatalog`, cached per id, `Nothing` when no resource exists or any file in the chain is invalid; `Function Resolve(param) As OptionHelpStanza` implementing 4.4 including draft shadowing and `Use` aliases; `Function ValueNote(stanza, emittedValue) As String`; `Function PlainText(nodes) As String` for tooltips and the strip |
| `OptionHelpRoute` | The parsed form of an internal `staxrip:` link: `Kind` (`ConsoleHelp` or `Option`) and `Id`; `Shared Function TryParse(uri, route) As Boolean` accepting only the two routes in 5.4 |

Resources are discovered by enumerating `GetManifestResourceNames()` for names that contain `.OptionHelp.` and end with `.md`; the id and locale are the segments between them. Files load lazily on first dialog open, under a lock, once per process. Errors go to the existing debug log path and never to a dialog.

### 5.2 Parameter model changes: `Source/Video/VideoEncoderCommandLine.vb`

| Change | Detail |
| --- | --- |
| `CommandLineParams.OptionHelpId` | `Overridable ReadOnly Property`, returns `Nothing`; `SvtAv1EncParams` (`Source/Encoding/SvtAv1Enc.vb:437`) returns `"svt-av1"` |
| `CommandLineParam.OptionHelpKey` | `Property As String`; explicit stable ID, or `none` |
| `CommandLineParam.PrimaryHelpSwitch()` | The documented order from 4.4; the only routine that decides a primary switch |
| `CommandLineParam.OptionHelpIdentity(encoderId)` | Explicit key, else derived from `PrimaryHelpSwitch`, else `Nothing` |
| `OptionParam.GetEmittedValue(index)` | Returns the value string `GetArgs` emits for that index: `Values(index)` when `Values` exists, else the index for `IntegerValue`, else the lower-cased option text without spaces. `GetArgs` is changed to call it, so there is one implementation. This touches command construction; it is a pure extraction, covered by V6 and named in the approval packet |
| `CommandLineParams.ExportOptionHelpFacts()` | Returns the per-parameter facts (identity, switches, caption, emitted values, excluded flag) as JSON for the validator's reconciliation, see 6.7 |

None of these change persisted data: `Params` is not serialized (section 3).

### 5.3 `CommandLineForm` changes

All changes are in `Source/Forms/CommandLineForm.vb` and its designer file.

| Change | Where | Behavior |
| --- | --- | --- |
| Help targets | `Item` class, `InitUI` | `Item` gains `Targets As List(Of Control)` holding the label, the editor or checkbox, and the menu button where present, and `Stanza`. `helpControl` becomes a per-iteration local so no control can carry over to the next parameter |
| Resolve stanzas | `InitUI`, before the loop | `catalog = OptionHelpCatalog.Get(Params.OptionHelpId)`; per parameter `stanza = catalog?.Resolve(param)` |
| Hover tooltip | the four branches at lines 212, 231, 253, 297 | When a stanza exists: a form-owned `OptionHelpTips As ToolTip` instance, separate from `TipProvider`, with its own display period, sets `Summary` plus `Press F1 or right-click for details` on every target. Setting is idempotent and registers no mouse handlers. `TipProvider` is untouched, so no other StaxRip tooltip changes |
| Right-click details | same branches | When a stanza exists: `HelpAction = Sub() ShowOptionHelp(item)`. Without a stanza: unchanged |
| F1 | `CommandLineForm_HelpRequested`, line 337 | If `ActiveControl` belongs to an `Item` with a stanza, open that item's details; otherwise the existing dialog help. The dialog help stays in the menu as today |
| Accessibility | `InitUI` | Editors and menu buttons get `AccessibleName` = caption and `AccessibleDescription` = `Summary` |
| Dropdown value notes | option branch, line 275 | `Dim menuItem = menuBlock.Button.Add(text, x2)`; when the stanza has a note for `oParam.GetEmittedValue(x2)`, `menuItem.ToolTipText = note`, set directly so the 80-character rule in `Menu.vb` does not apply, and only when `MenuItemEx.UseTooltips` is on, honoring the user's menu-tooltip setting |
| Description strip | designer plus `InitUI` | `lblDescription As LabelEx` in `tlpMain` at a new row 1 spanning all four columns; `tlpRTB` moves to row 2 and the button row to row 3; `AutoSize = False`, height `FontHeight * 3` plus padding, `AutoEllipsis = True`, `UseMnemonic = False`, anchored left and right. `MouseEnter` and `Enter` on every target call `SetDescription(item)`, which shows `<caption>: <Summary>` and, on the next line, `When to change: <text>`; text that does not fit is cut with an ellipsis and remains available in the details window. The strip keeps the last text on `MouseLeave`. Initial text: `Point at an option, or move focus to it, to see what it does. Press F1 for details.` The strip is hidden when no option in the dialog has a reviewed stanza, so dialogs of encoders without help are unchanged |
| Details window | new `ShowOptionHelp(item)` | Generated first, from the parameter: `Current value` (option text for dropdowns, number for numeric fields, On or Off for checkboxes; omitted for text fields so paths never reach the temp file), `StaxRip default`, `Encoder default` from the stanza when present, `Valid range` from `NumParam.Config`, and `Switches` sorted ordinally. Then the authored sections: what it does, `Used when`, when to change it, example, a table of every dropdown value with the note where one exists, related options as `staxrip://option/<id>` links (non-reviewed targets omitted), references, and the final link `Show the encoder's own help for <switch>` as `staxrip://console-help`. Rendered through the trust boundary in 5.4 |
| Search | `cbGoTo_TextChanged`, line 413 | Also matches the stable ID, every alias, label, summary, `Used when`, `When to change`, example, value notes, and the labels of related entries, case-insensitive |

### 5.4 `HelpForm` and rendering: trust boundary

- Authored text never reaches `WriteRaw`. The details window renders the parsed nodes from 5.1: text nodes are HTML-encoded, code spans become `<code>`, links become `<a>` only for `http` and `https` with an encoded `href`. `HelpDocument` gains `WriteNodes(...)` for this; the existing methods keep their behavior for existing callers.
- `HelpForm.Browser_Navigating` gains typed routes. `staxrip://console-help` and `staxrip://option/<id>` with `<id>` matching `^[a-z0-9-]+(\.[a-z0-9-]+)+$` invoke `Property RouteAction As Action(Of OptionHelpRoute)`; any other `staxrip:` URL does nothing and logs a bounded diagnostic; `http` and `https` keep today's shell handling; every other scheme is cancelled.
- `HelpForm` deletes its temp document when the window is disposed, whether by closing it or by application shutdown. This applies to every help window.
- `HelpDocument.WriteStart` drops the unused Google Fonts `@import` and adds `<meta charset="utf-8">`. This applies to every help window; the visible result is identical because the imported face was never used. These two `HelpDocument` and `HelpForm` hygiene changes land in their own commit so they can be reverted independently.
- Consequence for the privacy statement: after this change, opening a help window makes no network request.

### 5.5 Build metadata and repository files

- `Source/StaxRip.vbproj` gains `<Compile Include="General\OptionHelp.vb" />` and, for each content file, `<EmbeddedResource Include="..\Docs\OptionHelp\<file>.md"><Link>OptionHelp\<file>.md</Link><LogicalName>StaxRip.OptionHelp.<file>.md</LogicalName></EmbeddedResource>`, mirroring the existing `CHANGELOG.md` item. VB names an embedded resource `<RootNamespace>.<file name>` and ignores the link folder, so the `LogicalName` is what gives the loader its `.OptionHelp.` marker; the validator's E12 requires it. This is the "normal explicit entries" touch that `SLICE-001.md` section 6 already allows; no configuration, solution mapping, or packaging script changes.
- `.gitattributes` gains `Docs/OptionHelp/** text eol=lf`.
- `AGENTS.md` gains a short "Option help" paragraph pointing to `Docs/OptionHelp/README.md` and stating the drafting workflow from 4.5.
- Because `AGENTS.md` lists build files as approval-gated, the maintainer's approval of this document is the approval for exactly these entries.

### 5.6 Failure handling

File-level errors invalidate the whole file, and an invalid file anywhere in an encoder's chain makes the catalog return `Nothing` for that encoder, so the dialog behaves as today:

| File-level | Stanza-level |
| --- | --- |
| Unknown or missing `Schema`; missing or invalid `Encoder` or `Locale`; header disagreeing with the file name; duplicate header key; invalid encoding; `Inherits` unknown or cyclic; duplicate stanza ID; two resources resolving to the same encoder and locale | Missing or overlong `Summary`; missing `When to change` on a reviewed stanza; bad field order; duplicate field; unknown field; unresolved `Related` or `Use`; value note for a value the option does not have; invalid URL; malformed inline markup |

Stanza-level errors fail the validator, so they never reach a validated build; production fails closed only on file-level errors (identity and inheritance), and a reviewed stanza that somehow carries a stanza-level error still displays, its markup rendered inert by the node writers.

## 6. Validator and ratchet: `Source/Tools/OptionHelp/Check-OptionHelp.ps1`

A deterministic PowerShell 7 script. It reads text; it does not build or run StaxRip, so it runs the same on Windows and Linux and fits the `AGENTS.md` rule to use parsers and diffs for facts they can settle exactly.

### 6.1 Interface

| Parameter | Effect |
| --- | --- |
| `-RepoRoot <path>` | Defaults to the script's repository |
| `-Encoder <id>` | Check one file |
| `-Json` | The report as JSON on stdout and nothing else on stdout; diagnostics go to stderr |
| `-AdvanceRatchet` | After a clean run only: lowers `Allowed-Missing` to the current missing count and raises `Minimum-Reviewed` to the current reviewed count, never the other direction, never `Reviewed-Complete`; rewrites files atomically, and a failed rewrite leaves every file byte-identical |
| `-SelfTest` | Runs the fixture suite in 6.5 and exits non-zero on any mismatch |
| `-CompareFacts <json>` | Reconciles the extractor against an application export, see 6.7 |

Exit code 0 when no error rule fires; 1 otherwise. The report is one `ENCODER <id> total= excluded= reviewed= draft= missing= allowed-missing= minimum-reviewed= reviewed-complete= result=` row per encoder file, ordinal by encoder id, each followed by `MISSING <id> <caption>` once per id; then every error as `<code> <file>:<line> <message>`, sorted ordinally by code, file, line, and message; then every warning as `<code> <file> <message>`, sorted ordinally by code, file, and message; then `RESULT PASS` or `RESULT FAIL`.

### 6.2 Parameter extraction from VB

For each `Source:` file: drop lines whose first non-space character is `'`; find every `New OptionParam`, `New NumParam`, `New BoolParam`, or `New StringParam` followed by `With {`; take the initializer up to the matching `}` counting braces outside double-quoted strings; inside it read `.OptionHelpKey`, `.HelpSwitch`, `.Switch`, `.NoSwitch`, `.Switches`, `.Name`, `.Text`, `.Values`, `.Options`, and `.IntegerValue`. Derive identity per 4.4 and the emitted values per 5.2. The extractor is exact for these four declared patterns and fails loudly for anything else (E11); it does not claim to be exact in general. `LineParam` is ignored by name.

Known blind spots, recorded in the script's README: parameters declared but never added to `Items` count toward totals unless excluded with `none`; anything outside the four patterns is E11, not silently invisible. V5 reconciles the extraction against the application's own export.

### 6.3 Rules

| Id | Level | Rule |
| --- | --- | --- |
| E1 | error | File-level grammar violation from 4.2 and 5.6, including unknown `Schema`, invalid encoding, header and file-name disagreement, duplicate header key, two help files for the same encoder and locale, `Inherits` cycle or unknown target, and verification headers missing once a stanza is reviewed |
| E2 | error | `Summary` missing, empty, over 200 characters, or not ending with `.`; `When to change` missing on a `reviewed` stanza; any field over its limit |
| E3 | error | Unknown field, field out of the order in 4.3, or duplicate field in one stanza |
| E4 | error | `Values` on a stanza that no option parameter resolves to, or a value key that none of the parameters resolving to the stanza emits; reported once per stanza and value |
| E5 | error | Orphan stanza: an encoder-file stanza outside the file's own namespace, or whose local part matches no own-namespace identity of that encoder or of any encoder inheriting from it, transitively; `staxrip.md` and `concepts.md` are exempt |
| E6 | error | `Related` or `Use` target that does not exist, or a `Use` target that is not reviewed; applies to shared files too |
| E7 | error | `missing > Allowed-Missing`, or `reviewed < Minimum-Reviewed`, or `Reviewed-Complete: true` with any parameter not resolved to reviewed text |
| E8 | error | Duplicate stanza ID within one file |
| E9 | error | The `Source:` file does not override `OptionHelpId` with this file's `Encoder` id |
| E10 | error | A parameter with no identity: no explicit key and no primary switch |
| E11 | error | A parameter-like construction the extractor does not recognize: `New <anything>Param` outside the four patterns, a pattern without `With {`, or a `Param` type name it does not know; also an `OptionParam` whose literal `Options` and `Values` arrays differ in length, which makes `GetEmittedValue` index past the end of `Values` |
| E12 | error | Resource pairing: a help file without exactly one matching `EmbeddedResource` entry, a resource without a file, a `Source` path outside the repository or whose case differs from Git's |
| E13 | error | A URL that is not `http` or `https`, a malformed inline link, an unmatched backtick, or a C0 control character other than tab in a text field or value note |
| W1 | warning | An encoder VB file under `Source/Encoding/` with no help file; reported as fully missing, never fails |
| W2 | warning | `Label` differs from the VB `.Text` |
| W3 | warning | Parameters excluded with `none`, listed by name |
| W4 | warning | An own-namespace identity that resolves in `staxrip.md` because its local part collides with a StaxRip-owned key; it still counts as reviewed, but the text shown is about StaxRip's setting, not the encoder's switch |

### 6.4 Counters and the ratchet

For each encoder file, over parameters that are not excluded:

- `missing` is the count whose ID resolves to no stanza in the chain;
- `draft` is the count whose first matching stanza is a draft;
- `reviewed` is the count whose first matching stanza is reviewed, counting a `Use` alias only when both alias and target are reviewed.

The file passes when `missing <= Allowed-Missing`, `reviewed >= Minimum-Reviewed`, and, when `Reviewed-Complete` is true, `missing = 0` and `draft = 0`. Adding a parameter raises `missing` past the allowance, so the check fails until the author adds at least a draft; adding the draft restores the previous count and passes. Once a file is `Reviewed-Complete`, a draft is no longer enough. `-AdvanceRatchet` is the only way counters move, in the strict direction only, and the resulting header diff is reviewed like any other change. `Reviewed-Complete` is set by hand.

The skeleton `svt-av1.md` created in step 1 starts at `Allowed-Missing: 100`, `Minimum-Reviewed: 0`, `Reviewed-Complete: false` (101 declared parameters, one excluded); step 4 ends at `Allowed-Missing: 0`, `Minimum-Reviewed: 100`, `Reviewed-Complete: true`.

### 6.5 Self-test fixtures

`Source/Tools/OptionHelp/fixtures/` holds a small fake VB file exercising every extraction pattern (property declarations, inline `New ... With {` inside `Add(...)`, nested braces in `.Config`, quoted braces, commented-out declarations, shared switches, switch-less controls with explicit keys, an excluded control, and an unrecognized construction for E11), one Markdown file per rule E1 to E13, a clean pair, and security fixtures: HTML characters in every field, fake and nested links, unmatched backticks, `javascript:` and `file:` schemes, protocol-relative links, duplicate headers, locale collisions, and a variant draft shadowing a reviewed base stanza. Per-fixture canonical dumps and report expectations under `fixtures/expected/*.txt` record the result for each; `-SelfTest` compares and prints the first difference as a bounded failure packet.

### 6.6 Not in this slice

An upstream drift mode that diffs the tool's cached `--help` text against implemented switches; `ConsolAppTester` already does this inside the application. Continuous integration: the repository has no workflows, and adding privileged automation is approval-gated under `AGENTS.md`; until that decision, `-SelfTest` and the full check run in the branch close-out (V1, V2) and join the verification sweep list, and this document records that a gate nobody runs is decorative.

### 6.7 Runtime reconciliation

`GlobalCommands.ExportOptionHelpFacts(path)` writes `CommandLineParams.ExportOptionHelpFacts()` for every encoder that overrides `OptionHelpId` to a JSON file. `Check-OptionHelp.ps1 -CompareFacts <file>` compares identities, switches, captions, emitted values, and exclusions against its own extraction and reports any difference as E11. This replaces a throwaway probe with a repeatable check: V5 runs it before the close-out. The command is exposed like every other `GlobalCommands` member, as the command-line command `-ExportOptionHelpFacts:filePath` documented in `Docs/Usage/Command-Line-Interface.md` and in the custom menu editor, and takes no other input than the output path.

### 6.8 Parser harness

`Source/Tests/OptionHelp/OptionHelpTests.vbproj`, a .NET Framework 4.8 x64 console project outside `Source/StaxRip.sln` with no package references, source-links `Source/General/OptionHelp.vb` and runs the fixture files from 6.5 through `OptionHelpParser` and `OptionHelpCatalog`, comparing with the per-fixture canonical dumps and report expectations under `fixtures/expected/*.txt`. This follows the `SLICE-001.md` precedent for a standalone deterministic harness and gives the loader the same fixtures as the validator, so the two parsers cannot drift silently.

## 7. Linux and web contract

The grammar in 4.2 to 4.4 is the contract; the payload below is the contract's resolved form. The Linux line implements its own small parser in C# when its options UI is built and packages the `Docs/OptionHelp` files into the server's publish output or embeds them; it never assumes a repository checkout at runtime. `GET /api/v1/option-help/{encoder}` validates `{encoder}` against `^[a-z0-9-]+$` before any lookup, returns 404 for an unknown encoder, fails at startup or returns 422 for malformed packaged content, sets an `ETag` from the content version, keeps option order deterministic, resolves inheritance and `Use` on the server, and sends reviewed text only:

```json
{
  "schemaVersion": 1,
  "contentVersion": "2026-08-26.1",
  "encoder": "svt-av1",
  "encoderVersion": "...",
  "locale": "en",
  "options": [
    {
      "id": "svt-av1.preset",
      "label": "Preset",
      "switches": ["--preset"],
      "summary": "...",
      "usedWhen": "...",
      "whenToChange": "...",
      "encoderDefault": "8",
      "example": "...",
      "values": [{ "value": "6", "note": "..." }],
      "related": [{ "id": "svt-av1.crf", "label": "Constant Rate Factor" }],
      "references": ["https://..."]
    }
  ]
}
```

The browser renders `summary` in a hover popover and the option in a side panel; it does not parse Markdown. The validator runs there under `pwsh` unchanged and is the only grammar authority; the two parsers are never linked at build time. Nothing on the Linux line is built in this slice.

## 8. First slice: scope and build order

In scope, in build order:

| Step | Contents | Success test |
| --- | --- | --- |
| 1. Grammar, validator, repository files | `Check-OptionHelp.ps1`, fixtures, the per-fixture expectations under `fixtures/expected/*.txt`, `Docs/OptionHelp/README.md` (rules, template, drafting workflow), the `AGENTS.md` paragraph, the `.gitattributes` line, and skeleton `svt-av1.md`, `staxrip.md`, and `concepts.md` with headers and no stanzas | `-SelfTest` passes; the repository run reports `svt-av1` at 100 missing within its allowance, W1 for every other encoder, and no errors |
| 2. Parameter model and loader | 5.2 in `VideoEncoderCommandLine.vb` and the SVT-AV1 keys; `OptionHelp.vb`; the harness in 6.8; the export command in 6.7; vbproj entries | Debug x64 build; harness green; `-CompareFacts` on a fresh export reports no difference |
| 3. Dialog and help window | 5.3 and 5.4, with the `HelpDocument` and `HelpForm` hygiene changes in their own commit | Manual checklist V4 on the SVT-AV1 dialog; V6 command-line equivalence |
| 4. Tier 1 content | `svt-av1.md` for every ID in section 9, `staxrip.md` for the nine StaxRip-owned controls, `concepts.md` entries that Tier 1 stanzas link to; verification headers filled from the bundled build | `Reviewed-Complete: true` with `-AdvanceRatchet` applied; the maintainer reads the text on the real dialog |

Steps 1 and 2 can proceed in parallel; step 4 can start as soon as step 1 exists, since the validator is what authors run.

Out of scope, on purpose:

| Excluded | Where it may connect later |
| --- | --- |
| Content for any encoder other than SVT-AV1 mainline | Tier 2 (SVT-AV1 variants, x264, x265) and Tier 3 (NVEnc, QSVEnc, VCEEnc, aomenc, rav1e, vvenc, ffmpeg) after the tone review |
| `shared.md` and its orphan checks | The first encoder that reuses another's prose |
| Linux parser, API, and web rendering | A slice on `fork/linux-foundation` when its options UI exists |
| Showing `draft` stanzas, even marked | Never; drafts exist so that coverage can be counted and inherited text can be shadowed |
| A `suppressed` status for permanently hiding inherited text | Revisit when a variant needs it; a draft with a comment covers it until then |
| Translations | `<encoder>.<locale>.md` per 4.1; the grammar already carries `Locale` |
| Changing `ShowConsoleHelp` or the `Help about <package>` menu | None; both stay reachable |
| Upstream drift report; continuous integration | 6.6 |
| Any change to persisted formats, tool selection, or process execution | None |

## 9. Tier 1 content: every SVT-AV1 ID

IDs as the validator derives them from `Source/Encoding/SvtAv1Enc.vb`, grouped by dialog page in `Items` order (`Source/Encoding/SvtAv1Enc.vb:1290`). Controls that share an ID are listed once. Counts: 94 stanzas, of which 9 live in `staxrip.md` and 85 in `svt-av1.md`; one hidden field is excluded.

| Page | IDs (all `svt-av1.` unless marked) |
| --- | --- |
| Input/Output | `staxrip.decoder`, `staxrip.pipe`, `progress`, `frames`, `skip`, `color-format`, `enable-stat-report`, `asm`, `lp`, `pin`, `ss` |
| Basic | `preset`, `profile`, `level`, `tune`, `fast-decode`, `adaptive-film-grain`, `max-tx-size` |
| Rate Control | `rc`, `crf`, `cqp`, `qp`, `tbr`, `mbr`, `max-qp`, `min-qp`, `tf-strength`, `luminance-qp-bias`, `sharpness`, `pass`, `aq-mode`, `hbd-mds`, `qp-scale-compress-strength`, `ac-bias`, `recode-loop`, `enable-qm`, `qm-max`, `qm-min` |
| GOP size/type | `keyint`, `irefresh-type`, `scd`, `lookahead`, `hierarchical-levels`, `pred-struct`, `enable-dg`, `startup-mg-size` |
| AV1 Specific 1 | `tile-rows`, `tile-columns`, `enable-dlf`, `enable-cdef`, `enable-restoration`, `enable-tpl-la`, `enable-mfmv`, `enable-tf`, `enable-kf-tf`, `enable-overlays`, `scm`, `enable-intrabc`, `film-grain`, `film-grain-denoise`, `fgs-table` |
| AV1 Specific 2 | `superres-mode`, `superres-denom`, `superres-kf-denom`, `superres-qthres`, `superres-kf-qthres`, `sframe-dist`, `sframe-mode`, `resize-mode`, `resize-denom`, `resize-kf-denom`, `frame-resz-events`, `frame-resz-denoms`, `frame-resz-kf-denoms`, `lossless`, `avif` |
| Color Description | `color-primaries`, `transfer-characteristics`, `matrix-coefficients`, `color-range`, `chroma-sample-position`, `mastering-display`, `content-light.max-cll`, `content-light.max-fall`; the hidden combined field is `none` |
| Variance Boost Options | `enable-variance-boost`, `variance-boost-strength`, `variance-octile` |
| Custom | `staxrip.custom` |
| Other | `staxrip.override-target-file-name`, `staxrip.target-file-name`, `staxrip.target-file-name-preview`, `staxrip.chunks`, `staxrip.comp-check`, `staxrip.aimed-quality` |

The two commented-out `--input-depth` declarations are excluded by the comment rule in 6.2.

Authoring sources: the bundled `SvtAv1EncApp.exe --help` and `--version` output, the SVT-AV1 `Docs/Parameters.md` at the tag matching the bundled build's base, Patman's release notes for PMod-specific behavior, and the StaxRip code for the StaxRip-owned controls. Where the bundled build and upstream disagree, as with tune 4, the stanza stays `draft` until the binary settles it.

## 10. Verification

| Id | Check | Evidence kept |
| --- | --- | --- |
| V1 | `Check-OptionHelp.ps1 -SelfTest` passes | Command and compact output in the pull request |
| V2 | `Check-OptionHelp.ps1` on the repository: no errors; `svt-av1` at `Reviewed-Complete: true` after step 4 | Report table |
| V3 | Debug x64 build of `Source/StaxRip.sln` with a direct `msbuild` invocation succeeds with no new warnings in touched files. `Source/Build.ps1` is a packaging script that copies to a release share and is not run | Build summary; configuration and platform recorded per `AGENTS.md` |
| V4 | Manual checklist on the SVT-AV1 dialog: tooltip on label, editor, and menu button; the F1 hint line; strip updates on hover and on keyboard focus, keeps text on leave, truncates with an ellipsis; value note on a dropdown entry; F1 on a focused option opens its details, F1 elsewhere opens the dialog help; details window generated facts match the dialog; a related link opens its stanza; the encoder-help link opens the console help at the switch; search finds `grain` in a `When to change` line; a disabled editor still shows help from its label; Narrator reads the accessible name and description; x265 dialog unchanged; both themes; 100 and 150 percent DPI; a 1366 by 768 display | Screenshots with synthetic paths only |
| V5 | `ExportOptionHelpFacts` then `-CompareFacts`: no difference for `svt-av1` | One line in the close-out |
| V6 | Command-line equivalence: for a saved SVT-AV1 template and an x265 template, `Copy Command Line` before and after the change is byte-identical; `GetEmittedValue` is the only edit inside command construction | Two diffs, empty |
| V7 | `git diff --stat` on the branch touches only the files named in this document | Diff stat in the pull request |
| V8 | The parser harness in 6.8 passes on the same fixtures as V1 | Harness output |

Untested boundary, stated: displays above 200 percent DPI, and translations, which have no files yet.

## 11. Risks, unknowns, rollback, privacy

| Id | Item | Confidence | Handling |
| --- | --- | --- | --- |
| U-OH-1 | Manifest resource name for a linked file whose name contains a hyphen | inferred | Loader enumerates names instead of computing them; verified in step 2 |
| U-OH-2 | The display period a two-sentence tooltip needs | unknown feel | Owned by the form's own `ToolTip` instance; no global tooltip changes; judged in V4 |
| U-OH-3 | Strip height across DPI scales and on a 1366 by 768 display | inferred | `FontHeight`-based height; V4 |
| U-OH-4 | Constructions the text extractor does not recognize in encoders added later | verified none for SVT-AV1 | E11 fails loudly; V5 reconciles against the application export per encoder |
| U-OH-5 | The bundled PMod build's option list differs from upstream in places not yet enumerated | verified for tune 4 | Verification headers pin the build; disagreements stay `draft` |
| RK-1 | Reviewed text contains a wrong fact | inferred | Rules 3 to 5 and 10 in 4.5; generated facts; pinned references; the maintainer's tone review |
| RK-2 | Authors drift from the grammar | inferred | E1 to E3 and E13 fail the check with file and line |
| RK-3 | Authored text reaches the browser as markup | mitigated | 5.4 renders nodes, never raw text; security fixtures in 6.5 |

Rollback: revert the dialog, parameter-model, help-window, and vbproj commits and delete `Docs/OptionHelp/`, `Source/Tools/OptionHelp/`, and `Source/Tests/OptionHelp/`. No project, template, settings, or job format changes; no persisted state is added.

Privacy and logging: the content is static text; after 5.4 a help window makes no network request; a user's deliberate click on a reference opens the system browser through the existing `http` handling; text-field values are never written into the temp document; the only log output is a parse error with a file name and line number, or a rejected internal route.

## 12. Decisions staged for the Decision Log

`Docs/Planning/DECISION-LOG.md` on `master` ends at D-036 while `fork/linux-foundation` has reached D-059. The entries below are numbered after the higher line to avoid a collision and are appended to the log when this branch merges into a line whose log is current; renumber then if the log has moved.

### D-060: Option help is external, layered Markdown with stable option IDs

Date: 2026-08-26. Status: Proposed. Area: sections 4 and 5.

Context: 2,261 encoder options have no hover help; 24 have inline `.Help` strings, most of them discarded by the dialog. The Linux line needs the same text. Switches and captions identify controls today, but one switch can serve several controls and a hash set decides which switch is first.

Decision: Help text lives in `Docs/OptionHelp/*.md` in the strict grammar of 4.2, one file per encoder with inheritance for variants, `staxrip.md` for application-owned controls, a glossary reached only through `Related`, and shared prose only through an explicit `Use`. Every parameter has one stable namespaced ID: explicit in VB where a switch is shared or absent, derived from a documented primary-switch routine otherwise.

Because: Prose-first editing on GitHub with a rendered preview, no new dependency, a small parser per side, a layering that covers 2,261 controls with about 700 stanzas, and an identity that survives caption edits, translation, and cross-platform rendering.

Options considered: inline `.Help` in VB (VB-only, rebuild per wording fix, no coverage check); generated from upstream documentation (expert prose, GPL text in an MIT project); YAML or JSON (escaping and indentation traps for non-programmer authors); switch-keyed stanzas without IDs (ambiguous for shared switches, unstable across captions).

Consequences: The grammar becomes a cross-platform contract with a validator as its authority; about sixteen SVT-AV1 declarations gain an explicit key. Own-namespace identities resolve namespace-relative through the chain, so a variant inherits every base stanza without repeating ids; value notes on a shared stanza are valid for the union of the controls' values. Revisit when: a second consumer needs fields the grammar cannot express.

### D-061: Only reviewed text displays; drafts shadow; coverage is an exact ratchet

Date: 2026-08-26. Status: Proposed. Area: sections 4.4 and 6.

Decision: `Status: reviewed` is the only displayed state. A `draft` in a file earlier in the chain blocks inherited text. Each encoder file carries `Allowed-Missing`, `Minimum-Reviewed`, and `Reviewed-Complete`; the validator fails when a count crosses its bound, and only `-AdvanceRatchet` moves a bound, in the strict direction, after a clean run.

Because: Adding a parameter must force at least a draft without forcing a backfill of every encoder on day one; unvetted text must never reach users; a variant author must be able to suppress base text that is wrong for the variant; percentages can hide a regression behind rounding.

Options considered: percentage floors (leak at rounding boundaries; a draft can fail the reviewed floor); hard fail on any missing stanza from day one (blocks every parameter addition until prose exists); warning only (never enforced).

Consequences: A file reaches hard-fail mode by setting `Reviewed-Complete: true`. Revisit when: a bulk parameter sync makes the draft requirement a burden, or a variant needs a permanent `suppressed` state.

### D-062: Three presentation surfaces, keyboard-complete, with generated facts

Date: 2026-08-26. Status: Proposed. Area: section 5.3.

Decision: Hover tooltip carrying the summary; a description strip above the command line updated by hover and keyboard focus; a details window opened by F1 on the focused option or by right-click, whose first lines are generated from the live parameter and which links to the encoder's own console help. F1 with no focused option keeps today's dialog help.

Because: Tooltips are what was asked for; the strip makes the text discoverable and keyboard-reachable; generated facts keep prose from carrying values the application already knows; power users lose nothing.

Options considered: tooltips only (invisible to keyboard users); replacing console help (removes information power users rely on); keeping F1 as dialog help only (no keyboard route to option details).

Consequences: About 90 pixels of dialog height at 100 percent DPI; F1 changes meaning when an option is focused. Revisit when: V4 shows the strip crowding small screens.

### D-063: Independent parsers, one validator, one review gate

Date: 2026-08-26. Status: Proposed. Area: sections 4.5, 6, and 7.

Decision: The Windows and Linux parsers are written separately against the grammar; `Check-OptionHelp.ps1` is the grammar authority and runs on both, with a runtime reconciliation export to catch extractor blind spots. A stanza becomes `reviewed` only after a human readability review in the real interface and technical verification against the bundled encoder version named in the file header. The drafting tool is a workflow choice recorded in `AGENTS.md` and the authoring README, not in this grammar.

Because: Sharing a parser assembly would couple the net48 and net8 builds for a small amount of code; the wording is the product, so the gate is the review of the outcome, which the validator can check for, rather than the tool, which it cannot.

Consequences: A grammar change is a validator change first, then both parsers. Revisit when: the grammar grows past what a fixture suite can pin.
