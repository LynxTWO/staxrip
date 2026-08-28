# AOMEnc and vvencFFapp: StaxRip code defects

Found while writing `Docs/OptionHelp/aomenc.md` and `Docs/OptionHelp/vvencffapp.md` (branch
`worktree-option-help`, 2026-08-28). Fifteen defects across `Source/Encoding/AOMEnc.vb` and
`Source/Encoding/VvencffappEnc.vb`, plus two in `Source/Encoding/ffmpegEnc.vb` found while assessing
that file. **None is fixed here**; every one would change a command line or an encode, which was
outside the scope of a help-text task. Each finding names the code, what the user sees, how it was
verified and by whom, the stanza that states the behaviour to the user, and the shape of the safe
fix. That stanza text has to change when the code or the bundled build does.

Bundled encoders:

- `AOMedia Project AV1 Encoder 3.14.1-46-g1b5a433c0a` at `C:\StaxRip\Apps\Encoders\AOMEnc\aomenc.exe`
  (aomenc has no `--version`; the string is the footer of its `--help`).
- `vvencFFapp version 1.15.0-dev [Windows][GCC 16.1.0][64 bit][SIMD=AVX2]` at
  `C:\StaxRip\Apps\Encoders\vvencFFapp\vvencFFapp.exe`.

## How everything below was verified

Two kinds of probe, both bounded and both run on generated clips in a scratchpad outside the
repository, deleted afterwards.

**Parse-only.** The binary is given the switch and no input file, so only the argument parser runs.

| Encoder | Value accepted | Value refused |
| --- | --- | --- |
| aomenc | `No input file specified!` | `Option X=Y: Invalid value 'Y'` or `Invalid character` |
| vvencFFapp | `Parameter Check Error: Input resolution not set` | `Error parsing option "X" with argument "Y"`, or an `ERROR: In function ...` line |

**Short encodes.** A 64x64 Y4M or raw clip of 2 to 8 frames, used where a parse check cannot reach
the behaviour: anything the encoder only decides once it has frames, and every claim of the form
"this setting changes nothing", which is proved by comparing output size or SHA-256.

**Who verified what.** The implementer probed all fifteen. An independent reviewer re-probed both
binaries from its own scripts and confirmed twelve of the first fourteen, corrected two of the
implementer's descriptions (findings 6 and 14 below carry the correction), and found finding 15,
which the implementer then reproduced. **Findings 9 and 10 were accepted on the implementer's
evidence and not reproduced by the reviewer** — they are marked as such in place, and are the two
to re-run first if any of this is ever acted on.

## The store-key trap, which binds several of these fixes

`CommandLineParam.GetKey` (`Source/Video/VideoEncoderCommandLine.vb:345-359`) falls through
`Name` → `Switch` → `Text + HelpSwitch` → `Text`, and `OptionParam.Value` persists the dropdown
**index**, not the value string (`VideoEncoderCommandLine.vb:697-733`). Two consequences bind the
fixes below:

1. **Never shorten or reorder an `.Options`/`.Values` array.** A saved profile holding index 6 comes
   back as whatever is at index 6 in the new list, silently. The pattern StaxRip already uses is
   `OptionParam.ShowOption(value, visible)` (`VideoEncoderCommandLine.vb:641-647`) to hide the
   entry, plus a guarded reset in `OnValueChanged` that moves a stored value off the hidden entry —
   the NVEnc/QSVEnc/VCEEnc shape, and what commit `24ae9c2c` did for the ten undefined AV1 levels.
   Adding a `.Values` array of the **same length and order** as `.Options` is index-stable and safe;
   that is the shape finding 8 wants.
2. **Check for a shared store key before touching `.Name`, `.Switch` or `.HelpSwitch`.** That check
   is what the `PassesCBR`/`PassesVBR` collision and the rav1e `--content-light` fix both turned on.
   It was run here: **every one of AOMEnc's 175 parameters and vvencFFapp's 27 has a distinct
   `GetKey()`, so neither file has a shared key today.** Re-run the survey if either file gains
   controls. None of the fixes below needs to move a key.

