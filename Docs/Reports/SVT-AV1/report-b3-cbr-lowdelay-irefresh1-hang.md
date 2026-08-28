# CBR + low delay + `--irefresh-type 1` hangs forever after printing
# `Unexpected temporal_layer - RPS for LD CBR HL2`

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11.

## Reproduce

Any clip will do; mine was a synthetic 160x120, 75-frame, 25 fps, 8-bit 4:2:0 y4m with a content
change at frame 40. The combination is what matters:

```
SvtAv1EncApp.exe --rc 2 --tbr 500 --pred-struct 1 --keyint 1s --irefresh-type 1 \
                 --progress 0 --preset 8 -i clip.y4m -b out.ivf
```

It also hangs without `--keyint 1s`.

## Observed

The process never exits. Killed at 90 seconds, it had used **0.03 seconds of CPU** across the
whole wall time — it is wedged, not slow. It leaves a **4096-byte `.ivf` stub** behind.

Full message set before it wedges:

```
Svt[warn]: Fwd key frame is only supported for hierarchical levels 4 at this point.
           Hierarchical levels are set to 4
Svt[info]: SVT [config]: gop size / mini-gop size / key-frame type : 26 / 16 / FWD key frame
Encoding
Svt[error]: Unexpected temporal_layer - RPS for LD CBR HL2
Svt[error]: Unexpected temporal_layer - RPS for LD CBR HL2
```

The error is printed twice, and then nothing. The controls all finish normally:

```
cbr ld irefresh 1 keyint 1s          HANG: killed after 90 s, cpu=0.03s  bytes=4096
cbr ld irefresh 1 (default keyint)   HANG: killed after 90 s, cpu=0.05s  bytes=4096
cbr ld irefresh 2 keyint 1s          exit=0                              bytes=174522
crf ld irefresh 1 keyint 1s          exit=0                              bytes=22365
crf ld irefresh 1 (default keyint)   exit=0                              bytes=18754
crf ld irefresh 2 keyint 1s          exit=0                              bytes=38852
crf ra irefresh 1 keyint 1s          exit=0                              bytes=19188
vbr    irefresh 1 keyint 1s          exit=0                              bytes=152752
```

So it takes all three of CBR, low delay and `--irefresh-type 1` together. CRF with low delay and
open GOP is fine (and prints the same `Fwd key frame` warning). Random access with open GOP is
fine. CBR + low delay with `--irefresh-type 2` is fine.

## Runs and independent reproduction

It was hit twice, independently, on the same machine. The first pass hit it as an unguarded run that had to
be killed by hand after several minutes at 0.02 s CPU, then re-ran it under a 90-second guard — the
table above. The second reproduced it at the first attempt under a 60-second guard: killed after
60 s at 0.03 s CPU with the same 4096-byte stub and the same two `Unexpected temporal_layer` lines.
Every attempt at this combination hung; no attempt at it ever completed.

## Expected

The encoder already knows the configuration is wrong — it prints `Unexpected temporal_layer - RPS
for LD CBR HL2` before wedging. Refusing the combination at configuration time, the way
`--pred-struct 1` with VBR is refused (`VBR Rate control is currently not supported for LOW_DELAY,
use CBR mode`, exit 1), would turn this into a clean error.

**It fails unsafely.** A 4096-byte stub is written and the process never exits, so an automated
caller waits forever and then finds a plausible-looking file.

## Ruled out

- Not `--keyint`: hangs with and without an explicit key interval.
- Not low delay alone: `--rc 0 --pred-struct 1 --irefresh-type 1` completes.
- Not open GOP alone: `--rc 0` and `--rc 1` with `--irefresh-type 1` complete.
- Not CBR alone: `--rc 2 --pred-struct 1 --irefresh-type 2` completes (174522 bytes).
- Not slowness: 0.03-0.05 s of CPU over 60-90 s of wall time.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU or OS.
- Longer than 90 seconds — I cannot state it never exits, only that it consumed no CPU for 90 s
  in the guarded runs and for several minutes in the unguarded one.
- Whether the hierarchical-levels forcing named in the warning is on the path to the fault. The
  warning and the error are both reported; the connection between them is a guess I did not test.
- Any other clip. The two clips used were both small and synthetic.
