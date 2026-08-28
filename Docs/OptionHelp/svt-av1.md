# SVT-AV1 option help

Schema: 1
Encoder: svt-av1
Locale: en
Title: SVT-AV1
Source: Source/Encoding/SvtAv1Enc.vb
Allowed-Missing: 0
Minimum-Reviewed: 100
Reviewed-Complete: true
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
Related: svt-av1.crf, svt-av1.tune, svt-av1.hierarchical-levels, concept.compression-efficiency
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
Related: svt-av1.skip, svt-av1.avif, staxrip.chunks
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
Related: svt-av1.profile, svt-av1.chroma-sample-position
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
Related: svt-av1.pin, svt-av1.ss, svt-av1.hbd-mds, svt-av1.enable-tf, concept.parallelism
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-a-encoder-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#threading-and-efficiency
Status: reviewed

## svt-av1.pin
Label: Pinned Execution
Summary: The encoder that ships with StaxRip does not accept this switch, so the dialog no longer offers it. Upstream documents `--pin` as running the encoder on the first N CPU cores only.
When to change: Nothing to set here. `--pin` on the command line stops the bundled build before encoding with "Unprocessed tokens: --pin", so the encode does not start (checked on 2026-08-27 with a test clip). To limit the encoder's CPU and memory use, lower Level Of Parallelism instead.
Related: svt-av1.lp, svt-av1.ss, concept.parallelism
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-a-encoder-parameters
Status: reviewed

## svt-av1.ss
Label: Target Socket
Summary: The encoder that ships with StaxRip does not accept this switch, so the dialog no longer offers it. Target Socket once told the encoder which CPU socket to run on; no current document describes it.
When to change: Nothing to set here. `--ss` on the command line stops the bundled build before encoding with "Unprocessed tokens: --ss", so the encode does not start (checked on 2026-08-27).
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
When to change: Leave it at Autodetect unless a delivery target names a level. You can pick 2.0, 2.1, 3.0, 3.1, 4.0, 4.1, 5.0 to 5.3 and 6.0 to 6.3. The AV1 format can express ten more level numbers that the specification has not defined yet, so no encoder can produce them and the list leaves them out. The help does not say whether a chosen level constrains the encode or only labels it.
Values:
- 0: Autodetect from input. The encoder default; its banner then shows the level as auto.
- 2.2: Not defined in the AV1 specification, so the list leaves it out.
- 2.3: Not defined in the AV1 specification, so the list leaves it out.
- 3.2: Not defined in the AV1 specification, so the list leaves it out.
- 3.3: Not defined in the AV1 specification, so the list leaves it out.
- 4.2: Not defined in the AV1 specification, so the list leaves it out.
- 4.3: Not defined in the AV1 specification, so the list leaves it out.
- 7.0: Not defined in the AV1 specification, so the list leaves it out.
- 7.1: Not defined in the AV1 specification, so the list leaves it out.
- 7.2: Not defined in the AV1 specification, so the list leaves it out.
- 7.3: Not defined in the AV1 specification, so the list leaves it out.
Related: svt-av1.profile
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#encoder-global-options
- https://aomediacodec.github.io/av1-spec/av1-spec.pdf
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
Related: svt-av1.film-grain
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
Related: svt-av1.crf, svt-av1.qp, svt-av1.aq-mode, svt-av1.rc, svt-av1.enable-tpl-la, concept.quality-level
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
When to change: Leave it at 0 unless a player or a bandwidth limit needs a ceiling; then set the ceiling and check the hardest scene. In a test on a small clip, CRF 20 with a cap well below its natural rate came out at the cap, and a cap above it left the file byte for byte unchanged. The dialog goes up to 100000 kbps in steps of 100.
Example: Test: 160x120 synthetic gradient-and-noise clip, 24 frames at 25 fps, preset 8, CRF 20; uncapped 60550 bytes, about 500 kbps. Cap 100: 12098 bytes; 200: 25878; 400: 60523; 1000: the uncapped file byte for byte.
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
Related: svt-av1.enable-tf, svt-av1.tune, svt-av1.ac-bias
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
Example: Test: 160x120 synthetic gradient-and-noise clip, 24 frames, preset 8, CRF 35: 4526 bytes at 0, 6558 at 7 (45% larger) and 4239 at -7 (6% smaller).
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
Used when: Shown with Variable Bitrate (1 or 2 passes) or Constant Bitrate (1-pass only). Quality mode has no pass control, and the bundled build refuses a second pass in CRF mode anyway (tested).
When to change: For Variable Bitrate pick 2-pass when the size matters; upstream says multi-pass helps VBR reach its target. For Constant Bitrate the list holds only 1-pass: the bundled build refuses multi-pass with the Low Delay structure CBR needs, and `--pass 3` outright (tested), so those entries are left out. StaxRip keeps the first-pass statistics in a file named after the output plus `_2pass.log`.
Values:
- 1: One pass. The default, and the only choice for Constant Bitrate in the bundled build.
- 2: First pass gathers statistics, second pass encodes with them. Works for Variable Bitrate (tested).
- 3: The list leaves it out: the bundled build refuses multi-pass CBR and `--pass 3` itself (tested).
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
Related: svt-av1.crf, svt-av1.cqp, svt-av1.qp, svt-av1.mbr, svt-av1.rc, svt-av1.enable-tpl-la
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.hbd-mds
Label: High Bit Depth Mode Decisions
Summary: Chooses the bit depth for the encoder's mode decisions (its block size and prediction choices) with 10-bit video: 8-bit, 10-bit, or a mix. -1 lets the preset decide.
Used when: 10-bit video only. Upstream says 10-bit decisions need 10-bit input, and the bundled build refuses 1 and 2 with 8-bit video (tested).
When to change: Leave it at -1: Off. With 10-bit video, 1 and 2 crashed the bundled build in a test unless Level Of Parallelism was 1 to 3, so set that first if you experiment; a crash can leave a partial file behind.
Encoder default: -1
Example: To try 10-bit mode decisions, pick 1: Forces 10-bit and set Level Of Parallelism to 1 to 3, which slows the encode: in a test (640x480 10-bit clip, 16-core machine) 1 and 2 ran at 1 to 3, crashed intermittently at 4 and always at 5 and 6.
Values:
- -1: Off. Nothing is sent and the preset decides. The encoder default and StaxRip's.
- 0: Mode decisions run in 8-bit even for 10-bit video.
- 1: 10-bit mode decisions: refused with 8-bit video, crashed with 10-bit above Level Of Parallelism 3 (tested).
- 2: 8/10-bit hybrid: refused with 8-bit video, crashed with 10-bit above Level Of Parallelism 3 (tested).
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
Summary: Tilts the encoder's trade of bits against picture error, its rate-distortion choices, toward keeping high-frequency detail such as texture and grain, from 0.0 (off) to 8.0.
When to change: Leave it at 0.0 for a first encode. Upstream suggests 1.0 to 1.5 to keep textures and busy motion crisp, and 4.0 to 6.0 together with temporal filtering and CDEF (the Constrained Directional Enhancement Filter) turned off to retain film grain and noise. It costs bits: in a test on a small clip, 1.25 and 8 both grew the file. Compare a grainy scene at 0 and at 1.25 before using it everywhere.
Example: Test: 160x120 synthetic gradient-and-noise clip, 24 frames, preset 8, CRF 35: 4526 bytes at 0, 5024 at 1.25 (11% larger) and 5838 at 8 (29% larger).
Related: svt-av1.sharpness, svt-av1.tf-strength, svt-av1.enable-cdef, svt-av1.tune
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#rate-control-options
Status: reviewed