---

# AOMEnc — `Source/Encoding/AOMEnc.vb`

## 1. Five of the seven Tune entries stop the encode — OPEN

**Code.** `AOMEnc.vb:494`. An `OptionParam` with
`.Options = {"psnr", "ssim", "vmaf_with_preprocessing", "vmaf_without_preprocessing", "vmaf", "vmaf_neg", "butteraugli"}`,
no `.Values`, no `.Init`, so index 0 (`psnr`) is `DefaultValue` and emits nothing; every other index
emits `--tune=<option text>`.

**What the user sees.** Picking any of the five VMAF or butteraugli entries kills the encode after
the encoder has started, with `Error: Tried to set control 24 = N`. The bundled binary was built
without libvmaf and without butteraugli, so it rejects the tuning values that need them. The
dropdown gives no hint which two of seven work.

**Verified — implementer and reviewer independently.** Short encodes with each of the ten tune names
the build's help lists:

```
psnr, ssim, vmaf_saliency_map, iq, ssimulacra2      encode normally
vmaf_with_preprocessing     Tried to set control 24 = 4
vmaf_without_preprocessing  Tried to set control 24 = 5
vmaf                        Tried to set control 24 = 6
vmaf_neg                    Tried to set control 24 = 7
butteraugli                 Tried to set control 24 = 8
```

The dialog is also short of the three tunes this build does support — `iq`, `ssimulacra2` and
`vmaf_saliency_map` — which are only reachable from the Custom boxes.

**Shape of the safe fix.** Hide the five broken entries with `ShowOption` and reset a stored value
that lands on one, per the trap above; do **not** shorten `.Options`. Adding the three working names
means appending to `.Options`, which is index-stable because it only extends the tail. A build that
does have libvmaf would want the five shown again, so the hide is better keyed on a capability probe
than hard-coded — or, more simply, left visible with the stanza carrying the warning it carries now.

**Stanza.** `aomenc.tune`. Its `When to change` and five of its `Values` notes state the failure and
name the three undocumented working tunes. **All of it has to be rewritten if the entries start
working**, because the notes would then be wrong in the most misleading direction.

## 2. Four transform checkboxes send a switch that requires an argument — OPEN

**Code.** `AOMEnc.vb:543-546`. Four `BoolParam`s — `--reduced-tx-type-set`, `--use-intra-dct-only`,
`--use-inter-dct-only`, `--use-intra-default-tx-only` — declared **without** `.IntegerValue = True`.
`BoolParam.GetArgs` (`VideoEncoderCommandLine.vb:422-448`) therefore emits the bare switch when the
box is ticked. All four of aomenc's help entries are `--switch=<arg>` (help lines 171-175).

**What the user sees.** Ticking any of the four stops the encode before a frame is read, with
`Error: option reduced-tx-type-set requires argument`. Four checkboxes that cannot be used at all.

**Verified — implementer and reviewer independently.** Bare switch fails for all four;
`--reduced-tx-type-set=1` and `--use-intra-dct-only=1` encode normally.

**Shape of the safe fix.** Add `.IntegerValue = True` to all four. `BoolParam` then emits
`--switch=1` when ticked and `--switch=0` when unticked-from-a-ticked-default; here `DefaultValue`
is False, so an unticked box still emits nothing, which is right. No `.Options`, no key, nothing
persisted changes: `BoolParam` stores a boolean under `GetKey` = `.Switch`, and that is untouched.
This is the cheapest of the fifteen and it has no downside.

**Stanzas.** `aomenc.reduced-tx-type-set`, `aomenc.use-intra-dct-only`, `aomenc.use-inter-dct-only`,
`aomenc.use-intra-default-tx-only`. Each `When to change` says the box stops the encode and gives
the Custom-box spelling that works. All four have to be rewritten when this is fixed.

## 3. Color Primaries SMPTE170 is a name the build does not know — OPEN

