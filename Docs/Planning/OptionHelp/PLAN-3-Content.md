# Option Help Implementation Plan 3: SVT-AV1 Content

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every SVT-AV1 option and every StaxRip-owned control in that dialog has a reviewed stanza, verified against the bundled `SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]` build, so the maintainer can judge the tone on real screens and the file can be marked `Reviewed-Complete: true`.

**Architecture:** Content only, plus one validator rule (W2). Stanzas are authored page by page in `Docs/OptionHelp/svt-av1.md`, the nine StaxRip-owned controls in `staxrip.md`, and the glossary entries they link to in `concepts.md`. Each task drafts, verifies against the bundled `--help` text and the pinned upstream document, marks `reviewed`, runs the validator, advances the ratchet, and looks at the result in the dialog.

**Tech Stack:** Markdown per the grammar, PowerShell 7 validator, the dev build from plan 2.

**Spec:** `Docs/Planning/OPTION-HELP.md` (v0.2), sections 4.5, 4.6, 8 step 4, 9, 10 V2 and V4.

## Global Constraints

- Prerequisite: plans 1 and 2 complete; the dev build runs from `Source\bin\StaxRip.exe` with the `Apps` junction; `svt-av1.md` already carries the verification headers and the reviewed `svt-av1.preset` stanza.
- Writing rules 1 to 10 from `Docs/OptionHelp/README.md` apply to every stanza. Prose is drafted by the strongest writer available for warm, plain, friend-to-friend English, at the drafter's judgment (the maintainer's standing instruction); rule 10 is the gate.
- Facts come from, in this order of authority: the bundled binary's `--help` and `--version` output; `https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md` and `Docs/CommonQuestions.md` at that tag; Patman's release notes at `https://github.com/Patman86/SVT-AV1-Mod-by-Patman/releases` for PMod-specific behavior; `Source/Encoding/SvtAv1Enc.vb` for StaxRip defaults and option lists. Where the bundled build and upstream disagree, the bundled build wins and the stanza says so.
- Every number in an `Example` is either from those sources or from a test encode the author actually ran; label test results with the clip, resolution, and machine class. Never add a number to satisfy the template.
- Original wording only. Never paste upstream text.
- Field limits: Summary 200, Used when 200, When to change 400, Encoder default 40, Example 300, value notes 120. `Values` are selective: explain the landmarks.
- On this branch, `reviewed` means technically verified; the maintainer's readability review on the real dialog (Task 9) is the gate before merge.
- Commit after every task with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer; push at the end of every task.

---

## File structure

| File | Responsibility |
| --- | --- |
| `Docs/OptionHelp/svt-av1.md` | 85 stanzas, one per SVT-AV1 id in spec section 9 |
| `Docs/OptionHelp/staxrip.md` | 9 stanzas for the StaxRip-owned controls |
| `Docs/OptionHelp/concepts.md` | Glossary entries referenced by `Related` |
| `Source/Tools/OptionHelp/OptionHelp.psm1` | W2 rule (Task 9) |
| `J:\TEMP\claude\c--DEV-StaxRip\cd295f73-6a7a-4720-87b2-705b360e3125\scratchpad\svtav1\` | Captured `--help`, `--version`, facts export, and fetched upstream documents used during authoring; not committed |

## The authoring procedure used by Tasks 2 to 8

Each task repeats these steps for its list of ids. They are written out once here and referenced by number in the tasks.

- **P1 Gather facts.** For each id, print the application facts and the bundled help line:

```powershell
$facts = Get-Content -Raw 'J:\TEMP\claude\c--DEV-StaxRip\cd295f73-6a7a-4720-87b2-705b360e3125\scratchpad\svtav1\facts.json' | ConvertFrom-Json
$p = $facts.encoders[0].parameters | Where-Object identity -eq 'svt-av1.tune'
$p | ConvertTo-Json -Compress
Select-String -Path 'J:\TEMP\claude\c--DEV-StaxRip\cd295f73-6a7a-4720-87b2-705b360e3125\scratchpad\svtav1\help.txt' -Pattern '^\s*--tune\b' -Context 0,3
```

Read the StaxRip declaration in `Source/Encoding/SvtAv1Enc.vb` for `.Init`, `.Config`, `.Options`, `.VisibleFunc` (which becomes `Used when`), and `.HintText`. Read the upstream `Parameters.md` section for the switch.

- **P2 Draft.** Write the stanza with `Status: draft` following the template in `Docs/OptionHelp/README.md`: `Label` equal to the caption (`.Text`), `Summary`, `Used when` where a `VisibleFunc` or the documentation makes the option conditional, `When to change`, `Encoder default` when the encoder's default differs from StaxRip's `.Init`, `Example` when a concrete action helps, `Values` for the landmarks of a dropdown, `Related` to sibling options and glossary entries, `References` with the pinned upstream anchor.

- **P3 Validate.** `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -Encoder svt-av1`. Fix every E and W line. The `MISSING` list shrinks by the ids just written.

- **P4 Verify and mark reviewed.** Re-read each stanza against P1's sources: every value key exists in the emitted values, every default and range matches `--help`, every claim about behavior is supported by upstream or PMod documentation, `Used when` matches the `VisibleFunc`. Change `Status: draft` to `Status: reviewed`. Add `When to change` if it is missing.

- **P5 Advance and look.** `pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -AdvanceRatchet` (only after a clean run). Build is not needed for content; restart the dev build (`Source\bin\StaxRip.exe` embeds the files at build time, so rebuild StaxRip once per task: `& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' 'Source\StaxRip.vbproj' -t:Build -p:Configuration=Debug -p:Platform=x64 -m -nologo -verbosity:minimal`). Open the SVT-AV1 dialog, hover three of the new stanzas, open one details window, and fix anything that reads wrong on screen before committing.