## svt-av1.recode-loop
Label: Recode Loop
Summary: Lets the encoder encode a frame a second time when the first try misses its bitrate limits; higher levels allow it for more frame types. 4 leaves the choice to the preset.
Used when: Matters for bitrate targets, which is what upstream's recode table describes; in a test with the bundled build, changing it left a CRF encode byte for byte unchanged.
When to change: Leave it at 4. Encoding a frame twice takes time and only helps when a frame overshoots a bitrate limit; upstream's table says which frame types each level may recode and no more. If you experiment, try 0 on a bitrate encode that lands close to its target anyway and compare time and size on a short scene. The bundled help states no default; upstream's table says 4.
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
Used when: Shown and sent only with Enable quantisation matrices on.
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
Summary: Sets how often a new group of pictures starts with a keyframe, a frame stored whole. Closer keyframes make seeking quicker and the file larger; the default is five to seven seconds by frame rate.
Used when: Two lists share this switch: Constant Rate Factor offers -1 for a single keyframe, the other modes 0, hidden in Variable Bitrate. Nothing is sent at the default entry; the encoder's own -2 applies.
When to change: Leave it at -2 for video you keep; upstream says home users often choose 5 to 10 seconds, and every keyframe costs bits. Pick 1s or 2s when quick seeking matters more than size; upstream says video-on-demand services commonly use about one second. The list hides 0 in Variable Bitrate because the bundled build then writes no file yet reports success (tested).
Example: Encode a short scene at -2 and again at 1s, compare the two sizes, then seek around both files in your player. In tests -2 placed a keyframe every 161 frames from 23.976 to 30 fps and every 321 at 50 and 60 fps: 5.4 s at 30 and 60, 6.4 at 25 and 50, 6.7 at 24 and 23.976.
Values:
- -2: The encoder default and StaxRip's; 161 frames in tests, 321 at 50 and 60 fps: five to seven seconds by frame rate.
- -1: One keyframe at the start and never again. Offered with Constant Rate Factor; the help calls it CRF-only.
- 0: Same as -1; hidden in Variable Bitrate, which wrote no file yet reported success; Constant Bitrate ran (tested).
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
Used when: Quality mode only; with a bitrate target the control is hidden and nothing is sent. The bundled build stops a Variable or Constant Bitrate encode handed the switch (tested).
When to change: Leave it at 0. The help says only that it swaps in another mini-GOP configuration after each keyframe, nothing about when that helps, so treat it as an experiment: in a test on a synthetic clip, 2, 3 and 4 each moved the file size by up to about a tenth, up or down, with no keyframe change.
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

## svt-av1.tile-rows
Label: Tile Rows
Summary: Splits each frame into horizontal strips that are coded on their own, so a player with spare cores can decode them in parallel. Upstream says tiles cost quality; 0 leaves the frame whole.
When to change: Leave it at 0 unless a player or delivery spec needs tiles. Upstream lists them among the tips for a stuttering decoder, with a gain only if the player decodes tiles in parallel, and warns that many tiles can show as artifacts. The value is a power of two: 1 is 2 rows, 2 is 4, 6 is 64; rows the picture cannot hold are cut (tested). Above 0 the bundled build suggests adding Fast Decode 1 or 2.
Example: In CRF tests (bundled build, testsrc2 clips, preset 8), value 1, two rows, made a 3840x2160 clip 3% larger and a 640x480 clip 1% smaller; at 640x480 the values 3 to 6 gave the same file. Without the switch the encoder chose 0 from 160x120 to 3840x2160, though its help says it varies by resolution.
Related: svt-av1.tile-columns, svt-av1.fast-decode, svt-av1.lp, concept.tiles
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#improving-decoding-performance
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#threading-and-efficiency
Status: reviewed

## svt-av1.tile-columns
Label: Tile Columns
Summary: Splits each frame into vertical strips that are coded on their own, so a player with spare cores can decode them in parallel. Upstream says tiles cost quality; 0 leaves the frame whole.
When to change: Leave it at 0 unless a player or a delivery spec needs tiles. Upstream's decoding tips give 2 (4 columns) as the example, with a gain only where the player decodes tiles in parallel, and warn that many tiles can show as artifacts. The value is a power of two: 1 is 2 columns, 2 is 4, 4 is 16. Anything above 0 makes the bundled build suggest adding Fast Decode 1 or 2.
Example: In CRF tests (bundled build, testsrc2 clips, preset 8), value 1, two columns, made a 3840x2160 clip 0.4% larger and a 1920x1080 clip 0.5% larger; at 640x480, value 4, 16 columns, cost 4.6%. Without the switch the encoder chose 0 at every size from 160x120 to 3840x2160.
Related: svt-av1.tile-rows, svt-av1.fast-decode, svt-av1.lp, concept.tiles
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#improving-decoding-performance
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#threading-and-efficiency
Status: reviewed