**Code.** `AOMEnc.vb:563`. `.Options` holds thirteen names including `"SMPTE170"` at index 6, with
no `.Values`, so the emitted value is the option text lowercased.

**What the user sees.** Picking SMPTE170 stops the encode with
`Option color-primaries=smpte170: Invalid value 'smpte170'`. The other twelve entries work. The
build's own name for those primaries is `bt601`, which is already index 2 of the same list, so the
entry is both broken and redundant.

**Verified — implementer and reviewer independently.** All thirteen values put through the parse
probe; `smpte170` is the only refusal. All seventeen Transfer Characteristics values and all
fourteen Matrix Coefficients values were probed the same way and every one is accepted, so this is a
single bad entry, not a stale list like rav1e's.

**Shape of the safe fix.** `ShowOption(6, False)` plus a guarded reset to index 0 for a profile
sitting on it, per the trap above. Do **not** delete the entry from `.Options`: index 7 to 12
(`XYZ` through `EBU3213`) would all shift down by one and every saved profile past index 6 would
come back tagged with the wrong primaries — a silent colour change, which is worse than the loud
error it replaces.

**Stanza.** `aomenc.color-primaries`. Its `When to change` and the `smpte170` value note say the
entry is refused and point at BT601.

## 4. Force video mode can never send 1 — OPEN

**Code.** `AOMEnc.vb:531`. `New BoolParam With {.Switch = "--force-video-mode", .Text = "Force video mode", .Init = True, .IntegerValue = True}`.
`.Init = True` sets both `Value` and `DefaultValue` to True. aomenc's own default is **false**
(help line 160).

**What the user sees.** Nothing, which is the problem. Ticked — the state the box starts in —
matches `DefaultValue`, so `BoolParam.GetArgs` emits nothing and the encoder's default (off) stands.
Unticked emits `--force-video-mode=0`, which is also off. Both positions of the box give off; the
setting it names is unreachable from the dialog.

**Verified — implementer, reviewer confirmed by reading the code.** From `BoolParam.GetArgs` and
from the help's stated default. `--force-video-mode=1` and `=0` both encode, so the switch itself is
fine.

**Shape of the safe fix.** `.Init = False`. Ticked then differs from `DefaultValue` and emits
`--force-video-mode=1`; unticked matches and emits nothing, which is the encoder's default. Check
what `.Init = False` does to saved profiles first: `BoolParam.Value` persists only when it differs
from `InitialValue`, so a user who left the box alone stored nothing and will now see it unticked —
which is the state they were actually getting. A user who deliberately unticked it stored False, and
after the change False equals the new initial value, so the stored entry is dropped and the box
still reads unticked. **No encode changes for anybody**; only the displayed state stops lying.

**Stanza.** `aomenc.force-video-mode` states the whole defect and gives the Custom-box workaround.
It has to be rewritten when this is fixed.

## 5. Restoration cannot be switched back on in realtime mode — OPEN

**Code.** `AOMEnc.vb:283-289`, the `EnableRestoration` property: an `OptionParam` with
`.Init = 1` and two entries, `"Off (default in Realtime mode)"` and `"On (default in Non-realtime mode)"`.
`.Init = 1` makes On the `DefaultValue`, so it emits nothing.

**What the user sees.** With Realtime Quality Deadline ticked, the Restoration box reads On and the
loop restoration filter is off, because nothing is sent and aomenc's realtime default is off
(help line 117). The box says one thing and the encode does another. In good quality the two agree
by luck, both being on.

**Verified — implementer, reviewer confirmed by reading the code.** From `OptionParam.GetArgs` and
the help's per-mode defaults.

**Shape of the safe fix.** `.AlwaysOn = True`, so the control always emits `--enable-restoration=0`
or `=1` and the box becomes the truth in both modes. That is safe here in a way it was not for
rav1e's Tune: both entries are already meaningful, the emitted value for the current index is the
same as the encoder's good-quality default, so a good-quality encode is byte-identical before and
after; only a realtime encode changes, and it changes to what the box was already claiming. Do not
reach for `.Init = 0` instead: that would make Off the default and quietly turn the filter off for
every good-quality user.

