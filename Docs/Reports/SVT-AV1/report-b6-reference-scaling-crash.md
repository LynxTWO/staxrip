# Reference scaling (`--resize-mode` 1, 2 and 4) crashes with an access violation in most runs

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11.

## Reproduce

```
ffmpeg -f lavfi -i testsrc2=size=640x480:rate=25 -frames:v 24 -pix_fmt yuv420p clip.y4m

SvtAv1EncApp --rc 0 --crf 35 --preset 8 --resize-mode 1 --resize-denom 16 \
             --progress 0 -i clip.y4m -b out.ivf
```

Run it several times — it does not fail every time (see below).

## Observed

Exit code `-1073741819` = `0xC0000005`, an access violation. The only thing printed beforehand is
the expected `Svt[warn]: TPL will be disabled when reference scalings (resize) is enabled!`.

Across every run that actually scaled frames **between** keyframes (excluding runs rejected at
configuration time, runs where nothing was scaled, and the superres+resize combination):

| mode | runs | crashes |
| --- | --- | --- |
| `--resize-mode 1` (fixed) | 28 | 18 |
| `--resize-mode 2` (random) | 2 | 2 |
| `--resize-mode 4` (event-driven) | 13 | 11 |
| **total** | **43** | **31** |

Keyframe-only scaling — `--resize-kf-denom` set with `--resize-denom` left at 8 — finished in all
5 runs tried (108088, 106699, 107099 for kf 16; 119565 for kf 9; and one more by the second
pass).

**The runs that finish are not repeatable.** `--resize-mode 1 --resize-denom 16` crashed in one
probe and finished three times in another (54157, 54110, 54263 bytes — three different files).
With `--lp 1` it finished (58827); with `--lp 2` it crashed. `--resize-denom 16 --resize-kf-denom 8`
finished at 51190, 54229 and 53161 bytes on the 640x480 clip and crashed on a 160x120 clip.

Individual crashing lines, verbatim:

```
c resize-mode 1 denom 16   exit=-1073741819  bytes=12288
c resize-mode 1 denom 12   exit=-1073741819  bytes=0
c resize-mode 1 denom 9    exit=-1073741819  bytes=0
c resize-mode 2            exit=-1073741819  bytes=0     (twice; warns "designed for test and
                                                          debugging purpose" first)
c resize-mode 4 event 0    exit=-1073741819  bytes=4096
c resize-mode 4 VBR        exit=-1073741819  bytes=0
c resize-mode 1 denom 16 low delay  exit=-1073741819  bytes=12288
a resize-mode 1 denom 16   exit=-1073741819  bytes=0     (160x120 clip)
```

**It fails unsafely.** Several crashes leave a 4096- or 12288-byte partial `.ivf` behind, so a
caller that checks only whether an output file exists sees a result.

**`--resize-mode 4` has no range check on the list values.** A denominator of 7 or 17 inside
`--frame-resz-denoms` crashes, where the same value passed to `--resize-denom` is rejected cleanly
(`Invalid resize-denom 7, should be in the range [8 - 16]`, exit 1). Upstream's own example lists
from `Docs/Appendix-Reference-Scaling.md` crashed, twice.

## Runs and independent reproduction

This was run twice, independently, on the same machine. The first pass ran the 43-run sweep tallied above
across two probe scripts; the second classified all 72 candidate lines from those outputs by hand
and confirmed each tally, then ran the minimal case again independently:

```
plain (baseline)               exit=0            bytes=4526
resize-mode 1 denom 16 run1    exit=-1073741819  bytes=0
resize-mode 1 denom 16 run2    exit=-1073741819  bytes=0
resize-mode 1 denom 16 kf 16   exit=0            bytes=8576
resize-mode 1 kf 16 only       exit=0            bytes=9072
```

Note that the second pass's `denom 16 + kf 16` run *finished* where the first pass's crashed.
That disagreement is itself the point: the same command does not do the same thing twice.

## Expected

Reference scaling is a documented feature with its own upstream appendix. It should either work or
be rejected. 31 crashes in 43 runs across the three scaling modes, with partial output left
behind, is what I would expect to be told about rather than to find.

## Ruled out

- Not a bad configuration: `--resize-mode 5` and `--resize-denom 7`/`17` are refused cleanly with
  `Invalid resize-mode 5, should be in the range [0 - 4]` and the matching denom message, exit 1.
  The crashing runs are all in-range.
- Not the input: the same clip encodes cleanly with `--resize-mode 0`, and `--resize-denom 16`
  or `--resize-kf-denom 16` on their own with `--resize-mode 0` produce byte-identical output to
  plain (105036, `7204EFA9FD`), i.e. they are correctly ignored.
- Not threading alone: `--lp 1` finished one run that crashed at the automatic level, but `--lp 2`
  crashed, so pinning the level of parallelism is not a workaround.
- Not mode 3: `--resize-mode 3` never crashed, but it also never scaled anything — outside 1-pass
  CBR low delay it warns `Resize dynamic mode only works at 1-pass CBR low delay mode!` and
  produces output byte-identical to plain, and inside CBR at 300 and 50 kbps it produced output
  byte-identical to plain CBR. That is a separate question and I am not reporting it as a defect.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU or OS.
- No debugger was attached; no faulting address, module or stack was captured, for any mode.
- Real source material — both clips are synthetic (`testsrc2` 640x480 and a 160x120 generated
  gradient).
- Whether the outputs of the runs that *do* finish are correct. I checked with `ffprobe` that
  frames came back at the scaled size (e.g. 320x240 for denom 16 on both denominators, and
  first-frame-scaled-then-full-size for keyframe-only scaling), but I did not check quality.
