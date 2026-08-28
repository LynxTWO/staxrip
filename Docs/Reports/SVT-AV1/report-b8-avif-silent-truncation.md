# `--avif 1` on a multi-frame input silently encodes only 3 frames and exits 0; with VBR it hangs

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11.

## Reproduce

```
ffmpeg -f lavfi -i testsrc2=size=640x480:rate=25 -frames:v 24 -pix_fmt yuv420p clip.y4m

SvtAv1EncApp --rc 0 --crf 35 --preset 8 --avif 1 --progress 0 -i clip.y4m -b out.ivf
echo "exit: $?"
ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames out.ivf
```

## Observed — part 1: silent truncation

```
Svt[warn]: TPL is disabled for all-intra coding
Encoding
Svt[error]: AVIF flag is specified, but more than 3 frames were sent.
            This will not produce an AVIF image sequence (avis)!
SUMMARY: Total Frames 3
```

Exit code **0**. `ffprobe` reports 3 frames in the output; the same clip without `--avif 1` gives
24. So the encoder prints `Svt[error]`, discards 21 of the 24 input frames, and then reports
success. Any caller that checks the exit code — which is the normal thing to do — treats a
3-frame file as a completed 24-frame encode.

The boundary is exactly 3: `--frames 3` produces no error at all; `--frames 4` produces the error
and 3 frames of output.

## Observed — part 2: hang with VBR

```
SvtAv1EncApp --rc 1 --tbr 300 --preset 8 --avif 1 --progress 0 -i clip.y4m -b out.ivf
```

Never returns. Under a 20-second guard:

```
c avif VBR frames 1 (20 s limit)     finished=False  cpu=0.05  bytes=0
c avif VBR 24 frames (20 s limit)    finished=False  cpu=0.09  bytes=16384
c plain VBR (20 s limit, control)    finished=True   cpu=0.62  bytes=127490
c avif VBR lp 1 frames 1 (20 s limit) finished=True  cpu=0.02  bytes=0
```

It uses 0.05-0.09 s of CPU across the whole 20 s — wedged, not slow. It leaves a 16384-byte stub
when the input has 24 frames. The same clip with the same VBR settings and no `--avif 1` finishes
in well under the limit. With `--lp 1` it exits, but writes a **zero-byte** file.

An unguarded run of this combination sat at 0.03 s CPU for 10 minutes before I killed it.

CBR is refused cleanly, which is the behaviour I would want here:
`CBR Rate control is currently not supported for RANDOM_ACCESS/ALL_INTRA, use VBR mode`, exit 1.

## Runs and independent reproduction

This was run twice, independently, on the same machine. The first pass ran the frame-count and rate-control
matrix; the second reproduced the truncation from scratch on a 160x120 clip:

```
avif 1 on 24-frame clip  exit=0  bytes=1326
  Svt[error]: AVIF flag is specified, but more than 3 frames were sent. ...
  SUMMARY: Total Frames 3
ffprobe avif output:  160,120,3
ffprobe plain output: 160,120,24
```

Both passes saw exit 0 in every truncation run. The VBR hang was seen by the first pass twice
(once unguarded for 10 minutes, once under the 20 s guard at 1 and at 24 frames).

## Expected

Two separate things:

1. When `--avif 1` receives more than 3 frames, the app already detects it and prints
   `Svt[error]`. That should be a non-zero exit, not exit 0. As it stands, the one condition the
   encoder explicitly diagnoses is the one it hides from the caller.
2. `--avif 1` with `--rc 1` should be refused the way `--rc 2` already is, rather than hanging.

**Both fail unsafely**: the first writes a plausible short file and reports success, the second
never exits and can leave a 16 KB stub.

## Ruled out

- Not a parse error: `--avif 2` is refused cleanly (`Invalid parameter 'avif' with value '2'`).
- Not clip-specific: the truncation reproduced on both a 640x480 `testsrc2` clip and a 160x120
  synthetic one.
- Not preset-specific: single-frame `--avif 1` runs succeeded at presets 2, 4, 8 and 12, and the
  truncation appeared at preset 8 and with `--tune 3`.
- The hang is not the truncation: it also hangs with `--frames 1`, where no truncation occurs.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU or OS.
- Longer than 20 seconds under a guard (10 minutes unguarded, once).
- Whether the 3-frame output is a valid AVIF image sequence. I checked frame counts and
  dimensions with `ffprobe`, not container conformance.
- 2-pass VBR with `--avif 1`.
