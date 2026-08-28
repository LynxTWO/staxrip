# Glossary

Schema: 1
Encoder: concepts
Locale: en
Title: Glossary

## concept.compression-efficiency
Label: Compression efficiency
Summary: How small a file the encoder can make for a given picture quality. Better efficiency means a smaller file that looks the same, usually at the cost of encoding time.
When to change: Not a setting. See the options that link here; it is how you compare choices such as presets.
Status: reviewed

## concept.psnr
Label: PSNR
Summary: Peak signal-to-noise ratio, a decibel score for how far the encoded pixels stray from the source; higher is closer. Upstream notes a lower PSNR can still look good: a lab number, not a verdict.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## concept.ssim
Label: SSIM
Summary: Structural similarity, a score comparing local patterns of brightness and contrast between encode and source rather than single pixels. The stat report prints it from 0 to 1; 1 means identical.
When to change: Not a setting. See the options that link here.
Status: reviewed

## concept.vmaf
Label: VMAF
Summary: Video Multimethod Assessment Fusion, a quality score that combines several measurements to estimate how viewers would rate the picture. SVT-AV1 offers a tune for it, video only.
When to change: Not a setting. See the options that link here.
Status: reviewed

## concept.vq
Label: VQ (visual quality)
Summary: Visual quality, the encoder's name for tuning toward what viewers see rather than a measured score. Upstream says it often gives a sharper picture, meant to look good to people, not to score well.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## concept.parallelism
Label: Parallelism
Summary: Doing several parts of the encode at once on different CPU cores: more threads and more pictures in flight. More of it means a faster encode on a many-core machine, at the cost of memory.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-a-encoder-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#threading-and-efficiency
Status: reviewed

## concept.rate-control
Label: Rate control
Summary: The encoder's rule for how many bits each frame gets. Quality modes (CRF, QP) hold a quality level and let the size fall where it may; bitrate modes (VBR, CBR) hold a bitrate and let quality vary.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#bitrate-control-modes
Status: reviewed

## concept.quality-level
Label: Quality level (CRF, QP)
Summary: The number a quality mode (CRF, QP) holds steady: lower means a finer quantizer, a better picture and a larger file. AV1's quantizer scale is 0 to 63; SVT-AV1's CRF runs to 70 in quarter steps.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## concept.bitrate
Label: Bitrate
Summary: How many bits the video uses per second, in kbps here; bitrate times running time is the size of the video. A bitrate mode aims at a number, a quality mode lets it float with the content.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#bitrate-control-modes
Status: reviewed

## concept.two-pass
Label: Two-pass encoding
Summary: An analysis pass over the video, then an encoding pass that uses what it learned. Upstream says it helps hit a bitrate target (VBR) but matters less in quality (CRF) mode; CBR is always one pass.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#multi-pass-encoding
Status: reviewed

## concept.keyframe
Label: Keyframe
Summary: A frame stored whole, borrowing from no other frame, so playback can start there. Each group of pictures opens with one; it costs far more bits than the frames between, which hold only changes.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#gop-size-selection
Status: reviewed

## concept.gop
Label: GOP (group of pictures)
Summary: A keyframe (a frame stored whole) and the frames up to the next. Keyint sets its length: short for quick seeking, long for a small file; SVT-AV1 builds it from mini-GOPs, layered runs of frames.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#gop-size-selection
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
Status: reviewed

## concept.lookahead
Label: Lookahead
Summary: The frames the encoder reads ahead of the one it is coding, to plan bits and frame types with what comes next in view. More means better planning, more memory and a longer start-up wait.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
Status: reviewed

## concept.scene-change
Label: Scene change
Summary: A cut between shots, where the next frame shares little with the last. Upstream says SVT-AV1 adds no keyframe there; it leans less on neighboring frames instead, so keyframe spacing stays as set.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#scene-change-detection
Status: reviewed

## concept.tiles
Label: Tiles
Summary: A frame cut into rectangles coded on their own, so a player or encoder can work on several at once. Each cut costs bits, as prediction starts afresh at its edge, and many tiles can show as artifacts.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#improving-decoding-performance
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#threading-and-efficiency
Status: reviewed

## concept.film-grain
Label: Film grain synthesis
Summary: Instead of compressing random grain, which is costly, the encoder describes it and the player draws matching grain on playback. Upstream says it can cut the file a lot at similar apparent quality.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#practical-advice-on-grain-synthesis
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#improving-decoding-performance
Status: reviewed

## concept.deblocking
Label: Deblocking and the loop filters
Summary: AV1 codes pictures in blocks; heavy compression shows seams. Three in-loop filters, deblocking, CDEF and restoration, clean the frame before later frames predict from it, in encoder and player alike.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## concept.super-resolution
Label: Super-resolution
Summary: Coding a frame at a reduced width and having the player stretch it back, an AV1 tool meant for very low bitrates. The file plays at its normal size; the detail lost in the squeeze does not come back.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#super-resolution
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Appendix-Super-Resolution.md
Status: reviewed

## concept.lossless
Label: Lossless coding
Summary: Compression that gives back every pixel exactly, as a zip file gives back every byte, so the file is many times larger than a normal encode. In AV1 it is a mode of its own, not a low quality number.
When to change: Not a setting. See the options that link here.
Status: reviewed

## concept.color-description
Label: Color description
Summary: The tags in a video file that tell a player which color primaries, transfer curve, matrix and range the pixels use, so it can show them as intended. They describe the picture and change no pixel.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
Status: reviewed

## concept.hdr-metadata
Label: HDR metadata
Summary: HDR10 metadata: the primaries, white point and luminance range of the mastering display, and the video's brightest pixel and frame average (MaxCLL, MaxFALL). Players use it to fit HDR to the screen.
When to change: Not a setting. See the options that link here.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#hdr-and-sdr-video
Status: reviewed

## concept.level
Label: Profile, level and tier
Summary: The compatibility labels a stream carries: the profile names the coding tools it uses, the level caps resolution, frame rate and bitrate, and the tier picks between two ceilings at a level.
When to change: Not a setting. See the options that link here. A player refuses, or stumbles over, a stream whose profile or level is above what its decoder promises to handle.
Status: reviewed
