# `--lossless 1` at presets 11-13 produces a stream that is not lossless and that dav1d and
# libaom cannot decode

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. `--lossless` does not exist upstream — it appears in this build's `--help` and in no
version of `Docs/Parameters.md` or `Docs/CommonQuestions.md` at the v4.2.0 tag — so this is a
fork-only switch and the report belongs here. I did not test a stock upstream build.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11. Decoders: ffmpeg with libdav1d, and ffmpeg with
libaom-av1.

## Reproduce

```
ffmpeg -f lavfi -i testsrc2=size=640x480:rate=25 -frames:v 24 -pix_fmt yuv420p clip.y4m

SvtAv1EncApp --rc 0 --crf 35 --preset 8  --lossless 1 --progress 0 -i clip.y4m -b p8.ivf
SvtAv1EncApp --rc 0 --crf 35 --preset 12 --lossless 1 --progress 0 -i clip.y4m -b p12.ivf

ffmpeg -i p8.ivf  -i clip.y4m -lavfi "[0:v][1:v]psnr" -f null -
ffmpeg -i p12.ivf -i clip.y4m -lavfi "[0:v][1:v]psnr" -f null -
```

## Observed

Preset 8 is genuinely lossless. Preset 12 is not, and the stream is also malformed.

Sweep across presets on a 160x120 synthetic clip, with a decode check on each output:

```
preset  2   exit=0  272731 bytes   dav1d PSNR y:inf u:inf v:inf
preset  4   exit=0  269215          y:inf u:inf v:inf
preset  6   exit=0  267557          y:inf u:inf v:inf
preset  8   exit=0  266853          y:inf u:inf v:inf
preset  9   exit=0  272980          y:inf u:inf v:inf
preset 10   exit=0  271047          y:inf u:inf v:inf
preset 11   exit=0  317070          y:10.276678 u:41.618066 v:36.493704
preset 12   exit=0  317070          y:10.276678 u:41.618066 v:36.493704
preset 13   exit=0  317070          y:10.276678 u:41.618066 v:36.493704
```

Presets 11, 12 and 13 give one byte-identical file (SHA-1 `033B88FEFE`); the banner confirms
`Preset M12 is mapped to M11.` Same result with `--lp 1`, so it is not a threading effect.

libaom refuses the same file outright:

```
[dec:libaom-av1] Error submitting packet to decoder: Invalid data found when processing input
   ... (repeated for 23 of 24 frames)
[dec:libaom-av1] Decode error rate 0.958333 exceeds maximum 0.666667
```

On the 640x480 `testsrc2` clip, libdav1d fails too:

```
preset  4   exit=0  441950   y:inf u:inf v:inf
preset  8   exit=0  462585   y:inf u:inf v:inf
preset 10   exit=0  493513   y:inf u:inf v:inf
preset 12   exit=0  498839   Error submitting packet to decoder: Invalid data found ... /
                             Cannot allocate memory ... / Decode error rate 0.875 exceeds
                             maximum 0.666667 / PSNR y:15.609367
preset 13   exit=0  498839   (identical file, identical failure)
```

**The encoder's own reconstruction is not lossless there either.** With
`--enable-stat-report 1` on the same 160x120 clip:

| preset | Y-PSNR (average) | Y-SSIM |
| --- | --- | --- |
| 8 | 100.96 dB | 1.00000 |
| 12 | 67.48 dB | 0.99988 |

So this is not only a bitstream-conformance problem visible to external decoders; the encoder
reports its own output as lossy at preset 12 while `--lossless 1` is in effect.

Exit code is **0** in every one of these runs, and the banner prints
`Lossless Coding : BRC mode` as usual, so nothing signals a problem to a caller.

## Runs and independent reproduction

This was run twice, independently, on the same machine. The first pass ran the preset sweep with the dav1d
and libaom decode checks on both clips. The second re-ran presets 8 and 12 on the 160x120 clip
from scratch and got `10.276678` for preset 12 — matching to six decimal places — plus `inf` on
all planes and 24 cleanly decoded frames at preset 8 through libaom.

## Expected

Either `--lossless 1` produces a lossless, decodable stream at every preset it accepts, or it
refuses (or warns about) the presets where it cannot. Presets 11-13 currently accept the flag,
exit 0, and write a file that is neither lossless nor reliably decodable.

## Ruled out

- Not the CRF value: `--lossless 1` at CRF 1, 20, 35 and 60 all decode to `inf` at preset 8
  (276176, 269244, 266853, 266421 bytes).
- Not threading: preset 12 with `--lp 1` gives the byte-identical file and the same 10.28 dB.
- Not the decoder: two independent decoders (libdav1d and libaom-av1) both fail on the same file,
  and both decode preset 8 cleanly.
- Not `--scm`: `--lossless 1 --scm 1` at preset 8 still decodes to `inf`.
- Not a general preset-11+ problem: without `--lossless 1` the same presets encode and decode
  normally.

## Not tested

- Presets -1, 0, 1, 3, 5 and 7 with `--lossless 1` — only 2, 4, 6, 8, 9, 10, 11, 12 and 13 were run.
- Real source material — both clips are synthetic.
- 10-bit input with `--lossless 1` at presets 11-13.
- Where in the pipeline it goes wrong. I did not read the fork's source for this one.
