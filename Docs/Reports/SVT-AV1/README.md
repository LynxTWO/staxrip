# SVT-AV1 defect reports — cover note

Eight reports, one file each, ready to paste into an issue tracker. They came out of a systematic
pass over every SVT-AV1 option exposed by StaxRip's encoder dialog: each option was exercised
against the bundled binary, and each observation was then re-run independently in a second pass
on the same machine before it was written down. Where a claim rests on one run rather than two,
the report says so.

## The build, and the one thing this does not establish

Everything below was observed on **`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`**, the
prebuilt Windows x64 binary bundled with StaxRip, on an AMD Ryzen 9 5950X under Windows 11.

**No stock upstream build was tested.** No such binary was available on this machine, and none of
these was re-run against one. The observations are solid; the attribution below is a judgement
about which switch belongs to whom, not a reproduction result. Every report repeats this in its
own opening paragraph, so each file stands alone.

## Where to send each one

### Patman's fork — https://github.com/Patman86/SVT-AV1-Mod-by-Patman

- **b7 — `--lossless 1` at presets 11-13.** Certain. `--lossless` exists only in this build:
  it appears in the bundled `--help` and in no version of `Docs/Parameters.md` or
  `Docs/CommonQuestions.md` at the v4.2.0 tag. There is no upstream code to report it against.

### Probably upstream — https://gitlab.com/AOMediaCodec/SVT-AV1

Every switch below is an upstream switch, documented in upstream's own `Parameters.md` at v4.2.0,
and none appears on the list of fork-only additions (which is exactly `--allow-mmap-file`,
`--lossless`, `--max-inter-bitrate-pct`, `--max-intra-bitrate-pct`, `--variance-boost-curve`).
That makes upstream the likelier owner — but since the fork is what was tested, the practical
route is to open them with Patman first and let him confirm against a stock build before they go
upstream. Two of them carry extra evidence pointing upstream:

- **b1 — `--asm sse2`/`sse3` crash (0xC0000005) at presets 10-13.** Access violation, no
  diagnostic; one variant left a 4 KB stub.
- **b2 — `--hbd-mds 1`/`2` crash on 10-bit input above `--lp 3`.** Clean at `--lp 1`-`3`
  (33/33 runs), a race at `--lp 4`, always at `--lp 5`-`6` (18/18 runs). Leaves a 28 KB partial
  file.
- **b3 — CBR + low delay + `--irefresh-type 1` hangs forever.** The encoder prints its own
  `Unexpected temporal_layer - RPS for LD CBR HL2` and then wedges at 0.03 s CPU. That error
  string is upstream's.
- **b5 — `--enable-tf 2` is not deterministic** at the automatic level of parallelism, which
  contradicts upstream's own `Threading and Efficiency` claim about `--lp 1` versus `--lp n`.
  Levels 0 and 1 are deterministic on the same clip.
- **b6 — reference scaling crashes in 31 of 43 runs** that scaled non-key frames, and the runs
  that finish are not repeatable. `--resize-mode 4` also has no range check on its list values.
- **b8 — `--avif 1` on a multi-frame input silently keeps 3 frames and exits 0**; with VBR it
  hangs. The encoder diagnoses the condition with `Svt[error]` and then reports success.
- **b9 — an unparseable `--mastering-display` value spins a core forever**, before the input is
  opened. The report includes a source reading of `svt_aom_parse_mastering_display` in upstream
  v4.2.0 `Source/Lib/Globals/metadata_handle.c`, whose `default:` branch does not advance the
  parse pointer. That reading is **derived**, clearly labelled as such in the report, and was not
  confirmed with a debugger or a patched build.

## Lesser findings, not written up separately

These are real and were observed, but each is either a documentation mismatch, a behaviour that is
merely surprising rather than harmful, or something too thin to carry its own report. They are
listed here so nothing is lost, and any of them can be promoted if a maintainer wants it.

- **Documentation: `--tbr` default.** The bundled `--help` says the default is 7000. A run with no
  `--tbr` shows `2000` in both the VBR and CBR banners, which matches upstream `Parameters.md`.
  The help text is what is wrong.
- **Documentation: tile defaults.** The help says the tile default "changes per resolution but is
  1". Encoding with no `--tile-rows`/`--tile-columns` gave output byte-identical to an explicit
  `0` at 160x120, 640x480, 1920x1080 and 3840x2160. The upstream table says 0; the help text is
  what is wrong.
- **Documentation: `--fast-decode`.** Values 1 and 2 changed nothing at preset 8 on the test clip
  — byte-identical output, mini-GOP still 32 — although upstream documents fast decode as
  defaulting to a 5-layer structure. Observed on one clip at one preset; too thin to file.
- **Documentation: `--sframe-mode` default.** The help calls 2 the default. A run without the
  switch and runs with 1 and 2 gave three different files at the automatic level of parallelism
  and the same file at `--lp 1`. The internal default could not be established either way, so
  there is nothing to report yet.
- **Documentation: `--superres-mode 3`.** Never scaled a frame on the test clip at any
  q-threshold including 0, at CRF 35 and 60 and at preset 12. The gating condition is in no
  document I could find. An observation without an explanation; not a defect claim.
- **`--lookahead -1` is refused.** The help lists `-1` as the default for this switch, and typing
  it gives `Invalid parameter 'lookahead' with value '-1'`, exit 1. A help-text bug.
- **`--max-qp` and `--min-qp` act in CRF mode.** The help presents them as VBR/CBR controls;
  `--crf 35 --max-qp 30` gave 13373 bytes and `--crf 35 --min-qp 40` gave 1458, against 4526
  plain. Either a documentation gap or intended behaviour — I could not tell which, so I am not
  filing it as a defect.
- **`--content-light` with MaxCLL 0 drops the whole pair.** `--content-light 0,400` writes no
  light-level side data at all, while `400,0` and `1000,400` both write correctly, so a
  FALL-only signal is silently lost. This one is a genuine defect and could reasonably be
  promoted to its own report; it is here only because it is small and has an obvious workaround.
- **Screen-content detection and IntraBC are off from preset 9 in both prediction structures**,
  although the warning names random access only. A flat-colour test clip was 4.85 times larger at
  preset 9 than at preset 8. Worth knowing; not obviously a bug rather than a design choice.
- **Film grain synthesis warns from preset 7 up** ("should only be used for debug purposes"),
  which includes preset 8. That is the encoder correctly warning; it is noted only because preset
  8 is a very common default.
- **`--color-range 2` and `--chroma-sample-position 3` write streams libdav1d cannot decode.**
  `--color-range 2` gives no warning at all and produces a sequence header dav1d reports as
  `Invalid value at transfer_characteristics: bitstream ended`. `--chroma-sample-position 3` warns
  that the value is reserved and then writes a stream dav1d rejects. Both are out-of-spec values a
  user has to go out of their way to pass, so refusing them cleanly would be a nicety rather than
  a fix.
- **VBR output varies between identical runs by about 0.4 %.** Not a defect, but it is the noise
  floor for everything above: any VBR claim in these reports rests either on repeated runs or on
  an effect far larger than 0.4 %.

## A note on the numbers in these reports

Byte counts, exit codes and hashes are quoted from captured probe output rather than retyped. Run
counts are exact. Where the two passes disagreed — the `--lp 4` row in b2, the both-16 resize run in
b6 — the disagreement is reported rather than averaged away, because in both cases the
disagreement is the finding.
