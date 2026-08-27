# SVT-AV1 option help

Schema: 1
Encoder: svt-av1
Locale: en
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Allowed-Missing: 38
Minimum-Reviewed: 62
Reviewed-Complete: false
Verified-Encoder-Version: SVT-AV1 v4.2.0+71+88-17cd99550 [Mod by Patman] (release)
Verified-Encoder-Build: 17cd99550
Verified-Date: 2026-08-27
Documentation: https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md

## svt-av1.preset
Label: Preset
Summary: Controls the tradeoff between encoding speed and compression. Lower numbers usually make a smaller file at similar quality, but the encode can take much longer.
When to change: StaxRip starts you at 8, which is also the encoder's own default. Try 6 for a final encode when a smaller file is worth the extra time; use 10 or higher for quick tests.
Example: Encode the same 60-second sample at presets 8, 6, and 4. Compare the time and file size before committing the whole video.
Values:
- 0: Extremely slow. Mainly useful for experiments.
- 4: High compression efficiency with a large encoding-time cost.
- 6: Slower than StaxRip's default, with better compression efficiency.
- 8: The encoder's default and StaxRip's.
- 9: One step faster than the default.
- 13: Fastest, with the largest compression tradeoff.
Related: svt-av1.crf, concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md
Status: reviewed

## svt-av1.progress
Label: Progress
Summary: Chooses how much progress text the encoder prints while it runs. It changes only what you see in the processing window and the log, never the encoded video.
When to change: Leave it at 2. It is the only level that prints the per-frame `Encoding: n/N Frames @` lines StaxRip turns into the progress line of its processing window. With 1 the encoder's own frame counter goes to the log instead, and with 0 you see nothing until the summary at the end.
Encoder default: 1
Values:
- 0: No per-frame output. The log gets only the settings banner, one bare Encoding line, and the final summary.
- 1: The encoder's plain frame counter. StaxRip cannot read it as progress, so it lands in the log.
- 2: Patman's style: one line per frame with frames done, speed, bitrate, size, and time. StaxRip's default.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#options
Status: reviewed

## svt-av1.frames
Label: Frames To Be Encoded
Summary: Encodes only this many frames of your script instead of all of them; 0 means all frames. It is for test encodes, not for cutting a video.
When to change: Set a few hundred frames, or a few thousand for a whole scene, to try settings before committing hours to the full encode. Counting starts after Frames To Be Skipped, and a negative number encodes everything except that many frames at the end. To cut a video for real, select the parts to keep in the preview window's Cut menu; this control only shortens the video stream.
Example: Set 1500 here and 20000 in Frames To Be Skipped to encode one minute of a 25 fps movie starting about 13 minutes in. A number larger than what is left after the skip is cut down to fit, so the encoder never loops back to the start.
Related: svt-av1.skip, staxrip.chunks
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.skip
Label: Frames To Be Skipped
Summary: Leaves out this many frames at the start of your script and begins the encode after them; 0 starts at the first frame. It is for test encodes, not for cutting a video.
When to change: Use it with Frames To Be Encoded to test a scene from the middle of the video instead of the opening. Unless Chunks is above 1, the skipped frames are still decoded and piped to the encoder, which drops them, so a large skip takes a while to reach the first encoded frame. To cut a video for real, select the parts to keep in the preview window's Cut menu; this only shortens the video stream.
Example: With a 24 fps source, 14400 skipped frames start the test 10 minutes in.
Related: svt-av1.frames, staxrip.chunks
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.color-format
Label: Encoder Color Format
Summary: Tells the encoder how the color is sampled in the frames it receives. The encoder that ships with StaxRip supports only 4:2:0.
When to change: Leave it at 1: YUV420. In a test with the bundled build, every other choice stopped the encode at once with "Only support 420 now"; 2 and 3 also demand profile 1 or 2, which failed too with 8-bit 4:2:0 video. The names describe chroma subsampling, the share of color detail kept next to the brightness: 4:2:0 a quarter, 4:2:2 half, 4:4:4 all, 4:0:0 none.
Values:
- 0: Grayscale with no color. The bundled build refuses it with "Only support 420 now".
- 1: 4:2:0. The encoder default and the only format the bundled build accepts.
- 2: 4:2:2. Refused by the bundled build, which also asks for profile 1 or 2; those failed too with 8-bit 4:2:0 input.
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
When to change: Leave it at MAX. Drop to a lower set only to check whether a crash or a corrupt picture comes from a CPU-specific code path; the encoder prints the set it selected in its banner. In a test with the bundled build (160x120 clip, Ryzen 9 5950X), SSE2 and SSE3 crashed the encoder at presets 10 to 13 and ran at presets 8 and 9, while every other choice ran and produced a file of the same size.
Values:
- c: No CPU-specific instructions at all. Ran in the test.
- sse2: Crashed the bundled build in the test at presets 10 to 13, the quick-test presets; ran at 9 and below. Avoid.
- sse3: Crashed the bundled build in the test at presets 10 to 13, once leaving a 4 KB stub; ran at 8 and 9. Avoid.
- sse4_2: The bundled build reported sse4_1 as the selected set for this choice.
- avx512: Used only when your CPU has it; otherwise the build picks the next set your CPU supports.
- max: Everything your CPU supports. The encoder default and StaxRip's.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
Status: reviewed

