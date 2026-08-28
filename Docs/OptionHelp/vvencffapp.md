# vvencFFapp option help

Schema: 1
Encoder: vvencffapp
Locale: en
Title: vvencFFapp
Source: Source/Encoding/VvencffappEnc.vb
Allowed-Missing: 0
Minimum-Reviewed: 27
Reviewed-Complete: true
Verified-Encoder-Version: vvencFFapp version 1.15.0-dev
Verified-Encoder-Build: 1.15.0-dev [Windows][GCC 16.1.0][64 bit][SIMD=AVX2]
Verified-Date: 2026-08-28
Documentation: https://github.com/fraunhoferhhi/vvenc/wiki/Usage

## vvencffapp.mode
Label: Mode
Summary: Chooses what the encode aims at: the quality level you set under Quantizer, or a bitrate. It also decides which box appears beside it and how many times the encoder runs.
When to change: Leave it on Quantizer for video you keep; the Quantizer box sets the quality and the size falls where it may. Switch to Bitrate when the file has to hit a size. Two Pass aims at the same bitrate but splits the work into two runs of the encoder, which lets StaxRip feed the second run the bitrate the main window works out. Two Pass also adds the Custom First Pass and Second Pass boxes.
Values:
- bitrate: One run with `--TargetBitrate`. It reported `Passes:2 Pass:-1`: its own two-pass rate control, in one process (tested).
- quantizer: Holds the Quantizer setting and sends no bitrate at all. The dialog's default.
- twopass: Two runs, `--NumPasses 2 --Pass 1` then `--Pass 2`, sharing a `--RCStatsFile`. The first writes its bitstream to NUL.
Related: vvencffapp.qp, vvencffapp.target-bitrate, vvencffapp.lookahead, staxrip.custom, concept.rate-control, concept.two-pass
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.qp
Label: Quantizer
Summary: Sets how coarsely the encoder rounds picture detail away, from 0 (finest, largest file) to 63 (coarsest). It holds that quality for the whole encode.
Used when: Only in Quantizer mode. In Bitrate and Two Pass mode the box is hidden and no `--QP` is sent.
When to change: Lower it for a better picture and a larger file, raise it for a smaller one, then judge a short test encode by eye rather than by the number. StaxRip starts you at 32, which is vvencFFapp's own default, and at 32 it sends nothing at all, so the encode is the same either way. This is VVC's own quantizer scale; a number that suits an AV1 or x265 encoder does not carry over.
Encoder default: 32
Example: Encode the same 60-second scene at 32 and at 27 with everything else unchanged. Compare the sizes, then step through a detailed frame in each and take the higher number if you cannot see the difference.
Related: vvencffapp.mode, vvencffapp.preset, concept.quality-level, concept.rate-control
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.target-bitrate
Label: Target Bitrate
Summary: The bitrate in kbps the encoder aims at across the whole video. Together with the running time it sets the size of the video stream.
Used when: Only in Bitrate and Two Pass mode. In Quantizer mode the box is hidden and no bitrate reaches the encoder.
When to change: Set the size or the bitrate in the main window instead; both boxes feed this one. StaxRip appends `k` to whatever you type, so 5000 here is 5000 kbit per second. The dialog takes 0 to 1000000 in steps of 100. In Two Pass mode the second run uses the bitrate the main window works out rather than this box, so a target size set there wins.
Example: Twenty minutes at 4000 kbps is roughly 600 MB of video before audio (4000 x 1200 / 8 / 1000). Type a size into the main window's target size box and reopen this dialog: this value follows it.
Related: vvencffapp.mode, concept.bitrate, concept.rate-control
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.preset
Label: Preset
Summary: Picks the whole set of coding tools and search effort the encoder uses. It is the one control that trades encoding time against file size at the same quality.
When to change: Leave it at Medium, the encoder's own default, which StaxRip does not send at all. Step to Slow or Slower for a final encode you can wait for, to Fast or Faster for a quick look. The steps are not just more searching: each one switches VVC tools on or off, which is why the file size moves so much. Judge it on a 60-second scene before committing the whole video.
Encoder default: Medium
Example: Encode the same 60-second scene at Medium and at Slow with the same Quantizer, then compare the time and the file size.
Values:
- none: No preset: the bare defaults, with most VVC tools off. Fast and much less efficient. Undocumented but accepted (tested).
- faster: The fastest documented step. 64-sample coding units and a 128-sample search range (tested).
- fast: One step above faster.
- medium: The encoder's own default and the dialog's; never sent. 128-sample coding units and a 384-sample search range (tested).
- slow: One step below medium in speed, more tools and more searching.
- slower: The slowest documented step.
- medium_lowdecenergy: Medium, held back from the tools that make playback expensive, for weak playback hardware.
- firstpass: The stripped-down setting used for the analysis run of two-pass rate control, not for a final encode (tested).
- tooltest: Switches on tools medium leaves off, to exercise the encoder rather than to look good. Not a quality setting (tested).
Related: vvencffapp.qp, vvencffapp.threads, concept.compression-efficiency
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.profile
Label: Profile
Summary: Names the set of VVC coding tools the stream is allowed to use. A player checks it first and refuses the file if it does not support that profile.
When to change: Leave it on Automatic. StaxRip then sends nothing and the encoder chooses for itself, which for ordinary video is Main 10. Main 10 Still Picture is for a file holding a single picture and nothing else. The bundled build rejects the word `automatic`, so that entry works only because it is the dialog's default and is never sent (tested).
Values:
- automatic: Never sent, being the dialog's default; the encoder's own `auto` applies.
- main_10: The ordinary VVC profile, up to 10 bits a sample. Accepted by the bundled build (tested).
- main_10_still_picture: For a single coded picture rather than video. Accepted by the bundled build (tested).
Related: vvencffapp.level, vvencffapp.tier, concept.level
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.level
Label: Level
Summary: Caps the resolution, frame rate and bitrate the stream may use, and labels it so a decoder knows what it is in for. It is a ceiling and a tag, not a quality setting.
When to change: Leave it on Automatic and let the encoder work the level out from the video. Set one by hand only when a delivery target names it. A level below what the video needs does not make the file smaller; the encoder refuses it or the label ends up wrong. The bundled build rejects the word `automatic` itself, so that entry works only by never being sent (tested).
Values:
- automatic: Never sent, being the dialog's default; the encoder's own `auto` applies.
- 1.0: The lowest level, for very small pictures. Accepted by the bundled build (tested).
- 6.3: The highest numbered level, for 8K work. Accepted by the bundled build (tested).
- 15.5: VVC's "no limit" level. Pick it when a level must be signalled but nothing should be capped.
Related: vvencffapp.profile, vvencffapp.tier, concept.level
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.tier
Label: Tier
Summary: Picks between the two bitrate ceilings a VVC level allows: Main for ordinary video, High for the far higher rates professional delivery uses.
When to change: Leave it on Main. High only lifts the bitrate the level permits; it does not improve the picture by itself, and fewer decoders accept it. It is worth setting only alongside a Level, since on its own there is no ceiling to lift. StaxRip sends `--Tier high` for the High entry; Main is the dialog's default and is never sent, which is the encoder's default anyway.
Values:
- main: Never sent, being the dialog's default; the encoder's own default is main too.
- high: Sends `--Tier high`. Accepted by the bundled build; the build wants the name in lower case (tested).
Related: vvencffapp.level, vvencffapp.profile, concept.level
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.verbosity
Label: Verbosity
Summary: Sets how much the encoder prints while it runs. It changes nothing in the picture, only what you see in StaxRip's log and status line.
When to change: Leave it at Verbose, the dialog's default and the encoder's own, which StaxRip does not send. Below Notice the encoder stops printing its line per frame, and StaxRip's status line, which reads exactly those lines, stops moving (tested). Silent prints nothing at all, not even the reason a failed encode failed (tested). Debug is for reporting a problem.
Encoder default: 5 (Verbose)
Values:
- 0: Silent. Nothing is printed, and a failed encode leaves no reason behind (tested).
- 1: Errors only. A missing input file printed two lines and nothing else (tested).
- 2: Warnings and errors.
- 3: Info. The configuration summary, but no per-frame lines, so StaxRip's status line stays still (tested).
- 4: Notice. Adds the per-frame lines StaxRip reads for its status line (tested).
- 5: Verbose. The default; adds the encoder's tool configuration.
- 6: Debug. Everything the encoder can say.
Status: reviewed

