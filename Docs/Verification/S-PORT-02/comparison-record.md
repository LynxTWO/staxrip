# S-PORT-02 Windows Comparison Record

Date: 2026-08-20. Recorded by Record-MediaComparison.ps1 over the four
committed media fixtures, per the comparison protocol in the agreed-facts list.

## Provenance

- Portable primary: pinned MediaInfo CLI, sha256 `30f2828a45a1895b033c3cd7784581033327e7b393033c55f4a03bb15cab0d89`, verified against the
  fixture manifest before execution, invoked exactly as the goldens were captured.
- Windows authority: the installed product''s library, `MediaInfoLib - v26.05`,
  sha256 `a2612fa8bf639349aee9747d8a555d361f5db95b049b3af9b0c3851a21a4308d`, read through the same native calls and parameter names the
  product source reads. The installed library is outside repository control; its
  identity is recorded here, not pinned.

## Summary

| Verdict | Count |
|---|---|
| equal | 85 |
| absent-both | 79 |
| absent-cli | 0 |
| absent-dll | 0 |
| divergent | 7 |

`absent-both` pairs are counted but not listed: a fact absent from both
authorities on a fixture agrees by absence. `absent-cli`, `absent-dll`, and
`divergent` rows are the findings this record exists to carry.

## Non-equal rows

| File | Section | Stream | Parameter | Verdict | Product library | Pinned CLI |
|---|---|---|---|---|---|---|
| cfr-h264-aac.mp4 | General | 0 | Duration | divergent | 2000 | 2.000 |
| cfr-h264-aac.mp4 | Video | 0 | Format_Profile | divergent | Constrained Baseline@L1.2 | Constrained Baseline |
| cfr-ffv1-10bit-pcm.mkv | General | 0 | Duration | divergent | 1000 | 1.000 |
| cfr-ffv1-10bit-pcm.mkv | Audio | 0 | Video_Delay | divergent | 0 | 0.000 |
| cfr-vp9-opus.webm | General | 0 | Duration | divergent | 2008 | 2.008 |
| cfr-vp9-opus.webm | Audio | 0 | Video_Delay | divergent | 0 | 0.000 |
| vfr-ffv1.mkv | General | 0 | Duration | divergent | 2966 | 2.966 |

## Equal rows, count per file

| File | Equal facts |
|---|---|
| cfr-ffv1-10bit-pcm.mkv | 24 |
| cfr-h264-aac.mp4 | 24 |
| cfr-vp9-opus.webm | 22 |
| vfr-ffv1.mkv | 15 |