## svt-av1.enable-dlf
Label: Deblocking Loop Filter
Summary: Smooths the seams between coded blocks before a frame is shown or used as a reference, so heavy compression looks less like a grid. On by default; 2 is a slower, more accurate version.
When to change: Leave it at 1: On; upstream keeps this filter on at every preset in its table. Off leaves the block seams in the picture and in every frame predicted from it, and saved no measurable time in a timed test. 2 is upstream's slower, more accurate filtering: 8 to 9% slower in that test, with the output changed at every preset tried, so judge it on a short scene. Sharpness Bias steers this filter.
Example: Timed test: 1280x720 testsrc2 clip, 120 frames, preset 8, CRF 35, 16-core Ryzen 9 5950X, three runs each in three rounds, speed by the encoder's own figure. Off matched the default within 1%; 2 encoded 8 to 9% fewer frames per second. In CRF tests off moved the size by up to 2% either way.
Values:
- 0: Off. Block seams stay; no time saved in the timed test; size moved by up to 2% either way in CRF tests.
- 1: On. The encoder default and StaxRip's; on at every preset in upstream's table.
- 2: Slower, more accurate filtering, per upstream: 8 to 9% slower in the timed test; output changed at every preset tried.
Related: svt-av1.enable-cdef, svt-av1.enable-restoration, svt-av1.sharpness, svt-av1.preset, concept.deblocking
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.enable-cdef
Label: Constrained Directional Enhancement Filter
Summary: Cleans ringing and coding noise along edges inside the coding loop, following the direction of each edge so the edge itself stays sharp. On by default and at every preset in upstream's table.
When to change: Leave it on; upstream keeps it on through preset 10, and off leaves the noise in the picture and in every frame predicted from it for a small speed gain, 1 to 3% in a timed test, near the spread between runs. Upstream's one reason to switch it off: with ALT-REF Frames off and AC Bias 4 to 6, to keep film grain and noise. CRF sizes moved from nothing at 1280x720 to 4% up on a noisy 160x120 clip.
Example: Timed test: 1280x720 testsrc2 clip, 120 frames, preset 8, CRF 35, 16-core Ryzen 9 5950X, three runs each: off encoded 1.5 to 3% more frames per second by the encoder's own figure across three rounds, within the spread between runs. With all three loop filters off the gain was 7 to 11%.
Related: svt-av1.enable-dlf, svt-av1.enable-restoration, svt-av1.ac-bias, svt-av1.enable-tf, svt-av1.film-grain, concept.deblocking
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.enable-restoration
Label: Loop Restoration Filter
Summary: Runs AV1's third in-loop filter, which repairs some of the detail that quantization blurred, after deblocking and CDEF. On by default, but faster presets already skip parts of it.
Used when: Presets 8 and below. Upstream's table turns its self-guided part off from preset 4 and its Wiener part from preset 9; at presets 9, 10 and 13 the switch changed nothing in tests (byte-identical).
When to change: Leave it on. At StaxRip's default preset 8 only the Wiener part still runs; off is the biggest saving among the three loop filters, 8 to 10% more speed in a timed test, at an unmeasured cost to the picture, with the file size moving under 1% either way in CRF tests. Turn it off only for an experiment of your own, and keep Preset in mind: from 9 up the switch has nothing left to switch.
Example: Timed test: 1280x720 testsrc2 clip, 120 frames, preset 8, CRF 35, 16-core Ryzen 9 5950X, three runs each: off encoded 8 to 10% more frames per second by the encoder's own figure across three rounds, and all three loop filters off 7 to 11%.
Related: svt-av1.enable-dlf, svt-av1.enable-cdef, svt-av1.preset, concept.deblocking
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.enable-tpl-la
Label: Temporal Dependency Model
Summary: The encoder that ships with StaxRip does not accept this switch, so the dialog no longer offers it. The encoder's own temporal dependency model stays on either way.
When to change: Nothing to set here. The model weighs how much later frames lean on each block when the encoder hands out bits. `--enable-tpl-la` on the command line stops the bundled build before encoding with "Unprocessed tokens: --enable-tpl-la" (checked on 2026-08-27). The model itself goes off with Adaptive Quantization 0, which the build reports as "TPL is disabled for aq_mode 0".
Related: svt-av1.aq-mode, svt-av1.cqp, svt-av1.lookahead, svt-av1.rc
Status: reviewed

## svt-av1.enable-mfmv
Label: Motion Field Motion Vector
Summary: Lets the encoder reuse motion it already found in earlier frames as a starting guess for the current one, which saves bits on motion data. -1 leaves the choice to the preset.
When to change: Leave it at -1. In CRF tests with the bundled build it was on at presets 8 to 10 and off from 11 up, in line with upstream's table for presets 0 to 10. Forcing 0 made the files 0.2% to 1.5% larger at presets 8 to 10; forcing 1 at presets 11 to 13 made them 0.3% smaller, at whatever time cost the preset was avoiding. Test a short scene before deciding either way.
Example: Test: 640x480 testsrc2 clip, 24 frames, CRF 35. Forcing 0: 105865 bytes against 105036 at preset 8, 111113 against 110871 at 9, 122177 against 121389 at 10. Forcing 1 at presets 11 to 13: 130098 against 130533. A noisy 160x120 clip grew 1.5% at preset 8.
Related: svt-av1.preset, svt-av1.enable-tf
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.enable-tf
Label: ALT-REF Frames
Summary: Adds alternate reference frames, built by averaging a frame with its neighbors to wash out noise, for other frames to predict from. On by default; 2 varies the filter strength by block.
When to change: Leave it at 1: On; Temporal Filtering Strength sets how hard the filter works and does nothing with this off (tested). Turn it off only to keep grain and noise, which upstream pairs with CDEF off and a high AC Bias. Avoid 2 for anything you may need to reproduce: on a 640x480 test clip, identical runs gave different files at the automatic Level Of Parallelism and the same file at level 1.
Values:
- 0: Off. No filtered frames; Temporal Filtering Strength, MCTF for key frames and overlays then change nothing (tested).
- 1: On. The encoder default and StaxRip's.
- 2: Adaptive, experimental per upstream: the strength follows each block's prediction error; not repeatable (tested).
Related: svt-av1.tf-strength, svt-av1.enable-kf-tf, svt-av1.enable-overlays, svt-av1.enable-cdef, svt-av1.ac-bias, svt-av1.lp, svt-av1.film-grain
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#appendix-b-psychovisual-parameters
Status: reviewed

## svt-av1.enable-kf-tf
Label: Enable MCTF for key frames
Summary: Applies the motion-compensated temporal filter that builds ALT-REF frames to keyframes as well, so the frame each group of pictures starts from is filtered too. On by default.
Used when: Only with ALT-REF Frames on; with them off, on and off gave byte-identical output in a test.
When to change: Leave it on. Turn it off if keyframes look softer than the frames around them in a test encode. In a CRF test on a 640x480 clip, off made the file 0.7% larger. The help says nothing more about it.
Values:
- 0: Off. Keyframes are coded unfiltered.
- 1: On. The encoder default and StaxRip's.
Related: svt-av1.enable-tf, svt-av1.tf-strength, concept.keyframe
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
Status: reviewed

## svt-av1.enable-overlays
Label: Insertion of Overlayer Pictures
Summary: Inserts extra coded pictures, overlays, that the base layer, the lowest of the frame layers, can use as one more reference. Off by default; the help says only that much, and in tests the file grew.
Used when: Only with ALT-REF Frames on; with them off, turning this on changed nothing in a test (byte-identical).
When to change: Leave it off. Upstream documents no case where it helps, and in CRF tests with the bundled build it made the file 1% larger on a 640x480 clip and 4% larger on a 160x120 clip. Treat it as an experiment: encode a short scene both ways and compare the picture as well as the size.
Related: svt-av1.enable-tf, svt-av1.hierarchical-levels
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
Status: reviewed

## svt-av1.scm
Label: Screen Content Detection Level
Summary: Decides whether the encoder looks for screen content, flat colors, sharp edges and repeated shapes, and uses AV1's palette and block-copy tools on it. The default, 2, decides from the content.
Used when: Presets 8 and below. From preset 9 up the bundled build switches detection and the tools off with a warning, and 0, 1 and 2 gave byte-identical output in tests, with Random Access and with Low Delay.
When to change: Leave it at 2, which detects per content: a flat-color test clip came out the same with 1 as with 2, and over four times larger at 0. Pick 1 to force the tools on when you know it is a screen recording and 2 misses it: on natural-looking test clips 1 changed the file where 2 left it alone. Mind the preset: at 9, with the tools off, the flat-color clip was almost five times larger than at 8.
Example: Test clip: a 160x120 synthetic pattern of flat color blocks with a bright grid, 24 frames, preset 8, CRF 35: 1964 bytes with detection on, 8970 with it off; at preset 9, with the tools gone, 9526. The other clips were a noisy 160x120 gradient and a 640x480 testsrc2 pattern.
Values:
- 0: Off. Everything is coded as natural video.
- 1: Turns the block copy and palette tools on without detecting anything.
- 2: Content adaptive. The encoder default and StaxRip's; detected a flat-color test clip, left natural-looking ones alone.
- 3: Content adaptive, anti-alias aware. The help says no more; it gave the same output as 2 on three test clips.
Related: svt-av1.enable-intrabc, svt-av1.preset, svt-av1.pred-struct
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.enable-intrabc
Label: Enable Intra Block Copy
Summary: Lets a block be predicted by copying an area already coded elsewhere in the same frame, which suits repeated text, icons and patterns. It applies only to frames coded as screen content.
Used when: Only where the screen-content tools are active: Screen Content Detection Level 1, or 2 and 3 when they detect it, at presets 8 and below. Elsewhere 0 and 1 gave byte-identical output in tests.
When to change: Leave it on; where it does not apply it changes nothing, and where it does it helped a little in CRF tests (a 160x120 flat-color test clip at preset 8, CRF 35, was 0.3% smaller with it). Turn it off only as an experiment on a screen recording that shows a problem.
Values:
- 0: Off.
- 1: On where screen content is detected or forced. The encoder default and StaxRip's.
Related: svt-av1.scm, svt-av1.preset
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#what-presets-do
Status: reviewed

## svt-av1.film-grain
Label: Film Grain Level
Summary: Turns on film grain synthesis: the encoder measures the grain or noise in the source and the player adds matching synthetic grain on playback, so the grain itself need not be compressed. 0 is off.
When to change: Use it on grainy or noisy live action; upstream says it can cut the file a lot at similar quality. Try 8; 10 to 15 for noisier video, 4 for hand-drawn animation, 0 for clean sources such as 3D animation. Use preset 6 or lower: from 7 up the bundled build warns the pairing is for debug purposes only; it still runs, just slower. Upstream: too high a level smooths detail away or stacks noise.
Example: Encode a grainy 20-second scene at preset 6 at 0 and at 8, compare the sizes, then play both and look for pasted-on grain or lost fine detail. The player draws the grain, so upstream lists it among the things to avoid for a struggling decoder. Adaptive Film Grain does nothing at 0 (tested).
Related: svt-av1.film-grain-denoise, svt-av1.fgs-table, svt-av1.adaptive-film-grain, svt-av1.preset, svt-av1.enable-cdef, svt-av1.ac-bias, svt-av1.fast-decode, concept.film-grain
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#practical-advice-on-grain-synthesis
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#tuning-for-animation
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#options-that-give-the-best-encoding-bang-for-buck
Status: reviewed

## svt-av1.film-grain-denoise
Label: Film Grain Denoise
Summary: Chooses whether the encoder also removes the grain from the source before coding it, leaving synthesis to put it back. 0 keeps the source as it is and only adds the grain description.
Used when: Only with Film Grain Level above 0; the control is hidden at 0, and the bundled build ignores the switch then with a warning.
When to change: Leave it at 0 unless the encoded grain looks doubled or the file stays large; upstream says 0 can give higher fidelity if the level is right, since too high a level then stacks noise. 1 smooths the source first, so the file shrinks: by 8% at level 8 and 26% at level 50 on a noisy 160x120 test clip, not at all on a clean one. Upstream warns the smoothing can take fine detail with it.
Values:
- 0: No denoising; the grain description still goes into the frame headers. The encoder default and StaxRip's.
- 1: Denoises the source at the strength of Film Grain Level. Smaller file on grainy sources (tested); fine detail at risk.
Related: svt-av1.film-grain, svt-av1.fgs-table, concept.film-grain
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#practical-advice-on-grain-synthesis
Status: reviewed

## svt-av1.fgs-table
Label: FGS Table
Summary: Points the encoder at a file holding a ready-made film grain description (FGS is film grain synthesis), which it uses instead of measuring the grain itself. Empty means no table.
When to change: Leave it empty unless you have a grain table for it. Upstream ties the option to the library interface, but the bundled build reads the file from the command line and stops if it cannot: "Invalid parameter '--fgs-table'" for a missing file, "invalid grain table magic" for one that is no table (tested). With a Film Grain Level too, it warns "Both film-grain-denoise and fgs-table were specified".
Related: svt-av1.film-grain, svt-av1.film-grain-denoise, concept.film-grain
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
Status: reviewed

## svt-av1.superres-mode
Label: Super-Resolution Mode
Summary: Codes each frame at a reduced width and leaves the player to stretch it back to full width, an AV1 tool for very low bitrates. Off by default; the modes differ in how the width is chosen.
Used when: Not with Low Delay, so not with Constant Bitrate, and not with 2-pass Variable Bitrate: the bundled build stops before encoding in each case (tested).
When to change: Leave it at 0. Upstream says any coding gain comes only at very low bitrates, and only in the automatic mode; the bundled build switches off its temporal dependency model whenever it scales. In a CRF test, mode 1 at half width halved the file but dropped PSNR from 43 to 32 dB, while CRF 45 without it gave a smaller file at 38.5 dB. Modes 3 and 4 never scaled a frame in tests.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35; PSNR by ffmpeg against the source. Plain: 105036 bytes, 43.1 dB. Mode 1, denominator 16: 50461 bytes, 32.1 dB. Plain at CRF 45: 44312 bytes, 38.5 dB. On a noisy 160x120 clip, mode 1 at 16 made the file 43% larger.
Values:
- 0: Off. The encoder default and StaxRip's.
- 1: Every frame at the width the two denominators set; 8 leaves it alone. Halved a test file at a cost of 11 dB.
- 2: A random width per frame. A test and debugging mode per the bundled build, which buffers every scale of each reference.
- 3: Scales a frame whose quantizer passes the thresholds below. Never scaled a frame in tests at CRF 35 or 60.
- 4: Tries scaled and unscaled and keeps the better; upstream says it encodes at least twice. Chose no scaling in tests.
Related: svt-av1.superres-denom, svt-av1.superres-kf-denom, svt-av1.superres-qthres, svt-av1.superres-kf-qthres, svt-av1.resize-mode, svt-av1.crf, svt-av1.pred-struct, svt-av1.pass, svt-av1.enable-tpl-la, concept.super-resolution, concept.psnr
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#super-resolution
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Appendix-Super-Resolution.md
Status: reviewed

## svt-av1.superres-denom
Label: SuperRes Denominator
Summary: Sets the width the frames between keyframes are coded at in Super-Resolution Mode 1, as 8 over this number: 8 is full width, 16 is half. Keyframes have their own denominator.
Used when: Super-Resolution Mode 1 only; the control is hidden and nothing is sent otherwise, and the encoder ignored the switch in the other modes anyway (tested: byte-identical output).
When to change: Leave it at 8 unless you are experimenting with mode 1, and then judge the picture, not the size: every step narrows the coded frame and the player stretches it back. In a CRF test 16 halved the file and cost 11 dB of PSNR, 12 saved 14% for 10 dB, and 9, the mildest cut, made the file 17% larger and cost 7 dB.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35, mode 1; PSNR by ffmpeg against the source. 8: 105036 bytes, 43.1 dB. 9: 123078 bytes, 36.4 dB. 12: 90650 bytes, 33.4 dB. 16: 50461 bytes, 32.1 dB. The decoded frames were 640x480 in every case.
Values:
- 8: Full width, no scaling. The encoder default and StaxRip's.
- 9: The mildest cut, 8/9 of the width. In a CRF test the file grew 17% and PSNR fell 7 dB.
- 12: Two thirds of the width. In a CRF test the file shrank 14% and PSNR fell 10 dB.
- 16: Half width. In a CRF test the file halved and PSNR fell from 43 to 32 dB.
Related: svt-av1.superres-mode, svt-av1.superres-kf-denom, concept.super-resolution, concept.psnr
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#super-resolution
Status: reviewed