## vvencffapp.simd
Label: SIMD
Summary: Chooses which set of CPU vector instructions the encoder uses. It changes encoding speed, not the picture.
When to change: Leave it on Automatic, which is never sent, so the encoder picks the best set your CPU has. Every other entry stops the encode in this build: it wants the name in capitals and StaxRip sends it in lower case, so the encoder answers "Invalid SIMD Mode string" before it reads a frame (tested). To pin one anyway, put `--SIMD AVX2` in the Custom box.
Example: `--SIMD SCALAR` in the Custom box turns the vector code off, which is useful only for comparing against a suspected instruction-set bug. The bundled build accepts that spelling (tested).
Values:
- automatic: Never sent, being the dialog's default; the encoder picks the widest set the CPU supports.
- scalar: Refused by the bundled build, which wants `SCALAR`. Use the Custom box (tested).
- sse41: Refused by the bundled build, which wants `SSE41`. Use the Custom box (tested).
- sse42: Refused by the bundled build, which wants `SSE42`. Use the Custom box (tested).
- avx: Refused by the bundled build, which wants `AVX`. Use the Custom box (tested).
- avx2: Refused by the bundled build, which wants `AVX2`. Use the Custom box (tested).
- avx512: Refused by the bundled build, which wants `AVX512`, and refuses that too on a CPU without it (tested).
Related: staxrip.custom
Status: reviewed

