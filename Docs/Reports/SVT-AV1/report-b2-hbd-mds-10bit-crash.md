# `--hbd-mds 1` and `--hbd-mds 2` crash on 10-bit input above `--lp 3`, leaving a partial file

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11. The automatic level of parallelism resolves to 6 on
this machine (banner: `Number of PPCS 305`).

## Reproduce

A synthetic 640x480, 48-frame, 25 fps, 10-bit 4:2:0 (`C420p10`) y4m. Generator (PowerShell), then
the encode:

```powershell
$w = 640; $h = 480; $frames = 48
$fs = [System.IO.File]::Create('clip10.y4m')
$hdr = [Text.Encoding]::ASCII.GetBytes("YUV4MPEG2 W$w H$h F25:1 Ip A1:1 C420p10`n")
$fs.Write($hdr, 0, $hdr.Length)
$tag = [Text.Encoding]::ASCII.GetBytes("FRAME`n")
$y  = New-Object byte[] ($w * $h * 2)
$uv = New-Object byte[] (($w / 2) * ($h / 2) * 2)
for ($i = 0; $i -lt ($w / 2) * ($h / 2); $i++) { $uv[2 * $i] = 0; $uv[2 * $i + 1] = 2 }
$rand = New-Object System.Random(12345)
for ($f = 0; $f -lt $frames; $f++) {
  for ($row = 0; $row -lt $h; $row++) { for ($col = 0; $col -lt $w; $col++) {
    $v = (($col + $row + 4 * $f) % 200) + 20 + $rand.Next(0, 16)
    if ($v -gt 235) { $v = 235 }
    $i = $row * $w + $col; $v10 = $v * 4
    $y[2 * $i] = [byte]($v10 -band 0xFF); $y[2 * $i + 1] = [byte]($v10 -shr 8) } }
  $fs.Write($tag, 0, $tag.Length); $fs.Write($y, 0, $y.Length)
  $fs.Write($uv, 0, $uv.Length); $fs.Write($uv, 0, $uv.Length)
}
$fs.Close()
```

```
SvtAv1EncApp.exe --rc 0 --crf 35 --preset 8 --hbd-mds 1 --lp 5 --progress 0 -i clip10.y4m -b out.ivf
```

Omitting `--lp` (automatic, = 6 here) crashes the same way.

## Observed

Exit code `-1073741819` = `0xC0000005`, an access violation, with **a 28672-byte partial `.ivf`
left on disk**. A clean run of the same command writes 36243 bytes. No `Svt[error]` is printed;
the last thing on stderr is the normal banner.

Failure depends on the level of parallelism, not on the preset. Counting every run at preset 8,
CRF 35, on the 640x480 10-bit clip above, across the two independent passes:

| `--lp` | `--hbd-mds 1` ran / crashed | `--hbd-mds 2` ran / crashed |
| --- | --- | --- |
| 1 | 9 / 0 | 3 / 0 |
| 2 | 4 / 0 | 1 / 0 |
| 3 | 13 / 0 | 3 / 0 |
| 4 | 8 / 9 | 7 / 2 |
| 5 | 0 / 7 | 0 / 3 |
| 6 | 0 / 5 | 0 / 3 |
| automatic (= 6) | 0 / 3 | 0 / 1 |

So: 33 of 33 runs at `--lp 1`-`3` succeeded; `--lp 4` is close to a coin flip (11 crashes in 26
runs); and every one of the 18 runs at `--lp 5` and `--lp 6` crashed. One batch, verbatim:

```
hbd-mds 1 lp 3: 4 runs, 0 crashes | exit=0 bytes=36243 (x4)
hbd-mds 1 lp 4: 8 runs, 5 crashes | crash, crash, ok, ok, crash, ok, crash, crash
                                    (crash = exit -1073741819, 28672-byte partial file each time)
hbd-mds 1 lp 5: 4 runs, 4 crashes
hbd-mds 2 lp 4: 6 runs, 0 crashes | exit=0 bytes=36243 (x6)
```

The `--lp 4` row is where the two passes diverge: 6 crashes in 12 runs for one, 5 in 14 for the
other. That is a race, not a threshold — and it is why I would not describe `--lp 4` as safe.

A second, smaller 10-bit clip (320x240, 48 frames, same generator shape) crashed with
`--hbd-mds 1` and `2` at presets 6, 8, 10 and 12 at the automatic level, and ran at `--lp 1`
(16078 bytes both values).

## Expected

The runs that succeed at `--lp 1`-`3` all produce the identical 36243-byte file, so the setting
works; it is the parallel path that faults. Either it should work at every level of parallelism,
or the app should refuse the combination.

**It fails unsafely.** The 28672-byte truncated `.ivf` is left behind, so a caller checking only
for an output file sees a valid-looking result.

## Ruled out

- Not an input-format problem: `--hbd-mds -1` (37133 bytes) and `--hbd-mds 0` (41457 bytes) run
  cleanly on the same clip at every level tried.
- Not the assembly path: the 320x240 clip crashed identically with `--asm c` and with `--asm avx2`.
- Not a mis-typed value. `--hbd-mds 3` is refused cleanly with
  `hbd-mds must be -1 (preset default), 0, 1, or 2`, and on **8-bit** input `--hbd-mds 1`/`2` are
  refused cleanly with `Full high bit depth and hybrid 8/10 mode decision are not supported when
  encoder bit depth is 8` plus `Please use 10-bit encoding if you want to take advantage of
  hbd-mds 1 and 2.` The crash is specific to 10-bit input with a working configuration.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU or OS; the level-of-parallelism boundary is likely to move with core count.
- Real 10-bit source material — both clips are synthetic.
- No debugger was attached; no faulting address, module or stack was captured.