## svt-av1.lp
Label: Level Of Parallelism
Summary: Controls how much parallel work SVT-AV1 creates, including threads and picture buffers. 0 lets the encoder choose for your CPU.
When to change: Leave it at 0 for a single encode. Set a low explicit level when you need to reduce CPU or memory use, or when several encodes are running at once. The level is not a thread count. Upstream says levels 4 and up also work on extra groups of frames at once in CRF mode, at a much higher memory cost, and that in the default CRF setup the picture is the same at level 1 as at higher levels.
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
Summary: Records an AV1 level in the stream, the rank from the AV1 specification that tells a player how demanding the video is. Autodetect lets the encoder work it out from the input.
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
Related: svt-av1.preset, svt-av1.crf, concept.psnr, concept.ssim, concept.vmaf, concept.vq
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## svt-av1.fast-decode
Label: Fast Decode
Summary: Shapes the stream so a player needs less work to decode it, at a possible cost in picture quality. Off leaves the encoder free to use every tool it has.
When to change: Turn it on when a player stutters on your AV1 files, most often software decoding on slow hardware. Upstream says level 1 can help even where the player has no multithreading, and that 2 decodes faster still. Upstream also notes it changes the layering of frames by default, which Hierarchical Levels can override. Test on the weakest player you care about.
Values:
- 0: Off. The default; no decoding shortcuts.
- 1: Upstream's first suggestion for a stuttering player; it says the gain can come even without multithreaded decoding.
- 2: The faster of the two levels for the decoder, per upstream. Check the picture.
Related: svt-av1.preset, svt-av1.hierarchical-levels
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
- 32: Prevents 64-point transforms. The bundled build warns this can cost efficiency at low to medium quality.
- 64: Every transform size allowed. The encoder default.
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
Status: reviewed

## svt-av1.rc
Label: Rate Control Mode
Summary: Chooses what the encoder holds steady: a quality level (Quality, the default) or a bitrate (Variable or Constant Bitrate). It decides which controls below appear and which the encoder uses.
When to change: Leave it at Quality for video you keep; set the level with Constant Rate Factor and the size follows. Use Variable Bitrate when the file must hit a size; the main window's size and bitrate boxes then feed Target Bitrate. Constant Bitrate needs Prediction Structure at Low Delay and Variable Bitrate needs Random Access, the default; the bundled build stops on the wrong pairing (tested).
Example: Encode the same clip once at Quality with CRF 35 and once at Variable Bitrate with the size the first run produced, and compare the look. Upstream recommends the quality mode wherever a target size is not required.
Values:
- 0: Quality. Holds a quality level; Adaptive Quantization decides whether you set it as CRF, QP, or CQP. The default.
- 1: Variable Bitrate. Aims at Target Bitrate over the whole video; needs Prediction Structure at Random Access (tested).
- 2: Constant Bitrate. Holds the target throughout; the bundled build refuses it unless Prediction Structure is Low Delay.
Related: svt-av1.crf, svt-av1.tbr, svt-av1.aq-mode, svt-av1.pass, svt-av1.pred-struct, staxrip.comp-check, concept.rate-control, concept.bitrate, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#bitrate-control-modes
Status: reviewed

## svt-av1.crf
Label: Constant Rate Factor
Summary: Sets the quality level the encoder keeps for the whole video: lower is a better picture and a larger file, higher is smaller and rougher. It is the main dial in the default Quality mode.
Used when: Rate Control Mode at Quality with Adaptive Quantization at 2, the defaults. With a bitrate target it is not sent; with Adaptive Quantization 0 or 1 you set CQP or QP instead.
When to change: StaxRip starts you at 35, which is also the encoder's default. The dialog takes 1 to 70 in steps of 0.25. Lower it for quality and raise it for a small file, then judge a short test encode by eye rather than by the number. The main window's encoder panel shows the same value as Quality, with named steps from 15 (incredible high) through 35 (higher, the default) to 60 (ultra low).
Example: Encode the same 60-second scene at CRF 30 and at CRF 40 with everything else unchanged. Compare the two file sizes, then step through a detailed frame in each; take the higher value if you cannot see the difference.
Related: svt-av1.rc, svt-av1.aq-mode, svt-av1.mbr, svt-av1.cqp, svt-av1.qp, svt-av1.preset, concept.quality-level, concept.compression-efficiency
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#bitrate-control-modes
Status: reviewed