- **P6 Commit and push.**

---

### Task 1: Capture the sources and restore the preset cross-link

**Files:**
- Create (scratchpad, not committed): `svtav1\help.txt`, `svtav1\version.txt`, `svtav1\facts.json`, `svtav1\Parameters.md`, `svtav1\CommonQuestions.md`
- Modify: `Docs/OptionHelp/svt-av1.md` (the `Related` line of `svt-av1.preset` once `svt-av1.crf` exists in Task 4)

- [ ] **Step 1: Capture the bundled build's help and version**

```powershell
$dir = 'J:\TEMP\claude\c--DEV-StaxRip\cd295f73-6a7a-4720-87b2-705b360e3125\scratchpad\svtav1'
New-Item -ItemType Directory -Force $dir | Out-Null
& 'C:\StaxRip\Apps\Encoders\SvtAv1EncApp\SvtAv1EncApp.exe' --version 2>&1 | Out-File "$dir\version.txt" -Encoding utf8
& 'C:\StaxRip\Apps\Encoders\SvtAv1EncApp\SvtAv1EncApp.exe' --help 2>&1 | Out-File "$dir\help.txt" -Encoding utf8
Get-Content "$dir\version.txt"
(Get-Content "$dir\help.txt" | Measure-Object -Line).Lines
```

Expected: the version line `SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman] (release)` (if it differs, update the `Verified-*` headers in `svt-av1.md` to match) and a help file of well over one hundred lines.

- [ ] **Step 2: Export the application facts**

```powershell
& 'Source\bin\StaxRip.exe' "-ExportOptionHelpFacts:$dir\facts.json" '-Exit'
pwsh -NoProfile -File Source/Tools/OptionHelp/Check-OptionHelp.ps1 -CompareFacts "$dir\facts.json"
```

Expected: `facts: no differences`.

- [ ] **Step 3: Fetch the pinned upstream documents**

```powershell
Invoke-WebRequest 'https://gitlab.com/AOMediaCodec/SVT-AV1/-/raw/v4.2.0/Docs/Parameters.md' -OutFile "$dir\Parameters.md"
Invoke-WebRequest 'https://gitlab.com/AOMediaCodec/SVT-AV1/-/raw/v4.2.0/Docs/CommonQuestions.md' -OutFile "$dir\CommonQuestions.md"
```

If the `v4.2.0` tag does not exist, list tags at `https://gitlab.com/AOMediaCodec/SVT-AV1/-/tags`, use the nearest tag at or below the bundled version, and change the `Documentation` header and every `References` URL in this plan's tasks to that tag.

- [ ] **Step 4: Note the PMod-specific switches**

Compare the switch list in `help.txt` with `Parameters.md`:

```powershell
$help = Select-String -Path "$dir\help.txt" -Pattern '^\s*(--[a-z0-9-]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique
$doc = Select-String -Path "$dir\Parameters.md" -Pattern '\*\*(--[a-z0-9-]+)\*\*' -AllMatches | ForEach-Object { $_.Matches | ForEach-Object { $_.Groups[1].Value } } | Sort-Object -Unique
Compare-Object $help $doc | Where-Object SideIndicator -eq '<=' | ForEach-Object InputObject
```

Save the output as `$dir\pmod-only.txt`. Every switch in that list that StaxRip exposes must be documented from PMod's release notes or from the `--help` line alone, and its stanza's `References` must point at the PMod releases page rather than upstream.

No commit for this task; it produces scratchpad files only.

---

### Task 2: `staxrip.md`: the nine StaxRip-owned controls

**Files:**
- Modify: `Docs/OptionHelp/staxrip.md`
- Read: `Source/Encoding/SvtAv1Enc.vb:451-515` (declarations), `Source/Encoding/VideoEncoder.vb` (chunk encoding and compressibility check), `Source/General/Macro.vb` (target file name macros)

**Ids and facts to gather (P1 uses the StaxRip code, not `--help`):**

| Id | Caption | Control | Where the behavior lives |
| --- | --- | --- | --- |
| `staxrip.decoder` | Decoder | dropdown `AviSynth/VapourSynth`, `QSVEnc (Intel)`, `ffmpeg (Intel)`, `ffmpeg (DXVA2)` | `SvtAv1Enc.vb:477-481`; `SvtAv1Enc.GetArgs` chooses the pipe source by this value |
| `staxrip.pipe` | Pipe | two dropdowns, `Automatic`, `avs2pipemod` or `vspipe`, `ffmpeg` | `SvtAv1Enc.vb:483-495`; the AviSynth and VapourSynth variants share this stanza, so the text must cover both tools |
| `staxrip.custom` | Custom | four text boxes: all passes, first, second, third pass | `SvtAv1Enc.vb:1247-1282`; appended verbatim to the command line |
| `staxrip.override-target-file-name` | Override Target File Name | checkbox | `SvtAv1Enc.vb:451-453` |
| `staxrip.target-file-name` | Target File Name | text with macros | `SvtAv1Enc.vb:455-463`; `Macro.vb` for `%source_name%` |
| `staxrip.target-file-name-preview` | Preview | read-only text | `SvtAv1Enc.vb:465-475` |
| `staxrip.chunks` | Chunks | number 1 to 128 | `SvtAv1Enc.vb:511-514`; chunk encoding in `VideoEncoder.vb` (search `Chunks`) |
| `staxrip.comp-check` | Comp. Check | number 1 to 50 | `SvtAv1Enc.vb:497-502`; compressibility check in `VideoEncoder.vb` (search `CompCheck`) |
| `staxrip.aimed-quality` | Aimed Quality | number 1 to 100 | `SvtAv1Enc.vb:504-509` |

- [ ] **Step 1: P1 for the nine ids.** Read each referenced code location; write down in the scratchpad, per control, what it actually does to the encode or workflow. For `Chunks`, state precisely how pieces are cut, encoded, and joined and what that means for the result; do not guess, read `VideoEncoder.vb`.
- [ ] **Step 2: P2 draft the nine stanzas** in `staxrip.md`. `Related` links between `staxrip.comp-check` and `staxrip.aimed-quality`, and from `staxrip.target-file-name` to `staxrip.override-target-file-name` and `staxrip.target-file-name-preview`. No `References` (the source is StaxRip itself).
- [ ] **Step 3: P3, P4, P5.** Expected after P3: `MISSING` no longer lists the nine `staxrip.*` ids; `reviewed` for `svt-av1` rises by 13, because the counters count parameters and the two `Pipe` controls and the four `Custom` boxes resolve to shared stanzas.
- [ ] **Step 4: P6.**

```bash
git add Docs/OptionHelp/staxrip.md Docs/OptionHelp/svt-av1.md
git commit -m "Docs: option help for the StaxRip-owned dialog controls" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push origin worktree-option-help
```

---

### Task 3: Input/Output and Basic pages

**Ids (15 new; `svt-av1.preset` already exists):** `svt-av1.progress` (Progress), `svt-av1.frames` (Frames To Be Encoded), `svt-av1.skip` (Frames To Be Skipped), `svt-av1.color-format` (Encoder Color Format), `svt-av1.enable-stat-report` (Stat Report), `svt-av1.asm` (Limit Assembly Instruction Set), `svt-av1.lp` (Level Of Parallelism), `svt-av1.pin` (Pinned Execution), `svt-av1.ss` (Target Socket); `svt-av1.profile` (Profile), `svt-av1.level` (Level), `svt-av1.tune` (Tune), `svt-av1.fast-decode` (Fast Decode), `svt-av1.adaptive-film-grain` (Adaptive Film Grain), `svt-av1.max-tx-size` (Max TX Size). `svt-av1.preset` exists already.

Facts that Task 1 already settled: the bundled `--help` describes `--lp` as "Amount of parallelism to use. 0 means choose the level based on machine core count", range 0 to 6; `--tune` values are `0 = VQ, 1 = PSNR, 2 = SSIM, 3 = IQ (Image Quality), 4 = MS_SSIM (MS_SSIM and SSIMULACRA2 optimized mode), 5 = VMAF`, default 1, so StaxRip's label for tune 4 matches the bundled build and the tune stanza can be reviewed with that wording.

- [ ] **Step 1: P1 for the sixteen ids.**
- [ ] **Step 2: P2.** For `svt-av1.tune`, use the spec's revised example (section 4.6) with the value-4 note rewritten from the bundled help line. `Related` for the tune stanza: `svt-av1.preset, svt-av1.crf, concept.psnr, concept.ssim, concept.vmaf, concept.vq`; add those four glossary entries to `concepts.md` in this task (Summary, `When to change: Not a setting. See the options that link here.`, `Status: reviewed`). For `svt-av1.lp`, use the spec's revised example with `Related: svt-av1.pin, svt-av1.ss, concept.parallelism` and add `concept.parallelism`. For `svt-av1.frames` and `svt-av1.skip`, say plainly that they encode a part of the source and are for tests, not for cutting a video.
- [ ] **Step 3: P3, P4, P5.**
- [ ] **Step 4: P6** (`git add Docs/OptionHelp/svt-av1.md Docs/OptionHelp/concepts.md`, message `Docs: SVT-AV1 option help for the Input/Output and Basic pages`).

---

### Task 4: Rate Control page

**Ids (20):** `svt-av1.rc` (Rate Control Mode), `svt-av1.crf` (Constant Rate Factor), `svt-av1.cqp` (Constant Quantization Parameter), `svt-av1.qp` (Quantization Parameter), `svt-av1.tbr` (Target Bitrate), `svt-av1.mbr` (Maximum Bitrate), `svt-av1.max-qp` (Maximum Quantizer), `svt-av1.min-qp` (Minimum Quantizer), `svt-av1.tf-strength` (Temporal Filtering Strength), `svt-av1.luminance-qp-bias` (Luminance QP Bias), `svt-av1.sharpness` (Sharpness Bias), `svt-av1.pass` (Passes; two controls), `svt-av1.aq-mode` (Adaptive Quantization), `svt-av1.hbd-mds` (High Bit Depth Mode Decisions), `svt-av1.qp-scale-compress-strength` (QP Scale Compress Strength), `svt-av1.ac-bias` (AC Bias in Rate Distortion), `svt-av1.recode-loop` (Recode Loop), `svt-av1.enable-qm` (Enable quantisation matrices), `svt-av1.qm-max` (Max quant matrix flatness), `svt-av1.qm-min` (Min quant matrix flatness).

- [ ] **Step 1: P1.** The `VisibleFunc` of `ConstantRateFactor`, `ConstantQuantizationParameter`, `QuantizationParameter`, `TargetBitrate`, `PassesVBR`, and `PassesCBR` in `SvtAv1Enc.vb:672-720` and `856-875` define `Used when` for those stanzas (which rate-control mode shows them). `--crf`, `--cqp`, `--qp`, `--tbr`, and `--rc` are emitted through `ArgsFunc`, so their `HelpSwitch` is the id; the `--help` lines are still the fact source.
- [ ] **Step 2: P2.** Add glossary entries `concept.rate-control`, `concept.quality-level` (what CRF and QP numbers mean, direction of the scale, 0 to 63 for AV1), `concept.bitrate`, `concept.two-pass`. The `svt-av1.crf` stanza is the most-read text in the file: name the scale, say that lower is higher quality and larger, give the StaxRip default from `.Init` and the encoder default from `--help`, and make the example a comparison the reader can run, not a claim about file sizes. Then restore `Related: svt-av1.crf, concept.compression-efficiency` on `svt-av1.preset`.
- [ ] **Step 3: P3, P4, P5.**
- [ ] **Step 4: P6** (message `Docs: SVT-AV1 option help for the Rate Control page`).

---

### Task 5: GOP size/type and Variance Boost pages

**Ids (11):** `svt-av1.keyint` (Keyint / GOP Size; two controls that alternate by rate-control mode), `svt-av1.irefresh-type` (Intra Refresh Type), `svt-av1.scd` (Scene Change Detection Control), `svt-av1.lookahead` (Lookahead), `svt-av1.hierarchical-levels` (Hierarchical Levels), `svt-av1.pred-struct` (Prediction Structure), `svt-av1.enable-dg` (Dynamic GOP), `svt-av1.startup-mg-size` (Startup Mini-GOP Size); `svt-av1.enable-variance-boost` (Enable Variance Boost), `svt-av1.variance-boost-strength` (Variance Boost Strength), `svt-av1.variance-octile` (Variance Octile).

- [ ] **Step 1: P1.** `KeyInt` and `KeyIntCrf` (`SvtAv1Enc.vb:877-895`) emit values such as `-2`, `0`, `-1`, `1s`; the stanza's `Values` keys must be the emitted strings from the facts export, and the note for `-2` explains "about five seconds" in words. `VarianceBoostStrength` and `VarianceOctile` are visible only when `EnableVarianceBoost` is 1 (`Used when`). Check which of these switches appear in `pmod-only.txt`; variance boost is documented upstream at v4.2.0 (`--enable-variance-boost`, range 0 to 1, default 0; `--variance-boost-strength` 1 to 4, default 2), so upstream references apply.
- [ ] **Step 2: P2.** Add glossary entries `concept.keyframe`, `concept.gop`, `concept.lookahead`, `concept.scene-change`. Explain variance boost in terms of dark and flat areas getting more bits, because that is what a newcomer sees.
- [ ] **Step 3: P3, P4, P5.**
- [ ] **Step 4: P6** (message `Docs: SVT-AV1 option help for the GOP and Variance Boost pages`).

---

### Task 6: AV1 Specific 1 page

**Ids (15):** `svt-av1.tile-rows` (Tile Rows), `svt-av1.tile-columns` (Tile Columns), `svt-av1.enable-dlf` (Deblocking Loop Filter), `svt-av1.enable-cdef` (Constrained Directional Enhancement Filter), `svt-av1.enable-restoration` (Loop Restoration Filter), `svt-av1.enable-tpl-la` (Temporal Dependency Model), `svt-av1.enable-mfmv` (Motion Field Motion Vector), `svt-av1.enable-tf` (ALT-REF Frames), `svt-av1.enable-kf-tf` (Enable MCTF for key frames), `svt-av1.enable-overlays` (Insertion of Overlayer Pictures), `svt-av1.scm` (Screen Content Detection Level), `svt-av1.enable-intrabc` (Enable Intra Block Copy), `svt-av1.film-grain` (Film Grain Level), `svt-av1.film-grain-denoise` (Film Grain Denoise), `svt-av1.fgs-table` (FGS Table).

- [ ] **Step 1: P1.** Note that the bundled `--scm` has four levels (`3: content adaptive (anti-alias aware)`) while StaxRip's dropdown may list fewer; the stanza documents the values StaxRip emits and no others. `--fgs-table` is a file path; do not describe its format beyond "a file the encoder reads".
- [ ] **Step 2: P2.** Add glossary entries `concept.tiles`, `concept.film-grain`, `concept.deblocking`. For the three loop filters, say what turning one off does to the picture and to speed, and that the defaults are on for a reason.
- [ ] **Step 3: P3, P4, P5.**
- [ ] **Step 4: P6** (message `Docs: SVT-AV1 option help for the AV1 Specific 1 page`).

---

### Task 7: AV1 Specific 2 page

**Ids (15):** `svt-av1.superres-mode` (Super-Resolution Mode), `svt-av1.superres-denom` (SuperRes Denominator), `svt-av1.superres-kf-denom` (SuperRes Denominator for KeyFrames), `svt-av1.superres-qthres` (SuperRes q-threshold), `svt-av1.superres-kf-qthres` (SuperRes q-threshold for KeyFrames), `svt-av1.sframe-dist` (S-Frame Interval), `svt-av1.sframe-mode` (S-Frame Insertion Mode), `svt-av1.resize-mode` (Resize Mode), `svt-av1.resize-denom` (Resize Denominator), `svt-av1.resize-kf-denom` (Resize Denominator for KeyFrames), `svt-av1.frame-resz-events` (Resize Events), `svt-av1.frame-resz-denoms` (Resize Denominator In Event), `svt-av1.frame-resz-kf-denoms` (Resize Denominator for KeyFrames In Event), `svt-av1.lossless` (Lossless), `svt-av1.avif` (Avif (Still-Picture Coding)).

- [ ] **Step 1: P1.** The `VisibleFunc` on the super-resolution and resize sub-options gives their `Used when` (the mode that enables them). Lossless changes what several other options do; say so in `Used when` of `svt-av1.lossless` itself is wrong, so put that interaction in `When to change`.
- [ ] **Step 2: P2.** Add glossary entries `concept.super-resolution`, `concept.lossless`. Most of these options are for streaming and research; the honest `When to change` for most is "leave it at the default unless you know you need it", and the stanza says what the option is for so the reader knows they do not.
- [ ] **Step 3: P3, P4, P5.**
- [ ] **Step 4: P6** (message `Docs: SVT-AV1 option help for the AV1 Specific 2 page`).

---

### Task 8: Color Description page

**Ids (8):** `svt-av1.color-primaries` (Color Primaries), `svt-av1.transfer-characteristics` (Transfer Characteristics), `svt-av1.matrix-coefficients` (Matrix Coefficients), `svt-av1.color-range` (Color Range), `svt-av1.chroma-sample-position` (Chroma Sample Position), `svt-av1.mastering-display` (Master Display), `svt-av1.content-light.max-cll` (Maximum CLL), `svt-av1.content-light.max-fall` (Maximum FALL).

- [ ] **Step 1: P1.** The two `content-light` ids come from explicit keys; both controls emit through the same `--content-light` switch, and the `--help` line describes the pair. `MasteringDisplay` is a text field whose value StaxRip usually fills from the source; the stanza says where the value comes from and that hand-editing it is rare.
- [ ] **Step 2: P2.** Add glossary entries `concept.hdr-metadata` and `concept.color-description` (what the three signaling options tell a player, and that they describe the source rather than change it). The four signaling stanzas share the `Used when` idea "when StaxRip's automatic detection is wrong or the source lacks the information".
- [ ] **Step 3: P3, P4, P5.**
- [ ] **Step 4: P6** (message `Docs: SVT-AV1 option help for the Color Description page`).

---

### Task 9: Glossary completion, W2, `Reviewed-Complete`, maintainer review, close-out

**Files:**
- Modify: `Docs/OptionHelp/concepts.md`, `Docs/OptionHelp/svt-av1.md`
- Modify: `Source/Tools/OptionHelp/OptionHelp.psm1` (W2), `Source/Tools/OptionHelp/fixtures/expected/report-repo.txt`

- [ ] **Step 1: Glossary audit.** Every `Related` target of the form `concept.*` must exist and be reviewed (E6 catches missing ones; this step catches thin ones). Read every glossary entry once as a set: consistent voice, each defines one idea in two sentences, no entry depends on another entry to be understood.

- [ ] **Step 2: W2 in the validator.** In `Test-OptionHelpRepository`, inside the loop over parameters after the resolution `switch`, add:

```powershell
            if ($r.Stanza -and $r.Stanza.Fields.Contains('Label') -and $r.Stanza.Fields['Label'] -ne $p.Caption) {
                $warnings.Add([pscustomobject]@{ File = "Docs/OptionHelp/$($r.File)"; Line = $r.Stanza.Line; Code = 'W2'; Message = "Label '$($r.Stanza.Fields['Label'])' differs from caption '$($p.Caption)'" })
            }
```

The fixture `fixtures/repo/Docs/OptionHelp/fake.md` already carries `Label: Alfa` on `fake.alpha` (plan 1), so add `W2 Docs/OptionHelp/fake.md Label 'Alfa' differs from caption 'Alpha'` to `expected/report-repo.txt` between the `W1` and `W3` lines (warnings sort by code, then file, then message). Run `-SelfTest`: 23 cases, 0 failures. Run the repository check: W2 must not fire for any real stanza; where it does, the `Label` is wrong, not the caption.

- [ ] **Step 3: Complete the file.** Run the repository check: `svt-av1` must show `reviewed=100 draft=0 missing=0`. Run `-AdvanceRatchet` (expected header `Allowed-Missing: 0`, `Minimum-Reviewed: 100`), then set `Reviewed-Complete: true` by hand and run the check once more (`RESULT PASS`). Run `-CompareFacts` against a fresh export (`facts: no differences`) and the harness (18 cases, 0 failures).

- [ ] **Step 4: Maintainer tone review on the real dialog.** Rebuild, launch, and hand over the dialog with this list; record answers in the pull request:

1. Read the Basic and Rate Control pages by hovering every control: does each summary say what the option changes, in words you would use to a friend?
2. Open three details windows (Preset, CRF, Tune): are the generated facts right for the current template, and is `When to change` a decision you could act on?
3. Pick five options you personally never touch (AV1 Specific 2 is a good place): does the text tell you honestly to leave them alone, without being condescending?
4. Read `staxrip.chunks` and `staxrip.comp-check`: do they describe what StaxRip actually does?
5. Search for `dark`, `grain`, `size`, and `speed`: do the hits make sense?
6. List every stanza that reads as a forum opinion rather than dependable help, by id.

Fix every listed stanza, re-run P3 to P5 for the touched ids, and repeat the list until the maintainer has nothing left to name. Only then is the readability review of rule 10 satisfied for this branch.

- [ ] **Step 5: Commit, push, close-out.**

```bash
git add Docs/OptionHelp Source/Tools/OptionHelp
git commit -m "Docs: complete the reviewed SVT-AV1 option help" -m "Adds the W2 label check. svt-av1.md is Reviewed-Complete." -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push origin worktree-option-help
```

Append to the pull request's close-out record: the counts (`reviewed=100`, 85 stanzas in `svt-av1.md`, 9 in `staxrip.md`, the glossary count), the verification headers used, the PMod-only switches documented from release notes, the maintainer's review rounds, and the follow-up (Tier 2: SVT-AV1 variants via `Inherits`, x264, x265).

---

## Self-review against the spec (plan 3 scope)

| Spec item | Task |
| --- | --- |
| 4.5 writing rules, rule 10 gate | every task (P2, P4), Task 9 Step 4 |
| 4.6 revised examples (preset, tune, lp) | plan 2 Task 8 (preset), Task 3 (tune, lp) |
| 8 step 4 deliverable | Tasks 2 to 9 |
| 9 every id, including the nine `staxrip.*` ids and the two `content-light` ids | Tasks 2 to 8 (16 + 20 + 11 + 15 + 15 + 8 = 85 in `svt-av1.md`, 9 in `staxrip.md`) |
| 6.3 W2 | Task 9 |
| 6.4 ratchet to completion | every task (P5), Task 9 Step 3 |
| 10 V2, V4 (tone review), V5 | Task 9 |
| 11 U-OH-5 (PMod differences stay honest) | Task 1 Step 4, every P4 |

Id count check against spec section 9: Input/Output 9 + Basic 7 (including `preset`, already done) = 16 with `preset` counted, so Task 3 authors 15 new ids and the totals hold at 85.