## svt-av1.superres-kf-denom
Label: SuperRes Denominator for KeyFrames
Summary: Sets the width keyframes are coded at in Super-Resolution Mode 1, as 8 over this number: 8 is full width, 16 is half. The frames between keyframes follow SuperRes Denominator.
Used when: Super-Resolution Mode 1 only; the control is hidden and nothing is sent otherwise.
When to change: Leave it at 8 unless you are experimenting with mode 1, and then judge the picture. In a CRF test, narrowing only the keyframes (16 here, 8 for the other frames) left the file within 0.3% of the plain encode and cost 2 dB of PSNR; with SuperRes Denominator at 16 as well the file shrank 59%, at 32 dB against 43 dB plain, the same loss as scaling the other frames alone.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35, mode 1; PSNR by ffmpeg against the source. Plain: 105036 bytes, 43.1 dB. 16 here alone: 104766 bytes, 41.2 dB. 16 for both denominators: 43385 bytes, 32.0 dB.
Values:
- 8: Full width, no scaling. The encoder default and StaxRip's.
- 16: Half-width keyframes. Alone it moved the size by 0.3% in a CRF test; with the other denominator at 16 too, by 59%.
Related: svt-av1.superres-mode, svt-av1.superres-denom, concept.super-resolution, concept.keyframe, concept.psnr
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#super-resolution
Status: reviewed

## svt-av1.superres-qthres
Label: SuperRes q-threshold
Summary: The quantizer a frame must exceed before Super-Resolution Mode 3 codes it at reduced width, on the 0 to 63 scale; 63 means never. In tests it never triggered.
Used when: Super-Resolution Mode 3 only; the control is hidden and nothing is sent otherwise. Keyframes use SuperRes q-threshold for KeyFrames instead.
When to change: Leave it at 43, the encoder default. In tests with the bundled build, mode 3 scaled nothing at 0, 43 or 63 here: the file stayed within 2 bytes of the plain encode, and only 63 in both thresholds gave the identical file. Upstream says only that the frame's QP is compared with the threshold and that 63 means no scaling.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, mode 3. At CRF 35, 0, 43 and 63 here all gave 105037 bytes against 105036 plain, and 63 in both thresholds gave the plain file; at CRF 60, 9994 bytes against 9992 plain.
Related: svt-av1.superres-mode, svt-av1.superres-kf-qthres, svt-av1.crf, concept.quality-level, concept.super-resolution
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#super-resolution
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Appendix-Super-Resolution.md
Status: reviewed

## svt-av1.superres-kf-qthres
Label: SuperRes q-threshold for KeyFrames
Summary: The quantizer a keyframe must exceed before Super-Resolution Mode 3 codes it at reduced width, on the 0 to 63 scale; 63 means never. The frames between keyframes use SuperRes q-threshold.
Used when: Super-Resolution Mode 3 only; the control is hidden and nothing is sent otherwise.
When to change: Leave it at 43, the encoder default. In tests with the bundled build, mode 3 scaled no keyframe at 0, 43 or 63 here; the file stayed within 2 bytes of the plain encode whatever the two thresholds, and only 63 in both gave the identical file. Upstream says only that the QP is compared with the threshold and that 63 means no scaling.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, mode 3, CRF 35. 0 or 63 here with SuperRes q-threshold at 43: 105037 bytes, as at 43, against 105036 plain; 63 in both thresholds gave the plain file.
Related: svt-av1.superres-mode, svt-av1.superres-qthres, svt-av1.crf, concept.quality-level, concept.keyframe, concept.super-resolution
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#super-resolution
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Appendix-Super-Resolution.md
Status: reviewed

## svt-av1.sframe-dist
Label: S-Frame Interval
Summary: Inserts a switch frame, an S-frame, every this many frames; 0 inserts none. S-frames are points where a streaming player can hop between versions of the same video without waiting for a keyframe.
When to change: Leave it at 0 unless you build an adaptive streaming ladder and your packager wants S-frames; they serve switching between streams, not playback of a single file. In CRF tests on a 640x480 clip, 8 put one S-frame into 24 frames and 1 put three, and the file grew 5 to 7%; a noisy 160x120 clip grew 24%. At the automatic Level Of Parallelism the output differed run to run; at 1 three runs matched.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35. Plain: 105036 bytes, no S-frame. Interval 8: 110401 to 110833 bytes over four runs, one S-frame, the 17th frame; interval 1: 112197 bytes with three. Frame types read back with ffprobe, which marks a switch frame with a lowercase p.
Related: svt-av1.sframe-mode, svt-av1.keyint, svt-av1.lp, concept.keyframe, concept.gop
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
Status: reviewed

## svt-av1.sframe-mode
Label: S-Frame Insertion Mode
Summary: Chooses which frame becomes the S-frame when S-Frame Interval comes due: the frame at the interval, but only if it is an alternate reference frame (1), or the next such frame (2).
Used when: Only with S-Frame Interval above 0; at 0 the bundled build ignored the mode (tested: byte-identical output).
When to change: Leave it at 2, the encoder default. In a test 1 and 2 gave the same file with Level Of Parallelism at 1, so the choice made no difference there, and the help says no more. The bundled build also takes modes 3 and 4, which upstream documents as taking frame numbers from `--sframe-posi` (the bundled help names mode 3 only); StaxRip does not offer them, so they belong in the Custom box.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35, S-Frame Interval 8, Level Of Parallelism 1. Modes 1 and 2 gave the same 110661-byte file; either mode alone with the interval at 0 gave the plain 105036-byte file.
Values:
- 1: The frame at the interval, and only if it is an alternate reference frame. Same file as 2 in a test.
- 2: The next alternate reference frame after the interval. The encoder default and StaxRip's; nothing is sent for it.
Related: svt-av1.sframe-dist, svt-av1.enable-tf, staxrip.custom
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
Status: reviewed

## svt-av1.resize-mode
Label: Resize Mode
Summary: Codes frames at a reduced width and height and the player shows them that size: reference scaling, an AV1 tool for low-bitrate streaming. Off by default; it crashed the bundled build in most tests.
Used when: Mode 3 works only in 1-pass Constant Bitrate with Low Delay; anywhere else the bundled build warns and encodes plainly (tested). The other modes ran, or crashed, whatever the rate control.
When to change: Leave it at 0. Unlike super-resolution the player does not scale the picture back, so the video plays smaller or changes size at a keyframe or event, and the encoder drops its temporal dependency model. In tests, 31 of 43 runs that scaled the frames between keyframes crashed the bundled build, and the runs that finished gave different files. Scaling keyframes alone ran every time.
Example: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35. Mode 1 with both denominators at 16 ran once, 56110 bytes against 105036 plain, every frame decoded at 320x240; the same setting crashed at presets 4 and 12 and with a bitrate target. Dynamic mode in Constant Bitrate never scaled a frame.
Values:
- 0: Off. The encoder default and StaxRip's.
- 1: Fixed: every frame at 8 over the denominators below. Crashed the bundled build in 18 of 28 test runs.
- 2: A random size per frame. The bundled build calls it a test and debugging mode; it crashed in both test runs.
- 3: Dynamic: rate control drops to 3/4 or 1/2 size when its buffer runs low. 1-pass Constant Bitrate with Low Delay only.
- 4: Changes size at the frames listed under Resize Events. Crashed the bundled build in 11 of 13 test runs.
Related: svt-av1.resize-denom, svt-av1.resize-kf-denom, svt-av1.frame-resz-events, svt-av1.frame-resz-denoms, svt-av1.frame-resz-kf-denoms, svt-av1.superres-mode, svt-av1.rc, svt-av1.pred-struct, svt-av1.enable-tpl-la, concept.super-resolution
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#reference-scaling
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Appendix-Reference-Scaling.md
Status: reviewed

## svt-av1.resize-denom
Label: Resize Denominator
Summary: Sets the size the frames between keyframes are coded at in Resize Mode 1, as 8 over this number in width and height alike: 8 is full size, 16 is half width and half height.
Used when: Resize Mode 1 only; the control is hidden and nothing is sent otherwise, and the encoder ignored the switch in the other modes (tested: byte-identical output).
When to change: Leave it at 8. Anything else scales the frames between keyframes, which crashed the bundled build in most tests: 16 on its own crashed one run and finished three, with a different file each time; 9 and 12 crashed. Keyframes keep their own denominator, so the decoded video changes size at each keyframe unless the two match. Super-resolution at the same time resets this to 8 (tested).
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35. 16 here and for keyframes ran once: 56110 bytes, every frame decoded at 320x240 by ffprobe. 16 here with keyframes at 8 finished three times, at 51190, 53161 and 54229 bytes, and crashed on a 160x120 clip.
Values:
- 8: Full size, no scaling. The encoder default and StaxRip's.
- 16: Half width and half height. Crashed the bundled build in some test runs and finished others, never with the same file.
Related: svt-av1.resize-mode, svt-av1.resize-kf-denom, svt-av1.superres-denom
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#reference-scaling
Status: reviewed

## svt-av1.resize-kf-denom
Label: Resize Denominator for KeyFrames
Summary: Sets the size keyframes are coded at in Resize Mode 1, as 8 over this number in width and height alike: 8 is full size, 16 is half width and half height. The other frames follow Resize Denominator.
Used when: Resize Mode 1 only; the control is hidden and nothing is sent otherwise.
When to change: Leave it at 8. Scaling keyframes alone was the one resize setting that finished every test run, four of four, but the decoded video then changes size after each keyframe, and the file did not shrink: 16 gave 106699 to 108088 bytes against 105036 plain, a different file each run. With Resize Denominator also away from 8 it crashed in most runs.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35. 16 here with Resize Denominator at 8: the first frame decoded at 320x240 and the 23 after it at 640x480, read back with ffprobe.
Values:
- 8: Full size, no scaling. The encoder default and StaxRip's.
- 16: Half-size keyframes. Finished every test run; the file was up to 3% larger and changed size after the keyframe.
Related: svt-av1.resize-mode, svt-av1.resize-denom, concept.keyframe
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#reference-scaling
Status: reviewed

## svt-av1.frame-resz-events
Label: Resize Events
Summary: Lists the frame numbers, counted from 0 and separated by commas, at which Resize Mode 4 switches to a new size; the sizes come from the two denominator lists below. Empty means no events.
Used when: Resize Mode 4 only; the control is hidden and nothing is sent otherwise. Without Resize Denominator In Event the events did nothing (tested: byte-identical to mode 4 alone).
When to change: Leave it empty. All three lists need the same number of entries, or the bundled build stops before encoding ("Size for the list passed to frame-resz-denoms doesn't match"). Upstream's example is events `5,10,15,20,25,30` with keyframe denominators `8,9,10,11,12,13` and denominators `16,15,14,13,12,11`; that example crashed the bundled build in both test runs, as did most other event lists tried.
Example: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35. Event `5` with both denominators `16` finished with Level Of Parallelism 1 (66849 bytes against 105036 plain) and in Constant Bitrate, crashed with Low Delay; event `1` crashed too, as did `5,10` at preset 12 and `5` at denominators `12`.
Related: svt-av1.resize-mode, svt-av1.frame-resz-denoms, svt-av1.frame-resz-kf-denoms, svt-av1.lp, concept.keyframe
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#reference-scaling
Status: reviewed

## svt-av1.frame-resz-denoms
Label: Resize Denominator In Event
Summary: Lists, one per entry in Resize Events, the size the frames between keyframes are coded at from that event on, as 8 over the number in width and height alike: 8 is full size, 16 half of each.
Used when: Resize Mode 4 only; the control is hidden and nothing is sent otherwise. Needs Resize Events and Resize Denominator for KeyFrames In Event with the same number of entries.
When to change: Leave it empty. Any entry other than 8 scales the frames between keyframes, and in tests that crashed the bundled build in 11 of 13 mode 4 runs; an all-8 list ran and changed nothing. Entries are not range-checked: 7 and 17 crashed the encoder instead of being refused, while a letter is refused ("Invalid parameter 'frame-resz-denoms'").
Example: Events `5`, this list `16`, keyframe list `16`: finished with Level Of Parallelism at 1, 66849 bytes against 105036 plain, and in Constant Bitrate; crashed with Low Delay, and at preset 12 with events `5,10` (640x480 testsrc2 clip, 24 frames, preset 8, CRF 35).
Related: svt-av1.resize-mode, svt-av1.frame-resz-events, svt-av1.frame-resz-kf-denoms, svt-av1.resize-denom, svt-av1.lp
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#reference-scaling
Status: reviewed

## svt-av1.frame-resz-kf-denoms
Label: Resize Denominator for KeyFrames In Event
Summary: Lists, one per entry in Resize Events, the size keyframes are coded at from that event on, as 8 over the number in width and height alike: 8 is full size, 16 half of each.
Used when: Resize Mode 4 only; the control is hidden and nothing is sent otherwise. Needs Resize Events and Resize Denominator In Event with the same number of entries.
When to change: Leave it empty. The list must match Resize Events in length or the bundled build stops before encoding, and without Resize Denominator In Event the events did nothing (tested: byte-identical to mode 4 alone). Upstream's appendix suggests milder scaling for keyframes, 8/9 or 8/10, than for the frames between them, 8/13 to 8/16, where bandwidth forces scaling at all.
Example: Test: 640x480 testsrc2 clip, 24 frames, preset 8, CRF 35, Resize Mode 4, events `5,10,15`, this list `16,15,14`, Resize Denominator In Event empty: 107694 bytes, the same file as Resize Mode 4 with no lists at all.
Related: svt-av1.resize-mode, svt-av1.frame-resz-events, svt-av1.frame-resz-denoms, svt-av1.resize-kf-denom, concept.keyframe
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#reference-scaling
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Appendix-Reference-Scaling.md
Status: reviewed