## svt-av1.cqp
Label: Constant Quantization Parameter
Summary: Sets one fixed quantizer for the whole video on the same 1 to 70 scale as CRF, but with adaptive quantization off: lower is a better picture and a larger file.
Used when: Quality mode with Adaptive Quantization at 0: Off. The help likens it to `--rc 0 --aq-mode 0 --qp x`; in a test, `--cqp 30` and `--crf 30` gave identical output with adaptive quantization off.
When to change: Leave Adaptive Quantization at 2 and use Constant Rate Factor unless you want every frame quantized the same way, say for a comparison. With adaptive quantization off the bundled build also switches off its temporal dependency model (TPL) and ignores Maximum Bitrate; it prints a warning for each. StaxRip starts you at 35, the encoder default, in steps of 0.25.
Related: svt-av1.crf, svt-av1.qp, svt-av1.aq-mode, svt-av1.rc, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.qp
Label: Quantization Parameter
Summary: Sets the base quantizer for the video as a whole number from 1 to 63; lower is a better picture and a larger file. Keyframes and the lower frame layers get offsets from it.
Used when: Rate Control Mode at Quality with Adaptive Quantization at 1, which the bundled build labels a demo and experimentation feature in a warning.
When to change: Prefer Constant Rate Factor; this control appears only with Adaptive Quantization level 1, which the bundled build says is not ready for benchmarking. Whole numbers only: in a test the bundled build refused 30.5 and 64. StaxRip starts you at 35, the encoder default.
Related: svt-av1.crf, svt-av1.cqp, svt-av1.aq-mode, svt-av1.rc, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#usefixedqindexoffsets-and-more-information
Status: reviewed

## svt-av1.tbr
Label: Target Bitrate
Summary: The average bitrate in kbps the encoder aims for when Rate Control Mode is Variable Bitrate or Constant Bitrate. With the running time it sets the file size.
Used when: Variable Bitrate and Constant Bitrate. StaxRip always sends it in those modes and never in Quality mode.
When to change: Set the size or bitrate in the main window instead; both boxes feed this value, and Comp. Check can set it for you. Range 100 to 100000 kbps. A value typed here is used by a single pass or the first pass; later passes take the main window's bitrate. The help names 7000 as the encoder's default, but a run without the switch used 2000, as upstream documents; StaxRip sends the value anyway.
Example: Type a size into the main window's target size box and reopen this dialog: this value follows. Twenty minutes at 4000 kbps is roughly 600 MB of video before audio (4000 x 1200 / 8 / 1000).
Related: svt-av1.rc, svt-av1.mbr, svt-av1.max-qp, svt-av1.min-qp, svt-av1.pass, staxrip.comp-check, staxrip.aimed-quality, concept.bitrate, concept.rate-control
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#bitrate-control-modes
Status: reviewed

## svt-av1.mbr
Label: Maximum Bitrate
Summary: Caps the bitrate of a CRF encode in kbps: the encoder keeps the CRF quality where it fits under the cap and cuts back where it would not. 0 means no cap; the encoder calls the result capped CRF.
Used when: Only with Constant Rate Factor visible, that is Quality mode with Adaptive Quantization 2. With a bitrate target the bundled build refuses it, and with CQP it ignores it with a warning (tested).
When to change: Leave it at 0 unless a player or a bandwidth limit needs a ceiling; then set the ceiling and check the hardest scene. In a test on a small clip, CRF 20 with a cap below its natural rate came out at the cap, and a cap above it left the file byte for byte unchanged. The dialog goes up to 100000 kbps in steps of 100.
Related: svt-av1.crf, svt-av1.tbr, svt-av1.rc, svt-av1.aq-mode, concept.bitrate
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.max-qp
Label: Maximum Quantizer
Summary: Caps how coarse the quantizer may get in a bitrate encode; 63, the default and the top of the AV1 scale, means no cap. Lowering it puts a floor under the roughest frames.
Used when: Shown with Variable Bitrate or Constant Bitrate and not sent in Quality mode. The help ties it to VBR and CBR, though in a test it changed a CRF encode too (reachable only through Custom).
When to change: Leave it at 63. If a bitrate encode has frames that look too rough, lower it a little and re-check the size: a cap leaves the encoder fewer ways to hold the target in hard scenes. It must stay at or above Minimum Quantizer, or the bundled build stops with "MinQpAllowed must be smaller than or equal to MaxQpAllowed".
Related: svt-av1.min-qp, svt-av1.tbr, svt-av1.rc, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.min-qp
Label: Minimum Quantizer
Summary: Sets the finest quantizer a bitrate encode may use; 1 is the finest the dialog offers. Raising it stops any frame from being quantized finer than that, however easy the scene.
Used when: Shown with Variable Bitrate or Constant Bitrate and not sent in Quality mode. The help ties it to VBR and CBR, though in a test it changed a CRF encode too (reachable only through Custom).
When to change: Leave it at 1, the default in the bundled help; the upstream document says 0, and the bundled build accepted 0 in a test. The dialog goes up to 62. Keep it at or below Maximum Quantizer, or the bundled build stops before encoding. Both at the same number ran in a test; that pins the quantizer there whatever the target.
Related: svt-av1.max-qp, svt-av1.tbr, svt-av1.rc, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.tf-strength
Label: Temporal Filtering Strength
Summary: Sets how strongly the encoder smooths its alternate reference frames by averaging across neighboring frames, 0 to 4; higher is stronger. Upstream says the visible effect depends on the material.
Used when: Only while ALT-REF Frames (the temporally filtered frames, on the AV1 Specific page) is on; with it off, 0, 3 and 4 gave byte-identical output in a test.
When to change: Leave it at 3. Lower it if grain or fine texture looks softened in a test encode, raise it on clean, static footage, and compare a short scene each way. With Tune VQ the encoder also applies a keyframe offset, per upstream.
Values:
- 0: The weakest setting.
- 3: The encoder default and StaxRip's.
- 4: The strongest filtering.
Related: svt-av1.tune, svt-av1.ac-bias
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.luminance-qp-bias
Label: Luminance QP Bias
Summary: Shifts each frame's quantizer by how dark the frame is on average, so dark scenes get finer quantization; 0 is off and 100 the strongest shift. Upstream added it to improve quality in dark scenes.
When to change: Leave it at 0 unless dark scenes lose detail or show banding in a test encode. Then try a moderate value and compare the dark scene and the file size; the help gives no guidance on strength, so treat it as an experiment. The bundled build accepted 100 in a test.
Related: svt-av1.crf, svt-av1.aq-mode, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
Status: reviewed

