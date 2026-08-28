# StaxRip-owned option help

Schema: 1
Encoder: staxrip
Locale: en
Title: StaxRip

## staxrip.decoder
Label: Decoder
Summary: Chooses what feeds frames to the encoder: your AviSynth or VapourSynth script, or the source file decoded on the GPU. The hardware choices skip your script and its filters.
When to change: Leave it on AviSynth/VapourSynth. It is the only choice that applies your filters and the only one Chunks can cut, and then only with avs2pipemod or vspipe. Pick a hardware decoder when you want a plain encode of the source with no filtering. Cropping still reaches the decoder while the Crop filter is active.
Values:
- script: Runs your script through the tool chosen under Pipe. Filters, resizing, and Chunks all work.
- qs: QSVEncC decodes the source file on an Intel GPU and pipes raw frames. Only cropping is applied.
- ffqsv: ffmpeg decodes the source file with Intel Quick Sync, the GPU's built-in video decoder. Only cropping is applied.
- ffdxva: ffmpeg decodes the source file through DXVA2, the Windows hardware decoding interface. Only cropping is applied.
Related: staxrip.pipe, staxrip.chunks
Status: reviewed

## staxrip.pipe
Label: Pipe
Summary: Picks the tool that runs your script and pipes its frames to the encoder. Automatic uses avs2pipemod for AviSynth scripts and vspipe for VapourSynth scripts.
Used when: Only with the AviSynth/VapourSynth decoder. You see the AviSynth list with an .avs script and the VapourSynth list with a .vpy script; each keeps its own choice.
When to change: Leave it on Automatic. Switch to ffmpeg only to get around a script that avs2pipemod or vspipe cannot open. StaxRip cannot cut the video into chunks through ffmpeg, so with ffmpeg selected it ignores Chunks, encodes the video in one piece, and writes the reason in the log.
Values:
- automatic: avs2pipemod for AviSynth, vspipe for VapourSynth. The default.
- avs2pipemod: The AviSynth pipe tool. Supports the cutting Chunks needs.
- vspipe: VapourSynth's own pipe tool. Supports the cutting Chunks needs.
- ffmpeg: Reads the script through ffmpeg. It has no cutting, so Chunks is ignored and the video is encoded in one piece.
Related: staxrip.decoder, staxrip.chunks
Status: reviewed

## staxrip.custom
Label: Custom
Summary: Adds your own switches to the encoder command line, as typed. Use it for options this dialog does not offer.
Used when: Which boxes you get depends on the encoder. Most have an all-passes box and add one per pass for a multi-pass encode, each applying to that pass alone. AOMEnc has only its two per-pass boxes.
When to change: Only for a switch that has no control here; Ctrl+F1 lists them all. Type it as on a command line, one switch per line if you like. Put it in the box for the pass that must see it, remembering that the last pass writes the file you keep. Name a switch the dialog already sets and StaxRip drops its own copy there, so yours wins. A bad value stops the encode. `%source_name%` is expanded.
Example: In a two-pass AOMEnc encode, a switch typed only into Custom 1st pass never reaches the run that writes the file, so it looks as if it did nothing. Put it in both boxes unless you mean it for the analysis pass alone.
Related: concept.two-pass
Status: reviewed

## staxrip.override-target-file-name
Label: Override Target File Name
Summary: Lets the Target File Name pattern below name the output file instead of StaxRip's usual naming. Off by default.
When to change: Turn it on when you want the file name to record the settings, say the CRF and preset of a test series. While it is on, StaxRip renames the target each time you close this dialog with OK or load a source. Typing a name into the main window's target box turns it off again. The encoder panel of the main window shows the same switch as Target Name Override.
Related: staxrip.target-file-name, staxrip.target-file-name-preview
Status: reviewed