## vvencffapp.output-bit-depth
Label: Output Bit-Depth
Summary: Sets the bit depth of the encoder's optional reconstructed YUV file. It does not change the video you get, because StaxRip never asks for that file.
When to change: Nothing to change here; leave it on Automatic. The encoder's `--OutputBitDepth` applies to the decoded YUV dump it can write beside the bitstream, and StaxRip never asks for that file: the same clip encoded with 8, with 10 and with nothing at all gave three byte-identical bitstreams (tested). The depth the codec works at is `--InternalBitDepth`, 10 by default and not in this dialog.
Example: To encode at another internal depth, put `--InternalBitDepth 8` in the Custom box; changing this box does nothing.
Values:
- automatic: Never sent, being the dialog's default. The bundled build rejects the word itself (tested).
- 8: Sent, and it changed nothing in the bitstream (tested).
- 10: Sent, and it changed nothing in the bitstream (tested).
- 12: Sent, and it changed nothing in the bitstream.
Related: staxrip.custom
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.frame-skip
Label: Frames To Be Skipped
Summary: Drops this many frames from the start before encoding begins. 0, the default, starts at the first frame your script produces.
Used when: Sent to the encoder only when Chunks is 1. With Chunks above 1 StaxRip works the piece boundaries out from this number instead and the pipe tool does the cutting.
When to change: Use it to reach the part you want to judge in a test encode, then put it back to 0. To cut a video for real, choose the parts to keep in the preview window's Cut menu. With Chunks above 1 the cutting only happens with the AviSynth/VapourSynth decoder through avs2pipemod or vspipe; a hardware decoder is fed the whole video and every piece then covers all of it.
Encoder default: 0
Example: 750 here starts a 25 fps script at the 30-second mark.
Related: vvencffapp.frames-to-be-encoded, staxrip.chunks, staxrip.decoder
Status: reviewed

## vvencffapp.frames-to-be-encoded
Label: Frames To Be Encoded
Summary: Encodes only this many frames instead of the whole script; 0, the default, encodes all of them. It is for test encodes, not for cutting a video.
Used when: Sent to the encoder only when Chunks is 1, for the same reason as Frames To Be Skipped.
When to change: Set a few hundred frames, or a few thousand for a whole scene, to try settings before committing hours to the full encode. Counting starts at the frame Frames To Be Skipped leaves you on, and StaxRip caps the number at what the script still holds. Put it back to 0 before the real encode.
Encoder default: 0
Example: 1500 here encodes one minute of a 25 fps script. The progress bar counts toward the script's full length either way, so a limited run finishes long before the bar fills.
Related: vvencffapp.frame-skip, staxrip.chunks
Status: reviewed

## vvencffapp.threads
Label: Threads
Summary: Caps how many threads the encoder may use, and with them how much of your CPU the encode takes. 0, the dialog's default, means no multithreading at all.
When to change: Raise it. This is the one box worth touching on a modern machine: left at 0 the encoder reported `NumThreads:0`, one thread and no parallel frames, and a VVC encode is slow enough already (tested). Set it to about the number of logical CPUs you can spare, or put `--Threads -1` in the Custom box to let the encoder choose by resolution: its help gives 4 below 720p, 8 below 5K, 12 above.
Encoder default: 0
Example: With `--Threads 8` the encoder reported `NumThreads:8 MaxParallelFrames:4`: it took four frames in flight of its own accord (tested).
Related: vvencffapp.max-parallel-frames, vvencffapp.preset, staxrip.custom, staxrip.chunks, concept.parallelism
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.max-parallel-frames
Label: Max Parallel Frames
Summary: Caps how many frames the encoder works on at once. More frames in flight uses more of a many-core CPU and more memory; it does not change what a frame is worth.
Used when: Only with Threads above 1. With one thread there is nothing to run in parallel.
When to change: Leave it at -1 and let the encoder decide: with `--Threads 8` it chose 4 by itself (tested). Lower it to 2 to cut the memory an encode holds, or to 0 to switch parallel frames off and leave the threads to work inside one frame at a time. Raising it past what Threads allows buys nothing.
Encoder default: -1 (automatic)
Related: vvencffapp.threads, concept.parallelism
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed

## vvencffapp.lookahead
Label: LookAhead
Summary: Turns on the encoder's pre-analysis pass, which reads ahead of the frame being coded so single-pass rate control can plan its bits.
Used when: Never, as this dialog stands. The encoder allows it only with one-pass rate control, and StaxRip never sends `--NumPasses 1`.
When to change: Leave it at -1. Setting 1 stops the encode in every mode this dialog offers: in Quantizer mode the encoder answers "Look-ahead encoding is not supported when rate control is disabled", and in Bitrate and Two Pass mode "not supported for two-pass rate control" (tested). Setting 0 changes nothing; -1, 0 and leaving the switch out gave three byte-identical bitstreams (tested).
Encoder default: -1 (automatic)
Example: To really use it, put `--NumPasses 1 --LookAhead 1` in the Custom box in Bitrate mode. That combination is accepted and the encoder then reports `LookAhead:1` (tested).
Related: vvencffapp.mode, staxrip.custom, concept.lookahead, concept.two-pass
References:
- https://github.com/fraunhoferhhi/vvenc/wiki/Usage
Status: reviewed