## svt-av1.sharpness
Label: Sharpness Bias
Summary: Biases the deblocking filter and the rate control toward a softer (negative) or sharper (positive) picture, -7 to 7. Upstream says it may help perceived quality in video too.
Used when: Ignored with Tune 4: MS-SSIM, which overrides it; the bundled build says so in a warning. Tune 3 overrides it too but stops anyway with the usual prediction structure.
When to change: Leave it at 0. Try 1 or 2 when a test encode looks soft, and compare the file size as well as the picture: in a test on a small clip, 7 gave a clearly larger file than 0 and -7 a smaller one, so the bias spends and saves bits, not only filtering. Upstream made it for the still-image tunes.
Values:
- -7: Softest bias. In a test the file got smaller than at 0.
- 0: No bias. The encoder default and StaxRip's.
- 7: Sharpest bias. In a test the file got clearly larger than at 0.
Related: svt-av1.tune, svt-av1.ac-bias
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
Status: reviewed

## svt-av1.pass
Label: Passes
Summary: Chooses whether the encoder first analyzes the whole video and then encodes it with that knowledge, so a bitrate target is met more accurately. 1-pass encodes in one go.
Used when: Shown with Variable Bitrate (1 or 2 passes) or Constant Bitrate (1 to 3). Quality mode has no pass control, and the bundled build refuses a second pass in CRF mode anyway (tested).
When to change: For Variable Bitrate pick 2-pass when the size matters; upstream says multi-pass helps VBR reach its target. For Constant Bitrate leave it at 1-pass: the bundled build refuses multi-pass with the Low Delay structure CBR needs, and `--pass 3` outright (tested), so 2-pass and 3-pass fail. StaxRip keeps the first-pass statistics in a file named after the output plus `_2pass.log`.
Values:
- 1: One pass. The default, and the only choice that works for Constant Bitrate in the bundled build.
- 2: First pass gathers statistics, second pass encodes with them. Works for Variable Bitrate (tested).
- 3: Constant Bitrate only. The bundled build refuses multi-pass CBR and `--pass 3` itself, so nothing is encoded.
Related: svt-av1.rc, svt-av1.tbr, svt-av1.pred-struct, staxrip.custom, concept.two-pass
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#multi-pass-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#pass-information
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#multi-pass-encoding
Status: reviewed

