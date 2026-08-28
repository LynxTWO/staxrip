# rav1e: StaxRip code defects

Found while writing `Docs/OptionHelp/rav1e.md` (branch `worktree-option-help`, 2026-08-28). Three
defects in `Source/Encoding/Rav1e.vb`; one is fixed here and two are left for a pass of their own.
Each finding names the code, what the user sees, how it was verified, and the stanza that states the
behaviour to the user — that text has to change when the code or the bundled build does.

Bundled encoder: `rav1e 0.8.0 (p20250624-3-g564ae3b) (release)` at
`C:\StaxRip\Apps\Encoders\rav1e\rav1e.exe`.

## How everything below was verified

No encodes were run. Every claim comes from running the bundled binary with the switch or value and
**no input file**, so only clap's argument parser executed and the process exited on a usage error
before opening anything. That gives a clean three-way oracle:

| Message | Meaning |
| --- | --- |
| `error: unexpected argument found` | the switch name is unknown to this build |
| `error: invalid value for one of the arguments` | switch known, value rejected |
| `error: one or more required arguments were not provided` | switch and value both accepted; only INPUT/OUTPUT are missing |

The accepted value names were confirmed a second way, independent of the probe: the ASCII string
table inside `rav1e.exe` holds them in enum order, and the four `docs.rs/rav1e/0.8.0/rav1e/prelude/`
colour pages list the same names. All three sources agree.

## 1. `--content_light` — FIXED on this branch

**Code.** `Rav1e.vb`, the `Light` and `MaxFALL` properties. `Light` carried
`.Switch = "--content_light"` and an `ArgsFunc` emitting `"--content_light ""cll,fall"""`; `MaxFALL`
carried `.Switches = {"--content_light"}` and feeds `Light`'s `ArgsFunc`. rav1e spells it
`--content-light`, with a hyphen (bundled `--help` lines 154-155).

**What the user saw.** Any value above 0 in Content Light *or* Maximum FALL put an unknown switch on
the command line, and the encode died on an argument error before a frame was coded. The two boxes
were unusable, and the only route to HDR light-level metadata was the Custom box. Every other
encoder in the tree already spells it correctly — `SvtAv1Enc.vb`, `SvtAv1EssentialEnc.vb`,
`SvtAv1HdrEnc.vb`, `SvtAv1PsyexEnc.vb` and `SvtAv1TritiumEnc.vb` all use `--content-light` — so this
was a rav1e-only typo, not a convention.

**Verified.** `rav1e --content_light 100,50` → `unexpected argument found`;
`rav1e --content-light 100,50` → `one or more required arguments were not provided`, i.e. the switch
and the value both parsed. After the fix, `--content-light "1000,400"` parses.

**The fix, and the store-key trap it had to avoid.** `.Switch`, the `ArgsFunc` literal and
`.Switches` now all say `--content-light`. That alone would have been a silent regression:
`CommandLineParam.GetKey` falls through to `.Switch` when there is no `.Name`, so `Light` persisted
under `"--content_light"`, and `MaxFALL`, having only `.Switches`, persisted under
`Text + HelpSwitch` = `"Maximum FALL--content_light"` (`Add` copies the primary switch into
`HelpSwitch`). Correcting the switch moves both keys, so a saved profile's numbers would have
reverted to 0 — and the failure mode would have changed from a loud argument error to a silently
missing metadata block. Both controls therefore now carry a `.Name` pinning the key to the exact
string profiles already hold, the same disambiguation `SvtAv1Enc` uses for `PipingToolAVS` /
`PipingToolVS` and for `PassesCBR`. A comment above each property says why the name looks wrong.

**Stanzas.** `rav1e.content-light.max-cll` and `rav1e.content-light.max-fall` were rewritten in the
same commit: they no longer say "do not use these two boxes" and no longer point at the Custom box,
and `max-cll` gains an Example showing the switch StaxRip now sends. `rav1e.mastering-display` never
mentioned the defect and is unchanged.

**Whole-file switch audit.** Every switch name `Rav1e.vb` can emit was put through the same probe.
`--content_light` was the only unknown one:

```
--bitrate  --first-pass  --keyint  --limit  --low-latency  --mastering-display  --matrix
--min-keyint  --primaries  --quantizer  --range  --second-pass  --speed  --threads
--transfer  --tune  -y  -o        all accepted by the parser
--content_light                   unexpected argument  (now --content-light, accepted)
```

`--matrix`, `--primaries`, `--range`, `--transfer` and `--tune` answered "switch known, value
rejected" because the probe passed them the placeholder value `1`; the switch names themselves are
right. Their *values* are finding 2.

## 2. Stale colour value names in Primaries, Matrix and Transfer — OPEN

**Code.** `Rav1e.vb`, the `Prime`, `Matrix` and `Transfer` properties. Each is an `OptionParam` with
an `.Options` list and no `.Values`, so `OptionParam.GetEmittedValue` sends the option text
lowercased with spaces removed. The lists hold rav1e's *older* enum names; 0.8.0 renamed most of
them.

**What the user sees.** Picking one of the renamed entries emits a value this build refuses, and the
encode stops on an argument error before it starts — the same failure as finding 1, from a dropdown
that looks perfectly ordinary. 27 of the 43 entries across the three lists are affected. The default
entry of each list is Unspecified, which emits nothing, so a user who never touches the VUI page
never meets this.

**Verified.** Each of the 43 values was put through the parser probe, and each replacement name was
probed as well. What reaches the encoder today:

| Control | Works | Refused → the name 0.8.0 wants |
| --- | --- | --- |
| Primaries (12) | `bt709`, `unspecified`, `bt470m`, `bt470bg`, `bt2020` | `st170m`→`BT601`, `st240m`→`SMPTE240`, `film`→`GenericFilm`, `st428`→`XYZ`, `p3dci`→`SMPTE431`, `p3display`→`SMPTE432`, `tech3213`→`EBU3213` |
| Matrix (14) | `identity`, `bt709`, `unspecified`, `bt470bg`, `ycgco`, `ictcp` | `bt470m`→`FCC`, `st170m`→`BT601`, `st240m`→`SMPTE240`, `bt2020nonconstantluminance`→`BT2020NCL`, `bt2020constantluminance`→`BT2020CL`, `st2085`→`SMPTE2085`, `chromaticityderivednonconstantluminance`→`ChromatNCL`, `chromaticityderivedconstantluminance`→`ChromatCL` |
| Transfer (17) | `unspecified`, `bt470m`, `bt470bg`, `linear`, `srgb` | `bt1886`→`BT709`, `st170m`→`BT601`, `st240m`→`SMPTE240`, `logarithmic100`→`Log100`, `logarithmic316`→`Log100Sqrt10`, `xvycc`→`IEC61966`, `bt1361e`→`BT1361`, `bt2020ten`→`BT2020_10Bit`, `bt2020twelve`→`BT2020_12Bit`, `perceptualquantizer`→`SMPTE2084`, `st428`→`SMPTE428`, `hybridloggamma`→`HLG` |

HDR10 is the practical loss: `perceptualquantizer` is the PQ curve and it is one of the refused
entries, so an HDR10 tag cannot be set from the dialog at all.

**Shape of the safe fix.** *Rename the option strings in place.* This is the unusual case where the
`ShowOption`-and-reset pattern is not needed, because the three StaxRip lists are positionally
identical to rav1e's enums — 12, 14 and 17 entries against 12, 14 and 17 variants, in the same order
(confirmed against both the binary's string table and the docs.rs enum pages). Every stale name maps
one-to-one onto the correct name in the *same slot*, so a rename changes no index: a profile holding
Primaries index 4 goes from `ST170M`, which fails, to `BT601`, which is the same colour space and
works. That is strictly better than hiding the entries, which would leave HDR10 unreachable except
through the Custom box.

**Checks it needs first.**

1. *Store keys.* `Prime`, `Matrix` and `Transfer` each carry `.Switch` and no `.Name`, so `GetKey`
   returns `"--primaries"`, `"--matrix"` and `"--transfer"`. A survey of all 19 controls in
   `Rav1eParams` found **no shared store key**, so nothing here repeats the `PassesCBR`/`PassesVBR`
   collision. Worth re-running the survey if the file gains controls: the keys are `Mode`→`"Mode"`,
   `Bitrate`→`"Bitrate"`, `Passes`→`"Passes--first-pass"`, `Custom`→`"Custom"` (all falling through
   to `Text` or `Text + HelpSwitch`), and `.Switch` for the rest. A rename of `.Options` does not
   move any of these keys, since none of them is derived from the option text.
2. *`ImportCommandLine`.* An `OptionParam` with no `.Values` is matched by its option text, so
   renaming changes which command lines StaxRip can read back. That is the right direction — it
   should read what rav1e actually emits — but confirm the matcher before the change, and check
   whether any profile or preset shipped with StaxRip stores a rav1e command line as text.
3. *Nothing else reads the strings.* `%--primaries%`-style target-file-name macros expand the
   emitted value; `Rav1eParams` declares no target-file-name control, so no name pattern in the wild
   can depend on the old spellings from this dialog.

**Range needs no change.** `Range`'s three entries are `Unspecified`, `Limited`, `Full` against
rav1e's two, `Limited` and `Full`. The extra entry is index 0 and is also StaxRip's default, so it
emits nothing and rav1e's own default (limited) applies — a deliberate "send nothing" entry, not a
stale name. Leave it.

**Stanzas.** `rav1e.primaries`, `rav1e.matrix` and `rav1e.transfer` carry a `Values` note for every
entry saying whether it reaches the encoder and, when it does not, which name to put in the Custom
box. All three `When to change` fields name the working entries and point at the Custom box. **All
of that text has to be rewritten when this is fixed** — after a rename the notes become wrong in the
most misleading direction, telling the user an entry fails when it now works.

## 3. Tune cannot select PSNR — OPEN

**Code.** `Rav1e.vb`, the `Tune` property: `.Options = {"PSNR", "Psychovisual"}`,
`.Values = {"psnr", "psychovisual"}`, and **no `.Init`**, so `DefaultValue` is 0.
`OptionParam.GetArgs` emits only when `Value <> DefaultValue OrElse AlwaysOn`, and `AlwaysOn` is
False.

**What the user sees.** Selecting PSNR — index 0, which equals `DefaultValue` — sends no `--tune` at
all, and rav1e's own default is Psychovisual (bundled `--help` line 120: `[default: Psychovisual]`).
So the dialog offers two entries that produce the same encode, and the one labelled PSNR gives
Psychovisual. Nothing fails; the setting is simply inert, which is worse than a visible error.

**Verified.** From the code path above, and from the bundled help's stated default. Both values are
accepted by the parser, so `--tune psnr` in the Custom box is a working escape hatch today.

**Shape of the safe fix.** Add `.Init = 1` to `Tune`, making Psychovisual the dialog's default as
well as rav1e's. Index 0 then differs from `DefaultValue` and emits `--tune psnr`; index 1 matches
the default and emits nothing, which still yields Psychovisual. Both entries become truthful with no
change to the list's length or order.

Do **not** reach for `.AlwaysOn = True` instead. It would make a profile sitting on index 0 start
sending `--tune psnr`, changing the encode from Psychovisual to PSNR for every existing user without
telling them — a quality change disguised as a bug fix.

**Checks it needs first.**

1. *Store key.* `Tune` has `.Switch = "--tune"` and no `.Name`, so `GetKey` is `"--tune"`, shared
   with nothing (see the survey in finding 2).
2. *What `.Init = 1` does to saved profiles.* `OptionParam.Value` persists only when the value
   differs from `InitialValue`, and `InitialValue` is whatever the constructor set. Under the
   current code a user who explicitly picked PSNR (0) stored nothing, because 0 was the initial
   value; a user who picked Psychovisual (1) stored 1. After `.Init = 1`: the first user's dialog
   comes back on Psychovisual, the second's stays on Psychovisual. **No encode changes** — both were
   getting Psychovisual all along — and only the displayed entry moves, from a label that was lying
   to one that is not. Confirm this reading against a real profile before committing.
3. Consider whether the dialog should say anything about the swap, since a user who deliberately
   chose PSNR will find Psychovisual selected next time. It is the setting they were actually
   getting, but it will look like StaxRip changed their mind for them.

**Stanza.** `rav1e.tune` states the defect in full today: its `When to change` says both entries give
the same encode and points at `--tune psnr` in the Custom box, and its two `Values` notes say the
PSNR entry is never sent. **All of it has to be rewritten when this is fixed.**

## Also noted, not a defect worth a finding

`Rav1e.QualityMode` (`Rav1e.vb`) returns `Params.Mode.OptionText.EqualsAny("Quality")`, but `Mode`'s
entries are `Speed` and `Bitrate`, so it is always False and StaxRip treats rav1e as a bitrate
encoder in both modes. The visible consequence is mild: the main window's size and bitrate boxes stay
live in Speed mode and write into `Params.Bitrate`, which Speed mode does not send, and Comp. Check
stays enabled (`VideoEncoder.IsCompCheckEnabled` is `Not QualityMode`). Nothing breaks, and the
user-facing half is already stated in `rav1e.mode`. Fixing it means deciding what "quality mode"
should mean for an encoder whose quality control is a quantizer that is also live in bitrate mode,
which is a design question rather than a typo.