## staxrip.target-file-name
Label: Target File Name
Summary: The pattern for the output file name, without the extension. Macros such as `%source_name%` and `%--crf%` are replaced with their values.
Used when: Only while Override Target File Name is on. The text is kept but not used otherwise.
When to change: Put the settings you want to see in the name. `%source_name%` is the source name without extension; every encoder option in this dialog is available as `%--switch%`, such as `%--preset%` or `%--crf%`, with `_L`, `_U`, or `_T` added for lower, upper, or title case. Line breaks and any character a file name cannot hold become `-`. Check the Preview.
Example: `%source_name%_CRF%--crf%_P%--preset%` turns `movie.mkv` encoded at CRF 30 with preset 6 into `movie_CRF30_P6`.
Related: staxrip.override-target-file-name, staxrip.target-file-name-preview
Status: reviewed

## staxrip.target-file-name-preview
Label: Preview
Summary: Shows the file name the pattern above produces with the current settings. It is read-only and updates as you type and whenever an option changes.
When to change: Nothing to change here. If the preview is not what you expect, fix the pattern in Target File Name. A macro that shows up unexpanded is misspelled or names an option this dialog does not have.
Related: staxrip.target-file-name, staxrip.override-target-file-name
Status: reviewed

## staxrip.chunks
Label: Chunks
Summary: Splits the video into this many pieces, encodes them as separate encoder processes at the same time, and joins them when muxing. 1 encodes the whole video in one run.
Used when: Cutting into pieces needs the AviSynth/VapourSynth decoder with avs2pipemod or vspipe, and an mkvmerge or mp4box muxer. Only SVT-AV1 checks: it encodes in one piece instead and logs the reason.
When to change: Leave it at 1 unless the encoder leaves cores idle; SVT-AV1 already uses many threads for one encode. Pieces run in parallel, sharing the settings' parallel-processes limit (3 by default) with audio. Each starts with its own keyframe, and a bitrate target is held per piece. AOMEnc and vvencFFapp do not check the conditions above, so the wrong decoder or pipe there spoils the output silently.
Example: Set 2 with the parallel-processes limit at 2 or more and compare the total time with a plain encode of the same clip before using it for a real job.
Related: staxrip.decoder, staxrip.pipe, concept.rate-control, concept.keyframe
Status: reviewed

## staxrip.comp-check
Label: Comp. Check
Summary: The quality level (CRF or QP) used by the compressibility check, a short test encode that measures how many bits your video needs at that quality. Its result is the 100% mark for Aimed Quality.
Used when: The check is offered only with a bitrate target (VBR or CBR rate control); in a quality mode (CRF or QP) there is no target size to adjust, so the button and the menu entry are hidden.
When to change: Leave it at 18; moving it only shifts what 100% means. Run the check once source, crop, and filters are set. StaxRip encodes 5% of the video in 2-second blocks at this quality, measures bits per pixel per frame, and, as chosen under Options > Misc, sets the target size or shrinks the picture (needs a Resize filter) to reach the Aimed Quality share. Repeat it after changing filters or size.
Related: staxrip.aimed-quality, concept.quality-level, concept.rate-control
Status: reviewed

## staxrip.aimed-quality
Label: Aimed Quality
Summary: After the compressibility check, StaxRip sets the target file size, or the picture size, so the encode gets this percentage of the bits the test encode used. 50 means half.
Used when: Only with a bitrate target (VBR or CBR rate control), together with Comp. Check.
When to change: 50 is the default; the assistant asks for 50 to 70 and warns when the size you set later drifts more than 20 points from this value. Go toward 70 when quality matters more than size, lower for small files. It is applied when you close this dialog with OK, so set it before the check or run the check again. The main window's size menu has 50% and 60% entries that reuse the check.
Example: If the check finds the video needs 10 Mbps at quality 18, 50 sets the target size for about 5 Mbps and 70 for about 7 Mbps at the same resolution and frame rate.
Related: staxrip.comp-check, concept.rate-control, concept.bitrate
Status: reviewed