## svt-av1.aq-mode
Label: Adaptive Quantization
Summary: Lets the encoder vary the quantizer within a frame instead of using one value everywhere. In StaxRip it also decides which quality control you set: CQP at 0, QP at 1, CRF at 2.
When to change: Leave it at 2, the encoder default, and set the quality with Constant Rate Factor. Level 0 turns adaptive quantization off, and with it the temporal dependency model (TPL) and Maximum Bitrate, as the bundled build warns. Level 1 is described by the bundled build as a demo and experimentation feature that should not be used for benchmarking.
Values:
- 0: Off. One quantizer per frame, set as CQP. The bundled build also disables TPL and ignores Maximum Bitrate (tested).
- 1: Variance based, using AV1 segments; set as QP. The bundled build warns it is at demo and experimentation level.
- 2: Per-block deltas driven by prediction efficiency; set as CRF. The encoder default and StaxRip's.
Related: svt-av1.crf, svt-av1.cqp, svt-av1.qp, svt-av1.mbr, svt-av1.rc
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.hbd-mds
Label: High Bit Depth Mode Decisions
Summary: Chooses the bit depth the encoder uses for its mode decisions with 10-bit video: 8-bit, 10-bit, or a mix. -1 lets the preset decide, and in this dialog it is the only entry that works.
Used when: 10-bit video only. Upstream says 10-bit decisions need 10-bit input, and the bundled build refuses 1 and 2 with 8-bit video (tested).
When to change: Leave it at -1: Off. StaxRip sends each entry's position rather than the number in its label, so the list is off by one and every other entry either stops the encode or, with 10-bit video, crashed the bundled build in a test unless Level Of Parallelism was 1 to 3. The notes on each entry say what is sent.
Encoder default: -1
Example: To try 10-bit mode decisions, put `--hbd-mds 1` in the Custom box (StaxRip then drops its own copy) and set Level Of Parallelism to 1 to 3, which slows the encode: in a test (640x480 10-bit clip, 16-core machine) 1 and 2 ran at 1 to 3, crashed intermittently at 4 and always at 5 and 6.
Values:
- 0: The -1: Off entry. Nothing is sent and the preset decides; the only entry that works in this dialog.
- 1: The 0: Forces 8-bit entry sends `--hbd-mds 1` (10-bit): refused for 8-bit video, crashed with 10-bit in a test.
- 2: The 1: Forces 10-bit entry sends `--hbd-mds 2` (hybrid): refused for 8-bit video, crashed with 10-bit in a test.
- 3: The 2: 8/10-bit Hybrid entry sends `--hbd-mds 3`, outside the encoder's range; the bundled build always stops.
Related: svt-av1.lp, svt-av1.preset, staxrip.custom
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#8-or-10-bit-encoding
Status: reviewed

