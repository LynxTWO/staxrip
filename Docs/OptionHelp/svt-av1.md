# SVT-AV1 option help

Schema: 1
Encoder: svt-av1
Locale: en
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Allowed-Missing: 71
Minimum-Reviewed: 29
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

## svt-av1.progress
Label: Progress
Summary: Chooses how much progress text the encoder prints while it runs. It changes only what you see in the processing window and the log, never the encoded video.
When to change: Leave it at 2. It is the only level that prints the per-frame `Encoding: n/N Frames @` lines StaxRip turns into the progress line of its processing window. With 1 the encoder's own frame counter goes to the log instead, and with 0 you see nothing until the summary at the end.
Encoder default: 1
Values:
- 0: No per-frame output. The log gets only the settings banner and the final summary.
- 1: The encoder's plain frame counter. StaxRip cannot read it as progress, so it lands in the log.
- 2: Patman's style: one line per frame with frames done, speed, bitrate, size, and time. StaxRip's default.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#options
Status: reviewed

## svt-av1.frames
Label: Frames To Be Encoded
Summary: Encodes only this many frames of your script instead of all of them. 0 means all frames. It is for test encodes, not for cutting a video.
When to change: Set a few hundred frames, or a few thousand for a whole scene, to try settings before committing hours to the full encode. Counting starts after Frames To Be Skipped, and a negative number encodes everything except that many frames at the end. To cut a video for real, select the parts to keep in the preview window's Cut menu; this control only shortens the video stream.
Example: Set 1500 here and 20000 in Frames To Be Skipped to encode one minute of a 25 fps movie starting about 13 minutes in. A number larger than the script is cut down to the script length, so the encoder never loops back to the start.
Related: svt-av1.skip, staxrip.chunks
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.skip
Label: Frames To Be Skipped
Summary: Leaves out this many frames at the start of your script and begins the encode after them. 0 starts at the first frame. It is for test encodes, not for cutting a video.
When to change: Use it with Frames To Be Encoded to test a scene from the middle of the video instead of the opening. Unless Chunks is above 1, the skipped frames are still decoded and piped to the encoder, which drops them, so a large skip takes a while to reach the first encoded frame. To cut a video for real, select the parts to keep in the preview window's Cut menu; this only shortens the video stream.
Example: With a 24 fps source, 14400 skipped frames start the test 10 minutes in.
Related: svt-av1.frames, staxrip.chunks
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.color-format
Label: Encoder Color Format
Summary: Tells the encoder how the color is sampled in the frames it receives. The encoder that ships with StaxRip supports only 4:2:0.
When to change: Leave it at 1: YUV420. In a test with the bundled build, every other choice stopped the encode at once with "Only support 420 now"; 2 and 3 also ask for a profile the build then refuses. The numbers describe chroma subsampling, how much color detail is stored next to the brightness: 4:2:0 keeps a quarter of the color samples, 4:2:2 half, 4:4:4 all of them, and 4:0:0 has no color at all.
Values:
- 0: Grayscale with no color. The bundled build refuses it with "Only support 420 now".
- 1: 4:2:0. The encoder default and the only format the bundled build accepts.
- 2: 4:2:2. Refused by the bundled build, which also asks for profile 1 or 2 and refuses those too.
- 3: 4:4:4. Refused by the bundled build with the same messages as 2.
Related: svt-av1.profile
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.enable-stat-report
Label: Stat Report
Summary: Makes the encoder measure PSNR and SSIM against the source and print a table of the scores at the end of the encode. It does not change the video.
When to change: Turn it on only for a test where you want the numbers; the bundled build warns that it can slow the encode. The table lands in StaxRip's log after the encoder's summary: average QP, Y, U and V PSNR and SSIM, and bitrate. A higher score is not the same as a better-looking picture; upstream notes that a large drop in PSNR can still look good.
Values:
- 0: Off. The default.
- 1: Measures PSNR and SSIM per frame and prints the totals at the end. The bundled build warns it can slow the encode.
Related: concept.psnr, concept.ssim
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## svt-av1.asm
Label: Limit Assembly Instruction Set
Summary: Caps which CPU instruction sets the encoder's optimized code may use. MAX lets it use everything your CPU has; anything lower switches off faster code paths and is only for tracking down a problem.
When to change: Leave it at MAX. Drop to a lower set only to check whether a crash or a corrupt picture comes from a CPU-specific code path; the encoder prints the set it selected in its banner. In a test with the bundled build (160x120 clip, preset 12, Ryzen 9 5950X), SSE2 and SSE3 crashed the encoder before it wrote a frame, while every other choice ran and produced a file of the same size.
Values:
- c: No CPU-specific instructions at all. Ran in the test.
- sse2: Crashed the bundled build in the test at preset 12; it ran at preset 8. Avoid.
- sse3: Crashed the bundled build in the test at preset 12. Avoid.
- sse4_2: The bundled build reported sse4_1 as the selected set for this choice.
- avx512: Used only when your CPU has it; otherwise the build picks the next set your CPU supports.
- max: Everything your CPU supports. The encoder default and StaxRip's.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.lp
Label: Level Of Parallelism
Summary: Controls how much parallel work SVT-AV1 creates, including threads and picture buffers. 0 lets the encoder choose for your CPU.
Used when: Always; the effect is larger on machines with many cores.
When to change: Leave it at 0 for a single encode. Set a low explicit level when you need to reduce CPU or memory use, or when several encodes are running at once. The level is not a thread count. Upstream says levels 4 and up also process extra mini-GOPs in parallel in CRF mode, at a much higher memory cost, and that in the default CRF setup the picture is the same at level 1 as at higher levels.
Example: On a 16-core Ryzen 9 5950X the bundled build chose level 6 for a test clip when left at 0, and printed it in its banner; `--lp 1` produced a file of the same size.
Related: svt-av1.pin, svt-av1.ss, concept.parallelism
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-a-encoder-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#threading-and-efficiency
Status: reviewed