**Stanza.** `aomenc.enable-restoration` states the defect and gives the Custom-box workaround.

## 6. `--skip` and `--limit` are emitted twice, and the second copy wins — OPEN

**Code.** `AOMEnc.vb`. Each decoder branch of `GetArgs` writes `--skip`/`--limit` for the run it is
building (L672-680 avs2pipemod, L689-697 vspipe, L706-715 ffmpeg, L723-731 `qs`, L739-747 `ffqsv`,
L757-765 `ffdxva`). Then the generic `Dim q = From i In Items Where i.GetArgs <> ""` at **L803**
emits the `Skip` and `Limit` parameters again, later on the same command line, so their values win.

**What the user sees.** With Chunks at 1 the two copies agree and the duplication is only untidy.
With Chunks above 1 **and** a non-zero Skip or Stop box, the pieces come out wrong, in two different
ways:

- **avs2pipemod and vspipe** (the default path) write no `--skip` in chunk mode at all — trimming is
  the pipe tool's job — so the late copy does not replace anything; it applies the user's skip
  *again*, on top of the pipe's own trim, pushing every chunk further into the material.
- **ffmpeg, `qs`, `ffqsv` and `ffdxva`** do write `--skip={startFrame}`, and the late copy replaces
  it, so every chunk starts at the same frame.

*This is the description the reviewer corrected: the implementer's first record said "replaces the
per-chunk values", which is true only of the second group.*

**Verified — implementer by reading `GetArgs`; reviewer independently by reading the same six
branches and L803.** No probe: reproducing it needs a chunked StaxRip run, not a bare encoder call.

**Shape of the safe fix.** Give `Skip` and `Limit` an `ArgsFunc` that returns Nothing, or add them
to the `IsCustom`-style exclusion the generic loop already applies, so the decoder branch stays the
only writer. Both are index-safe and key-safe: `NumParam` stores a double under `GetKey` =
`"--skip"` / `"--limit"`, and nothing here touches that. Test with Chunks at 2 and a non-zero Skip.

**Stanzas.** `aomenc.skip` and `aomenc.limit` both tell the user to leave the box at 0 when Chunks
is above 1, and say why. That advice becomes unnecessary when this is fixed.

## 7. A `NumParam` starting at 0 cannot express a real 0 — OPEN, and general

**Code.** `AOMEnc.vb`, about twenty Rate Control and AV1 Specific `NumParam`s declared with no
`.Init`, so `DefaultValue` is 0 and the box also starts at 0. `NumParam.GetArgs`
(`VideoEncoderCommandLine.vb:602-613`) emits only when `Value <> DefaultValue`.

**What the user sees.** A box showing 0 while the encoder is using something else, and no way to
send 0 from the dialog. The encoder's real defaults, read from its own `--verbose` dump:
undershoot-pct and overshoot-pct 25, buf-sz 6000, buf-initial-sz 4000, buf-optimal-sz 5000,
bias-pct 50, maxsection-pct 2000, max-q 63, the resize and superres denominators 8,
superres-qthresh 63, superres-kf-qthresh 32. So the CBR/VBR bias box reads 0, which would mean pure
CBR, while the encode runs at 50.

**Verified — implementer, reviewer reconciled every number against the same dump.** This is a shape
of `NumParam` rather than a typo, which is why it is one finding and not twenty.

**Shape of the safe fix.** Give each box an `.Init` equal to the encoder's own default, so the
displayed number is the number in force and the whole range including 0 becomes reachable. That
changes no command line: at the new `DefaultValue` nothing is emitted, exactly as now. Check saved
profiles per box — `NumParam.Value` persists only when it differs from `InitialValue`, so a user who
never touched the box stored nothing and will simply see the honest number. A user who typed a value
equal to the *new* default will have it dropped from the store, which is harmless.