## svt-av1.lossless
Label: Lossless
Summary: Reproduces every pixel of your script exactly, at a huge cost in size: 59 and 4 times the CRF 35 file on two test clips. Added by the Patman build of the encoder StaxRip bundles; off by default.
Used when: Quality mode only. With Variable or Constant Bitrate the bundled build switches to a fixed quantizer and then refuses the Target Bitrate StaxRip sends, so the encode stops (tested).
When to change: For an archive or intermediate that must not change, at a Preset that decoded exactly in tests: 2, 4, 6, 8, 9 or 10. At 11 to 13 the output was not lossless and two decoders failed on it (tested). It forces Adaptive Quantization 0 and overrides the quantizer, Maximum Bitrate, quantization matrices and loop filters; Film Grain Level and super-resolution still alter the output, so leave them off.
Example: Noisy 160x120 and 640x480 testsrc2 clips, 24 frames, preset 8; ffmpeg's PSNR against the source read inf from CRF 1 to 60. Sizes 266853 and 462585 bytes, against 4526 and 105036 at CRF 35. Presets 2, 4, 6, 8, 9 and 10 decoded exactly; 11 to 13 did not. Tune, Sharpness and AC Bias changed nothing.
Related: svt-av1.crf, svt-av1.cqp, svt-av1.aq-mode, svt-av1.preset, svt-av1.rc, svt-av1.tbr, svt-av1.enable-qm, svt-av1.mbr, svt-av1.enable-dlf, svt-av1.enable-cdef, svt-av1.enable-restoration, svt-av1.film-grain, svt-av1.superres-mode, svt-av1.resize-mode, svt-av1.tune, concept.lossless, concept.quality-level
References:
- https://github.com/Patman86/SVT-AV1-Mod-by-Patman/releases
Status: reviewed

## svt-av1.avif
Label: Avif (Still-Picture Coding)
Summary: Switches the encoder to still-picture coding for AVIF images and cuts the output to 3 frames: on a video it prints an error and still reports success (tested). Off by default.
Used when: Quality mode only: with Variable Bitrate the bundled build hung and never finished (tested with a 20-second limit, and once for 10 minutes), and with Constant Bitrate it stops with an error.
When to change: Leave it off. Use it only to code one frame as an image, with Frames To Be Encoded at 1: every frame is then a keyframe, and Tune 3 (Still Image Quality), which the bundled build refuses in the default Random Access structure, becomes usable. On a video it stops after 3 frames with "AVIF flag is specified, but more than 3 frames were sent" and exit code 0, so StaxRip would mux a 3-frame file.
Example: Test: 640x480 testsrc2 clip, preset 8, CRF 35. One frame: 6770 bytes with it on, 8053 off, quality not compared. The 24-frame clip with it on: 3 frames, 20726 bytes, exit code 0. Upstream describes it as still-picture optimizations for efficiency and lower memory use.
Related: svt-av1.frames, svt-av1.tune, svt-av1.rc, svt-av1.lossless, concept.keyframe
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#av1-specific-options
Status: reviewed

## svt-av1.color-primaries
Label: Color Primaries
Summary: Tells the player which red, green and blue your video was made with, so it shows the colors as intended. A label only: the encoded pixels are the same with or without it (tested).
Used when: StaxRip fills it from the source you open (Import VUI metadata, Project > Options > Video) for BT.709 and BT.2020 sources only; set it yourself when that is wrong or the source has no tag.
When to change: Leave what StaxRip set; the import is on by default. Check it when the source is standard definition (BT.601 is not auto-filled: pick it if you want the file to say so), when the source has no tag and you know its primaries, and when your script changes the colors, say tone-mapping HDR to SDR: the tag must then describe the new picture. Unspecified writes no claim at all.
Example: Test: 160x120 synthetic clip, 24 frames, preset 8, CRF 35, Level Of Parallelism 1: the plain encode and one tagged BT.709 throughout, studio range, left chroma decoded to identical frames (ffmpeg framemd5), and so did an HDR-tagged encode with mastering display and light level metadata.
Values:
- 2: Unspecified. The encoder default and StaxRip's; no claim is written into the file.
- 1: BT.709, the HD standard. What StaxRip sets for a source tagged BT.709.
- 6: BT.601, the standard-definition tag. Not auto-filled; pick it by hand for SD material.
- 9: BT.2020, the wider set of colors (gamut) of UHD and HDR. What StaxRip sets for a source tagged BT.2020.
Related: svt-av1.transfer-characteristics, svt-av1.matrix-coefficients, svt-av1.color-range, svt-av1.mastering-display, concept.color-description
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
Status: reviewed

## svt-av1.transfer-characteristics
Label: Transfer Characteristics
Summary: Tells the player which curve turns your video's code values into brightness: BT.709 for ordinary SDR, PQ or HLG for HDR. A label only; the encoded pixels are the same either way (tested).
Used when: StaxRip fills it from the source you open (Import VUI metadata, Project > Options > Video) for BT.709, PQ and HLG sources only; set it yourself when that is wrong or the source has no tag.
When to change: Leave what StaxRip set; the import is on by default. The case that needs your hand is a script that changes the curve, above all tone-mapping HDR to SDR: pick BT.709 here, or the player applies the HDR curve to an SDR picture. Upstream notes HDR is usually 10-bit and pairs PQ or HLG with BT.2020 primaries; the bit depth comes from your script, not from this tag.
Example: Test: 160x120 synthetic clip, 24 frames, preset 8, CRF 35, Level Of Parallelism 1: encodes tagged BT.709 and tagged PQ with the full HDR set both decoded to the same frames as the plain encode (ffmpeg framemd5).
Values:
- 2: Unspecified. The encoder default and StaxRip's; no claim is written.
- 1: BT.709, the SDR curve. What StaxRip sets for a source tagged BT.709.
- 6: BT.601, standard definition. Not auto-filled.
- 16: SMPTE ST 2084, the PQ curve of HDR10. What StaxRip sets for a PQ source.
- 18: HLG, the hybrid log-gamma curve of broadcast HDR. What StaxRip sets for an HLG source.
Related: svt-av1.color-primaries, svt-av1.matrix-coefficients, svt-av1.mastering-display, svt-av1.content-light.max-cll, concept.color-description, concept.hdr-metadata
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#hdr-and-sdr-video
Status: reviewed

