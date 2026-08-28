# aomenc option help

Schema: 1
Encoder: aomenc
Locale: en
Title: AOMEnc
Source: Source/Encoding/AOMEnc.vb
Allowed-Missing: 0
Minimum-Reviewed: 175
Reviewed-Complete: true
Verified-Encoder-Version: AOMedia Project AV1 Encoder 3.14.1-46-g1b5a433c0a
Verified-Encoder-Build: 1b5a433c0a
Verified-Date: 2026-08-28
Documentation: https://aomedia.googlesource.com/aom/

## aomenc.cfg
Label: Config File
Summary: Reads encoder settings from a text file, as if you had typed them on the command line. Nothing changes until you name a file.
Used when: Only when you fill it in. Left empty, which is how it starts, no `--cfg` reaches the encoder.
When to change: Only when you already keep aomenc settings in a file and want to reuse them. Everything in this dialog is applied as well, so the two can contradict each other; prefer the Custom boxes, whose contents you can see. Browse to the file with the button beside the box.
Related: staxrip.custom
Status: reviewed

## aomenc.debug
Label: Debug
Summary: Makes the encoder produce the same bytes every time it is given the same input and settings, whatever the machine is doing at the time.
When to change: Leave it off. Turn it on only to compare two encodes byte for byte, for example to prove that a setting you changed really did change something. Ordinary encodes do not need it.
Encoder default: off
Related: aomenc.verbose
Status: reviewed

## aomenc.codec
Label: Codec
Summary: Names the codec the encoder should use. This build has only one, AV1, so filling the box in cannot get you anything else.
Used when: Only when you fill it in. Left empty, which is how it starts, no `--codec` is sent and the build's only codec, AV1, is used.
When to change: Leave it empty. The bundled build lists exactly one included encoder, `av1`, and says it is the default. The box exists because aomenc can be built with more.
Example: The build reports itself as `av1 - AOMedia Project AV1 Encoder 3.14.1-46-g1b5a433c0a (default)`.
Status: reviewed

## aomenc.passes
Label: Passes
Summary: Chooses whether the encoder analyzes the video first and then encodes it with what it learned. Two runs take about twice as long and hit a bitrate target more closely.
When to change: Leave it on Two Pass, the dialog's default. StaxRip then runs aomenc twice over the same script, `--passes=2 --pass=1` and then `--pass=2`, sharing a statistics file it puts in the temp folder next to the target name with an `.fpf` extension. Drop to One Pass for a quick test; in the constant-quality modes the difference is smaller than with a bitrate target.
Encoder default: Two Pass
Values:
- onepass: Sends `--passes=1`, one run of the encoder.
- twopass: Sends `--passes=2` and runs the encoder twice, `--pass=1` then `--pass=2`. The dialog's default.
Related: aomenc.end-usage, aomenc.target-bitrate, staxrip.custom, concept.two-pass, concept.rate-control
Status: reviewed

## aomenc.skip
Label: Skip first n frames
Summary: Drops this many frames from the start before encoding begins. 0, the default, starts at the first frame your script produces.
When to change: Use it to reach the part you want to judge in a test encode, then put it back to 0. To cut a video for real, choose the parts to keep in the preview window's Cut menu. Leave it at 0 when Chunks is above 1: StaxRip works the piece boundaries out from this number and then sends it to the encoder again after them, so the pieces come out wrong.
Encoder default: 0
Example: 750 here starts a 25 fps script at the 30-second mark.
Related: aomenc.limit, staxrip.chunks
Status: reviewed

## aomenc.limit
Label: Stop after n frames
Summary: Encodes only this many frames instead of all of them; 0 means all frames. It is for test encodes, not for cutting a video.
When to change: Set a few hundred frames, or a few thousand for a whole scene, to try settings before committing hours to the full encode. Counting starts at the frame Skip leaves you on. Put it back to 0 before the real encode, and leave it at 0 when Chunks is above 1, where it would cut every piece short.
Encoder default: 0
Example: 1500 here encodes one minute of a 25 fps script. The progress bar counts toward the script's full length either way, so a limited run finishes long before the bar fills.
Related: aomenc.skip, staxrip.chunks
Status: reviewed

## aomenc.good
Label: Good Quality Deadline
Summary: Puts the encoder in its good-quality mode, the one meant for files you keep rather than for live streaming.
When to change: Leave it off. Good quality is what the encoder does anyway when neither this box nor Realtime Quality Deadline is ticked, so ticking it changes nothing: the encoder reported `g_usage = 0` with the box and without it (tested). Ticking both boxes gives you Realtime, since StaxRip sends `--good` first and the later switch wins (tested).
Encoder default: off, and you get good quality
Related: aomenc.rt, aomenc.usage, aomenc.cpu-used
Status: reviewed

## aomenc.rt
Label: Realtime Quality Deadline
Summary: Switches the encoder to its realtime mode, which is far faster, far less efficient, and changes what other options mean.
When to change: Leave it off for anything you keep. Turn it on only when the encode has to keep up with playback. It moves the useful CPU Used range from 0 to 6 up to 5 to 12, drops Lag In Frames to 0, and turns the Restoration filter off by default (tested).
Encoder default: off
Example: On a 64 by 64 two-frame test clip at CPU Used 5, the realtime encode came out at 11378 bytes against 5500 for the same clip in good quality. Judge it on your own material before trusting a number like that.
Related: aomenc.good, aomenc.cpu-used, aomenc.enable-restoration, aomenc.usage
Status: reviewed

## aomenc.verbose
Label: Show encoder parameters
Summary: Prints the encoder's whole configuration into StaxRip's log before the encode starts. It changes nothing in the picture.
When to change: Leave it ticked, which is how StaxRip starts it, so `--verbose` is sent on every encode. The list it prints is the surest way to find out what a setting really did, since it shows the values the encoder ended up with rather than the ones you typed. Untick it only if the log is in your way.
Encoder default: on in this dialog
Example: The dump names `g_lag_in_frames = 35` and `kf_max_dist = 9999` among about forty settings, which is how the defaults quoted in this file were checked.
Related: aomenc.debug, aomenc.psnr
Status: reviewed

## aomenc.psnr
Label: Show PSNR in status line
Summary: Prints a PSNR score for the finished encode. It measures the encode against the source and changes nothing in the picture.
When to change: Leave it at 1, the dialog's default and the encoder's own, which sends nothing. Set 0 to drop the measurement, which saves a little work. Use 2 only when you are comparing streams of different bit depths and want the score taken at the stream's depth rather than the input's.
Encoder default: 1
Values:
- 0: No PSNR line at all.
- 1: Measured at the bit depth of the input. The default, so it is never sent.
- 2: Measured at the bit depth of the stream, which matters when Bit Depth differs from the source.
Related: aomenc.bit-depth, aomenc.tune, concept.psnr
Status: reviewed

## aomenc.q-hist
Label: Q-Hist (n-buckets)
Summary: Prints a histogram of the quantizers the encoder chose, split into this many buckets. 0, the default, prints nothing.
When to change: Leave it at 0. Set 8 or 16 when you want to see how widely the rate control moved the quantizer across a video: a wide spread means the content varied a lot, or the target bitrate was hard to hold. It is a report about the encode, not a setting that changes it.
Encoder default: 0
Related: aomenc.rate-hist, aomenc.end-usage, concept.rate-control
Status: reviewed

## aomenc.rate-hist
Label: Rate Hist (n-buckets)
Summary: Prints a histogram of the bitrate the encoder produced over time, split into this many buckets. 0, the default, prints nothing.
When to change: Leave it at 0. Set 8 or 16 when a bitrate-targeted encode overshoots and you want to see where. It is a report about the encode, not a setting that changes it.
Encoder default: 0
Related: aomenc.q-hist, aomenc.target-bitrate, concept.bitrate
Status: reviewed

## aomenc.disable-warnings
Label: Disable Warnings
Summary: Stops the encoder warning you about settings it thinks are wrong. The encode itself is unchanged.
When to change: Leave it off. The warnings are worth reading; they catch things such as a bitrate far below what the picture needs. StaxRip already sends `--disable-warning-prompt` on every encode, so a warning never stops to ask you a question; this box removes the message as well.
Encoder default: off
Status: reviewed

## aomenc.test-decode
Label: Test Decode
Summary: Decodes each frame as it is encoded and checks it matches what the encoder thinks it produced. It adds a full decode to the encode and finds encoder bugs, not settings mistakes.
When to change: Leave it off. Turn it on only when you suspect the encoder or your hardware of producing a broken stream; Fatal stops the encode at the first mismatch, Warn keeps going and tells you. A mismatch is an encoder bug, not something a setting of yours can cause.
Encoder default: Off
Values:
- off: The dialog's default; never sent. No checking.
- fatal: Stops the encode at the first frame that does not match.
- warn: Reports a mismatch and carries on.
Status: reviewed

## aomenc.input-bit-depth
Label: Input Bit Depth
Summary: Tells the encoder how many bits a sample of the incoming video really has. It describes the input; it does not change the depth of the file you get.
When to change: Leave it on Automatic. StaxRip feeds aomenc a Y4M stream, whose header already carries the depth, so the encoder reads it for itself. The bundled build refuses the word `automatic`, which is harmless because Automatic is the dialog's default and is never sent (tested). Set a number only when you know the pipe is lying about the depth.
Values:
- automatic: Never sent, being the dialog's default; the encoder takes the depth from the Y4M header.
- 8: Claims the input is 8-bit.
- 10: Claims the input is 10-bit.
- 12: Claims the input is 12-bit.
Related: aomenc.bit-depth, aomenc.use-16bit-internal, staxrip.pipe
Status: reviewed

## aomenc.bit-depth
Label: Bit Depth
Summary: Sets how many bits a sample the AV1 stream is coded at. Ten bits leaves less banding in gradients than eight and costs a little speed.
When to change: Leave it at 10, which is what StaxRip starts on and sends on every encode; it is the usual choice for AV1 even from an 8-bit source. In a test the same 8-bit clip came out with `g_bit_depth = 10` while the input stayed at 8 (tested). Pick 8 only for a player that will not take 10-bit AV1; 12 is rare and pushes the stream into AV1's Professional profile.
Encoder default: 10 in this dialog, and always sent
Values:
- 8: Eight bits a sample. Smaller gains in speed, more visible banding in skies and fades.
- 10: Ten bits a sample. The dialog's default and the usual choice for AV1.
- 12: Twelve bits. The encoder reported `g_profile = 2`, AV1's Professional profile, which few players accept (tested).
Related: aomenc.input-bit-depth, aomenc.profile, aomenc.use-16bit-internal, aomenc.psnr
Status: reviewed

## aomenc.ivf
Label: Output IVF
Summary: Writes the video in an IVF container, a thin wrapper around the frames. It is what StaxRip starts on and what the rest of its pipeline expects.
When to change: Leave it ticked. The three output boxes are exclusive: ticking one unticks the others, and StaxRip names the file `.ivf`, `.obu` or `.webm` to match. IVF is the safe choice because everything downstream in StaxRip can remux it. Large Scale Tile Coding needs IVF and refuses to start without it (tested).
Encoder default: on in this dialog
Related: aomenc.obu, aomenc.webm, aomenc.large-scale-tile
Status: reviewed

## aomenc.obu
Label: Output OBU
Summary: Writes the raw AV1 bitstream with no container at all, just the coded units end to end.
When to change: Leave it off unless a tool downstream wants a bare stream. Ticking it unticks Output IVF and Output WEBM, and StaxRip names the file `.obu`. A bare stream carries no frame rate, so a muxer has to be told the timing separately.
Encoder default: off
Related: aomenc.ivf, aomenc.webm, aomenc.annexb
Status: reviewed

## aomenc.webm
Label: Output WEBM (enabled by default when WebM IO is enabled)
Summary: Writes the video into a WebM container, which is a Matroska file with a restricted set of codecs.
When to change: Leave it off. Ticking it unticks the other two output boxes and StaxRip names the file `.webm`. It is worth it only when you want the encoder's own container rather than the one StaxRip's muxer would build, and StaxRip then has to remux it anyway to add audio.
Encoder default: off
Related: aomenc.ivf, aomenc.obu
Status: reviewed

## aomenc.yv12
Label: YV12
Summary: Tells the encoder the incoming raw video is YV12, 4:2:0 with the two color planes in the other order. It describes the input, not the output.
When to change: Leave it off. It only means anything for raw input, and StaxRip always pipes Y4M, whose header names the format. Encoding the same clip with the box on and off gave two files of exactly the same size (tested).
Encoder default: off
Related: aomenc.i420, aomenc.i422, aomenc.i444, staxrip.pipe
Status: reviewed

## aomenc.i420
Label: I420
Summary: Tells the encoder the incoming raw video is I420, ordinary 4:2:0. It describes the input, not the output.
When to change: Nothing to do here. The box starts ticked and sends nothing either way: ticked it matches the encoder's own default, and unticked StaxRip has no switch to send. It only means anything for raw input, and StaxRip always pipes Y4M, whose header names the format (tested).
Encoder default: on in this dialog, and never sent
Related: aomenc.yv12, aomenc.i422, aomenc.i444, staxrip.pipe
Status: reviewed

## aomenc.i422
Label: I422
Summary: Tells the encoder the incoming raw video is 4:2:2, with the color planes at full height. It describes the input, not the output.
When to change: Leave it off. It only means anything for raw input, and StaxRip always pipes Y4M, whose header names the format; the neighbouring format boxes changed nothing in a test (tested). AV1 cannot store 4:2:2 at all, so a 4:2:2 script is converted before it reaches the encoder either way.
Encoder default: off
Related: aomenc.i420, aomenc.i444, staxrip.pipe
Status: reviewed

## aomenc.i444
Label: I444
Summary: Tells the encoder the incoming raw video is 4:4:4, with full color resolution. It describes the input, not the output.
When to change: Leave it off. It only means anything for raw input, and StaxRip always pipes Y4M, whose header names the format; the box changed nothing in a test (tested). To really encode 4:4:4, make the script produce it and let the Y4M header say so.
Encoder default: off
Related: aomenc.i420, aomenc.i422, aomenc.profile, staxrip.pipe
Status: reviewed

## aomenc.usage
Label: Usage
Summary: Picks the encoder's whole working mode: good quality, realtime, or all-intra, where every frame stands alone.
When to change: Leave it at 0. It is the same setting the Good Quality and Realtime Quality boxes reach, said as a number, and 2 is the third mode those boxes cannot reach. All-intra makes every frame a keyframe, which suits an editing master and is wrong for delivery: with `--usage=2` the encoder reported `kf_max_dist = 0` and `g_lag_in_frames = 0`, so nothing predicts from anything (tested).
Encoder default: 0
Related: aomenc.good, aomenc.rt, aomenc.cpu-used, aomenc.kf-max-dist
Status: reviewed

## aomenc.threads
Label: Threads
Summary: Caps how many threads the encoder may use, and with them how much of your CPU the encode takes.
When to change: Leave it at 32, which StaxRip sends on every encode. The encoder uses no more than the work it can find, so a number above your core count costs nothing; much of aomenc's parallel work comes from Tile Columns and Tile Rows, not from this box alone. Lower it to keep cores free for something else. Left to itself the encoder reported `g_threads = 0` (tested), so this box is doing real work.
Encoder default: 32 in this dialog, and always sent
Related: aomenc.tile-columns, aomenc.tile-rows, aomenc.row-mt, staxrip.chunks, concept.parallelism, concept.tiles
Status: reviewed

## aomenc.profile
Label: Profile
Summary: Picks the AV1 profile, the set of bit depths and color samplings the stream is allowed to use. A player refuses a profile it does not support.
When to change: Leave it at 0. Main, profile 0, covers 8-bit and 10-bit 4:2:0 and 4:0:0, which is nearly everything; the encoder picks the right profile from the Bit Depth and the input anyway. Profile 1 is High, for 4:4:4, and profile 2 is Professional, for 4:2:2 and 12-bit. Setting a profile the video does not fit stops the encode.
Encoder default: 0
Related: aomenc.bit-depth, aomenc.i444, aomenc.set-tier-mask, concept.level
Status: reviewed

## aomenc.width
Label: Width
Summary: Overrides the frame width the encoder reads from the input. 0, the default, uses the width the pipe reports.
When to change: Leave it at 0. StaxRip's Y4M pipe already carries the real size, and a number here that does not match it either stops the encode or crops and shifts the picture. Change the size with the Resize filter instead, where you can see the result.
Encoder default: 0
Related: aomenc.height, aomenc.forced-max-frame-width
Status: reviewed

## aomenc.height
Label: Height
Summary: Overrides the frame height the encoder reads from the input. 0, the default, uses the height the pipe reports.
When to change: Leave it at 0, for the same reason as Width: StaxRip's Y4M pipe already carries the real size. Change the size with the Resize filter instead.
Encoder default: 0
Related: aomenc.width, aomenc.forced-max-frame-height
Status: reviewed

## aomenc.forced-max-frame-width
Label: Force Width
Summary: Declares the largest frame width the stream will ever hold, so a decoder can set its buffers up once. It does not resize anything.
When to change: Leave it at 0. It matters only when the frame size changes part way through a stream, which StaxRip never produces: a script has one size throughout. Setting it below the real width stops the encode.
Encoder default: 0
Related: aomenc.forced-max-frame-height, aomenc.width, aomenc.resize-mode
Status: reviewed

## aomenc.forced-max-frame-height
Label: Force Height
Summary: Declares the largest frame height the stream will ever hold, so a decoder can set its buffers up once. It does not resize anything.
When to change: Leave it at 0, for the same reason as Force Width: StaxRip's scripts have one frame size from beginning to end.
Encoder default: 0
Related: aomenc.forced-max-frame-width, aomenc.height, aomenc.resize-mode
Status: reviewed

## aomenc.stereo-mode
Label: Stereo Mode
Summary: Tags the stream as a stereoscopic 3D picture and says how the two eyes are packed into each frame. It is a label and rearranges no pixel.
When to change: Leave it on Disabled unless your source really is a 3D frame-packed video and you know which way round it is. The frames are stored exactly as your script produces them either way; this only tells a 3D player how to split them. A wrong tag swaps or splits the picture on playback.
Values:
- disabled: Never sent, being the dialog's default. The bundled build refuses the word itself (tested).
- mono: One picture, not stereoscopic.
- left-right: The two eyes side by side, left on the left.
- bottom-top: The two eyes stacked, right eye on top.
- top-bottom: The two eyes stacked, left eye on top.
- right-left: The two eyes side by side, right on the left.
Related: aomenc.timing-info
Status: reviewed

## aomenc.timebase
Label: Timebase precision
Summary: Sets the unit the encoder counts timestamps in, as a fraction of a second. It changes how finely frame times can be expressed, not the frame rate.
Used when: Only when you fill it in. Left empty, which is how it starts, the encoder uses its own default of 1/1000 of a second.
When to change: Leave it empty. The encoder's own help gives the default as 1/1000, which is fine for every ordinary frame rate. Set it only when a downstream tool asks for a particular timebase, and write it as a fraction such as `1/1000`.
Encoder default: 1/1000
Related: aomenc.fps, aomenc.timing-info
Status: reviewed

## aomenc.fps
Label: Frame Rate
Summary: Overrides the frame rate the encoder reads from the input, as a fraction. It changes the timing written into the stream, not the frames themselves.
Used when: Only when you fill it in. Left empty, which is how it starts, the rate comes from the Y4M header StaxRip's pipe writes.
When to change: Leave it empty. The pipe already carries the script's real frame rate, and a wrong value here makes the video play at the wrong speed while the audio does not. Write it as rate over scale, so `30000/1001` for 29.97 fps. To really change the rate, use a frame rate filter in the script.
Example: `24000/1001` is 23.976 fps and `25/1` is 25 fps.
Related: aomenc.timebase, staxrip.pipe
Status: reviewed

## aomenc.global-error-resilient
Label: Global Error Resilient
Summary: Codes the stream so a decoder can recover from a lost or damaged part, at the cost of compression across the whole file.
Used when: Only when you fill it in. Left empty, which is how it starts, the encoder reported `g_error_resilient = 0` (tested).
When to change: Leave it empty. It is for streams sent over a lossy link, where a decoder must be able to carry on after damage; every frame then leans less on its neighbours, which costs bits. A file on disk is never damaged in that way. Type `1` to switch it on.
Encoder default: 0
Related: aomenc.error-resilient, aomenc.frame-parallel, concept.compression-efficiency
Status: reviewed

## aomenc.lag-in-frames
Label: Lag In Frames
Summary: Sets how many frames the encoder may read ahead of the one it is coding, so it can plan frame types and bits with what is coming into view.
When to change: Leave it at 35, which is the encoder's own default as well, so StaxRip sends nothing (tested). Lowering it shortens the wait before the first frame comes out and costs compression; 0 turns the alt-ref frames off entirely, which is what Realtime Quality Deadline does (tested). Raising it costs memory and rarely helps. The dialog takes 0 to 999.
Encoder default: 35
Related: aomenc.auto-alt-ref, aomenc.rt, aomenc.arnr-maxframes, concept.lookahead
Status: reviewed

## aomenc.large-scale-tile
Label: Large Scale Tile Coding
Summary: Codes the frame as a grid of tiles a player may decode on their own, so it can show one corner of a very large picture without decoding all of it.
Used when: Only with Output IVF ticked. Without it the encoder refuses to start: "only support ivf output format while large-scale-tile=1" (tested).
When to change: Leave it off. It is for viewers of very large still or panoramic images that pan around a picture, not for video you watch end to end, and it costs compression because each tile stands alone.
Encoder default: Off
Values:
- 0: Off. The dialog's default; never sent.
- 1: On. Needs Output IVF.
Related: aomenc.ivf, aomenc.tile-columns, aomenc.tile-rows, concept.tiles
Status: reviewed

## aomenc.monochrome
Label: Monochrome
Summary: Encodes only the brightness channel and throws the color away. The file is smaller and plays back grey.
When to change: Leave it off unless the source really is black and white and you never want color back. It cannot be undone, so keep the color source. On genuinely grey material it saves the bits the two color planes would have taken.
Encoder default: off
Related: aomenc.profile
Status: reviewed

## aomenc.full-still-picture-hdr
Label: Full header for still picture
Summary: Writes the complete sequence header into a single-picture stream instead of the short form, so more decoders can read it.
Used when: Only for a stream holding one picture. It has nothing to describe in ordinary video.
When to change: Leave it off. Turn it on only when you are encoding one frame as an AVIF-style still and a decoder rejects the short header.
Encoder default: off
Related: aomenc.force-video-mode, aomenc.limit
Status: reviewed

## aomenc.use-16bit-internal
Label: Force 16-bit pipeline
Summary: Makes the encoder hold every sample in 16 bits while it works, even for 8-bit video. It costs memory and some speed and changes nothing you can see.
When to change: Leave it off. The encoder chooses the right internal path on its own; it reported `Coding path: LBD` for 8-bit input (tested). Force it only to work around a suspected bug in the 8-bit path, or when an encoder developer asks you to.
Encoder default: off
Related: aomenc.bit-depth, aomenc.input-bit-depth
Status: reviewed

## aomenc.drop-frame
Label: Drop Frame
Summary: Lets the encoder throw a frame away when its rate buffer falls below this percentage, holding the bitrate by showing you fewer frames.
Used when: Only with a bitrate target, and it is really meant for CBR. In the constant-quality modes there is no buffer to run dry.
When to change: Leave it at 0, which switches it off and matches the encoder's own default. Dropped frames show as a stutter, which is nearly always worse than a moment of soft picture. Raise it only for a stream that must never exceed its bitrate, and then find the number by testing rather than by guessing.
Encoder default: 0
Related: aomenc.end-usage, aomenc.buf-sz, concept.rate-control
Status: reviewed

## aomenc.resize-mode
Label: Resize Mode
Summary: Lets the encoder code frames at a reduced size and have the player stretch them back, trading detail for bits when the bitrate is tight.
When to change: Leave it at 0, off, which is the encoder's own default. It is a low-bitrate rescue, not a quality tool: what the squeeze loses does not come back. Resize the picture in the script instead, where you choose the filter. Mode 1 uses a fixed denominator, 2 varies it at random, 3 lets the rate control decide.
Encoder default: 0
Related: aomenc.resize-denominator, aomenc.resize-kf-denominator, aomenc.superres-mode, concept.super-resolution
Status: reviewed

## aomenc.resize-denominator
Label: Resize Denominator
Summary: How far the encoder shrinks a frame in Resize Mode 1, as a fraction of eight: 8 is full size, 16 is half width and half height.
Used when: Only with Resize Mode 1. In every other mode the encoder ignores it.
When to change: Leave it at 0. The box starts at 0, which is not the encoder's default of 8, and because 0 is the box's own starting value StaxRip sends nothing at all, so the encoder uses 8, meaning no resize. To use it, set Resize Mode 1 and then a number from 9 to 16 here.
Encoder default: 8, which means full size
Related: aomenc.resize-mode, aomenc.resize-kf-denominator
Status: reviewed

## aomenc.resize-kf-denominator
Label: Resize KF Denominator
Summary: The same shrinking fraction as Resize Denominator, but for keyframes, so the frames playback starts from can keep more detail.
Used when: Only with Resize Mode 1.
When to change: Leave it at 0. As with Resize Denominator the box starts below the encoder's own default of 8, so nothing is sent and full-size keyframes are what you get. Use a smaller number than the ordinary denominator when you do turn resizing on, so keyframes stay sharper.
Encoder default: 8, which means full size
Related: aomenc.resize-mode, aomenc.resize-denominator, concept.keyframe
Status: reviewed

## aomenc.superres-mode
Label: SuperRes
Summary: Codes frames at a reduced width and has the player stretch them back with AV1's own upscaler, an escape valve for very low bitrates.
When to change: Leave it at 0, off, which is the encoder's own default. Unlike Resize Mode it only squeezes horizontally and the player uses a filter built into AV1, but the detail lost in the squeeze still does not come back. Mode 1 is a fixed denominator, 2 random, 3 keyed to the quantizer threshold below, 4 lets the encoder decide.
Encoder default: 0
Related: aomenc.superres-denominator, aomenc.superres-qthresh, aomenc.resize-mode, concept.super-resolution
Status: reviewed

## aomenc.superres-denominator
Label: SuperRes Denominator
Summary: How far SuperRes mode 1 squeezes the width, as a fraction of eight: 8 is full width, 16 is half.
Used when: Only with SuperRes mode 1.
When to change: Leave it at 0. The box starts below the encoder's own default of 8, so nothing is sent and no squeeze happens. If you do turn SuperRes on, 10 or 12 is a gentle squeeze and 16 is aggressive.
Encoder default: 8, which means full width
Related: aomenc.superres-mode, aomenc.superres-kf-denominator, concept.super-resolution
Status: reviewed

## aomenc.superres-kf-denominator
Label: SuperRes KF Denominator
Summary: The same squeeze as SuperRes Denominator, but for keyframes, so the frames playback starts from can keep their full width.
Used when: Only with SuperRes mode 1.
When to change: Leave it at 0; the box starts below the encoder's own default of 8, so nothing is sent. Keep it smaller than the ordinary denominator when you use SuperRes, so a viewer seeking into the video lands on a sharper frame.
Encoder default: 8, which means full width
Related: aomenc.superres-mode, aomenc.superres-denominator, concept.keyframe
Status: reviewed

## aomenc.superres-qthresh
Label: SuperRes qThresh
Summary: In SuperRes mode 3, the quantizer above which the encoder starts squeezing the width. It decides how bad things must get before SuperRes steps in.
Used when: Only with SuperRes mode 3.
When to change: Leave it at 0. The box starts below the encoder's own default of 63, so nothing is sent. Lower it only when you have chosen SuperRes mode 3 and want the squeeze to reach more frames; the lower the threshold, the more of the video is coded narrow.
Encoder default: 63
Related: aomenc.superres-mode, aomenc.superres-kf-qthresh, aomenc.cq-level
Status: reviewed

## aomenc.superres-kf-qthresh
Label: SuperRes KF qThresh
Summary: The same trigger as SuperRes qThresh, but for keyframes, so keyframes can be squeezed at a different point from the frames between them.
Used when: Only with SuperRes mode 3.
When to change: Leave it at 0; the box starts below the encoder's own default of 32, so nothing is sent. Note the encoder's default here is lower than the one for ordinary frames, so out of the box a keyframe is squeezed sooner than its neighbours.
Encoder default: 32
Related: aomenc.superres-mode, aomenc.superres-qthresh, concept.keyframe
Status: reviewed

## aomenc.end-usage
Label: Rate Mode
Summary: Chooses what the encode aims at: a bitrate, or a quality level with the size falling where it may. It also decides which of CQ Level and Target Bitrate you see.
When to change: Leave it on Q for video you keep: CQ Level sets the quality and nothing caps the bitrate. Pick VBR or CBR when the file has to hit a size. CQ is the middle ground, a quality target that a bitrate may still cut into. StaxRip sends this on every encode, so Q really is what you get out of the box; the encoder's own default would be VBR.
Encoder default: Q in this dialog, and always sent
Values:
- vbr: Aims at Target Bitrate and lets the bitrate rise and fall with the content.
- cbr: Holds the bitrate nearly steady, which costs quality on hard scenes. For live streaming.
- cq: Aims at CQ Level but will not exceed Target Bitrate, so both boxes appear.
- q: Holds CQ Level and lets the size fall where it may. The dialog's default.
Related: aomenc.cq-level, aomenc.target-bitrate, aomenc.passes, aomenc.min-q, aomenc.max-q, concept.rate-control, concept.quality-level
Status: reviewed

## aomenc.cq-level
Label: CQ Level
Summary: Sets how coarsely the encoder rounds picture detail away, on AV1's 0 to 63 quantizer scale. Lower is a better picture and a larger file.
Used when: Only in CQ and Q rate modes. In VBR and CBR the box is hidden and no `--cq-level` is sent.
When to change: Lower it for quality, raise it for a smaller file, then judge a short test encode by eye rather than by the number. StaxRip starts you at 24 and sends it on every encode in these two modes. The encoder takes 0 to 63 and this box does not stop you typing more: at 64 the encode stops with "Tried to set control 25 = 64" (tested). In CQ mode Target Bitrate can still cut in above this quality.
Encoder default: 24 in this dialog, always sent
Example: Encode the same 60-second scene at 24 and at 32 with everything else unchanged. Compare the sizes, then step through a detailed frame in each and take the higher number if you cannot see the difference.
Related: aomenc.end-usage, aomenc.min-q, aomenc.max-q, aomenc.target-bitrate, concept.quality-level
Status: reviewed

## aomenc.target-bitrate
Label: Target Bitrate
Summary: The bitrate in kbps the encoder aims at across the whole video. Together with the running time it sets the size of the video stream.
Used when: In VBR, CBR and CQ rate modes. In Q mode the box is hidden and no bitrate reaches the encoder.
When to change: Set the size or the bitrate in the main window instead; both boxes feed this one. The dialog takes 0 to 1000000 kbps in steps of 100. Two passes land closer to the target than one. In the second pass StaxRip sends the bitrate the main window works out rather than this box, so a target size set there wins.
Encoder default: 256
Example: Twenty minutes at 4000 kbps is roughly 600 MB of video before audio (4000 x 1200 / 8 / 1000). Type a size into the main window's target size box and reopen this dialog: this value follows it.
Related: aomenc.end-usage, aomenc.passes, aomenc.cq-level, concept.bitrate, concept.rate-control
Status: reviewed

## aomenc.min-q
Label: Minimum Quantizer
Summary: The finest quantizer the rate control may use, which is a floor on how many bits a single frame may be given.
Used when: In the bitrate modes. In Q mode the quality is fixed, so there is nothing for it to bound.
When to change: Leave it at 0, which is the encoder's own default and lets the rate control spend freely on an easy scene. Raise it only to stop a bitrate-targeted encode from pouring bits into a static shot; 8 or 12 is a gentle cap. Too high a floor makes the whole file soft.
Encoder default: 0
Related: aomenc.max-q, aomenc.end-usage, aomenc.cq-level, concept.rate-control
Status: reviewed

## aomenc.max-q
Label: Maximum Quantizer
Summary: The coarsest quantizer the rate control may use, which is a quality floor: the encoder will overshoot the bitrate rather than go beyond it.
Used when: In the bitrate modes.
When to change: Leave it at 0. The box starts at 0, which is not the encoder's default of 63, and because 0 is the box's own starting value StaxRip sends nothing, so 63 applies. Lower it, say to 50, when a bitrate-targeted encode falls apart on the hardest scenes and you would rather it went over the target than looked like that.
Encoder default: 63
Related: aomenc.min-q, aomenc.end-usage, aomenc.cq-level, concept.rate-control
Status: reviewed

## aomenc.undershoot-pct
Label: Datarate undershoot (min) target (%)
Summary: How far below the target bitrate the rate control is allowed to drift, as a percentage. It gives the encoder room to spend less on easy material.
Used when: In the bitrate modes.
When to change: Leave it at 0. The box starts at 0, which is not the encoder's default of 25, and because 0 is the box's own starting value nothing is sent, so 25 applies; you cannot reach a real 0 from this box, only from the Custom box. Raise it when you would rather the file came in small than exactly on target.
Encoder default: 25
Related: aomenc.overshoot-pct, aomenc.end-usage, staxrip.custom, concept.rate-control
Status: reviewed

## aomenc.overshoot-pct
Label: Datarate overshoot (max) target (%)
Summary: How far above the target bitrate the rate control is allowed to drift, as a percentage. It gives the encoder room to spend more on hard material.
Used when: In the bitrate modes.
When to change: Leave it at 0. As with the undershoot box, 0 is the box's own starting value, so nothing is sent and the encoder's default of 25 applies. Raise it when hard scenes look poor and the exact file size matters less than they do.
Encoder default: 25
Related: aomenc.undershoot-pct, aomenc.end-usage, staxrip.custom, concept.rate-control
Status: reviewed

## aomenc.buf-sz
Label: Client buffer size
Summary: How many milliseconds of video a player is assumed to be able to hold. It bounds how far the bitrate may swing before the rate control pulls it back.
Used when: In CBR, and to a lesser extent VBR. In the constant-quality modes there is no buffer model at all.
When to change: Leave it at 0. The box starts at 0, which is not the encoder's default of 6000 ms, so nothing is sent and 6000 applies. A smaller buffer holds the bitrate steadier and costs quality; a larger one is smoother to watch and harder to stream. Only change it when a streaming target names a buffer size.
Encoder default: 6000
Related: aomenc.buf-initial-sz, aomenc.buf-optimal-sz, aomenc.end-usage, staxrip.custom, concept.rate-control
Status: reviewed

## aomenc.buf-initial-sz
Label: Client initial buffer size (ms)
Summary: How full the player's buffer is assumed to be when playback starts. It decides how carefully the encoder must ration the opening seconds.
Used when: In CBR, and to a lesser extent VBR.
When to change: Leave it at 0; the box starts below the encoder's own default of 4000 ms, so nothing is sent. It should stay below Client buffer size. Only change it when a streaming target names a start-up delay.
Encoder default: 4000
Related: aomenc.buf-sz, aomenc.buf-optimal-sz, concept.rate-control
Status: reviewed

## aomenc.buf-optimal-sz
Label: Client optimal buffer size (ms)
Summary: The buffer level the rate control tries to settle at, between the initial level and the full size.
Used when: In CBR, and to a lesser extent VBR.
When to change: Leave it at 0; the box starts below the encoder's own default of 5000 ms, so nothing is sent. It belongs between the initial size and the full buffer size, and there is little reason to move it unless a streaming target names all three.
Encoder default: 5000
Related: aomenc.buf-sz, aomenc.buf-initial-sz, concept.rate-control
Status: reviewed

## aomenc.bias-pct
Label: CBR/VBR bias (0=CBR, 100=VBR)
Summary: How freely the two-pass rate control may move bits from easy scenes to hard ones. 0 keeps the bitrate steady, 100 lets it vary as much as the content asks.
Used when: In two-pass VBR encodes.
When to change: Leave it at 0. The box starts at 0, which is not the encoder's default of 50, and because 0 is the box's own starting value nothing is sent, so 50 applies; a real 0 is only reachable from the Custom box. Raise it toward 100 when the file may vary in bitrate and you want the hard scenes to look better.
Encoder default: 50
Related: aomenc.end-usage, aomenc.passes, staxrip.custom, concept.rate-control, concept.two-pass
Status: reviewed

## aomenc.minsection-pct
Label: GOP min bitrate (% of target)
Summary: The least a run of frames between keyframes may be given, as a percentage of the target bitrate. It stops the encoder starving an easy stretch.
Used when: In two-pass bitrate encodes.
When to change: Leave it at 0, which is the encoder's own default and means no floor. Raise it, say to 20, only when long still stretches come out visibly soft in a bitrate-targeted encode.
Encoder default: 0
Related: aomenc.maxsection-pct, aomenc.end-usage, concept.gop, concept.rate-control
Status: reviewed

## aomenc.maxsection-pct
Label: GOP max bitrate (% of target)
Summary: The most a run of frames between keyframes may be given, as a percentage of the target bitrate. It stops one hard scene eating the whole file.
Used when: In two-pass bitrate encodes.
When to change: Leave it at 0. The box starts at 0, which is not the encoder's default of 2000 per cent, so nothing is sent and that generous ceiling applies. Lower it, say to 400, when one action scene swallows so many bits that the rest of the film suffers.
Encoder default: 2000
Related: aomenc.minsection-pct, aomenc.end-usage, concept.gop, concept.rate-control
Status: reviewed

## aomenc.enable-fwd-kf
Label: Enable forward reference keyframes
Summary: Lets the encoder place a keyframe that later frames may still borrow from, so a cut costs fewer bits than an ordinary keyframe would.
When to change: Leave it at 0, off, which is the encoder's own default. Set 1 when file size matters more than being able to seek anywhere: a forward keyframe is cheaper but is not a clean entry point, so seeking to it is not guaranteed to work in every player.
Encoder default: 0
Related: aomenc.kf-min-dist, aomenc.kf-max-dist, aomenc.disable-kf, concept.keyframe
Status: reviewed

## aomenc.kf-min-dist
Label: Min keyframe interval
Summary: The shortest gap the encoder may leave between keyframes, so a run of quick cuts cannot fill the file with whole frames.
When to change: Leave it at 12, which StaxRip sends on every encode; the encoder's own default is 0, no minimum at all. Raise it when a cut-heavy source comes out larger than you expect: the scene-change detector must then wait that many frames before it may start another keyframe. It does nothing above Max keyframe interval, which is the other end of the same range. The dialog takes 0 to 9999.
Encoder default: 0, but StaxRip sends 12
Related: aomenc.kf-max-dist, aomenc.enable-fwd-kf, aomenc.disable-kf, concept.keyframe, concept.gop
Status: reviewed

## aomenc.kf-max-dist
Label: Max keyframe interval
Summary: The longest gap the encoder may leave between keyframes, the frames stored whole that playback can start from.
When to change: Leave it at 300, which StaxRip sends on every encode; the encoder's own default is 9999, which is effectively no limit. At 24 fps, 300 is a keyframe at least every twelve and a half seconds. Shorten it when quick seeking matters more than size, since every keyframe costs bits. The encoder also starts a keyframe at a scene cut of its own accord, so this is a ceiling rather than a rhythm.
Encoder default: 9999, but StaxRip sends 300
Example: At 24 fps, 120 gives a keyframe at least every five seconds. In all-intra mode the encoder sets this to 0 and every frame becomes a keyframe (tested).
Related: aomenc.kf-min-dist, aomenc.disable-kf, aomenc.usage, concept.keyframe, concept.gop
Status: reviewed

## aomenc.disable-kf
Label: Disable keyframe placement
Summary: Stops the encoder placing keyframes anywhere except the very first frame. Seeking then has almost nothing to land on.
When to change: Leave it off. A file with one keyframe is smaller but nearly unseekable, and a player that loses its place cannot recover. It exists for pipelines that cut and splice the stream themselves.
Encoder default: off
Related: aomenc.kf-max-dist, aomenc.kf-min-dist, concept.keyframe
Status: reviewed

## aomenc.cpu-used
Label: CPU Used
Summary: Sets how much work the encoder does on each frame, from 0 (slowest, smallest file) to 9 (fastest). It is the main speed against size control.
When to change: StaxRip starts you at 4 and sends it on every encode. Drop to 3 or 2 for a final encode when you can wait; go to 6 for a quick look. In good quality the encoder's own help gives the useful range as 0 to 6, and entries 7 and 9 produced a file identical in size to 6, so they buy nothing there (tested). Realtime Quality Deadline moves the range to 5 to 12, past what this dialog can reach.
Encoder default: 4 in this dialog, and always sent
Example: Encode the same 60-second scene at 4 and at 2 with the same CQ Level, then compare the time and the file size before you commit the whole video.
Values:
- 0: Slowest. Hours per minute of video on a large picture.
- 4: The dialog's default, and a reasonable place to judge a source from.
- 6: The fastest setting that still means anything in good quality.
- 7: Produced a file the same size as 6 in good quality; only Realtime uses it (tested).
- 8: Between 7 and 9, both of which matched 6 in good quality; only Realtime uses this range.
- 9: The fastest the dialog offers, and still the same as 6 in good quality (tested).
Related: aomenc.good, aomenc.rt, aomenc.usage, aomenc.threads, concept.compression-efficiency
Status: reviewed

## aomenc.auto-alt-ref
Label: Auto Alt Ref
Summary: Lets the encoder build extra hidden frames from several source frames and predict from those, which is where much of AV1's efficiency comes from.
When to change: Leave it at 1, which StaxRip sends on every encode. Setting 0 turns the hidden alt-ref frames off, which costs a lot of compression for a little speed; Realtime Quality Deadline effectively does that already by dropping Lag In Frames to 0 (tested). The frames it builds are filtered versions of what is coming, which is what ARNR Max Frames and ARNR Filter Strength control.
Encoder default: 1 in this dialog, and always sent
Related: aomenc.arnr-maxframes, aomenc.arnr-strength, aomenc.lag-in-frames, aomenc.enable-overlay, concept.compression-efficiency
Status: reviewed

## aomenc.sharpness
Label: Sharpness
Summary: Biases the encoder toward keeping block edges sharp rather than smooth when it decides how to spend bits, from 0 to 7.
When to change: Leave it at 0, the encoder's own default, which StaxRip does not send. Raise it when an encode looks soft or waxy and you would rather have visible detail than a clean surface; the cost is bits and sometimes visible block edges. In all-intra mode the encoder's help says it also eases the edge filtering.
Encoder default: 0
Example: On a 64 by 64 four-frame test clip `--sharpness=7` moved the file by 31 bytes in 14 KB, so expect the difference to be in how it looks rather than in how large it is.
Related: aomenc.enable-cdef, aomenc.enable-restoration, aomenc.tune, concept.deblocking
Status: reviewed

## aomenc.static-thresh
Label: Static Threshold
Summary: Lets the encoder skip a block whose motion search score falls under this number, coding it as unchanged. It buys speed by ignoring small differences.
When to change: Leave it at 0, which StaxRip sends on every encode and which switches the shortcut off. Raising it makes still parts of the picture freeze instead of shimmering, which can look either cleaner or smeared depending on the source, and saves a little time. It is a blunt tool; CPU Used is the better speed control.
Encoder default: 0 in this dialog, and always sent
Related: aomenc.cpu-used, aomenc.aq-mode
Status: reviewed

## aomenc.row-mt
Label: Multi-Threading
Summary: Lets several threads work on different rows of the same tile at once, so a many-core machine is used even when there are few tiles.
When to change: Leave it ticked, which is the encoder's own default and sends nothing. Unticking sends `--row-mt=0` and gives the threads much less to do, so the encode slows down on a many-core machine. Turn it off only to reproduce a bug that appears with threading.
Encoder default: on
Related: aomenc.threads, aomenc.tile-columns, aomenc.tile-rows, concept.parallelism
Status: reviewed

## aomenc.tile-columns
Label: Tile Columns
Summary: Cuts the frame into vertical strips coded on their own, counted as a power of two: 2 means four columns. More tiles use more cores and cost a little compression.
When to change: Leave it at 2, which StaxRip sends on every encode and which suits a large picture on a many-core machine. Drop it to 0 or 1 for small video, where four columns is more cutting than the picture can bear; each cut costs bits because prediction starts afresh at its edge. The encoder cannot use more columns than the picture is wide in superblocks.
Encoder default: 0, but StaxRip sends 2
Example: 2 gives four tile columns, 3 gives eight. For 1080p, 2 is a common choice; for 480p, 0 or 1.
Related: aomenc.tile-rows, aomenc.threads, aomenc.row-mt, aomenc.sb-size, concept.tiles, concept.parallelism
Status: reviewed

## aomenc.tile-rows
Label: Tile Rows
Summary: Cuts the frame into horizontal bands coded on their own, counted as a power of two: 1 means two rows. More tiles use more cores and cost a little compression.
When to change: Leave it at 1, which StaxRip sends on every encode. Rows help less than columns on wide video, so keep this the smaller of the two. Drop it to 0 for small pictures. Every cut costs bits, and many tiles can show as faint seams on flat areas.
Encoder default: 0, but StaxRip sends 1
Related: aomenc.tile-columns, aomenc.threads, aomenc.row-mt, concept.tiles, concept.parallelism
Status: reviewed

## aomenc.enable-tpl-model
Label: TPL model
Summary: Lets the encoder look at how much later frames will lean on each part of this one and spend bits accordingly. It is a real gain in efficiency.
When to change: Leave it at 1, which StaxRip sends on every encode. Delta QIndex Mode 1, the encoder's own default, needs this on; the dialog's caption for that control says so. Turning it off costs compression for a little speed.
Encoder default: 1 in this dialog, and always sent
Values:
- 0: Off. Bits are spread without regard to what later frames will need.
- 1: On, planning from the frames that follow. The dialog's default.
Related: aomenc.deltaq-mode, aomenc.lag-in-frames, concept.compression-efficiency, concept.lookahead
Status: reviewed

## aomenc.enable-keyframe-filtering
Label: Keyframe Filtering
Summary: Filters a keyframe against its neighbours before coding it, so that noise costing many bits on the most expensive frame in the group is smoothed away.
When to change: Leave it at 1, the dialog's default and the encoder's own, which sends nothing. Setting 0 keeps keyframes exactly as your script produced them, which suits already clean material. The encoder's own help calls 2 experimental and warns it may break seeking in some players.
Encoder default: 1
Values:
- 0: No filtering; the keyframe is coded as the script produced it.
- 1: Filter without an overlay frame. The default, so it is never sent.
- 2: Filter with an overlay frame. The encoder's help calls this experimental and says it may break random access in players.
Related: aomenc.kf-max-dist, aomenc.arnr-maxframes, aomenc.enable-overlay, concept.keyframe
Status: reviewed

## aomenc.arnr-maxframes
Label: ARNR Max Frames
Summary: How many frames the encoder blends together when it builds a filtered hidden reference frame, from 0 to 15. More frames means a cleaner reference and more work.
When to change: Leave it at 7, the value the box starts on, which StaxRip does not send. Lower it when fast motion makes the filtered frame smear; raise it on noisy but static material, where blending more frames removes noise the encoder would otherwise have to spend bits on. It does nothing with Auto Alt Ref at 0.
Encoder default: 7 in this dialog
Related: aomenc.arnr-strength, aomenc.auto-alt-ref, aomenc.lag-in-frames
Status: reviewed

## aomenc.arnr-strength
Label: ARNR Filter Strength
Summary: How hard the encoder filters when it blends frames into a hidden reference, from 0 to 6. Stronger filtering removes more noise and more real detail.
When to change: Leave it at 5, the value the box starts on, which StaxRip does not send. Lower it to 2 or 3 when fine detail is being smoothed away; 0 turns the filtering off. Raise it only on very noisy sources. It does nothing with Auto Alt Ref at 0.
Encoder default: 5 in this dialog
Related: aomenc.arnr-maxframes, aomenc.auto-alt-ref, aomenc.denoise-noise-level
Status: reviewed

## aomenc.tune
Label: Tune
Summary: Chooses which measure of distortion the encoder tries to make small when it weighs one coding choice against another.
When to change: Leave it on psnr, the dialog's default, which sends nothing. Only psnr and ssim work in this build: the five VMAF and butteraugli entries all stop the encode with "Tried to set control 24", because the bundled binary was not built with those metric libraries (tested). The build does accept `--tune=iq` and `--tune=ssimulacra2`, which are not in the dialog; put either in the Custom box to try them.
Encoder default: psnr in this dialog, and never sent
Values:
- psnr: Never sent, being the dialog's default. Weighs plain pixel error.
- ssim: Weighs local structure rather than single pixels. Accepted by the bundled build (tested).
- vmaf_with_preprocessing: Stops the encode in this build, which has no VMAF support (tested).
- vmaf_without_preprocessing: Stops the encode in this build, which has no VMAF support (tested).
- vmaf: Stops the encode in this build, which has no VMAF support (tested).
- vmaf_neg: Stops the encode in this build, which has no VMAF support (tested).
- butteraugli: Stops the encode in this build, which was built without butteraugli (tested).
Related: aomenc.psnr, staxrip.custom, concept.psnr, concept.ssim, concept.vmaf, concept.vq
Status: reviewed

## aomenc.max-intra-rate
Label: Max Intra Rate
Summary: Caps how many bits a keyframe may take, as a percentage of the bits one frame would get at the target bitrate. It stops a keyframe swallowing a stream's buffer.
Used when: In the bitrate modes. In the constant-quality modes there is no per-frame budget for it to cut into.
When to change: Leave it at 0, the box's starting value, which sends nothing and leaves the encoder to size keyframes as it sees fit. Set a few hundred per cent only for streaming, where one huge keyframe stalls playback; the cost is a softer picture right where a viewer starts watching.
Encoder default: 0 in this dialog
Related: aomenc.max-inter-rate, aomenc.kf-max-dist, aomenc.buf-sz, concept.keyframe, concept.rate-control
Status: reviewed

## aomenc.max-inter-rate
Label: Max Inter Rate
Summary: Caps how many bits a frame that is not a keyframe may take, as a percentage of its share of the target bitrate.
Used when: In the bitrate modes.
When to change: Leave it at 0, the box's starting value, which sends nothing. It is a streaming control, like Max Intra Rate: it holds the bitrate steadier at the cost of the hardest moments looking worse.
Encoder default: 0 in this dialog
Related: aomenc.max-intra-rate, aomenc.buf-sz, concept.rate-control
Status: reviewed

## aomenc.gf-cbr-boost
Label: GF CBR Boost
Summary: How many extra bits, as a percentage, a golden frame may take in CBR. A golden frame is a long-lived reference that later frames keep borrowing from.
Used when: Only in CBR.
When to change: Leave it at 0, the box's starting value, which sends nothing. Raise it when a CBR stream looks poor between keyframes and you can accept a bitrate spike where a golden frame lands.
Encoder default: 0 in this dialog
Related: aomenc.end-usage, aomenc.min-gf-interval, aomenc.max-gf-interval, concept.rate-control
Status: reviewed

## aomenc.lossless
Label: Lossless
Summary: Gives back every pixel of the source exactly, like a zip file, so the file is several times larger than a normal encode.
When to change: Leave it off unless you need an exact copy, for an intermediate file in an editing chain for example. On a test clip it more than doubled the file at the same settings (tested). CQ Level and the bitrate boxes stop meaning anything while it is on, since there is no quality left to trade.
Encoder default: off
Example: An eight-frame 64 by 64 test clip came out at 70877 bytes lossless against 31641 bytes without it. Try it on a few seconds of your own video before committing.
Related: aomenc.cq-level, aomenc.end-usage, concept.lossless
Status: reviewed

## aomenc.enable-cdef
Label: CDEF
Summary: Runs AV1's directional cleanup filter inside the encoder, removing the ringing that heavy compression leaves around edges before later frames predict from the frame.
When to change: Leave it ticked, the encoder's own default, which sends nothing. Unticking sends `--enable-cdef=0` and gives you a slightly faster encode with visible ringing at low bitrates. The bundled build also accepts 2, which skips the filter on frames nothing predicts from, and 3, which decides per frame from its quantizer; neither is in this dialog, so use the Custom box (tested).
Encoder default: on
Related: aomenc.enable-restoration, aomenc.sharpness, staxrip.custom, concept.deblocking
Status: reviewed

## aomenc.enable-restoration
Label: Restoration
Summary: Runs AV1's loop restoration filter, which repairs compression damage across a whole frame before later frames predict from it. It costs time and saves bits.
When to change: Leave it on, the dialog's default, which sends nothing so the encoder's own default applies: on in good quality, off in realtime. Note that the box cannot bring it back in realtime, because On is its own starting value and so is never sent; to force it there, put `--enable-restoration=1` in the Custom box. Turning it off is a small speed gain for a real loss at low bitrates.
Encoder default: On in this dialog, and never sent
Values:
- 0: Off. The encoder's own default in realtime mode.
- 1: On. The encoder's own default in good quality, and the dialog's default, so it is never sent.
Related: aomenc.enable-cdef, aomenc.rt, aomenc.sharpness, staxrip.custom, concept.deblocking
Status: reviewed

## aomenc.enable-rect-partitions
Label: Rectangular partitions
Summary: Lets the encoder split a block into two rectangles instead of only four squares, so a shape in the picture can be followed more closely.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-rect-partitions=0` and buys a little speed for a real loss in compression, because every edge in the picture then has to be squared off. Use CPU Used for speed instead; it turns off tools like this one in a balanced way.
Encoder default: on
Related: aomenc.enable-ab-partitions, aomenc.enable-1to4-partitions, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-ab-partitions
Label: AB partitions
Summary: Lets the encoder split a block into the T-shaped arrangements AV1 calls AB partitions, which fit some edges better than a straight cut.
When to change: Leave it ticked, the encoder's own default. Unticking is a small speed gain for a small loss in compression. CPU Used is the better speed control; it manages tools like this one for you.
Encoder default: on
Related: aomenc.enable-rect-partitions, aomenc.enable-1to4-partitions, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-1to4-partitions
Label: 14 And 41 partitions
Summary: Lets the encoder split a block into four thin strips, across or down, which suits fine horizontal or vertical structure such as text or railings.
When to change: Leave it ticked, the encoder's own default. Unticking is a small speed gain and costs most on material with fine repeated structure. CPU Used is the better speed control.
Encoder default: on
Related: aomenc.enable-rect-partitions, aomenc.enable-ab-partitions, aomenc.tune-content, concept.compression-efficiency
Status: reviewed

## aomenc.min-partition-size
Label: Min partition size
Summary: The smallest block the encoder is allowed to split down to. A larger minimum is faster and coarser, because fine detail can no longer get its own block.
When to change: Leave it on Disabled, the dialog's default, which sends nothing and lets the encoder choose. Setting 16 or 32 is a way to buy speed on soft material, but CPU Used does the same job better. The encoder's own help notes that at 4K and above, or at fast speeds, it will not go below 8 whatever you ask for.
Encoder default: Disabled in this dialog
Values:
- 0: Disabled. The dialog's default; never sent, so the encoder decides.
- 4: Four by four pixels, the finest AV1 allows.
- 8: Eight by eight.
- 16: Sixteen by sixteen.
- 32: Thirty-two by thirty-two, already coarse for detailed video.
- 64: Sixty-four by sixty-four.
- 128: A hundred and twenty-eight, the whole superblock, which is very coarse.
Related: aomenc.max-partition-size, aomenc.sb-size, aomenc.cpu-used
Status: reviewed

## aomenc.max-partition-size
Label: Max partition size
Summary: The largest block the encoder is allowed to use. A smaller maximum forces it to cut flat areas up, which costs bits and time.
When to change: Leave it on Disabled, the dialog's default, which sends nothing and lets the encoder choose. It has to be at least as large as Min partition size, and it cannot exceed the superblock size.
Encoder default: Disabled in this dialog
Values:
- 0: Disabled. The dialog's default; never sent, so the encoder decides.
- 4: Four by four pixels. Forces the finest possible split everywhere, which is very slow and very large.
- 8: Eight by eight.
- 16: Sixteen by sixteen.
- 32: Thirty-two by thirty-two.
- 64: Sixty-four by sixty-four, the older superblock size.
- 128: A hundred and twenty-eight, AV1's largest block.
Related: aomenc.min-partition-size, aomenc.sb-size, aomenc.cpu-used
Status: reviewed

## aomenc.enable-dual-filter
Label: Dual filter
Summary: Lets the encoder pick a different smoothing filter for the horizontal and the vertical direction when it fetches a reference block, which fits motion more closely.
When to change: Leave it ticked, the encoder's own default, which sends nothing. Unticking sends `--enable-dual-filter=0` and buys a little speed for a little compression. CPU Used is the better speed control; it manages tools like this one for you.
Encoder default: on
Related: aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-chroma-deltaq
Label: Chroma delta quant
Summary: Lets the encoder use a different quantizer for the color channels than for brightness, so color can be kept finer or coarser than the picture.
When to change: Leave it off, the encoder's own default; ticking sends `--enable-chroma-deltaq=1`. Try it when color detail looks smeared while the brightness looks fine, and compare a still frame side by side. It is not a general win, which is why the encoder leaves it off.
Encoder default: off
Related: aomenc.aq-mode, aomenc.deltaq-mode, aomenc.enable-cfl-intra
Status: reviewed

## aomenc.enable-intra-edge-filter
Label: Intra edge filtering
Summary: Smooths the row of already-coded pixels a block predicts from, so a predicted flat area does not inherit the noise of its neighbours.
When to change: Leave it ticked, the encoder's own default, which sends nothing. Unticking sends `--enable-intra-edge-filter=0` and costs compression on gradients and flat surfaces for a small speed gain.
Encoder default: on
Related: aomenc.enable-smooth-intra, aomenc.enable-filter-intra, concept.compression-efficiency
Status: reviewed

## aomenc.enable-order-hint
Label: Order hint
Summary: Writes each frame's place in the display order into the stream, which several AV1 tools need in order to work out how far away a reference frame is.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-order-hint=0` and switches off everything that depends on it, including temporal motion vector prediction, distance-weighted compound and the reference-frame handling behind Auto Alt Ref. That is a large loss for a small speed gain.
Encoder default: on
Related: aomenc.enable-ref-frame-mvs, aomenc.enable-dist-wtd-comp, aomenc.auto-alt-ref, concept.compression-efficiency
Status: reviewed

## aomenc.enable-tx64
Label: 64-pt transform
Summary: Lets the encoder transform a whole 64 by 64 block at once, which suits large flat or gently shaded areas such as skies.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-tx64=0` and forces large areas to be coded in smaller pieces, which costs bits on wide gradients. It is a small speed gain and it matters most on high-resolution material.
Encoder default: on
Related: aomenc.enable-rect-tx, aomenc.max-partition-size, concept.compression-efficiency
Status: reviewed

## aomenc.enable-flip-idtx
Label: Extended transform type
Summary: Adds the flipped and identity transforms to the set the encoder may choose from, which suit blocks whose detail runs mostly one way.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-flip-idtx=0` and removes twelve transform types the encoder's own help lists, among them the flipped variants and the pure horizontal and vertical ones. It is a speed gain that costs most on graphics and text.
Encoder default: on
Related: aomenc.enable-rect-tx, aomenc.reduced-tx-type-set, aomenc.tune-content, concept.compression-efficiency
Status: reviewed

## aomenc.enable-rect-tx
Label: Rectangular transform
Summary: Lets the encoder transform a non-square block in one piece instead of splitting it into squares first.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-rect-tx=0`, which mostly undoes the benefit of Rectangular partitions, since a rectangle then has to be transformed in squares anyway. Small speed gain, real loss.
Encoder default: on
Related: aomenc.enable-rect-partitions, aomenc.enable-tx64, concept.compression-efficiency
Status: reviewed

## aomenc.enable-dist-wtd-comp
Label: Distance-weighted compound
Summary: When a block is predicted from two reference frames, lets the encoder weigh the nearer one more heavily instead of averaging them equally.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-dist-wtd-comp=0` and costs compression on ordinary motion. It does nothing anyway once Order hint is off, since the encoder then cannot tell how far away a reference is.
Encoder default: on
Related: aomenc.enable-order-hint, aomenc.enable-masked-comp, concept.compression-efficiency
Status: reviewed

## aomenc.enable-masked-comp
Label: Masked (wedge/diff-wtd) compound
Summary: Lets the encoder blend two reference blocks along a shaped boundary rather than over the whole block, which follows a moving object's edge.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-masked-comp=0` and switches off both the wedge and the difference-weighted forms at once, which costs compression wherever something moves in front of something else.
Encoder default: on
Related: aomenc.enable-interinter-wedge, aomenc.enable-diff-wtd-comp, concept.compression-efficiency
Status: reviewed

## aomenc.enable-onesided-comp
Label: One sided compound
Summary: Lets the encoder predict a block from two reference frames that lie on the same side of it in time, rather than one before and one after.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-onesided-comp=0` and costs compression at the ends of a group of pictures, where there is no later frame to pair with.
Encoder default: on
Related: aomenc.enable-dist-wtd-comp, aomenc.gf-max-pyr-height, concept.gop
Status: reviewed

## aomenc.enable-interintra-comp
Label: Interintra compound
Summary: Lets the encoder blend a prediction from another frame with one built from this frame's own neighbours, which helps where something new comes into view.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-interintra-comp=0` and costs compression at the edges of moving objects and where a shot uncovers new background.
Encoder default: on
Related: aomenc.enable-smooth-interintra, aomenc.enable-interintra-wedge, concept.compression-efficiency
Status: reviewed

## aomenc.enable-smooth-interintra
Label: Smooth interintra mode
Summary: Adds the smooth blend to the interintra tool, so the mix between the two predictions fades gradually across the block instead of switching abruptly.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-smooth-interintra=0`. It does nothing at all once Interintra compound is off.
Encoder default: on
Related: aomenc.enable-interintra-comp, aomenc.enable-interintra-wedge
Status: reviewed

## aomenc.enable-diff-wtd-comp
Label: Difference-weighted compound
Summary: When blending two reference blocks, lets the encoder weigh each pixel by how much the two disagree, so the more reliable one wins where they differ.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-diff-wtd-comp=0` and costs compression on moving edges. It is one half of what Masked compound switches off together.
Encoder default: on
Related: aomenc.enable-masked-comp, aomenc.enable-interinter-wedge
Status: reviewed

## aomenc.enable-interinter-wedge
Label: Interinter wedge compound
Summary: Lets the encoder split a block along a slanted line and take each side from a different reference frame, which follows a moving edge closely.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-interinter-wedge=0` and costs compression where an object moves across a different background. It does nothing once Masked compound is off.
Encoder default: on
Related: aomenc.enable-masked-comp, aomenc.enable-interintra-wedge
Status: reviewed

## aomenc.enable-interintra-wedge
Label: Interintra wedge compound
Summary: The wedge split again, but between a prediction from another frame and one built from this frame's own neighbours.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-interintra-wedge=0`. It does nothing once Interintra compound is off.
Encoder default: on
Related: aomenc.enable-interintra-comp, aomenc.enable-interinter-wedge
Status: reviewed

## aomenc.enable-global-motion
Label: Global motion
Summary: Lets the encoder describe a pan, zoom or rotation once for the whole frame, so every block does not have to carry its own copy of that motion.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-global-motion=0`, which is a speed gain and costs most on camera moves: a slow pan is exactly what this tool is for.
Encoder default: on
Related: aomenc.enable-warped-motion, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-warped-motion
Label: Local warped motion
Summary: Lets a block's motion be a small warp rather than a straight shift, which follows rotation and perspective inside the frame.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-warped-motion=0`, a speed gain that costs most on handheld footage and on anything turning toward or away from the camera.
Encoder default: on
Related: aomenc.enable-global-motion, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-filter-intra
Label: Filter intra prediction mode
Summary: Adds a predictor that builds a block from its neighbours through a small recursive filter, which suits soft texture better than a straight-line guess.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-filter-intra=0`, a small speed gain that costs most on keyframes, where nearly everything is predicted from within the frame.
Encoder default: on
Related: aomenc.enable-smooth-intra, aomenc.enable-intra-edge-filter, concept.keyframe
Status: reviewed

## aomenc.enable-smooth-intra
Label: Smooth intra prediction modes
Summary: Adds the predictors that fill a block with a smooth ramp between its edges, which suit skies, walls and other gentle gradients.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-smooth-intra=0` and costs bits on exactly the flat areas where banding is easiest to see.
Encoder default: on
Related: aomenc.enable-filter-intra, aomenc.enable-paeth-intra, aomenc.enable-intra-edge-filter
Status: reviewed

## aomenc.enable-paeth-intra
Label: Paeth intra prediction mode
Summary: Adds the Paeth predictor, which picks for each pixel whichever neighbour above, to the left, or diagonally above-left is closest to the expected value.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-paeth-intra=0`, a small speed gain that costs a little on keyframes and on graphics.
Encoder default: on
Related: aomenc.enable-smooth-intra, aomenc.enable-angle-delta, concept.keyframe
Status: reviewed

## aomenc.enable-cfl-intra
Label: Chroma from luma intra prediction mode
Summary: Lets the encoder predict a block's color from the brightness it has just coded for the same block, which is cheap and accurate where the two move together.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-cfl-intra=0` and costs bits in the color channels, most visibly on saturated edges and graphics.
Encoder default: on
Related: aomenc.enable-chroma-deltaq, aomenc.enable-smooth-intra
Status: reviewed

## aomenc.force-video-mode
Label: Force video mode
Summary: Makes the encoder write a video stream even when it is given a single frame, instead of the still-picture form.
When to change: Nothing to do here, and the box cannot do what it says. It starts ticked, and because ticked is also its own starting value StaxRip sends nothing, so the encoder's default of off applies; unticking sends `--force-video-mode=0`, which is off as well (tested). To really force it, put `--force-video-mode=1` in the Custom box.
Encoder default: off, whatever this box shows
Related: aomenc.full-still-picture-hdr, aomenc.limit, staxrip.custom
Status: reviewed

## aomenc.enable-obmc
Label: OBMC
Summary: Blends a block's prediction with those of its neighbours along the shared edges, so the seams between blocks in a moving picture are less visible.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-obmc=0`, a noticeable speed gain that costs compression and can leave faint block edges in motion.
Encoder default: on
Related: aomenc.enable-warped-motion, aomenc.cpu-used, concept.deblocking
Status: reviewed

## aomenc.enable-overlay
Label: Coding overlay frames
Summary: Lets the encoder add a cheap correction frame on top of a hidden alt-ref frame, so the alt-ref can be shown as a real frame without visible error.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-overlay=0`, which costs compression wherever alt-ref frames are used and does nothing at all once Auto Alt Ref is 0.
Encoder default: on
Related: aomenc.auto-alt-ref, aomenc.enable-keyframe-filtering, aomenc.arnr-maxframes
Status: reviewed

## aomenc.enable-palette
Label: Palette prediction mode
Summary: Lets the encoder store a block as a short list of colors plus an index per pixel, which is how screen recordings and graphics compress well.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-palette=0` and costs a great deal on screen content, and almost nothing on camera footage. If you are encoding a screen recording, leave this alone and set Tune Content to Screen instead.
Encoder default: on
Related: aomenc.tune-content, aomenc.enable-intrabc, concept.compression-efficiency
Status: reviewed

## aomenc.enable-intrabc
Label: Intra block copy prediction mode
Summary: Lets a block be copied from somewhere else in the same frame, which is how repeated text, icons and window borders cost almost nothing.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-intrabc=0`. Like Palette prediction it earns its keep on screen content and does little on camera footage, so the honest answer for both is to leave them alone.
Encoder default: on
Related: aomenc.enable-palette, aomenc.tune-content, concept.compression-efficiency
Status: reviewed

## aomenc.enable-angle-delta
Label: Intra angle delta
Summary: Lets a directional intra prediction be nudged a few degrees off the nearest of AV1's fixed angles, so a slanted edge is followed more exactly.
When to change: Leave it ticked, the encoder's own default. Unticking sends `--enable-angle-delta=0`, a speed gain that costs most on keyframes and on pictures full of diagonal lines.
Encoder default: on
Related: aomenc.enable-paeth-intra, aomenc.enable-filter-intra, concept.keyframe
Status: reviewed

## aomenc.disable-trellis-quant
Label: Disable Trellis Quant
Summary: Turns off the search that tunes each transform coefficient for the best trade between bits and error. Turning it off is faster and larger.
When to change: Leave it at 3, the dialog's default and the encoder's own, which sends nothing: the search runs where it pays and is skipped in the rough estimate step. Set 0 to run it everywhere, which is slower for very little; 1 turns it off entirely, which is a real loss in efficiency.
Encoder default: 3
Values:
- 0: The search always runs. Slowest, and the gain over 3 is small.
- 1: The search never runs. Fastest and least efficient.
- 2: Off during the rate-distortion search, on for the final choice.
- 3: Off during the estimated rate-distortion search. The default, so it is never sent.
Related: aomenc.quant-b-adapt, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-qm
Label: Enable QM
Summary: Turns on quantization matrices, which quantize different frequencies by different amounts so that detail the eye notices least is thrown away first.
When to change: Leave it off, the encoder's own default; ticking sends `--enable-qm=1`. It is worth a try at low bitrates, where the matrices can keep a picture looking cleaner at the same size, and it does nothing useful at high ones. Min QM Flatness and Max QM Flatness only mean anything while it is on.
Encoder default: off
Related: aomenc.qm-min, aomenc.qm-max, aomenc.cq-level, concept.compression-efficiency
Status: reviewed

## aomenc.qm-min
Label: Min QM Flatness
Summary: The flattest quantization matrix the encoder may use, from 0 to 15. A flatter matrix treats all frequencies more alike; a steeper one throws fine detail away first.
Used when: Only with Enable QM ticked. Without it no matrix is used at all.
When to change: Leave it at 8, the value the box starts on, which StaxRip does not send; the encoder's own default is 5, so 5 is what you actually get until you move the box. Lower numbers mean steeper matrices and a softer, cleaner picture at low bitrates. It must not exceed Max QM Flatness.
Encoder default: 5, but the box shows 8 and sends nothing
Related: aomenc.enable-qm, aomenc.qm-max
Status: reviewed

## aomenc.qm-max
Label: Max QM Flatness
Summary: The flattest matrix the encoder may reach at high quality, from 0 to 15. At the flat end the matrices stop making a difference.
Used when: Only with Enable QM ticked.
When to change: Leave it at 15, the value the box starts on, which StaxRip does not send; the encoder's own default is 9, so 9 is what you actually get until you move the box. It must be at least Min QM Flatness.
Encoder default: 9; the box shows 15 and sends nothing
Related: aomenc.enable-qm, aomenc.qm-min
Status: reviewed

## aomenc.reduced-tx-type-set
Label: Reduced set of transform types
Summary: Cuts the list of transforms the encoder may try, which is faster and slightly larger.
When to change: Leave it off; ticking it stops the encode. StaxRip sends the bare switch `--reduced-tx-type-set`, and the bundled build answers "option reduced-tx-type-set requires argument" before it reads a frame (tested). Put `--reduced-tx-type-set=1` in the Custom box instead; that spelling is accepted (tested).
Encoder default: off
Related: aomenc.enable-flip-idtx, aomenc.use-intra-dct-only, staxrip.custom
Status: reviewed

## aomenc.use-intra-dct-only
Label: DCT only for INTRA modes
Summary: Restricts blocks predicted from within the frame to the plain DCT, dropping the other transforms. Faster, and larger on detailed keyframes.
When to change: Leave it off; ticking it stops the encode. StaxRip sends the bare switch, and the bundled build answers "option use-intra-dct-only requires argument" (tested). Put `--use-intra-dct-only=1` in the Custom box instead; that spelling is accepted (tested).
Encoder default: off
Related: aomenc.use-inter-dct-only, aomenc.use-intra-default-tx-only, staxrip.custom
Status: reviewed

## aomenc.use-inter-dct-only
Label: DCT only for INTER modes
Summary: Restricts blocks predicted from other frames to the plain DCT. Faster, and larger wherever there is motion.
When to change: Leave it off; ticking it stops the encode with "option use-inter-dct-only requires argument", because StaxRip sends the bare switch without a value (tested). Put `--use-inter-dct-only=1` in the Custom box if you really want it.
Encoder default: off
Related: aomenc.use-intra-dct-only, aomenc.reduced-tx-type-set, staxrip.custom
Status: reviewed

## aomenc.use-intra-default-tx-only
Label: Default-transform only for INTRA modes
Summary: Restricts blocks predicted from within the frame to each mode's default transform, skipping the search entirely.
When to change: Leave it off; ticking it stops the encode with "option use-intra-default-tx-only requires argument", because StaxRip sends the bare switch without a value (tested). Put `--use-intra-default-tx-only=1` in the Custom box if you really want it.
Encoder default: off
Related: aomenc.use-intra-dct-only, aomenc.reduced-tx-type-set, staxrip.custom
Status: reviewed

## aomenc.quant-b-adapt
Label: Adaptive quantize_b
Summary: Switches the encoder to a quantizer that adapts its rounding to the block, which can keep a little more detail at the same bitrate.
When to change: Leave it Off, the dialog's default, which sends nothing. Turning it on is a small change either way; measure it on your own material rather than assuming it helps.
Encoder default: Off
Values:
- 0: Off. The dialog's default; never sent.
- 1: On, using the adaptive quantizer.
Related: aomenc.disable-trellis-quant, aomenc.cq-level
Status: reviewed

## aomenc.coeff-cost-upd-freq
Label: Update freq for coeff costs
Summary: How often the encoder refreshes its estimate of what a coefficient costs in bits. Less often is faster and slightly less accurate.
When to change: Leave it on Undefined, the dialog's default, which sends nothing so the encoder decides for itself. The other entries buy speed at the cost of the rate-distortion decisions being made from stale numbers; CPU Used is the better speed control. Undefined itself is not a value the encoder accepts, and it works only because it is never sent (tested).
Encoder default: Undefined in this dialog
Values:
- undefined: Never sent, being the dialog's default. The bundled build refuses the word itself (tested).
- 0: Refresh at every superblock. The most accurate and the slowest.
- 1: Refresh once per superblock row in each tile.
- 2: Refresh once per tile.
- 3: Never refresh during the frame. The fastest and the least accurate.
Related: aomenc.mode-cost-upd-freq, aomenc.mv-cost-upd-freq, aomenc.cpu-used
Status: reviewed

## aomenc.mode-cost-upd-freq
Label: Update freq for mode costs
Summary: How often the encoder refreshes its estimate of what choosing a coding mode costs in bits. Less often is faster and slightly less accurate.
When to change: Leave it on Undefined, the dialog's default, which sends nothing and lets the encoder decide. Use CPU Used for speed instead; it sets these three refresh rates for you.
Encoder default: Undefined in this dialog
Values:
- undefined: Never sent, being the dialog's default. The bundled build refuses the word itself (tested).
- 0: Refresh at every superblock.
- 1: Refresh once per superblock row in each tile.
- 2: Refresh once per tile.
- 3: Never refresh during the frame.
Related: aomenc.coeff-cost-upd-freq, aomenc.mv-cost-upd-freq, aomenc.cpu-used
Status: reviewed

## aomenc.mv-cost-upd-freq
Label: Update freq for mv costs
Summary: How often the encoder refreshes its estimate of what a motion vector costs in bits. Less often is faster and slightly less accurate.
When to change: Leave it on Undefined, the dialog's default, which sends nothing and lets the encoder decide. Of the three refresh controls this one matters most on fast motion, where the vectors change quickly.
Encoder default: Undefined in this dialog
Values:
- undefined: Never sent, being the dialog's default. The bundled build refuses the word itself (tested).
- 0: Refresh at every superblock.
- 1: Refresh once per superblock row in each tile.
- 2: Refresh once per tile.
- 3: Never refresh during the frame.
Related: aomenc.coeff-cost-upd-freq, aomenc.mode-cost-upd-freq, aomenc.cpu-used
Status: reviewed

## aomenc.frame-parallel
Label: Frame Parallel
Summary: Codes frames so a decoder can work on several at once, by giving up the entropy-coder state that normally carries from one frame to the next.
When to change: Leave it off, the encoder's own default. It is for decoders that need to spread frames across cores, and it costs compression for everybody else. It does not make your encode faster; that is Threads, Tile Columns and Multi-Threading.
Encoder default: off
Related: aomenc.error-resilient, aomenc.cdf-update-mode, aomenc.threads, concept.parallelism
Status: reviewed

## aomenc.error-resilient
Label: Error Resilient
Summary: Codes each frame to lean less on the ones before it, so a decoder can carry on after damage. It costs compression across the whole file.
When to change: Leave it off, the encoder's own default. It is for streams sent over a lossy link; a file on disk is never damaged that way. It is the same idea as Global Error Resilient, set per frame rather than for the sequence.
Encoder default: off
Related: aomenc.global-error-resilient, aomenc.frame-parallel, concept.compression-efficiency
Status: reviewed

## aomenc.aq-mode
Label: AQ Mode
Summary: Lets the encoder vary the quantizer from block to block within a frame, spending more bits where the eye is most likely to notice.
When to change: Leave it on Disabled, the dialog's default and the encoder's own, which sends nothing; on most material Delta QIndex Mode is already doing this job better. Try Variance when flat areas such as skies band while detailed areas look fine. Cyclic Refresh is a streaming tool: it refreshes part of each frame in turn.
Encoder default: Disabled
Values:
- 0: Disabled. The dialog's default and the encoder's own; never sent.
- 1: Variance. More bits to flat areas, fewer to busy ones.
- 2: Complexity, judged from the content rather than from variance alone.
- 3: Cyclic refresh, which keeps a low-bitrate stream from decaying. For CBR streaming.
Related: aomenc.deltaq-mode, aomenc.enable-chroma-deltaq, aomenc.end-usage, concept.quality-level
Status: reviewed

## aomenc.deltaq-mode
Label: Delta QIndex Mode (req. enable-tpl-model)
Summary: Lets the encoder shift the quantizer per superblock according to a chosen rule, so bits go where that rule says they matter.
When to change: Leave it at 1, the dialog's default and the encoder's own, which sends nothing; it needs TPL model on, which StaxRip also sends on every encode. Try 3 or 4 only if you are chasing how a picture looks rather than how it measures. The bundled build also accepts 5, for HDR video, and 6, Variance Boost, which are not in this dialog; put `--deltaq-mode=5` or `=6` in the Custom box (tested).
Encoder default: 1
Values:
- 0: Off. One quantizer for the whole frame, before AQ Mode.
- 1: The encoder's own objective rule. The default, so it is never sent. Needs TPL model at 1.
- 2: A placeholder in the encoder; the help gives it no behaviour of its own.
- 3: Aimed at how a keyframe looks rather than how it scores.
- 4: Aimed at perceived quality, tuned by Delta QIndex Strengh %.
Related: aomenc.enable-tpl-model, aomenc.deltaq-strength, aomenc.aq-mode, staxrip.custom, concept.quality-level
Status: reviewed

## aomenc.deltaq-strength
Label: Delta QIndex Strengh %
Summary: How hard Delta QIndex Mode 4 pushes its quantizer changes, as a percentage. Higher means a larger swing between the parts of a frame.
Used when: Only with Delta QIndex Mode at 4. The box is hidden in every other mode, and no `--deltaq-strength` is sent.
When to change: Leave it at 100, the value the box starts on, which sends nothing. Raise it toward 150 for a stronger effect and lower it toward 50 for a gentler one, then judge a still frame by eye. The dialog takes 0 to 1000 in steps of 5. The encoder's help says it also applies to mode 6, which this dialog cannot select.
Encoder default: 100 in this dialog
Related: aomenc.deltaq-mode, aomenc.aq-mode, staxrip.custom
Status: reviewed

## aomenc.delta-lf-mode
Label: Delta-lf-Mode
Summary: Lets the strength of the deblocking filter vary from superblock to superblock, alongside the quantizer, instead of being fixed for the frame.
When to change: Leave it off, the encoder's own default. It only means anything when Delta QIndex Mode is already varying the quantizer, and even then it is a small change. Turn it on and compare a still frame if you are chasing the last of the block edges.
Encoder default: off
Related: aomenc.deltaq-mode, aomenc.enable-cdef, concept.deblocking
Status: reviewed

## aomenc.frame-boost
Label: Enable frame periodic boost
Summary: Gives extra bits to a frame every so often, so that the frames predicting from it start from something cleaner.
When to change: Leave it off, the encoder's own default; the golden-frame machinery already hands out extra bits where they pay. Try it only on long, slow, low-bitrate material, and compare the whole encode rather than one frame, since what it costs is taken from everything else.
Encoder default: off
Related: aomenc.min-gf-interval, aomenc.max-gf-interval, aomenc.gf-cbr-boost, concept.rate-control
Status: reviewed

## aomenc.noise-sensitivity
Label: Noise Sensitivity
Summary: Blurs this many frames together before coding, to take the noise out of a grainy source so it does not have to be spent bits on.
When to change: Leave it at 0, the box's starting value, which sends nothing. It is a blunt temporal blur and it smears motion; Denoise Level with grain synthesis is the modern way to handle a noisy source, because that puts the grain back on playback. Denoise in the script if you want real control.
Encoder default: 0 in this dialog
Related: aomenc.denoise-noise-level, aomenc.arnr-strength, concept.film-grain
Status: reviewed

## aomenc.tune-content
Label: Tune Content
Summary: Tells the encoder what kind of picture it is looking at, so it can favour the tools that suit it.
When to change: Leave it on Default, the dialog's default, which sends nothing and lets the encoder work it out. Pick Screen for a screen recording, a slide deck or a game capture with hard-edged text, which turns the palette and block-copy tools toward that kind of picture. Film keeps the grain structure of a film scan rather than smoothing it away.
Encoder default: Default
Example: On a random-noise test clip, Screen produced 15444 bytes and Film 14800 against 14721 with nothing set, so it does change the encode. Judge it on your own material.
Values:
- default: The dialog's default; never sent. The encoder decides for itself.
- screen: For screen recordings, text and graphics. Accepted by the bundled build (tested).
- film: For film scans, keeping grain rather than smoothing it. Accepted by the bundled build (tested).
Related: aomenc.enable-palette, aomenc.enable-intrabc, aomenc.denoise-noise-level, concept.film-grain
Status: reviewed

## aomenc.cdf-update-mode
Label: CDF Update
Summary: How often the encoder updates the probability tables its entropy coder uses. Updating more often compresses better; updating less is faster to decode.
When to change: Leave it at 1, the dialog's default and the encoder's own, which sends nothing. 0 turns updates off, which costs compression and is only useful when a decoder must be able to start anywhere. 2 updates on some frames only, a middle ground with little to recommend it for a file on disk.
Encoder default: 1
Values:
- 0: No update. Every frame starts from the same tables, which costs bits.
- 1: Update on all frames. The default, so it is never sent.
- 2: Update on selected frames only.
Related: aomenc.frame-parallel, aomenc.error-resilient, concept.compression-efficiency
Status: reviewed

## aomenc.color-primaries
Label: Color Primaries
Summary: Tags the video with its color primaries, the exact red, green and blue a player should assume. It is a label on the stream and changes no pixel.
When to change: Leave it on unspecified unless you know the source's primaries; a wrong tag shifts the color on playback. One entry is broken: SMPTE170 stops the encode with "Invalid value", because the bundled build calls those primaries `bt601`, which is the third entry in the same list (tested). Every other entry is accepted (tested).
Values:
- unspecified: Never sent, being the dialog's default; the stream then leaves the field unspecified.
- bt2020: The UHD and HDR primaries. Accepted (tested).
- bt601: Standard-definition primaries; this is also the build's name for SMPTE170. Accepted (tested).
- bt709: HD and most modern video. Accepted (tested).
- bt470m: The old NTSC primaries. Accepted (tested).
- bt470bg: The PAL and SECAM primaries. Accepted (tested).
- smpte170: Refused by the bundled build; pick BT601, which is the same primaries under the name it knows (tested).
- xyz: The CIE XYZ primaries, used in digital cinema. Accepted (tested).
- smpte240: The old SMPTE 240M primaries. Accepted (tested).
- smpte431: DCI-P3. Accepted (tested).
- smpte432: Display P3. Accepted (tested).
- film: Generic film primaries. Accepted (tested).
- ebu3213: The EBU 3213-E primaries. Accepted (tested).
Related: aomenc.transfer-characteristics, aomenc.matrix-coefficients, aomenc.chroma-sample-position, concept.color-description
Status: reviewed

## aomenc.transfer-characteristics
Label: Transfer Characteristics
Summary: Tags the video with its transfer curve, the rule linking stored numbers to light. It tells a player whether the file is SDR, HDR10 or HLG, and changes no pixel.
When to change: Leave it on unspecified unless you know the source's curve; a wrong tag makes an HDR file look washed out or an SDR one look flat. For HDR10 choose SMPTE2084, and for broadcast HDR choose HLG; both are accepted by the bundled build, as is every other entry in the list (tested).
Values:
- unspecified: Never sent, being the dialog's default; the stream then leaves the field unspecified.
- bt709: The HD curve, and the usual choice for SDR video. Accepted (tested).
- bt470m: The old NTSC curve. Accepted (tested).
- bt470bg: The PAL and SECAM curve. Accepted (tested).
- bt601: The standard-definition curve. Accepted (tested).
- smpte240: The old SMPTE 240M curve. Accepted (tested).
- lin: A linear curve, for light-linear material. Accepted (tested).
- log100: A logarithmic curve over a hundred to one range. Accepted (tested).
- log100sq10: The same, over a wider range. Accepted (tested).
- iec61966: The extended-range sYCC curve. Accepted (tested).
- bt1361: The extended-gamut BT.1361 curve. Accepted (tested).
- srgb: The sRGB curve, for computer graphics. Accepted (tested).
- bt2020-10bit: The BT.2020 curve at 10 bits. Accepted (tested).
- bt2020-12bit: The BT.2020 curve at 12 bits. Accepted (tested).
- smpte2084: The HDR10 perceptual quantizer curve. Accepted (tested).
- hlg: The hybrid log-gamma curve used for broadcast HDR. Accepted (tested).
- smpte428: The digital cinema curve. Accepted (tested).
Related: aomenc.color-primaries, aomenc.matrix-coefficients, aomenc.bit-depth, concept.color-description, concept.hdr-metadata
Status: reviewed

## aomenc.matrix-coefficients
Label: Matrix Coefficients
Summary: Tags the video with the matrix that turned its colors into the brightness and color-difference channels it is stored in. It is a label and changes no pixel.
When to change: Leave it on unspecified unless you know what the source uses; a wrong tag shifts the color on playback. Match it to the primaries: BT709 for HD, BT601 for standard definition, BT2020NCL for UHD. Every entry in the list is accepted by the bundled build (tested).
Values:
- unspecified: Never sent, being the dialog's default; the stream then leaves the field unspecified.
- identity: The channels are stored as they are, with no color transform. For RGB material. Accepted (tested).
- bt470bg: PAL and SECAM, the same matrix as standard-definition BT601. Accepted (tested).
- bt601: Standard-definition video. Accepted (tested).
- bt709: HD video, the usual choice. Accepted (tested).
- bt2020ncl: UHD, non-constant luminance. The usual UHD choice. Accepted (tested).
- bt2020cl: UHD, constant luminance. Rare. Accepted (tested).
- chromncl: Derived from the primaries, non-constant luminance. Accepted (tested).
- chromcl: Derived from the primaries, constant luminance. Accepted (tested).
- fcc73: The old FCC matrix. Accepted (tested).
- ictcp: The ICtCp representation used with HDR. Accepted (tested).
- smpte2085: The Y'D'zD'x representation. Accepted (tested).
- smpte240: The old SMPTE 240M matrix. Accepted (tested).
- ycgco: The YCgCo matrix, reversible and used for screen content. Accepted (tested).
Related: aomenc.color-primaries, aomenc.transfer-characteristics, concept.color-description
Status: reviewed

## aomenc.chroma-sample-position
Label: Chroma Sample Position
Summary: Tags where the color samples sit relative to the brightness samples in 4:2:0 video. It is a label and moves no pixel.
Used when: Only for 4:2:0 video, and in practice not at all through StaxRip's pipe: see below.
When to change: Leave it on Unknown. Vertical stops the encode outright unless the Y4M stream the pipe writes is tagged `C420mpeg2`: the encoder answers "Vertical chroma sample position only supported for 420mpeg2 input" and quits (tested). Colocated is read and then thrown away, with the message "Ignoring colocated chroma sample position for reading in Y4M" (tested). Neither is worth the risk.
Values:
- unknown: Never sent, being the dialog's default; the stream leaves the field unset.
- vertical: Stops the encode unless the Y4M header says `C420mpeg2` (tested).
- colocated: Accepted and then ignored for Y4M input, whatever the header says (tested).
Related: aomenc.color-primaries, staxrip.pipe, concept.color-description
Status: reviewed

## aomenc.min-gf-interval
Label: Min GF Interval
Summary: The shortest gap the encoder may leave between golden frames, the long-lived references later frames keep borrowing from.
When to change: Leave it at 0, which the encoder's own help calls its in-built behaviour: it works the interval out for itself. Set a number only when you are chasing an unusual group structure; too short a gap spends bits on references nothing needs.
Encoder default: 0, meaning the encoder decides
Related: aomenc.max-gf-interval, aomenc.gf-max-pyr-height, aomenc.auto-alt-ref, concept.gop
Status: reviewed

## aomenc.max-gf-interval
Label: Max GF Interval
Summary: The longest gap the encoder may leave between golden frames. A longer gap means fewer expensive reference frames and weaker prediction between them.
When to change: Leave it at 0, the encoder's own default, which means it decides for itself. It is bounded by Max keyframe interval anyway, since a keyframe restarts the structure.
Encoder default: 0, meaning the encoder decides
Related: aomenc.min-gf-interval, aomenc.kf-max-dist, aomenc.gf-max-pyr-height, concept.gop
Status: reviewed

## aomenc.gf-min-pyr-height
Label: Min height for GF gr. pyr. struct.
Summary: The shallowest layered structure the encoder may build inside a golden-frame group, from 0 to 5. Deeper means more frames coded out of order and better compression.
When to change: Leave it at 0, the encoder's own default, which sends nothing and lets the encoder shallow out a group when that suits the content. Raising it forces depth even where it does not pay.
Encoder default: 0
Related: aomenc.gf-max-pyr-height, aomenc.max-gf-interval, concept.gop
Status: reviewed

## aomenc.gf-max-pyr-height
Label: Max height for GF gr. pyr. struct.
Summary: The deepest layered structure the encoder may build inside a golden-frame group, from 0 to 5. Deeper compresses better and needs more frames held in memory.
When to change: Leave it at 5, the value the box starts on and the encoder's own default, which sends nothing. Lower it to 2 or 3 only when memory is tight or when something downstream cannot cope with frames coded far out of order.
Encoder default: 5
Related: aomenc.gf-min-pyr-height, aomenc.lag-in-frames, aomenc.enable-onesided-comp, concept.gop
Status: reviewed

## aomenc.sb-size
Label: Superblock size
Summary: The largest block the encoder starts from before splitting, 64 or 128 pixels square. Larger suits high resolutions; smaller suits small pictures and many tiles.
When to change: Leave it on Dynamic, the dialog's default, which sends nothing and lets the encoder pick from the frame size. Force 64 for small video or when you want many tiles out of a modest picture, since a tile cannot be narrower than one superblock. Force 128 only to test.
Encoder default: Dynamic
Values:
- dynamic: Never sent, being the dialog's default; the encoder picks from the resolution.
- 64: Sixty-four pixels square. Accepted by the bundled build (tested).
- 128: A hundred and twenty-eight pixels square, AV1's largest.
Related: aomenc.tile-columns, aomenc.tile-rows, aomenc.max-partition-size, concept.tiles
Status: reviewed

## aomenc.num-tile-groups
Label: Num Tile Groups
Summary: How many separately packaged groups the frame's tiles are split into. It affects how the stream is packetized, not how it looks.
When to change: Leave it at 1, the value the box starts on and the encoder's own default, which sends nothing. More groups only help when the stream is being sent over a network in small packets, and MTU Size overrides this setting anyway when it is set.
Encoder default: 1
Related: aomenc.mtu-size, aomenc.tile-columns, concept.tiles
Status: reviewed

## aomenc.mtu-size
Label: MTU Size
Summary: The largest size in bytes a tile group may reach, so each one fits in a network packet. The encoder then makes as many groups as it needs.
When to change: Leave it at 0, the encoder's own default, which means no packet targeting at all. Set it only when you are feeding a network transport with a known packet size; it overrides Num Tile Groups when it is above 0.
Encoder default: 0
Related: aomenc.num-tile-groups, concept.tiles
Status: reviewed

## aomenc.timing-info
Label: Timing info
Summary: Writes frame timing into the stream itself, so a player can work out when each frame is due without help from the container.
When to change: Leave it on Unspecified, the dialog's default, which sends nothing; StaxRip's container carries the timing. Constant declares a fixed frame rate. The encoder's own help warns that Model only works when there are no hidden frames and no super-resolution, which rules it out for most encodes.
Encoder default: Unspecified
Values:
- unspecified: Never sent, being the dialog's default; the container carries the timing.
- constant: Declares a constant frame rate in the stream. Accepted (tested).
- model: Declares a decoder model. The help says it needs no hidden frames and no super-resolution (tested for acceptance only).
Related: aomenc.fps, aomenc.timebase, aomenc.auto-alt-ref, aomenc.superres-mode
Status: reviewed

## aomenc.max-reference-frames
Label: Max ref frames per frame
Summary: How many already-coded frames a frame may choose from when it predicts, between 3 and 7. Fewer is faster and slightly larger.
When to change: Leave it at 7, the value the box starts on and the encoder's own default, which sends nothing. Drop it to 4 or 5 for a faster encode when you have already run out of room in CPU Used; the loss is small on simple motion and larger on anything with repeated or occluded detail.
Encoder default: 7
Related: aomenc.reduced-reference-set, aomenc.cpu-used, aomenc.gf-max-pyr-height, concept.compression-efficiency
Status: reviewed

## aomenc.reduced-reference-set
Label: Rreduced set of refs
Summary: Cuts down which single and paired reference frames a block may choose from, which is faster and costs some compression.
When to change: Leave it off, the encoder's own default; ticking sends `--reduced-reference-set=1`. It overlaps with Max ref frames per frame, so change one or the other rather than both, and use CPU Used first.
Encoder default: off
Related: aomenc.max-reference-frames, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.enable-ref-frame-mvs
Label: Temporal mv prediction
Summary: Lets a block reuse the motion of the frame before it as a starting guess, which makes motion vectors much cheaper to store.
When to change: Leave it at 1, the value the box starts on and the encoder's own default, which sends nothing. Setting 0 costs compression on anything that moves, for a small speed gain. It does nothing anyway once Order hint is off, since the encoder then cannot line frames up in time.
Encoder default: 1
Related: aomenc.enable-order-hint, aomenc.cpu-used, concept.compression-efficiency
Status: reviewed

## aomenc.target-seq-level-idx
Label: Target sequence level index
Summary: Asks the encoder to keep the stream inside a numbered AV1 level, which caps resolution, frame rate and bitrate so a decoder knows what it is in for.
Used when: Only when you fill it in. Left empty, which is how it starts, the encoder works the level out from the video and writes that.
When to change: Leave it empty and let the encoder choose. Fill it in only when a delivery target names a level. The encoder's own help gives the format as `ABxy`, where `AB` is the operating point and `xy` the level index: `0` is level index 0 for the first operating point, `1019` is level index 19 for the eleventh.
Example: `0` targets the lowest level for the first operating point; the bundled build accepts it (tested).
Related: aomenc.set-tier-mask, aomenc.profile, concept.level
Status: reviewed

## aomenc.set-tier-mask
Label: Tier mask
Summary: Chooses between the two bitrate ceilings a level allows: Main for ordinary video, High for the far higher rates professional delivery uses.
When to change: Leave it on Main tier, the dialog's default and the encoder's own, which sends nothing. High tier only lifts the bitrate the level permits; it does not improve the picture by itself, fewer decoders accept it, and it is worth setting only alongside a target level.
Encoder default: Main tier
Values:
- 0: Main tier. The dialog's default; never sent.
- 1: High tier. Accepted by the bundled build (tested).
Related: aomenc.target-seq-level-idx, aomenc.profile, concept.level
Status: reviewed

## aomenc.min-cr
Label: Minimum compression ratio
Summary: Asks the encoder to keep every frame at least this compressed, given as the ratio times a hundred. It stops a single frame becoming enormous.
When to change: Leave it at 0, the encoder's own default, which means no floor. Set 200 for a two to one floor when a decoder or a transport cannot cope with a very large frame. It costs quality exactly on the frames that needed the bits.
Encoder default: 0
Example: 100 asks for a compression ratio of at least 1 to 1, and 200 for 2 to 1. The bundled build accepts 100 (tested).
Related: aomenc.max-intra-rate, aomenc.buf-sz, concept.rate-control
Status: reviewed

## aomenc.vbr-corpus-complexity-lap
Label: Average corpus complexity for 1pass VBR
Summary: Tells a single-pass VBR encode how complex your whole library is on average, so it can decide whether this video deserves more or fewer bits than usual.
Used when: Only in single-pass VBR with the encoder's look-ahead rate control. It has nothing to compare against in the other modes.
When to change: Leave it at 0, the encoder's own default, which switches the comparison off. It is for someone encoding a large library to a consistent quality and measuring the average themselves; for one video it has nothing to say. The dialog takes 0 to 10000.
Encoder default: 0
Related: aomenc.end-usage, aomenc.passes, concept.rate-control
Status: reviewed

## aomenc.input-chroma-subsampling-x
Label: Chroma subsampling x value
Summary: Tells the encoder how much the incoming raw video's color is subsampled horizontally. It describes the input, not the output.
When to change: Leave it at 0. StaxRip always pipes Y4M, whose header already carries the sampling, so the box has nothing to correct. It exists for raw input, where nothing describes the layout.
Encoder default: 0
Related: aomenc.input-chroma-subsampling-y, aomenc.i420, staxrip.pipe
Status: reviewed

## aomenc.input-chroma-subsampling-y
Label: Chroma subsampling y value
Summary: Tells the encoder how much the incoming raw video's color is subsampled vertically. It describes the input, not the output.
When to change: Leave it at 0, for the same reason as the horizontal box: the Y4M header StaxRip's pipe writes already carries the sampling.
Encoder default: 0
Related: aomenc.input-chroma-subsampling-x, aomenc.i420, staxrip.pipe
Status: reviewed

## aomenc.sframe-dist
Label: S-Frame interval
Summary: Places a switch frame every this many frames. A switch frame lets a player change to a different stream of the same video without a full keyframe.
When to change: Leave it at 0, off, which is the encoder's own default. Switch frames are for adaptive streaming, where a player moves between quality levels; in a file on disk they only cost bits. The bundled build accepts 4 (tested).
Encoder default: 0
Related: aomenc.sframe-mode, aomenc.kf-max-dist, concept.keyframe
Status: reviewed

## aomenc.sframe-mode
Label: S-Frame insertion mode
Summary: How the encoder places the switch frames S-Frame interval asks for: strictly on the interval, or at the next suitable frame.
Used when: Only with S-Frame interval above 0. With no switch frames there is nothing to place.
When to change: Leave it at 1, the value the box starts on, which sends nothing. Mode 2 lets the encoder wait for a frame where a switch costs less, which is gentler on the bitrate and less exact about the interval. The dialog takes 1 or 2.
Encoder default: 1 in this dialog
Related: aomenc.sframe-dist, concept.keyframe
Status: reviewed

## aomenc.annexb
Label: Save as Annex-B
Summary: Writes the stream in the length-prefixed Annex-B form rather than plain low-overhead units, which some tools and transports expect.
Used when: Only when you fill it in. Left empty, which is how it starts, no `--annexb` reaches the encoder.
When to change: Leave it empty. It matters only when something downstream asks for Annex-B framing, and StaxRip's own muxers do not. Type `1` to switch it on; the bundled build accepts that (tested). It is a text box rather than a checkbox, so an empty box means off.
Related: aomenc.obu, aomenc.ivf
Status: reviewed

## aomenc.film-grain-test
Label: Film grain test vectors
Summary: Puts one of sixteen fixed, synthetic grain patterns into the stream, so a player draws that grain over the picture on playback.
When to change: Leave it on None. These are test patterns for checking that a decoder draws grain at all; they have nothing to do with your source's own grain. To keep a grainy look properly, use Denoise Level, which measures the real grain and describes it, or supply a Film Grain Table.
Encoder default: None (default)
Values:
- 0: None. The dialog's default; never sent.
- 1: The first of sixteen fixed test patterns. Accepted by the bundled build (tested).
Related: aomenc.film-grain-table, aomenc.denoise-noise-level, concept.film-grain
Status: reviewed

## aomenc.film-grain-table
Label: Film Grain Table
Summary: Reads a file describing the grain to draw on playback, so the encoder can compress a clean picture and have the player put the grain back.
Used when: Only when you fill it in. Left empty, which is how it starts, no grain table reaches the encoder.
When to change: Leave it empty unless you already have a grain table, usually one written by a previous denoising run or by a tool such as grav1synth. It is the precise version of what Denoise Level does automatically. Browse to the file with the button beside the box.
Related: aomenc.denoise-noise-level, aomenc.film-grain-test, concept.film-grain
Status: reviewed

## aomenc.denoise-noise-level
Label: Denoise Level
Summary: Removes this much noise before coding and describes it in the stream instead, so the player draws matching grain back on. 0 leaves the grain alone.
When to change: Leave it at 0 for clean sources. On grainy film a value of 5 to 15 can cut the file a great deal at a similar look, because random grain is the most expensive thing an encoder can be asked to keep. The dialog takes 0 to 50; above about 20 the picture starts to look plastic under the synthetic grain. Always compare a still frame before and after.
Encoder default: 0
Example: Encode 30 seconds of a grainy scene at 0 and at 10 with the same CQ Level, then compare the sizes and look closely at faces in both.
Related: aomenc.denoise-block-size, aomenc.enable-dnl-denoising, aomenc.film-grain-table, aomenc.noise-sensitivity, concept.film-grain
Status: reviewed

## aomenc.denoise-block-size
Label: Denoise Block Size
Summary: The block the grain estimator works in when Denoise Level is on. Larger blocks measure the grain more steadily; smaller ones follow it across the picture.
Used when: Only with Denoise Level above 0. Without denoising there is no grain model to build.
When to change: Leave it at 32, the value the box starts on and the encoder's own default, which sends nothing. There is little reason to move it; try 16 only if the grain in the result looks uniform where the source's varies across the frame. The dialog takes 0 to 64.
Encoder default: 32
Related: aomenc.denoise-noise-level, aomenc.enable-dnl-denoising, concept.film-grain
Status: reviewed

## aomenc.enable-dnl-denoising
Label: Apply Denoise Level Denoising
Summary: Chooses whether the frames actually sent to the encoder are the denoised ones, or the original grainy ones with a grain description attached.
Used when: Only with Denoise Level above 0.
When to change: Leave it ticked, the encoder's own default, which sends nothing: the picture is denoised, so it compresses well, and the player paints the grain back. Untick it, which sends `--enable-dnl-denoising=0`, only when you want the grain measured and described but the original frames encoded as they are; the file is then large and the player draws grain on top of grain.
Encoder default: on
Related: aomenc.denoise-noise-level, aomenc.denoise-block-size, concept.film-grain
Status: reviewed