## svt-av1.qp-scale-compress-strength
Label: QP Scale Compress Strength
Summary: Narrows the spread of quantizers between the frame layers of each group of pictures, 0 (off) to 3, so quality is steadier from frame to frame at some cost in average quality, per upstream.
When to change: Leave it at 0 unless quality pulses between frames. Upstream calls 1 nearly free at almost any quality level, 2 the choice for high-quality encodes, and 3 the limit for the highest fidelity or a very low CRF, where it can even improve fidelity. Reference frames then sit closer in quality to the frames built on them, so upstream expects average quality to drop; check a short scene.
Related: svt-av1.crf, svt-av1.aq-mode, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.ac-bias
Label: AC Bias in Rate Distortion
Summary: Tilts the encoder's rate-distortion choices toward keeping high-frequency detail such as texture and grain, from 0.0 (off) to 8.0. Upstream calls it an energy-preserving psychovisual metric.
When to change: Leave it at 0.0 for a first encode. Upstream suggests 1.0 to 1.5 to keep textures and busy motion crisp, and 4.0 to 6.0 together with temporal filtering and CDEF (the Constrained Directional Enhancement Filter) turned off to retain film grain and noise. It costs bits: in a test on a small clip, 1.25 and 8 both grew the file. Compare a grainy scene at 0 and at 1.25 before using it everywhere.
Related: svt-av1.sharpness, svt-av1.tf-strength, svt-av1.tune
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.recode-loop
Label: Recode Loop
Summary: Lets the encoder encode a frame a second time when the first try misses its bitrate limits; higher levels allow it for more frame types. 4 leaves the choice to the preset.
Used when: Matters for bitrate targets: in a test with the bundled build, changing it left a CRF encode byte for byte unchanged and altered a Variable Bitrate encode.
When to change: Leave it at 4. Encoding a frame twice takes time and only helps when a frame overshoots a bitrate limit, so try 0 to speed up a bitrate encode that lands close to its target anyway, or 3 when a Variable Bitrate encode misses its target badly and time is no object. The bundled help states no default; upstream's table says 4.
Values:
- 0: Off. No frame is encoded twice.
- 1: Keyframes, and any frame that exceeds the maximum frame bandwidth.
- 2: Keyframes, alternate reference frames, and golden frames only.
- 3: Every frame type, when bitrate constraints call for it.
- 4: The preset decides. The default per upstream and StaxRip's.
Related: svt-av1.rc, svt-av1.tbr, svt-av1.preset
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#recode-loop-level-table
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.enable-qm
Label: Enable quantisation matrices
Summary: Turns on quantization matrices, which weight frequencies differently instead of treating every coefficient the same. In CRF mode upstream expects a smaller file with slightly lower quality.
When to change: Leave it off unless you want a smaller file and accept a little quality loss. Upstream says the saving is larger at a low CRF than at a high one; in a test on a small synthetic clip, turning it on at CRF 20 with flatness 0 to 15 cut the file by more than a quarter. Set the range with Min and Max quant matrix flatness; Tune MS-SSIM overrides all three (bundled build warning).
Related: svt-av1.qm-min, svt-av1.qm-max, svt-av1.crf, svt-av1.tune
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#enableqm-and-more-information
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.qm-max
Label: Max quant matrix flatness
Summary: The flattest quantization matrix the encoder may pick, 0 to 15; 15 is fully flat, with no frequency weighting. The encoder picks each frame's level between Min and Max from its quantizer.
Used when: Only with Enable quantisation matrices on. The control is always shown, but the encoder ignores the value while matrices are off (tested: byte-identical output).
When to change: Leave it at 15. Lower it to force some weighting on every frame, which shrinks the file further at a quality cost. Keep it at or above Min quant matrix flatness, or the bundled build stops before encoding; in a test, matrices on with Min and Max both at 0 gave the smallest file of the settings tried.
Related: svt-av1.qm-min, svt-av1.enable-qm
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#enableqm-and-more-information
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.qm-min
Label: Min quant matrix flatness
Summary: The least flat quantization matrix the encoder may pick, 0 (strongest frequency weighting) to 15 (flat). The encoder maps each frame's quantizer onto the range from here to Max.
Used when: Shown and sent only with Enable quantisation matrices on.
When to change: Leave it at 8, the encoder default. Lower it toward 0 for a smaller file at some quality cost; upstream's own example uses 0 to 15. Keep it at or below Max quant matrix flatness, or the bundled build stops with "Min quant matrix level must not greater than max quant matrix level".
Related: svt-av1.qm-max, svt-av1.enable-qm
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#enableqm-and-more-information
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.keyint
Label: Keyint / GOP Size
Summary: Sets how often a new group of pictures starts with a keyframe, a frame stored whole. Closer keyframes make seeking quicker and the file larger; the default is about five seconds.
Used when: Two lists share this switch: with Constant Rate Factor on screen you get -1 for a single keyframe, otherwise 0 instead. Nothing is sent at the default entry; the encoder's own -2 applies.
When to change: Leave it at -2 for video you keep; upstream says home users often choose 5 to 10 seconds, and every keyframe costs bits. Pick 1s or 2s when quick seeking matters more than size; upstream says video-on-demand services commonly use about one second. In Variable Bitrate the default and the seconds entries work; on 0 the bundled build writes no file yet reports success (tested).
Example: Encode a short scene at -2 and again at 1s, compare the two sizes, then seek around both files in your player. In tests the bundled build reported a GOP of 161 frames for -2 at 24, 25 and 30 fps and 321 frames at 60 fps: about five seconds at 30 and 60, nearer seven at 24.
Values:
- -2: The encoder default and StaxRip's; 161 frames in tests, about five seconds, nearer seven at 24 fps.
- -1: One keyframe at the start and never again. Offered with Constant Rate Factor; the help calls it CRF-only.
- 0: Same as -1, for the other modes. Variable Bitrate writes no file yet reports success; Constant Bitrate ran (tested).
- 1s: A keyframe about every second at your frame rate; in tests it came one frame later than the rate, 26 at 25 fps.
- 10s: The longest entry. Upstream calls 5 to 10 seconds common for home use.
Related: svt-av1.irefresh-type, svt-av1.scd, svt-av1.rc, staxrip.chunks, concept.keyframe, concept.gop
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#gop-size-selection
Status: reviewed

## svt-av1.irefresh-type
Label: Intra Refresh Type
Summary: Chooses what opens each new group of pictures: a keyframe that closes the group, or a forward keyframe that leaves it open so frames just before it may predict from it. Closed is the default.
Used when: In effect Quality mode only: Variable Bitrate kept closed groups with 1 selected, and Constant Bitrate with Low Delay hung the bundled build without finishing (tested).
When to change: Leave it at 2: Key Frame. Closed groups are the safe choice for seeking and cutting. Try 1 only as an experiment in Quality mode: the bundled build then forces Hierarchical Levels to 4 with a warning, and the help says no more about it. Never pick 1 with Constant Bitrate: in a test the encoder printed "Unexpected temporal_layer" errors, wrote a 4 KB stub and never finished.
Values:
- 1: Forward keyframe (open GOP). Forces Hierarchical Levels 4; ignored in Variable Bitrate; hangs Constant Bitrate.
- 2: Keyframe, closed GOP. The encoder default and StaxRip's.
Related: svt-av1.keyint, svt-av1.hierarchical-levels, svt-av1.pred-struct, svt-av1.rc, concept.keyframe, concept.gop
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
Status: reviewed

