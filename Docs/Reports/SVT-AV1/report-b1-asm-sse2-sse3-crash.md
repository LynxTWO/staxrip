# `--asm sse2` and `--asm sse3` crash with an access violation at presets 10-13

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11. `--asm max` on this CPU selects `up to avx2`.

## Reproduce

The clip is a synthetic 160x120, 24-frame, 25 fps, 8-bit 4:2:0 y4m. Generator (PowerShell), then
the encode:

```powershell
$w = 160; $h = 120; $frames = 24
$fs = [System.IO.File]::Create('clip.y4m')
$hdr = [Text.Encoding]::ASCII.GetBytes("YUV4MPEG2 W$w H$h F25:1 Ip A1:1 C420jpeg`n")
$fs.Write($hdr, 0, $hdr.Length)
$tag = [Text.Encoding]::ASCII.GetBytes("FRAME`n")
$y  = New-Object byte[] ($w * $h)
$uv = New-Object byte[] (($w / 2) * ($h / 2))
for ($i = 0; $i -lt $uv.Length; $i++) { $uv[$i] = 128 }
$rand = New-Object System.Random(12345)
for ($f = 0; $f -lt $frames; $f++) {
  for ($row = 0; $row -lt $h; $row++) { for ($col = 0; $col -lt $w; $col++) {
    $v = (($col + $row + 4 * $f) % 200) + 20 + $rand.Next(0, 16)
    if ($v -gt 235) { $v = 235 }
    $y[$row * $w + $col] = [byte]$v } }
  $fs.Write($tag, 0, $tag.Length); $fs.Write($y, 0, $y.Length)
  $fs.Write($uv, 0, $uv.Length); $fs.Write($uv, 0, $uv.Length)
}
$fs.Close()
```

```
SvtAv1EncApp.exe --asm sse2 --progress 0 --preset 10 -i clip.y4m -b out.ivf
```

## Observed

Exit code `-1073741819` = `0xC0000005`, an access violation. Nothing is printed beyond the normal
banner: no `Svt[error]`, no `Svt[warn]`.

Sweep over presets, `--asm sse2` and `--asm sse3`:

```
sse2 p4    exit=0            bytes=2648
sse2 p6    exit=0            bytes=2750
sse2 p8    exit=0            bytes=4526
sse2 p9    exit=0            bytes=6928
sse2 p10   exit=-1073741819  bytes=0
sse2 p11   exit=-1073741819  bytes=0
sse2 p12   exit=-1073741819  bytes=0
sse2 p13   exit=-1073741819  bytes=0

sse3 p8    exit=0            bytes=4526
sse3 p9    exit=0            bytes=6928
sse3 p10   exit=-1073741819  bytes=0      (4096 in a second pass — see below)
sse3 p11   exit=-1073741819  bytes=0
sse3 p12   exit=-1073741819  bytes=0
sse3 p13   exit=-1073741819  bytes=0
```

Every other `--asm` value ran cleanly at the same presets and produced identical output:
`c`, `mmx`, `sse`, `ssse3`, `sse4_1`, `sse4_2`, `avx`, `avx2`, `avx512`, `max` — all `exit=0`,
all 6787 bytes at preset 10 and all 7545 bytes at preset 13.

**It can fail unsafely.** `--asm sse3` at preset 10 wrote a 4096-byte `.ivf` and then died in one
pass, and wrote nothing in the other. A caller that only checks whether an output file exists
would take the stub for an encode.

## Runs, and independent reproduction

This was run twice, independently, on the same machine at different times, from the same clip
generator. The first pass established the crash at preset 12; the second swept presets 4 through
13 for both values and re-ran all twelve `--asm` values at presets 10 and 13. The crash was
present in every run at presets 10-13 and absent in every run at presets 4-9. The two passes
differed only in the 4096-byte stub at `sse3` preset 10, which appeared once.

## Expected

Either the encode succeeds at these presets as it does at 9 and below, or the app refuses the
combination with a message. An access violation with no diagnostic is the one outcome a caller
cannot handle.

## Ruled out

- Not a general preset-10+ problem: ten other `--asm` values encode fine at presets 10 and 13.
- Not a general SSE2/SSE3 problem: both values encode fine at presets 4, 6, 8 and 9.
- Not an input problem: the same clip encodes at every preset with any other `--asm` value.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU, OS, or compiler. `--asm sse2` forces a code path this machine would never
  otherwise take, so a host whose native ISA really is SSE2 might behave differently.
- Any other clip, resolution or bit depth — one 160x120 8-bit clip only.
- No debugger was attached; no faulting address, module or stack was captured.