## svt-av1.pin
Label: Pinned Execution
Summary: The encoder that ships with StaxRip does not accept this switch. Upstream documents `--pin` as running the encoder on the first N CPU cores only; the bundled help does not list it.
When to change: Leave it at 0. Any other value puts `--pin` on the command line, and the bundled build then stops before encoding with "Unprocessed tokens: --pin", so the encode does not start (checked on 2026-08-27 with a test clip). To limit the encoder's CPU and memory use, lower Level Of Parallelism instead.
Related: svt-av1.lp, svt-av1.ss, concept.parallelism
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-a-encoder-parameters
Status: reviewed

## svt-av1.ss
Label: Target Socket
Summary: The encoder that ships with StaxRip does not accept this switch. Target Socket once told the encoder which CPU socket to run on; the bundled help does not list it and no current document describes it.
When to change: Leave it at the default. Changing the control puts `--ss` on the command line, and the bundled build then stops before encoding with "Unprocessed tokens: --ss", so the encode does not start (checked on 2026-08-27).
Related: svt-av1.lp, svt-av1.pin
Status: reviewed

## svt-av1.profile
Label: Profile
Summary: Records which AV1 profile the stream claims: Main, High, or Professional. The profile is tied to the color format and bit depth of the video.
When to change: Leave it at 0: Main. With 4:2:0 video, the only format this build accepts, the bundled build stops at once on the other two: High wants 4:4:4 and Professional wants 4:2:2 for 8-bit video.
Values:
- 0: Main. The encoder default and the profile that goes with the 4:2:0 video this build accepts.
- 1: High. Refused by the bundled build with "Profile 1 requires 4:4:4 color format".
- 2: Professional. Refused for 8-bit video with "Profile 2 bit-depth < 10 requires 4:2:2 color format".
Related: svt-av1.color-format, svt-av1.level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.level
Label: Level
Summary: Records an AV1 level in the stream, the tier from the AV1 specification that tells a player how demanding the video is. Autodetect lets the encoder work it out from the input.
When to change: Leave it at Autodetect unless a delivery target names a level. The bundled build accepts 2.0, 2.1, 3.0, 3.1, 4.0, 4.1, 5.0 to 5.3 and 6.0 to 6.3; it stops before encoding with "Invalid or undefined level" for 2.2, 2.3, 3.2, 3.3, 4.2, 4.3 and 7.0 to 7.3, which StaxRip lists anyway. The help does not say whether a chosen level constrains the encode or only labels it.
Values:
- 0: Autodetect from input. The encoder default; its banner then shows the level as auto.
- 2.2: Refused by the bundled build as an undefined level.
- 2.3: Refused by the bundled build as an undefined level.
- 3.2: Refused by the bundled build as an undefined level.
- 3.3: Refused by the bundled build as an undefined level.
- 4.2: Refused by the bundled build as an undefined level.
- 4.3: Refused by the bundled build as an undefined level.
- 7.0: Refused by the bundled build as an undefined level.
- 7.1: Refused by the bundled build as an undefined level.
- 7.2: Refused by the bundled build as an undefined level.
- 7.3: Refused by the bundled build as an undefined level.
Related: svt-av1.profile
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.tune
Label: Tune
Summary: Changes what the encoder rewards when it decides where to spend bits. VQ is tuned for perceived visual quality, while the other modes target named quality scores.
When to change: For video you plan to watch, try 0: VQ; upstream says it often gives a sharper picture and aims at what looks good to people rather than at PSNR. Keep 1: PSNR when PSNR is the score you are testing; choose another mode only when that specific metric is part of the comparison.
Example: Encode the same short scene with VQ and PSNR at the same quality setting. Compare the picture and file size, not only the reported score.
Values:
- 0: VQ. Tuned toward perceived visual quality.
- 1: PSNR. The encoder default; targets a pixel-error score.
- 2: SSIM. Targets a structural-similarity score.
- 3: Still-image quality. With the usual random-access prediction structure the bundled build stops with an error.
- 4: MS-SSIM. The help's MS-SSIM and SSIMULACRA2 optimized mode; overrides Sharpness, Variance Boost and quant matrices.
- 5: VMAF. Video only; the bundled build adds an unsharp-mask pre-processing step. For when VMAF is the metric tested.
Related: svt-av1.preset, concept.psnr, concept.ssim, concept.vmaf, concept.vq
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## svt-av1.fast-decode
Label: Fast Decode
Summary: Shapes the stream so a player needs less work to decode it, at a possible cost in picture quality. Off leaves the encoder free to use every tool it has.
When to change: Turn it on when a player stutters on your AV1 files, most often software decoding on slow hardware. Upstream says level 1 can help even where the player has no multithreading, and that 2 decodes faster still. Upstream also notes the option uses a 5-temporal-layer structure by default, which Hierarchical Levels can override. Test on the weakest player you care about.
Values:
- 0: Off. The default; no decoding shortcuts.
- 1: Upstream's first suggestion for a stuttering player; it says the gain can come even without multithreaded decoding.
- 2: The faster of the two levels for the decoder, per upstream. Check the picture.
Related: svt-av1.preset
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#improving-decoding-performance
Status: reviewed

## svt-av1.adaptive-film-grain
Label: Adaptive Film Grain
Summary: Lets film grain synthesis pick its block size from the picture's resolution instead of one fixed size. Upstream says this often makes the synthesized grain more even and reduces visible patterns.
Used when: Only with film grain synthesis on, that is a Film Grain Level above 0; otherwise there is no synthesized grain to place.
When to change: Leave it on. Turn it off only to compare against the fixed block size when you are judging the grain of a short test encode.
Values:
- 0: One fixed grain block size whatever the resolution.
- 1: Block size follows the resolution. The encoder default.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
Status: reviewed

## svt-av1.max-tx-size
Label: Max TX Size
Summary: Caps the blocks the encoder converts into frequency data (the transform) at 32 or 64 pixels. Upstream says the 64 size drops its finest detail, which can look blurry on noise-like textures.
When to change: Leave it at 64 unless fine textures look smeared in a test encode; then try 32 on a short sample and compare. Upstream says the gain is mostly quality consistency, especially for still images at medium to high quality, and the bundled build warns that 32 may reduce coding efficiency at low to medium quality settings.
Values:
- 32: Blocks 64-point transforms. The bundled build warns this can cost efficiency at low to medium quality.
- 64: Every transform size allowed. The encoder default.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
Status: reviewed