## svt-av1.scd
Label: Scene Change Detection Control
Summary: Turns on the encoder's scene change detector, which adds no keyframe at a cut: upstream says the encoder handles scene changes in its mode decisions instead, and the bundled build warns as much.
When to change: Leave it off. In tests with a hard cut in the clip, turning it on left CRF and Constant Bitrate output byte for byte unchanged and printed "will not insert a key frame at scene changes" every time. To get a keyframe at a cut, put `--force-key-frames` with the frame or time in the Custom box; upstream documents it for CRF only.
Values:
- 0: Off. The encoder default and StaxRip's.
- 1: On. No keyframe at cuts; the bundled build says so in a warning. CRF output was unchanged in a test.
Related: svt-av1.keyint, staxrip.custom, concept.scene-change, concept.keyframe
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#scene-change-detection
Status: reviewed

## svt-av1.lookahead
Label: Lookahead
Summary: Controls how many frames ahead of the ones it is coding the encoder looks, so it can plan bits and frame types with what comes next in view; -1 lets it choose. A longer lookahead costs memory.
When to change: Leave it at -1. The bundled build sets its own bounds anyway: a 2-pass Variable Bitrate run caps it at 42 with a warning, and 0 in Variable Bitrate was raised to 25 (tested). Do not type -1 into the Custom box: the bundled build refuses `--lookahead -1` as invalid; StaxRip sends nothing at -1. Values above 120 are refused.
Example: In a CRF test on a 6-second synthetic clip (160x120, 25 fps, preset 8), 0, 10, 24, 25 and 26 all gave the same file, about a quarter larger than at -1, while 32, 42, 60 and 120 matched the default byte for byte. Check a real scene before trusting a number.
Related: svt-av1.pass, svt-av1.rc, svt-av1.hierarchical-levels, svt-av1.tf-strength, staxrip.custom, concept.lookahead
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
Status: reviewed

## svt-av1.hierarchical-levels
Label: Hierarchical Levels
Summary: Sets the frame layers per mini-GOP, 0 (flat) to 5 (six layers, 32 frames). Per upstream, slower presets use more layers for efficiency and fewer make a simpler stream that decodes faster.
Used when: Bounded by other choices: Constant Bitrate caps it at 2 and open GOP (Intra Refresh Type 1) forces 4, each with a warning from the bundled build (tested).
When to change: Leave it alone. StaxRip sends nothing at its default entry, so the encoder picks by preset. In CRF tests that was 5 up to preset 8 and 4 from preset 9, and 4 in Variable Bitrate at presets 4 to 10; the help's "5 up to preset 12" did not hold. The entry marked default says 4, and changing Preset here moves the default to 3 (2 at preset 13); neither is sent. Any other entry you pick is sent.
Encoder default: 5 or 4 by preset, see below
Values:
- 0: Flat, no layers, one-frame mini-GOPs. Accepted by the bundled build although its help starts at 2.
- 2: Three layers, 4-frame mini-GOPs. Constant Bitrate's ceiling: the bundled build caps it there with a warning.
- 3: Four layers, 8-frame mini-GOPs. Where StaxRip's default entry lands after you change Preset here.
- 4: Five layers, 16-frame mini-GOPs. StaxRip's default entry; the encoder's pick from preset 9 and in Variable Bitrate.
- 5: Six layers, 32-frame mini-GOPs. The encoder's pick up to preset 8 in CRF tests; the help says up to preset 12.
Related: svt-av1.preset, svt-av1.fast-decode, svt-av1.pred-struct, svt-av1.irefresh-type, svt-av1.rc, svt-av1.qp-scale-compress-strength, svt-av1.startup-mg-size, concept.gop
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.pred-struct
Label: Prediction Structure
Summary: Chooses how frames may borrow from each other: Random Access lets a frame predict from pictures before and after it; Low Delay only from earlier ones, for live use, at a cost in compression.
Used when: Variable Bitrate needs Random Access and Constant Bitrate needs Low Delay; the bundled build stops on either other pairing. Quality mode (CRF, CQP) ran with both (tested).
When to change: Leave it at 2: Random Access unless you choose Constant Bitrate, which the bundled build refuses with it ("use VBR mode"); then pick 1: Low Delay. The price: in a CRF test on a small synthetic clip the Low Delay file was about 70% larger, upstream says low delay handles one picture at a time, and the bundled build refuses multi-pass with it. Tune 3 (still-image quality) needs it too.
Values:
- 1: Low Delay. Required for Constant Bitrate; no multi-pass with it, and about 70% larger in a CRF test.
- 2: Random Access. The encoder default and StaxRip's; required for Variable Bitrate (tested).
Related: svt-av1.rc, svt-av1.pass, svt-av1.hierarchical-levels, svt-av1.irefresh-type, svt-av1.tune, svt-av1.lp, concept.rate-control
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-a-encoder-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#bitrate-control-modes
Status: reviewed

