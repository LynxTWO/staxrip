# SVT-AV1 option help

Schema: 1
Encoder: svt-av1
Locale: en
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Allowed-Missing: 100
Minimum-Reviewed: 0
Reviewed-Complete: false
Verified-Encoder-Version: SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman] (release)
Verified-Encoder-Build: 17cd99550
Verified-Date: 2026-08-27
Documentation: https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md

## svt-av1.preset
Label: Preset
Summary: Controls the tradeoff between encoding speed and compression. Lower numbers usually make a smaller file at similar quality, but the encode can take much longer.
When to change: StaxRip starts you at 9. Try 6 for a final encode when a smaller file is worth the extra time; use 10 or higher for quick tests.
Encoder default: 8
Example: Encode the same 60-second sample at presets 9, 6, and 4. Compare the time and file size before committing the whole video.
Values:
- 0: Extremely slow. Mainly useful for experiments.
- 4: High compression efficiency with a large encoding-time cost.
- 6: Slower than StaxRip's default, with better compression efficiency.
- 8: The encoder's own default.
- 9: StaxRip's default and a practical starting point.
- 13: Fastest, with the largest compression tradeoff.
Related: concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
Status: reviewed