**Stanzas.** Every affected stanza already names the encoder's real default and says the box's own 0
is never sent. Roughly twenty `When to change` fields have to be simplified when this is fixed.

## 15. Only one of the three PSNR entries can turn PSNR on — OPEN

*Numbered 15 because the reviewer found it after the first fourteen were recorded; it belongs beside
findings 4 and 5, whose shape it shares.*

**Code.** `AOMEnc.vb:409`.
`New OptionParam With {.Switch = "--psnr", .Text = "Show PSNR in status line", .Init = 1, .IntegerValue = True, .Options = {"0 - ...", "1 - ... (default)", "2 - ..."}}`.
`.Init = 1` makes index 1 the `DefaultValue`, so it emits nothing.

**What the user sees.** A three-entry dropdown of which **only entry 2 produces a PSNR line**.
Entry 1, where the box starts, emits nothing, and aomenc prints no PSNR unless it is asked. Entry 0
emits `--psnr=0`, which the encoder treats exactly as saying nothing. So two of the three entries
are indistinguishable from each other and from not having the control.

The `(default)` in aomenc's help line 19 is the trap: it marks the argument `--psnr` takes when
written **bare**, not the feature's default. The same help line says so — "takes default option when
arguments are not specified". This is the only aomenc switch whose help is worded that way.

**Verified — reviewer found it, implementer reproduced it.** Four-frame encode, the same clip each
time:

```
no --psnr    exit 0, no PSNR line
--psnr       exit 0, Stream 0 PSNR (Overall/Avg/Y/U/V) 34.418 ...
--psnr=0     exit 0, no PSNR line
--psnr=1     exit 0, Stream 0 PSNR ...
--psnr=2     exit 0, Stream 0 PSNR ..., preceded by "Warning: --psnr==2 and --psnr==1 will
             provide same results when input bit-depth == stream bit-depth"
--psnr=3     exit 0, "Warning: --psnr can take only 0,1,2 as values,falling back to default"
```

**Shape of the safe fix.** `.AlwaysOn = True` is the honest one: the control then always emits its
index and every entry means what it says. It changes what every existing user gets — a profile
sitting on index 1 would start sending `--psnr=1` and printing a score it does not print today —
but the change is a status line, not the encode, so unlike rav1e's Tune there is no hidden quality
shift. `.Init = 0` is the smaller alternative: entry 0 then emits nothing and entries 1 and 2 emit,
which is truthful and leaves the default silent, at the cost of a box whose first entry is a
do-nothing. Either way, keep the three entries in place and in order; nothing here needs `.Options`
touched, so the index trap does not bite.

Note for whoever writes it: with StaxRip's Bit Depth sending `--bit-depth=10` on every encode, an
8-bit source has input depth 8 against stream depth 10, so entries 1 and 2 genuinely differ there
and the encoder's warning does not fire.

**Stanza.** `aomenc.psnr` was rewritten on 2026-08-28 to state exactly this: its `When to change`
says only entry 2 turns the score on, and all three `Values` notes say what each entry really does.
It has to be rewritten when this is fixed.

---

# vvencFFapp — `Source/Encoding/VvencffappEnc.vb`

## 8. Every SIMD entry except Automatic stops the encode — OPEN

**Code.** `VvencffappEnc.vb:477`. An `OptionParam` with
`.Options = {"Automatic", "SCALAR", "SSE41", "SSE42", "AVX", "AVX2", "AVX512"}` and **no `.Values`**,
so `OptionParam.GetEmittedValue` (`VideoEncoderCommandLine.vb:683-687`) lowercases the option text.
vvencFFapp's SIMD parser is case-sensitive.

**What the user sees.** Picking anything but Automatic stops the encode before a frame is read, with
`ERROR: In function "string_to_x86_vext" ...: Invalid SIMD Mode string: "avx2"`. Six of seven
entries are unusable; the seventh works only because index 0 is `DefaultValue` and emits nothing.