## svt-av1.enable-dg
Label: Dynamic GOP
Summary: Lets the encoder reshape the layer structure of a mini-GOP to suit the content instead of keeping one fixed pattern, per upstream. On by default; the keyframe spacing stays as set.
When to change: Leave it on. Upstream's one-line description is all the documentation there is. In tests on short synthetic clips, turning it off left CRF encodes at presets 4 and 8 byte for byte unchanged. Turn it off only to hold the layer structure fixed for an experiment of your own.
Values:
- 0: Off, one fixed structure. Changed nothing in CRF tests.
- 1: On. The encoder default and StaxRip's.
Related: svt-av1.hierarchical-levels, svt-av1.startup-mg-size, svt-av1.rc, concept.gop
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
Status: reviewed

## svt-av1.startup-mg-size
Label: Startup Mini-GOP Size
Summary: Gives the first mini-GOP after each keyframe a layer structure of its own, 3 to 5 layers; 0 keeps the usual one. Quality mode only.
Used when: Quality mode only. In Variable or Constant Bitrate the bundled build stops with "Startup MG size feature only supports CRF/CQP rate control mode" (tested); the control stays visible anyway.
When to change: Leave it at 0. The help says only that it swaps in another mini-GOP configuration after each keyframe, nothing about when that helps, so treat it as an experiment: in a test on a synthetic clip, 2, 3 and 4 each moved the file size by up to about a tenth, up or down, with no keyframe change. Set it back to 0 before a bitrate encode or the encode stops.
Values:
- 0: Off. The encoder default and StaxRip's.
- 2: Three layers for the first mini-GOP after each keyframe.
- 3: Four layers for the first mini-GOP.
- 4: Five layers for the first mini-GOP.
Related: svt-av1.hierarchical-levels, svt-av1.keyint, svt-av1.enable-dg, svt-av1.rc, concept.gop
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#gop-size-and-type-options
Status: reviewed

## svt-av1.enable-variance-boost
Label: Enable Variance Boost
Summary: Gives flat, low-detail areas more bits by lowering their quantizer, so smooth gradients keep their detail instead of turning into bands or blocks. Off by default; the file grows.
Used when: Not applied with Constant Bitrate or with Adaptive Quantization 1: the bundled build switches it off with a warning in both cases (tested). Tune MS-SSIM overrides its strength.
When to change: Turn it on when flat areas such as skies, walls or gradients band or block in a test encode, then compare that scene and the file size against the same encode without it. Strength and Octile appear once it is on; start with their defaults. It costs bits: in a test on a small synthetic clip the file grew markedly at the default strength. For dark scenes as such, see Luminance QP Bias.
Example: A 160x120 synthetic gradient-and-noise clip (3 s, CRF 35, preset 8) went from 16278 bytes off to 48234 on; such clips exaggerate. On your footage, encode a short scene with large smooth areas both ways, compare those frames, and decide whether the cleaner gradients are worth the bits.
Values:
- 0: Off. The encoder default and StaxRip's.
- 1: On; shows Strength and Octile. The bundled build turns it off with Constant Bitrate or Adaptive Quantization 1.
Related: svt-av1.variance-boost-strength, svt-av1.variance-octile, svt-av1.aq-mode, svt-av1.luminance-qp-bias, svt-av1.tune, svt-av1.rc, concept.quality-level
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.variance-boost-strength
Label: Variance Boost Strength
Summary: Sets how much extra quality the flat areas get, 1 (mild) to 4 (aggressive). Each step spends more bits there, so expect a larger file.
Used when: Only with Enable Variance Boost on; the control is hidden otherwise. Tune MS-SSIM overrides it, per the bundled build's warning.
When to change: Leave it at 2: Gentle, the encoder default. Go to 3 only if banding survives at 2, and compare the size: in a test on a small synthetic clip the file grew with every step, and 4 gave the largest file by far. The bundled build warns that 4 is a curve for specific situations, to be used with caution.
Values:
- 1: Mild.
- 2: Gentle. The encoder default and StaxRip's.
- 3: Medium.
- 4: Aggressive. The bundled build warns it is only useful in specific situations and says to use it with caution.
Related: svt-av1.enable-variance-boost, svt-av1.variance-octile, svt-av1.tune
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.variance-octile
Label: Variance Octile
Summary: Sets how picky the boost is about flatness: the encoder ranks each area's 8x8 blocks by variance and judges it by the block at this eighth. Lower boosts more of the picture, higher less.
Used when: Only with Enable Variance Boost on; the control is hidden otherwise.
When to change: Leave it at 5: 5/8th, the encoder default. Lower it to spread the boost over more of the picture, raise it to confine it to areas that are flat throughout; in a test on a small synthetic clip the file shrank steadily as the octile rose, 1 giving the largest file and 8 the smallest.
Values:
- 1: The flattest eighth decides, so an area counts as flat when an eighth of its blocks are. Largest file in the test.
- 4: The median block decides.
- 5: The encoder default and StaxRip's.
- 8: The busiest block decides, so only areas flat throughout are boosted. Smallest file in the test.
Related: svt-av1.enable-variance-boost, svt-av1.variance-boost-strength
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed
