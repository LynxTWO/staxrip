# An unparseable `--mastering-display` value spins the app at 100 % of a core forever,
# before the input is opened

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does. See "What I read in the source"
below: the code I read was the upstream v4.2.0 source, which suggests this is not fork-specific,
but I did not confirm that by running a stock binary.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11.

## Reproduce

The shortest case needs no input file at all:

```
SvtAv1EncApp --mastering-display hello
```

It never returns. With a real input and a 20-second guard:

```
ffmpeg -f lavfi -i testsrc2=size=160x120:rate=25 -frames:v 24 -pix_fmt yuv420p clip.y4m

SvtAv1EncApp --mastering-display "hello" \
             --preset 8 --rc 0 --crf 35 --lp 1 --progress 0 -i clip.y4m -b out.ivf
```

A well-formed string with a space in the wrong place hangs identically:

```
SvtAv1EncApp --mastering-display "G(0.17, 0.797) B(0.131,0.046)R(0.708,0.292)WP(0.3127,0.329)L(1000,0.005)" \
             --preset 8 --rc 0 --crf 35 --lp 1 --progress 0 -i clip.y4m -b out.ivf
```

(The space after the comma is fine. The space between `)` and `B` is what does it.)

## Observed

```
TIMED control: StaxRip string  exit=0                                 bytes=16303
      side_data_type=Mastering display metadata green_x=11141/65536
      min_luminance=82/16384 max_luminance=256000/256
TIMED hello                    HUNG, killed after 20 s (cpu 19.3 s)   bytes=0
TIMED no L() part              exit=0                                 bytes=16275   (no metadata)
TIMED L(max<min)               exit=0                                 bytes=16303   (written as given)
TIMED x above 1                exit=0                                 bytes=16303
      Svt[warn]: Invalid mastering display info will be clipped to 0.0 to 1.0
TIMED empty string             exit=0                                 bytes=16275
TIMED spaces inside            HUNG, killed after 20 s (cpu 19.2 s)   bytes=0
```

**It burns a core.** 19.3 s of CPU in 20 s of wall time — a busy loop, not a deadlock. An
unguarded run reached 13 minutes of CPU before I killed it.

**It happens before the input is opened.** With no `-i` at all, the well-formed string exits
immediately with `Invalid parameter '-i'`, while `--mastering-display hello` never reaches that
check. So the argument parse itself is where it spins, and no amount of input validation
downstream can save a caller from it.

Related, and arguably a second bug in the same parser: a string that is well-formed but has no
`L(...)` part (`G(...)B(...)R(...)WP(...)`) exits 0 and writes **no mastering display metadata at
all** — the good tokens that were parsed are silently discarded, with no warning.

## What I read in the source

This part is derived, not observed. `svt_aom_parse_mastering_display` in
`Source/Lib/Globals/metadata_handle.c` (upstream v4.2.0, lines ~173-236, fetched from the
AOMediaCodec repository) walks the string character by character:

```c
while (md_str && *md_str) {
    switch (*md_str) {
    case 'G': case 'g': md_str = parse_double(md_str + 1, &gx, &gy); break;
    ...
    case 'W': case 'w': md_str = parse_double(md_str + 2, &wx, &wy); break;
    default: break;                 /* does not advance md_str */
    }
}
```

The `default:` branch does not advance the pointer, so any character outside `G B R W L` (either
case) at a token boundary is an infinite loop. That accounts for both observed hangs: `hello`
starts on `h`, and the space between `)` and `B` in the well-formed string is likewise not a token
character. `parse_double` returning NULL merely ends the loop, which accounts for the silent
discard when `L(...)` is missing.

**What I did not do:** I did not build a patched binary, attach a debugger, or otherwise confirm
that the shipped binary executes this code. I did check that the binary contains no `sscanf`
format string for this option (the only `--mastering-display`-related strings in it are help
text), which is at least consistent with a hand-written scanner. Patman's fork may carry changes
here that I have not seen. Treat the source reading as an explanation that fits the evidence, not
as a verified diagnosis.

## Runs and independent reproduction

It was hit twice, independently, on the same machine. The first pass hit it as an unguarded run that
never returned after 13 minutes of CPU and had to be killed, then re-ran the whole string matrix
above under a 20-second guard. The second reproduced it independently under a 30-second cap in the
no-input form: the well-formed string exited 1 immediately with `Invalid parameter '-i'`, while
`--mastering-display hello` was still spinning at 28.9 s of CPU when killed. Every attempt with an
unparseable value hung; no attempt with one ever completed.

## Expected

An unrecognised character should end the parse with a diagnostic and a non-zero exit, the way
`--content-light abc` already does (`Svt[warn]: Invalid cll provided`) and the way
`--chroma-sample-position foo` does (`Invalid parameter 'chroma-sample-position' with value
'foo'`). A one-character typo in a metadata string should not be able to wedge the process.

## Ruled out

- Not input-dependent: it hangs with no `-i` at all.
- Not a threading effect: reproduced with `--lp 1`.
- Not a general option-parsing problem: every other malformed value tried in the same colour
  block (`--color-primaries 99`, `--chroma-sample-position foo`, `--content-light abc`,
  `--content-light 1000` with one number) returns immediately with a message.
- Not "any unusual mastering-display value": out-of-range coordinates are handled correctly
  (`Invalid mastering display info will be clipped to 0.0 to 1.0`), and min/max luminance reversed
  is written as given. Only unrecognised characters at a token boundary hang.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU or OS.
- Longer than 30 seconds under a guard (13 minutes unguarded, once).
- Whether Patman's fork sources differ from upstream v4.2.0 in this file.
- I did not enumerate which characters hang and which do not, beyond the two cases above.
