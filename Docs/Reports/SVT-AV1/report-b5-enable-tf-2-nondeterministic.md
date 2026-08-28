# `--enable-tf 2` is not deterministic at the automatic level of parallelism

## Build tested

`SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman]`, the prebuilt Windows x64 binary bundled with
StaxRip. I did not test a stock upstream build — no such binary was available on this machine — so
I can say the fork does this and cannot say whether upstream does.

Host: AMD Ryzen 9 5950X (16C/32T), Windows 11. The automatic level of parallelism resolves to 6
here.

## Reproduce

```
ffmpeg -f lavfi -i testsrc2=size=640x480:rate=25 -frames:v 24 -pix_fmt yuv420p clip.y4m

for i in 1 2 3 4 5; do
  SvtAv1EncApp --rc 0 --crf 35 --preset 8 --enable-tf 2 --progress 0 -i clip.y4m -b out$i.ivf
done
sha1sum out*.ivf
```

## Observed

Five identical invocations produced **four distinct files**:

```
104848  BC70682F55
104814  691C2898C9
104823  8653EF07AD
104896  35F7B69E78
104848  BC70682F55
```

Adding `--lp 1` makes it repeatable — three runs, all `104848 BC70682F55`. And `--enable-tf 0` and
`--enable-tf 1` are repeatable at the automatic level: three runs of `--enable-tf 1` all give
`105036 7204EFA9FD`, two runs of `--enable-tf 0` both give `104956 E1124DD575`.

`--enable-tf 2 --tf-strength 3` at the automatic level is worse — every run differed:

```
104946 F6D1D9BEFD  /  104983 E71EDBEC84  /  104864 9ECAA3F7E9      (first pass)
105052            /  104816            /  105215                  (second pass)
```

## Runs and independent reproduction

This was run twice, independently, on the same machine from the same `testsrc2` command. Between them:
9 runs of `--enable-tf 2` at the automatic level on the 640x480 clip produced at least four
distinct outputs; 6 runs at `--lp 1` produced one; 6 runs of `--enable-tf 1` and 4 of
`--enable-tf 0` each produced one; and 6 runs of `--enable-tf 2 --tf-strength 3` at the automatic
level produced 6 distinct outputs.

**Clip-dependent.** On a smaller synthetic 160x120 clip, `--enable-tf 2` was repeatable at the
automatic level across 3 runs (all `4490 D5FBD41079`). The 640x480 `testsrc2` clip is the one that
shows it, so use that clip to reproduce.

## Expected

Upstream's `Threading and Efficiency` documentation states that "the video output will be the same
when using `--lp 1` as `--lp n` in the default CRF configuration". That holds for `--enable-tf 0`
and `1` here and does not hold for `--enable-tf 2`. Either level 2 should be deterministic like
its neighbours, or the documentation should carve it out.

This is a correctness annoyance rather than a crash: every run completes with exit 0 and a
decodable file. It does mean level 2 cannot be used for anything that needs a reproducible build.

## Ruled out

- Not general encoder non-determinism: levels 0 and 1 repeat exactly on the same clip in the same
  session, and so does level 2 at `--lp 1`.
- Not measurement noise: the byte counts differ and so do the SHA-1 hashes.
- Not `--tf-strength`: level 2 is non-repeatable with the strength left at its default, and
  specifying a strength makes it more so, not less.

## Not tested

- A stock upstream build of the same tag.
- Any other CPU or OS; the effect plausibly depends on thread count.
- Whether the differing outputs differ in quality, or only in bit-exactness. I compared bytes and
  hashes, not PSNR.
- Which level of parallelism between 2 and 6 is the boundary — only automatic (6) and 1 were run.