## svt-av1.matrix-coefficients
Label: Matrix Coefficients
Summary: Tells the player which matrix turns your video's Y, Cb and Cr values into red, green and blue: BT.709 for HD, BT.2020 non-constant for UHD and HDR. A label only; the pixels are the same (tested).
Used when: StaxRip fills it from the source you open (Import VUI metadata, Project > Options > Video) for BT.709 and BT.2020 non-constant sources only; set it yourself when that is wrong or there is no tag.
When to change: Leave what StaxRip set; the import is on by default. Standard-definition sources tagged BT.601 are not auto-filled; pick BT.601 for them if you want the file to say so. Keep it in step with Color Primaries, as the two normally travel together: BT.709 with BT.709, BT.2020 with BT.2020. A wrong matrix skews every color a little on playback; Unspecified writes no claim.
Example: Test: 160x120 synthetic clip, 24 frames, preset 8, CRF 35, Level Of Parallelism 1: encodes tagged BT.709 and BT.2020 non-constant decoded to the same frames as the plain encode (ffmpeg framemd5).
Values:
- 2: Unspecified. The encoder default and StaxRip's; no claim is written.
- 0: Identity, for RGB video. The bundled build accepts 4:2:0 YUV only, so it has no use here.
- 1: BT.709, HD video. What StaxRip sets for a source tagged BT.709.
- 6: BT.601, standard definition. Not auto-filled.
- 9: BT.2020 non-constant luminance, UHD and HDR. What StaxRip sets for a source tagged that way.
Related: svt-av1.color-primaries, svt-av1.transfer-characteristics, svt-av1.color-format, concept.color-description
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
Status: reviewed

## svt-av1.color-range
Label: Color Range
Summary: Tells the player if your video's levels use the studio range (16 to 235 in 8-bit, the norm for video) or the full 0 to 255, so it scales them right. A label only; the pixels are the same (tested).
Used when: StaxRip fills it from the source you open (Import VUI metadata) when that source reports Limited or Full, and sets Studio along with Master Display; change it when that is wrong or there is no tag.
When to change: Leave it at Studio unless the source really is full range, say a screen recording or an RGB capture, and your script keeps it that way. A wrong tag shows on playback: studio-range video tagged Full looks flat and washed out, full-range video tagged Studio loses the darkest and brightest detail. Check a bright and a dark frame in the player after a test encode.
Example: Test: 160x120 synthetic clip, 24 frames, preset 8, CRF 35, Level Of Parallelism 1: the encode tagged Full decoded to the same frames as the plain encode (ffmpeg framemd5); only the flag in the file differs.
Values:
- 0: Studio, also called limited or TV range. The encoder default and StaxRip's; what nearly all video uses.
- 1: Full, also called PC range. Only for sources that really use it.
Related: svt-av1.color-primaries, svt-av1.matrix-coefficients, svt-av1.mastering-display, concept.color-description
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
Status: reviewed

## svt-av1.chroma-sample-position
Label: Chroma Sample Position
Summary: Tells the player where the color samples of 4:2:0 video sit against the brightness samples, so it puts the color back in the right place. A label only; the pixels are the same (tested).
Used when: StaxRip fills it from the source you open (Import VUI metadata): a left source becomes Vertical/Left, a top-left source Colocated/Topleft. Set it yourself when the source carries no position.
When to change: Leave it at Unknown unless you know where the color samples sit. AV1 has no value for center, the position MPEG-1 and JPEG use, so a source MediaInfo reports as center is left at Unknown rather than tagged as something it is not; nothing in this list fits it. Nearly all H.264 and HEVC video is left, and Unknown writes no claim at all.
Example: Test: 160x120 synthetic clip, 24 frames, preset 8, CRF 35, Level Of Parallelism 1: encodes tagged left (1) and top-left (2) decoded to the same frames as the plain encode (ffmpeg framemd5).
Values:
- 0: Unknown. The encoder default and StaxRip's; no claim is written.
- 1: Vertical or left: level with the brightness samples across, halfway between two rows down; what a left source gets.
- 2: Colocated or top-left: on the same spot as the top-left brightness sample; what a top-left source gets.
Related: svt-av1.color-format, svt-av1.matrix-coefficients, concept.color-description
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
Status: reviewed

## svt-av1.mastering-display
Label: Master Display
Summary: Writes HDR10's mastering display metadata into the file: primaries, white point and luminance range of the display it was graded on. Players use it to fit HDR to their screen; no pixel changes.
Used when: StaxRip fills it from the source you open (Import VUI metadata) when MediaInfo reports BT.2020, Display P3 or DCI P3 mastering primaries with a luminance range, and sets Color Range to Studio too.
When to change: Rarely by hand: StaxRip fills the standard coordinates of the reported display and the source's luminance range, so leave a plain HDR encode alone. Clear it when tone-mapping HDR to SDR. Type one exactly as `G(x,y)B(x,y)R(x,y)WP(x,y)L(max,min)`, nothing between the parts: StaxRip stops the job with a message rather than start an encoder that would spin forever. One without L is dropped silently.
Example: For a BT.2020 display, 1000 nits peak, 0.005 black, StaxRip fills `G(0.17,0.797)B(0.131,0.046)R(0.708,0.292)WP(0.3127,0.329)L(1000,0.005)`. Tests (bundled build, 160x120 clip): ffprobe read them back, give or take AV1's rounding; `hello` or a space inside spun the encoder until killed at 20 s.
Related: svt-av1.content-light.max-cll, svt-av1.content-light.max-fall, svt-av1.transfer-characteristics, svt-av1.color-primaries, svt-av1.color-range, concept.hdr-metadata
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/CommonQuestions.md#hdr-and-sdr-video
Status: reviewed

## svt-av1.content-light.max-cll
Label: Maximum CLL
Summary: The brightest single pixel anywhere in the video, in nits, written into the file as HDR10 metadata together with Maximum FALL. Players use the pair to fit HDR to their screen; no pixel changes.
Used when: Sent with Maximum FALL as one `--content-light` switch, `max-cll,max-fall`, whenever either is above 0; at 0,0 nothing is sent. StaxRip fills both from the source you open (Import VUI metadata).
When to change: HDR video only; leave both at 0 for SDR and clear them when your script tone-maps HDR to SDR. Check the pair against the source's MediaInfo report (Maximum Content Light Level, Maximum Frame-Average Light Level) and type them only if missing. The box stops at 65535, the format's ceiling.
Example: `--content-light 1000,400` read back from the encoded file as MaxCLL 1000 and MaxFALL 400 in ffprobe (bundled build, 160x120 test clip), while 0,0 and 0,400 wrote nothing.
Related: svt-av1.content-light.max-fall, svt-av1.mastering-display, svt-av1.transfer-characteristics, concept.hdr-metadata
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
Status: reviewed

## svt-av1.content-light.max-fall
Label: Maximum FALL
Summary: The brightest frame by its average light level, in nits, written into the file as HDR10 metadata together with Maximum CLL. Players use the pair to fit HDR to their screen; no pixel changes.
Used when: Rides in Maximum CLL's `--content-light` switch as its second number; with Maximum CLL at 0 the bundled build wrote no metadata (tested). StaxRip fills both from the source (Import VUI metadata).
When to change: HDR video only, and never above Maximum CLL: a frame's average cannot exceed its brightest pixel, and the encoder does not check (400,1000 went in as is in a test). Leave both at 0 for SDR and clear them after tone-mapping to SDR. Check it against MediaInfo's Maximum Frame-Average Light Level for the source and type it only if missing.
Example: In a test, `--content-light 400,0` wrote MaxCLL 400 and MaxFALL 0 into the file and `1,400` wrote both, while `0,400` wrote nothing at all (bundled build, 160x120 clip).
Related: svt-av1.content-light.max-cll, svt-av1.mastering-display, concept.hdr-metadata
References:
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#2-av1-metadata
- https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/v4.2.0/Docs/Parameters.md#color-description-options
Status: reviewed
