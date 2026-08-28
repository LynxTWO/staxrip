# Plan 3 close-out: reviewed SVT-AV1 option help

Branch `worktree-option-help`; the closing record of `Docs/Planning/OptionHelp/PLAN-3-Content.md`, written for the maintainer. Every finding below can be acted on from this page alone; the task reports under `.superpowers/sdd/PLAN-3-Content/` hold the probe scripts, their outputs, and the line-by-line evidence behind each one.

## 1. What the branch holds

### Counts

The validator, unscoped, after the last commit of the plan:

```text
ENCODER svt-av1 total=100 excluded=1 reviewed=100 draft=0 missing=0 allowed-missing=0 minimum-reviewed=100 reviewed-complete=true result=PASS
W3 svt-av1 ContentLightLevel excluded
RESULT PASS
```

plus one `W1 <file> no help file` line for each of the 13 other encoder files under `Source/Encoding/`, which is the Tier 2 backlog. The 100 parameters (101 declared, the hidden combined `ContentLightLevel` excluded) resolve to 94 stanzas:

| File | Stanzas | Holds |
| --- | --- | --- |
| `Docs/OptionHelp/svt-av1.md` | 85 | Every control of the SVT-AV1 dialog; `svt-av1.pass` and `svt-av1.keyint` each serve two controls |
| `Docs/OptionHelp/staxrip.md` | 9 | The thirteen StaxRip-owned controls (four `Custom` boxes share `staxrip.custom`, two `Pipe` dropdowns share `staxrip.pipe`) |
| `Docs/OptionHelp/concepts.md` | 21 | The glossary; every entry is reviewed and reached by at least one `Related` link |

Verification headers in `svt-av1.md`, the evidence every `reviewed` status rests on:

```text
Verified-Encoder-Version: SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman] (release)
Verified-Encoder-Build: 17cd99550
Verified-Date: 2026-08-27
Documentation: https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
```

PMod-only switches, meaning switches in the bundled `--help` that neither `Parameters.md` nor `CommonQuestions.md` at the v4.2.0 tag documents in any form: `--allow-mmap-file`, `--lossless`, `--max-inter-bitrate-pct`, `--max-intra-bitrate-pct`, `--variance-boost-curve`. Only `--lossless` is a StaxRip control; `svt-av1.lossless` is written from the bundled help and from tests, and its `References` point at Patman's releases page rather than upstream. The reverse list (switches upstream documents that the bundled build lacks) is empty.

### Checks run

After the last commit: validator self-test 35 cases, 0 failures; the unscoped check above, with no `W2` line (every stanza's `Label` matches its control's caption); `-CompareFacts` against a fresh `-ExportOptionHelpFacts` export from the rebuilt executable, `facts: no differences`; the VB parser harness (`Source/Tests/OptionHelp`) 52 cases, 0 failures; Debug x64 build of `Source/StaxRip.vbproj`, exit 0; `Source/Tests/OptionHelp/Probe-Embedded.ps1`, `PROBE PASSED`.

Untested boundary: no person has yet read the text in the real dialog (section 2). The claims about the bundled build's behaviour (crashes, refusals, hangs, sizes, timings) were reproduced by each task's reviewer on this machine (Ryzen 9 5950X); a timing claim carries its clip, preset, and run count in the stanza, and CRF was the comparison mode wherever bytes were compared because the build's VBR output varies between identical runs.

Untested boundary, validator: W2's alias branch (for a `Use:` alias the Label checked is the alias stanza's own, in the file that holds it) is exercised by no fixture and no real stanza, because no alias exists yet; add the fixture together with the first `shared.md` alias in Tier 2, in the same change.

Unratified boundary, validator: a scoped `-Encoder` run now applies the stanza rules to the translations of every encoder in the chain as well (`-Encoder svt-av1` would check a future `svt-av1.de.md`), a scope the plan never named; it is kept, because spec 4.2 makes `<Encoder>.<Locale>.md` a file of that encoder and only that encoder's dialog displays it, the validator README's `-Encoder` sentence ("its files") documents it, and the `-Encoder fakevar` self-test case pins it. English-only scoping would be a one-line `Locale` filter on the scope in `OptionHelp.psm1`.

Security, privacy, and logging: nothing new. The validator reads text; the help renders through the trust boundary of plan 2; opening a help window still makes no network request.

### What plan 3 changed besides the text

- Validator (`Source/Tools/OptionHelp`): W2 (a `Label` must equal the caption, or the first line of a wrapped caption, of at least one control that resolves to the stanza); a scoped `-Encoder` run now applies the stanza rules to the encoder's inheritance chain and the shared files; W4 keys on the encoder id rather than the file name; `Split-OhId` uses the char overload; `Resolve-OhId` skips a `Use` target file with file-level errors as the VB `FindByFileKey` does. Self-test 35 cases (new: `-Encoder fakevar`; the `repo` fixture holds a two-line-caption pair that pins W2's first-line rule from both sides).
- `HelpForm`: the temp document is deleted with `IO.File.Delete` at shutdown (no `UIOption` dialog during teardown); the comment names WinForms' thread teardown rather than `MainForm`.
- Probe: the negative case names `svt-av1.no-such-option` (it named `svt-av1.crf` before that stanza existed).
- Documentation: spec 4.3 (`Label`), 4.6, 5.3, 5.6, 6.3 (W2, W4), 6.5; the validator README's `-Encoder`, E4, E6, W2, and W4 text; the authoring README's inheritance section.

## 2. Maintainer's tone review (rule 10)

Answered by the maintainer on 2026-08-27, on the dev build of this branch:

1. Read the Basic and Rate Control pages by hovering every control: does each summary say what the option changes, in words you would use to a friend?

   Answer: Yes.

2. Open three details windows (Preset, CRF, Tune): are the generated facts right for the current template, and is `When to change` a decision you could act on?

   Answer: Yes, near as I can tell.

3. Pick five options you personally never touch (AV1 Specific 2 is a good place): does the text tell you honestly to leave them alone, without being condescending?

   Answer: Yes.

4. Read `staxrip.chunks` and `staxrip.comp-check`: do they describe what StaxRip actually does?

   Answer: Yes.

5. Search for `dark`, `grain`, `size`, and `speed`: do the hits make sense?

   Answer: Yes.

6. List every stanza that reads as a forum opinion rather than dependable help, by id.

   Answer: None seen. If any surface later they can be corrected as the truth surfaces.

One stanza was named in the same reading: `svt-av1.level` listed ten levels as "Refused by the bundled build as an undefined level", which reads as an encoder defect worth chasing. It is not. Annex A of the AV1 specification says "The missing entries in these tables (for example level 2.2 and 7.0) represent levels that are not yet defined", and those missing entries are exactly the ten. SvtAv1EncApp is right to refuse them; StaxRip was offering level numbers that do not exist. Fixed in both places (a5 below).

**Rule 10's readability review is satisfied for this branch.** Every stanza is now `reviewed` in the full sense of `Docs/OptionHelp/README.md`: technically verified against the bundled build and read on the real interface by the maintainer. A later change to a stanza's facts, or a new encoder build, reopens the question for the stanzas it touches.

## 3. Findings for the maintainer

Each line names the stanza that states the behaviour to the user, because that text must change when the code or the bundled build does.

### (a) StaxRip code defects

1. Chunks are not cut with the ffmpeg pipe or a hardware decoder: `SvtAv1Enc.GetArgs` adds `-trim`, `--start`, and `--end` only for avs2pipemod and vspipe and never `--skip` in chunk mode (`Source/Encoding/SvtAv1Enc.vb` 1450-1471, 1483-1497), so every piece encodes from frame 0; `x265Enc.vb` 1768-1837 covers the same paths with `--seek`. Stated in `staxrip.chunks` (Used when) and `staxrip.pipe` (When to change, value `ffmpeg`).
2. Only mkvmerge and MP4Box join chunk files: `ffmpegMuxer.Mux` (`Source/General/Muxer.vb` 1075-1082) opens `OutputPath`, which does not exist in chunk mode, and falls back to the source file; NullMuxer and BatchMuxer have no chunk code; `CanChunkEncode` is `Chunks > 1` and nothing else (`SvtAv1Enc.vb` 249-251). Stated in `staxrip.chunks`.
3. Dead code: `Replace(Environment.NewLine, "")` in `OverridingTargetFileName` (`SvtAv1Enc.vb` 56-58) runs after `Macro.ExpandParamValues` (`Source/General/Macro.vb` 900-903) has already turned CR and LF into `-`. Stated in `staxrip.target-file-name` ("line breaks ... become `-`").
4. **Fixed on this branch.** Stale switches the bundled build rejects with `Unprocessed tokens`: `--ss` (`svt-av1.ss`), `--pin` (`svt-av1.pin`), `--enable-tpl-la` (`svt-av1.enable-tpl-la`); moving the control off its default stopped the encode before it started. The three controls are hidden with `.VisibleFunc = Function() False` rather than deleted, so saved profiles keep their indices and the stanzas stay resolvable, and the three stanzas now say the dialog no longer offers them.
5. **Fixed on this branch.** Ten of the 24 Level values are refused by the build ("Invalid or undefined level"): 2.2, 2.3, 3.2, 3.3, 4.2, 4.3, 7.0, 7.1, 7.2, 7.3. The cause is the AV1 specification, not the encoder: Annex A leaves those seq_level_idx values undefined ("The missing entries in these tables (for example level 2.2 and 7.0) represent levels that are not yet defined"), so no AV1 encoder can produce them. `OnValueChanged` now hides them with `Level.ShowOption(i, False)` and resets a stored undefined level to Autodetect, the pattern `NVEnc`, `QSVEnc` and `VCEEnc` already use. They are hidden rather than deleted because `OptionParam` persists the dropdown **index**: a shorter `.Options`/`.Values` would silently re-map the level every saved profile holds (a profile on 5.1 would come back as 4.1). Delete them only together with a migration. `svt-av1.level` states the specification reason.
6. `HbdMds` is off by one (`SvtAv1Enc.vb` 791-797): `IntegerValue` emits the dropdown index while the labels start at -1, so "0: Forces 8-bit" sends `--hbd-mds 1`, "1: Forces 10-bit" sends 2, and "2: 8/10-bit Hybrid" sends 3, always refused. Fix `.Values = {"-1", "0", "1", "2"}`, then rewrite the `Values` of `svt-av1.hbd-mds`, which documents the current behaviour entry by entry.
7. Passes 2 and 3 send `p.VideoBitrate`, not the dialog's Target Bitrate (`SvtAv1Enc.vb` 1546), so a value typed in the dialog governs pass 1 only. Stated in `svt-av1.tbr`.
8. `--cqp` is formatted with `ToString("0.##")` and no invariant culture (`SvtAv1Enc.vb` 1537), unlike `--crf` (1533) and `--qp` (1541); a comma-decimal locale would emit `--cqp 30,25`. Not stated in a stanza (code review, not tested with a locale change).
9. `QmMax` is always visible: `SvtAv1Enc.vb` 835 tests `EnableQm.Visible`, presumably meant `EnableQm.Value`, so `--qm-max` is sent with matrices off (harmless in a test; the encoder ignores it). Stated in `svt-av1.qm-max`.
10. Constant Bitrate needs Prediction Structure at Low Delay and Variable Bitrate needs Random Access; the build stops on the wrong pairing and nothing in the dialog gates it, so Constant Bitrate cannot run with StaxRip's defaults. Stated in `svt-av1.rc` and `svt-av1.pred-struct`. Candidate: switch `--pred-struct` with the rate mode, or say so in the dialog.
11. `PassesCBR` offers 2-pass and 3-pass that can never work: CBR multi-pass is refused in low delay, CBR itself in random access, and `--pass 3` is outside the encoder's range. Stated in `svt-av1.pass`; reduce the list to one entry or hide it.
12. Startup Mini-GOP Size is shown in every rate-control mode but stops VBR and CBR encodes ("only supports CRF/CQP"). Stated in `svt-av1.startup-mg-size` (Used when); a `VisibleFunc` on the Quality mode is the candidate.
13. The keyint list's "0: infinite" entry is refused by VBR ("intra period must be > 0"): no file is written and the exit code is 0, so StaxRip reports success. Stated in `svt-av1.keyint` (value `0`). Candidate: a VBR list without 0.
14. Hierarchical Levels: the "(default)" entry says 4 while the build's own default is 5 up to preset 8 and 4 from preset 9 in CRF, and 4 in VBR; `Preset.ValueChangedAction` (`SvtAv1Enc.vb` 549-557) rewrites the default entry with an index from an older option list whenever the preset changes, though nothing is sent. Stated in `svt-av1.hierarchical-levels`; remove or fix the action and relabel the entry.
15. Chroma-position import: `SetMetaData` passes MediaInfo's H.264/HEVC value (0 left, 1 center, 2 top-left) straight into AV1's list (1 left, 2 top-left), so a left source stays Unknown and a center source is tagged left. Stated in `svt-av1.chroma-sample-position`; a three-line mapping fix (`0 -> 1`, `1 -> nothing`, `2 -> 2`).
16. The Master Display box is passed verbatim as `--mastering-display`; a malformed value makes the bundled build spin forever before it opens the input (b9), with no message in StaxRip. Stated in `svt-av1.mastering-display`; a format check before launch is the real fix.
17. Typo "2: Aadaptive" in `EnableTF.Options` (`SvtAv1Enc.vb` 1019); the dialog shows it, the stanza's note says "Adaptive". Stated in `svt-av1.enable-tf`.
18. `SetMetaData` sends `--content-light` whenever either number is non-zero, and the encoder then drops a FALL-only pair (b10); it also appends `--color-range 0` with every mastering-display string, overriding a `--color-range 1` sent a moment earlier for a full-range source. Stated in `svt-av1.content-light.max-fall` and `svt-av1.color-range` ("sets Studio along with Master Display").
19. An AV1 source carrying HDR metadata in both bitstream and container makes MediaInfo report MaxCLL as `1000 / 1000`, which `ToInt` reads as 0, so no `--content-light` is sent. Not stated; the stanzas say "type them only if missing". Take the first number.
20. The third pass is labelled "Video encoding second pass" (`SvtAv1Enc.vb` 116). Not stated; cosmetic.
21. Maintainer decision, deliberately not changed on this branch: the legacy `.Help` strings on `CompCheck` and `CompCheckAimedQuality` (`SvtAv1Enc.vb` 509-521; the second says "to adjusts") are still concatenated into the label help (`CommandLineForm.vb` 202-204) beside the reviewed tooltip from `staxrip.comp-check` and `staxrip.aimed-quality`, so both texts are reachable. Remove them once the stanzas have been read on screen.

### (b) Bundled-encoder defects

All against SVT-AV1 v4.2.0+71+88-17cd99550 (Patman build); worth reporting to Patman or upstream.

1. `--asm sse2` and `sse3` crash the build (0xC0000005) at presets 10 to 13 on a Ryzen 9 5950X and run at 9 and below; `sse3` at preset 10 can leave a 4096-byte stub. Stated in `svt-av1.asm`. Reached only by moving the control off MAX.
2. `--hbd-mds 1` and `2` crash on 10-bit input at the automatic level of parallelism: always at lp 5 and above, a race at lp 4, fine at 1 to 3; a partial `.ivf` is left behind. Stated in `svt-av1.hbd-mds`. Reachable from the dialog because of a6.
3. Constant Bitrate + Low Delay + Intra Refresh Type 1 hangs: "Unexpected temporal_layer - RPS for LD CBR HL2", a 4096-byte stub, never exits. Stated in `svt-av1.irefresh-type`. Candidate: hide entry 1 for CBR.
4. The help's `--tbr` default (7000) is wrong for the build, which uses 2000 (upstream's figure). Stated in `svt-av1.tbr`.
5. `--enable-tf 2` is not repeatable at the automatic parallelism (4 distinct files in 5 runs); repeatable at `--lp 1`. Stated in `svt-av1.enable-tf`.
6. Reference scaling (Resize Mode and the event lists) crashed in 31 of 43 runs that scaled non-key frames, and the runs that finished were not repeatable. Stated in `svt-av1.resize-mode` and the other resize stanzas, which advise the defaults.
7. Lossless at presets 11 to 13 (the build maps 12 and 13 to 11) writes a stream that is not lossless and that dav1d and libaom cannot decode properly. Stated in `svt-av1.lossless`.
8. `--avif 1` on a video encodes 3 frames, prints an error and exits 0, so StaxRip would report success and mux a 3-frame file; with VBR it hangs. Stated in `svt-av1.avif`. Candidate: guard the checkbox.
9. A `--mastering-display` value the parser does not recognise (a plain word, or spaces inside the right format) spins the build at 100% of a core forever, before it opens the input. Stated in `svt-av1.mastering-display`.
10. Light-level metadata is written only when MaxCLL is non-zero, so a FALL-only pair is silently lost. Stated in `svt-av1.content-light.max-fall`.
11. Screen-content detection and IntraBC are switched off from preset 9 in both prediction structures although the warning names RA only; a flat-colour test clip was 4.85 times larger at preset 9 than at 8. Stated in `svt-av1.scm` and `svt-av1.enable-intrabc`.
12. Film grain synthesis at StaxRip's default preset 8 triggers the build's "only for debug purposes" warning (from preset 7 up). Stated in `svt-av1.film-grain`, which advises preset 6 or lower.
13. The help's tile default text ("default changes per resolution but is 1") did not hold: the build chose 0 from 160x120 to 3840x2160. Stated in `svt-av1.tile-rows` (Example) and `svt-av1.tile-columns`.
14. Also stated in stanzas: `--lookahead -1`, the help's own default, is refused when typed (`svt-av1.lookahead`); `--max-qp` and `--min-qp` act in CRF mode despite the help (`svt-av1.max-qp`, `svt-av1.min-qp`). Not stated, because the dialog cannot emit them but the Custom box can: `--color-range 2` and `--chroma-sample-position 3` write streams libdav1d cannot decode. VBR output differs between identical runs by about 0.4%, which is why every VBR claim in the text rests on repeated runs or on an effect well above that; the maintainer may want a sentence about it in `svt-av1.rc` or `svt-av1.tbr`.

### (c) Documentation gaps

Against the bundled help and the upstream documents at the v4.2.0 tag.

1. S-frame mode default: the help calls 2 the default, but a run without the switch and runs with 1 and 2 gave different files at the automatic parallelism and the same file at `--lp 1`; the internal default could not be established. `svt-av1.sframe-mode` says what the help says and what the test showed, nothing more.
2. Super-resolution mode 3 never scaled a frame on the test clip at any q-threshold (even 0), at CRF 35 and 60 and at preset 12; the gating condition is in no source. `svt-av1.superres-mode`, `svt-av1.superres-qthres`, and `svt-av1.superres-kf-qthres` report the observation without explaining it.
3. `--fast-decode 1` and `2` changed nothing at preset 8 on the test clip (byte-identical output, mini-GOP still 32) although upstream says fast decode defaults to a 5-layer structure; `svt-av1.fast-decode` attributes the claim to upstream.
4. `--pin` is documented only in Parameters.md prose (Appendix A) and the build rejects it; `--ss` and `--enable-tpl-la` appear in no source at all (a4).
5. `svt-av1.recode-loop` once said changing it "altered a Variable Bitrate encode" on single runs (1.3 to 2%) against the 0.4% run-to-run spread above; the final review judged that below the plan's evidence bar, and the stanza now rests on upstream's recode table and the byte-identical CRF half of the test. The VBR observation stays in the task 4 report, probably real and unproven by repeats; repeat it with several runs per level if a VBR sentence is wanted.

## 4. Follow-up

- Tier 2: the four SVT-AV1 variants (`SvtAv1EssentialEnc`, `SvtAv1HdrEnc`, `SvtAv1PsyexEnc`, `SvtAv1TritiumEnc`) as files with `Inherits: svt-av1` holding only their differences; then x264 and x265 (GPL documentation, so original wording only, rule 9); then the remaining W1 encoders.
- The two Tier 2 resolver items: `Related` targets are looked up verbatim across every loaded file, so a variant's own-namespace override is not what a `Related: svt-av1.<x>` link opens from the variant's dialog; and `Lookup` (`FindInAnyFile`, and the reference's link scan) returns the first file in load order that holds the id, so two files carrying the same id make a link's target order-dependent. Reshape the chain fixtures to the own-namespace form at the same time (spec 6.5).
- Run the validator's self-test and the unscoped check with `pwsh` on the Linux host (the T540p) to prove the "same on Windows and Linux" claim of spec section 6.
- Maintainer decisions recorded above: the legacy `.Help` strings (a21); whether `svt-av1.rc` or `svt-av1.tbr` should mention the VBR run-to-run variance (b14).
- Encoder defect reports to Patman or upstream: b1, b2, b3, b5, b6, b7, b8, b9.