**Verified — implementer and reviewer independently.** All six lower-case spellings refused;
`AVX2`, `SCALAR` and `SSE41` in capitals parse. `AVX512` in capitals is refused on this machine as
unsupported by the CPU (max AVX2), which is a separate and correct refusal.

**Shape of the safe fix.** Add
`.Values = {"", "SCALAR", "SSE41", "SSE42", "AVX", "AVX2", "AVX512"}` — the same length and the same
order as `.Options`, so no index moves and no profile is disturbed. Index 0 emits an empty value,
which `OptionParam.GetArgs` already handles (`String.IsNullOrWhiteSpace(v)` suppresses the
separator), and in any case index 0 is the `DefaultValue` and never reaches that line. Consider also
falling back gracefully when the CPU cannot do the level asked for, rather than stopping.

**Stanza.** `vvencffapp.simd` states the defect, gives every value note as refused, and points at
`--SIMD AVX2` in the Custom box.

## 9. Output Bit-Depth does nothing — OPEN *(reviewer did not reproduce)*

**Code.** `VvencffappEnc.vb:480`, an `OptionParam` on `--OutputBitDepth`.

**What the user sees.** A control captioned "Output Bit-Depth" that has no effect on the video. In
vvenc, `--OutputBitDepth` is the depth of the **reconstructed YUV file** written by `--ReconFile`
(full help lines 66-67), and StaxRip never passes `--ReconFile`. The depth the codec actually works
at is `--InternalBitDepth`, default 10 (full help lines 279-280), which this dialog does not offer
at all.

**Verified — implementer only.** The same clip encoded with `--OutputBitDepth 8`, with `10`, and
with the switch absent produced three byte-identical bitstreams (SHA-256 identical). **The reviewer
did not re-run this**; it confirmed only that `automatic` is rejected and that 8, 10 and 12 parse,
and accepted the conclusion because the encoder's own help describes the switch as the `--ReconFile`
depth. Re-run the three-way hash comparison before acting on this finding.

**Shape of the safe fix.** Repoint the control at `--InternalBitDepth`, which is what a user reading
"Output Bit-Depth" expects. That moves the store key, because the control has `.Name = "OutputBitDepth"`
— so the key is `"OutputBitDepth"` and stays put if `.Name` is left alone, which it should be.
Changing only `.Switch` while keeping `.Name` is therefore key-safe. The `.Options` array
`{"Automatic", "8", "10", "12"}` maps onto `--InternalBitDepth` unchanged, so no index moves either.
Note that `automatic` is refused by the parser for both switches and works only because it is index
0 and never sent.

**Stanza.** `vvencffapp.output-bit-depth` says plainly that the box does nothing and names
`--InternalBitDepth` as the switch the reader probably wants.

## 10. LookAhead can only ever break the encode — OPEN *(reviewer did not reproduce)*

**Code.** `VvencffappEnc.vb:491`, a `NumParam` on `--LookAhead` with `.Config = {-1, 1, 1, 0}` and
`.Init = -1`.

**What the user sees.** Setting the box to 1 stops the encode in every mode this dialog can produce:

- Quantizer mode: `Parameter Check Error: Look-ahead encoding is not supported when rate control is disabled`.
- Bitrate and Two Pass mode: `Parameter Check Error: ... is not supported for two-pass rate control`.

vvenc allows look-ahead only with **one-pass** rate control, and StaxRip never sends
`--NumPasses 1`: Bitrate mode sends only `--TargetBitrate`, and the encoder then chooses two passes
by itself (`RateControl:1 Passes:2 Pass:-1`), while Two Pass mode sends `--NumPasses 2` explicitly.
Setting the box to 0 changes nothing.

**Verified — implementer only.** Short encodes produced both refusals;
`--NumPasses 1 --TargetBitrate 500k --LookAhead 1` was accepted and reported `LookAhead:1`; and
`-1`, `0` and omitting the switch gave three byte-identical bitstreams. **The reviewer did not
re-run this** — the refusals need a real input, which a parse-only probe cannot reach — and noted
only that `--LookAhead 1` does parse at the option level. Re-run the four encodes before acting.

**Shape of the safe fix.** Either give Bitrate mode a one-pass form that sends `--NumPasses 1`, in
which case LookAhead becomes usable there, or hide the control until it can be. The `NumParam` has
`.Name = "LookAhead"`, so its key is `"LookAhead"` and nothing here needs to move it.

**Stanza.** `vvencffapp.lookahead` has `Used when: Never, as this dialog stands`, states both
refusals verbatim and gives the Custom-box combination that works.

## 11. Chunked encoding sends no frame range at all — OPEN

**Code.** `VvencffappEnc.vb:658-661`. Inside `GetArgs`, the `Else` branch of `If isSingleChunk Then`
— the branch that would write `--FrameSkip {startFrame} --FramesToBeEncoded {endFrame - startFrame + 1}`
for a chunk — is commented out.

**What the user sees.** With Chunks above 1, the encoder is told nothing about which part of the
video this process should encode. With the AviSynth/VapourSynth decoder it still works, because
avs2pipemod's `-trim` and vspipe's `--start/--end` cut the stream before it reaches the encoder. With
a hardware decoder, or the ffmpeg pipe, nothing cuts anything: **every chunk encodes the whole
video**, and the muxer then joins N copies of the film together. No error, no warning.

**Verified — implementer and reviewer independently, both by reading the code.** The comment markers
are at L658-661 in the current file.

**Shape of the safe fix.** Uncomment the branch, or better, fix finding 12 first so the case cannot
arise. Nothing persisted is involved.

**Stanzas.** `vvencffapp.frame-skip` and `vvencffapp.frames-to-be-encoded` both say the switch is
sent only when Chunks is 1, and `frame-skip` says the cutting works only through avs2pipemod or
vspipe.

## 12. Neither encoder has SVT-AV1's chunk guard — OPEN

**Code.** `SvtAv1Enc.CanChunkEncode` (`SvtAv1Enc.vb:332-334`) defers to `GetChunkEncodeRefusal`
(`SvtAv1Enc.vb:337-359`), which refuses to chunk when the decoder is not the script, when the pipe
is ffmpeg, or when the muxer cannot join the pieces, and writes the reason into the log.
`AOMEnc.CanChunkEncode` (`AOMEnc.vb:110-112`) and `VvencffappEnc.CanChunkEncode`
(`VvencffappEnc.vb:113-115`) both `Return Chunks > 1` and nothing else.

**What the user sees.** For AOMEnc, a chunked run with a hardware decoder does work, because its
decoder branches write `--skip`/`--limit` per chunk — until finding 6 spoils it. For vvencFFapp it
produces the duplicated-video file of finding 11. In both cases a muxer that cannot join the pieces
leaves the user with N part-files and no output.

**Verified — implementer and reviewer independently, both by reading all three
`CanChunkEncode` implementations.**

**Shape of the safe fix.** Lift `GetChunkEncodeRefusal` to `BasicVideoEncoder`, or copy it, and have
both encoders defer to it as SVT-AV1 does. The fall-back to a single encode is already the safe
behaviour and is what the shared help text describes.

**Stanza.** `staxrip.chunks`, which all three dialogs display. It was corrected on 2026-08-28 to say
that **only SVT-AV1 checks**, and that AOMEnc and vvencFFapp will spoil the output silently with the
wrong decoder or pipe. That sentence comes out when this is fixed.

---

# ffmpegEnc — `Source/Encoding/ffmpegEnc.vb`

Found while assessing whether ffmpegEnc could be documented. It was **skipped**: its `Codec`
dropdown selects one of 24 different encoders and every other control is gated on that choice, so a
static stanza per control could not say what any control does. These two defects are part of why.

## 13. Five `VisibleFunc` predicates can never be true — OPEN

**Code.** `ffmpegEnc.vb:276` (`Speed`), `:277` (`CPU Used`), `:278` (`AQ Mode`), `:287`
(`Tile Columns`), `:288` (`Frame Parallel`), `:289` (`Auto Alt Ref`), `:290` (`Lag In Frames`). Each
compares `Codec.OptionText` against `"AV1"`, `"VP8"` or `"VP9"`. `OptionParam.OptionText` returns
`Options(Value)` verbatim (`VideoEncoderCommandLine.vb:666-669`), and the option texts in question
are `"AOM-AV1"`, `"VP | VP8"` and `"VP | VP9"`.

**What the user sees.** Seven controls that never appear, whatever codec is selected.

**Verified — implementer by reading the code; reviewer independently, and confirmed `OptionText`'s
implementation.**

**Shape of the safe fix.** Compare `Codec.ValueText` against the ffmpeg encoder name
(`libaom-av1`, `libvpx`, `libvpx-vp9`) rather than the display text, which is what the h264_nvenc
and utvideo predicates in the same list already do. `.Options` is untouched, so no index moves.

**Stanza.** None — ffmpegEnc has no help file, and `W1 Source/Encoding/ffmpegEnc.vb no help file`
in the validator report is the record of that.

## 14. AV1, VP8 and VP9 quality encodes emit the wrong switch — OPEN

**Code.** `ffmpegEnc.vb:428-451`, `GetQualityArgs`. Line 433 tests
`Codec.OptionText.EqualsAny("VP8", "VP9")` and line 435 tests
`Codec.OptionText.EqualsAny("x264", "x265", "AV1")`. For the same reason as finding 13, none of
`"AOM-AV1"`, `"VP | VP8"` or `"VP | VP9"` matches.

**What the user sees.** A quality-mode encode with libaom-av1, libvpx or libvpx-vp9 falls through to
the `Else` branch and gets `-q:v <n>` instead of `-crf <n>` — or, for the two VP codecs,
`-crf <n> -b:v 0`. `-q:v` is not a CRF control for those encoders, so the quality number the user
typed does not do what the box says.

*The implementer's first record named only the AV1 branch; the reviewer added the VP8/VP9 one,
which fails identically.*

**Verified — implementer by reading the code (AV1 branch); reviewer independently, adding the VP
branch and confirming `OptionText`.**

**Shape of the safe fix.** As finding 13: match on `Codec.ValueText`. Fix both findings together, in
one pass over the file, since they share a cause.

**Stanza.** None, as above.

---

## Also noted, not defects

- **`aomenc.i420` is inert.** `AOMEnc.vb:424`, `.Init = True` with no `.IntegerValue` and no
  `.NoSwitch`, so ticked emits nothing and unticked returns an empty string that the command-line
  builder filters out. The box does nothing in either position. It is harmless — StaxRip always
  pipes Y4M, whose header carries the format, so none of the four input-format boxes can matter —
  and fixing it would only make a useless switch reachable. Stated in `aomenc.i420`.
- **aomenc's `--tune` dropdown is missing the three tunes this build supports.** Part of finding 1's
  fix rather than a defect of its own.
- **aomenc's `--deltaq-mode` dropdown stops at 4** while the build accepts 5 (HDR video) and 6
  (Variance Boost), and **`--enable-cdef` is a checkbox** while the build accepts 0 to 3. Both are
  missing capability rather than broken behaviour; both are reachable from the Custom boxes and both
  are stated in their stanzas.
- **AOMEnc has no all-passes Custom box**, only `CustomFirstPass` (`AOMEnc.vb:345`) and
  `CustomSecondPass` (`AOMEnc.vb:354`), unlike `VvencffappEnc.vb:435` and `SvtAv1Enc.vb:1413`. Not a
  defect — two boxes are enough for a two-pass encoder — but it made the shared `staxrip.custom`
  stanza wrong for this dialog until it was corrected on 2026-08-28, and it is why twelve aomenc
  stanzas say "both Custom boxes" rather than "the Custom box".
