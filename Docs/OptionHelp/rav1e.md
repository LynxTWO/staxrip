# rav1e option help

Schema: 1
Encoder: rav1e
Locale: en
Title: rav1e
Source: Source/Encoding/Rav1e.vb
Allowed-Missing: 0
Minimum-Reviewed: 19
Reviewed-Complete: true
Verified-Encoder-Version: rav1e 0.8.0 (p20250624-3-g564ae3b) (release)
Verified-Encoder-Build: 564ae3b
Verified-Date: 2026-08-28
Documentation: https://github.com/xiph/rav1e/blob/v0.8.0/README.md

## rav1e.tune
Label: Tune
Summary: Chooses what the encoder rewards when it decides where to spend bits: a measured pixel-error score, or how the picture looks to a person.
When to change: Leave it alone; in this build both entries give the same encode. rav1e's own default is Psychovisual, and StaxRip sends `--tune` only for the Psychovisual entry, so picking PSNR sends nothing and you get Psychovisual anyway. To really encode for PSNR, put `--tune psnr` in the Custom box; the bundled build accepts that value (tested).
Encoder default: Psychovisual
Example: Encode a detailed scene twice at the same Quantizer, once as the dialog leaves it and once with `--tune psnr` in the Custom box. Compare the pictures, not the scores.
Values:
- psnr: Never sent, being the dialog's own default; rav1e then uses its default, Psychovisual.
- psychovisual: Sends `--tune psychovisual`, which is rav1e's default too: it weighs errors by how visible they are.
Related: rav1e.speed, rav1e.quantizer, staxrip.custom, concept.psnr, concept.vq, concept.compression-efficiency
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
Status: reviewed

## rav1e.mode
Label: Mode
Summary: Chooses what the encode aims at: the quality level you set under Quantizer, or a target bitrate. It also decides whether the Speed box or the Bitrate and Passes boxes are shown.
When to change: Leave it on Speed for video you keep; Quantizer sets the quality and the size falls where it may. Switch to Bitrate when the file has to hit a size: the Bitrate and Passes boxes appear, the Speed box goes away, and the encode then runs at rav1e's own speed 6. The main window's size and bitrate boxes stay live in both modes, but in Speed mode nothing from them is sent.
Values:
- --speed: Holds the Quantizer setting and lets the size fall where it may. Sends `--speed` with the Speed box.
- --bitrate: Aims at the Bitrate box instead. The Speed box is hidden, so rav1e's own default of 6 applies.
Related: rav1e.speed, rav1e.bitrate, rav1e.quantizer, rav1e.first-pass, concept.rate-control, concept.bitrate
Status: reviewed

## rav1e.first-pass
Label: Passes
Summary: Chooses whether the encoder analyzes the whole video first and then encodes it with what it learned, so that a bitrate target is met more closely.
Used when: Only in Bitrate mode. A speed-mode encode has no target to aim at, so the control is hidden and StaxRip runs a single pass.
When to change: Pick Two Passes when the file has to hit a size and you can spend about twice the time. StaxRip then runs rav1e twice over the same script: the first run writes statistics with `--first-pass` into a file named after the output with a `.stats` extension, and the second reads them back with `--second-pass`. One Pass is right for everything else.
Values:
- onepass: One run, no analysis pass. The default.
- twopasses: Two runs over the same script, sharing a `.stats` file next to the output.
Related: rav1e.mode, rav1e.bitrate, concept.two-pass, concept.rate-control
References:
- https://github.com/xiph/rav1e/blob/v0.8.0/README.md
Status: reviewed

## rav1e.speed
Label: Speed
Summary: Sets how much work the encoder does on each frame, from 0 (slowest, smallest file) to 10 (fastest). A higher number finishes sooner and needs more bits for the same picture.
Used when: Only in Speed mode. In Bitrate mode the box is hidden and no `--speed` is sent, so the encoder falls back to its own default of 6.
When to change: StaxRip starts you at 6, which is rav1e's default too. Drop to 4 or 3 for a final encode when you can wait; go to 8 or 9 for a quick look. rav1e's own help calls 0 and 10 extremes it does not recommend. The speed level also sets how far ahead the encoder looks: its help gives 10 frames at speeds 9 and 10, 20 at 6 to 8, 30 at 3 to 5, and 40 at 0 to 2.
Encoder default: 6
Example: Encode the same 60-second scene at 6 and at 4 with the same Quantizer, then compare the time and the file size before you commit the whole video.
Related: rav1e.mode, rav1e.quantizer, rav1e.tune, concept.compression-efficiency, concept.lookahead
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
Status: reviewed

## rav1e.bitrate
Label: Bitrate
Summary: The bitrate in kbps the encoder aims at across the whole video. Together with the running time it sets the size of the video stream.
Used when: Only in Bitrate mode. In Speed mode the box is hidden and no bitrate reaches the encoder.
When to change: Set the size or the bitrate in the main window instead; both boxes feed this one. The dialog takes 0 to 9999 kbps. Two passes usually land closer to the target than one. Quantizer caps how coarse the rate control may go, so a target far below what the video needs can still be missed.
Example: Twenty minutes at 4000 kbps is roughly 600 MB of video before audio (4000 x 1200 / 8 / 1000). Type a size into the main window's target size box and reopen this dialog: this value follows it.
Related: rav1e.mode, rav1e.first-pass, rav1e.quantizer, concept.bitrate, concept.rate-control
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
Status: reviewed

## rav1e.quantizer
Label: Quantizer
Summary: Sets how coarsely the encoder rounds picture detail away. Lower is a better picture and a larger file; 0 is the finest step and 255 the coarsest.
Used when: In Speed mode it holds the quality for the whole encode. In Bitrate mode rav1e takes it as the coarsest quantizer the rate control may reach, which makes it a quality floor.
When to change: Lower it for quality, raise it for a smaller file, then judge a short test encode by eye rather than by the number. The scale is AV1's own 0 to 255 quantizer index, four times finer than the 0 to 63 scale SVT-AV1's CRF uses, so each step moves less than you may expect. StaxRip starts you at 100, rav1e's default.
Encoder default: 100
Example: Encode the same 60-second scene at 100 and at 120 with everything else unchanged. Compare the sizes, then step through a detailed frame in each and take the higher number if you cannot see the difference.
Related: rav1e.mode, rav1e.speed, rav1e.bitrate, concept.quality-level, concept.rate-control
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
- https://github.com/xiph/rav1e/blob/v0.8.0/src/api/internal.rs
Status: reviewed

## rav1e.keyint
Label: Keyframe Interval
Summary: Sets the longest gap the encoder may leave between keyframes, the frames stored whole that playback can start from. 0 switches the fixed interval off.
When to change: Leave it at 240, rav1e's own default and about ten seconds at 24 fps. Shorten it when quick seeking matters more than size, since every keyframe costs bits. rav1e also starts a keyframe at a scene cut of its own accord, so this is a ceiling rather than a rhythm. The dialog stops at 300; for a longer gap put `--keyint` in the Custom box.
Encoder default: 240
Example: At 24 fps, 120 gives a keyframe at least every five seconds. At 0 rav1e places one only where it finds a scene cut, which can leave a long stretch with none.
Related: rav1e.min-keyint, staxrip.custom, concept.keyframe, concept.gop
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
Status: reviewed

## rav1e.min-keyint
Label: Min Keyframe
Summary: Sets the shortest gap the encoder may leave between keyframes, so that a run of quick cuts cannot fill the file with whole frames.
When to change: Leave it at 12, rav1e's own default. Raise it when a cut-heavy source comes out larger than you expect: the scene-change detector must then wait that many frames before it may start another keyframe. It does nothing above the Keyframe Interval, which is the other end of the same range.
Encoder default: 12
Related: rav1e.keyint, concept.keyframe, concept.gop
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
Status: reviewed

## rav1e.threads
Label: Threads
Summary: Caps how many threads the encoder may use, and with them how much of your CPU the encode takes. 0, the default, lets it use one for every logical CPU.
When to change: Leave it at 0 for a single encode. Set a small number to keep cores free for something else. rav1e's own help warns that threads alone may not be used: much of its parallel work comes from tiles, and this dialog has no tile control, so add `--tiles`, `--tile-rows` or `--tile-cols` in the Custom box if the encoder leaves cores idle. The dialog stops at 20.
Encoder default: 0
Related: staxrip.custom, concept.parallelism, concept.tiles
Status: reviewed

## rav1e.limit
Label: Limit
Summary: Encodes only this many frames of your script instead of all of them; 0 means all frames. It is for test encodes, not for cutting a video.
When to change: Set a few hundred frames, or a few thousand for a whole scene, to try settings before committing hours to the full encode. Counting starts at the first frame your script produces; rav1e's own `--skip` is not in this dialog, so put it in the Custom box to start further in. To cut a video for real, choose the parts to keep in the preview window's Cut menu.
Encoder default: 0
Example: 1500 here encodes one minute of a 25 fps script. Put it back to 0 before the real encode. The progress bar counts toward the script's full length either way, so a limited run finishes long before the bar fills.
Related: staxrip.custom
Status: reviewed

## rav1e.low-latency
Label: Low Latency
Summary: Makes the encoder code frames in playback order instead of reordering them. It shortens the delay before output starts, and costs compression.
When to change: Leave it off. rav1e normally codes some frames out of order so that a later frame can help predict an earlier one, which is where much of AV1's efficiency comes from; its own help calls switching that off a significant speed-to-quality trade-off. Turn it on only when something downstream needs each frame the moment it is ready.
Encoder default: off
Related: rav1e.speed, concept.gop, concept.compression-efficiency
References:
- https://docs.rs/rav1e/0.8.0/rav1e/config/struct.EncoderConfig.html
Status: reviewed

## rav1e.mastering-display
Label: Master Display
Summary: Records the primaries, white point and brightness range of the display the video was graded on, so a player can fit an HDR picture to the screen it has.
Used when: Only when you fill it in. Left empty, which is how it starts, StaxRip sends nothing and the stream carries no mastering display.
When to change: Fill it in for HDR10 video when you know the mastering display, copying the numbers from the source's own metadata. The bundled build wants one string of the form `G(x,y)B(x,y)R(x,y)WP(x,y)L(max,min)` with no spaces. The picture is unchanged either way; this is a label a player reads.
Example: `G(0.265,0.690)B(0.150,0.060)R(0.680,0.320)WP(0.3127,0.3290)L(1000,0.0001)` describes a 1000-nit P3 display with a D65 white point. The bundled build accepts that string (tested).
Related: rav1e.content-light.max-cll, rav1e.content-light.max-fall, rav1e.transfer, rav1e.primaries, concept.hdr-metadata
Status: reviewed

## rav1e.content-light.max-cll
Label: Content Light
Summary: The brightest single pixel in the video, in nits (MaxCLL), recorded in the stream so a player can fit HDR to the screen it has. 0 records nothing.
Used when: Only when this box or Maximum FALL is above 0. The two are sent together as one switch.
When to change: Fill it in for HDR10 video when the source's metadata gives you the number, and leave both boxes at 0 for SDR. Guessing is worse than leaving it out: a wrong number makes a player tone-map the picture wrongly. Content Light and Maximum FALL travel together as `--content-light "cll,fall"`, so a value in either box sends both.
Example: For a master graded at 1000 nits whose brightest frame averages 400, put 1000 here and 400 in Maximum FALL. StaxRip then sends `--content-light "1000,400"`, which the bundled build accepts (tested).
Related: rav1e.content-light.max-fall, rav1e.mastering-display, rav1e.transfer, concept.hdr-metadata
Status: reviewed

## rav1e.content-light.max-fall
Label: Maximum FALL
Summary: The frame average light level of the brightest frame, in nits (MaxFALL), recorded in the stream beside MaxCLL. 0 records nothing.
Used when: Only when this box or Content Light is above 0. The two are sent together as one switch.
When to change: Fill it in beside Content Light for HDR10 video, taking the number from the source's metadata, and leave both boxes at 0 for SDR. This is the average over one frame rather than a single pixel, so it is normally well below the Content Light figure. The two boxes travel together as `--content-light "cll,fall"`, so a value in either one sends both.
Related: rav1e.content-light.max-cll, rav1e.mastering-display, rav1e.transfer, concept.hdr-metadata
Status: reviewed

## rav1e.primaries
Label: Primaries
Summary: Tags the video with its color primaries, the exact red, green and blue a player should assume. It is a label on the stream and changes no pixel.
When to change: Leave it at Unspecified unless you know the source's primaries; a wrong tag shifts the color on playback. Only BT709, BT470M, BT470BG and BT2020 reach the encoder: the bundled build refuses the other seven names and the encode stops before it starts (tested). For those, put `--primaries` with the name rav1e uses in the Custom box.
Example: For a DCI-P3 master the dialog's P3DCI entry stops the encode, so leave this at Unspecified and put `--primaries SMPTE431` in the Custom box instead.
Values:
- bt709: HD and most modern video. Accepted by the bundled build (tested).
- unspecified: Never sent, being the dialog's default; the stream then leaves the field unspecified.
- bt470m: The old NTSC primaries. Accepted by the bundled build (tested).
- bt470bg: The PAL and SECAM primaries. Accepted by the bundled build (tested).
- st170m: Refused by the bundled build, which calls these primaries `BT601`. Use the Custom box (tested).
- st240m: Refused by the bundled build, which calls these primaries `SMPTE240`. Use the Custom box (tested).
- film: Refused by the bundled build, which calls these primaries `GenericFilm`. Use the Custom box (tested).
- bt2020: The UHD and HDR primaries. Accepted by the bundled build (tested).
- st428: Refused by the bundled build, which calls this `XYZ`. Use the Custom box (tested).
- p3dci: Refused by the bundled build, which calls this `SMPTE431`. Use the Custom box (tested).
- p3display: Refused by the bundled build, which calls this `SMPTE432`. Use the Custom box (tested).
- tech3213: Refused by the bundled build, which calls this `EBU3213`. Use the Custom box (tested).
Related: rav1e.matrix, rav1e.transfer, rav1e.range, staxrip.custom, concept.color-description
References:
- https://docs.rs/rav1e/0.8.0/rav1e/prelude/enum.ColorPrimaries.html
Status: reviewed

## rav1e.matrix
Label: Matrix
Summary: Tags the video with the matrix that turned its colors into the brightness and color-difference channels it is stored in. It is a label and changes no pixel.
When to change: Leave it at Unspecified unless you know what the source uses; a wrong tag shifts the color on playback. Only Identity, BT709, BT470BG, YCgCo and ICtCp reach the encoder: the bundled build refuses the other eight names and the encode stops before it starts (tested). For those, put `--matrix` with the name rav1e uses in the Custom box.
Values:
- identity: The channels are stored as they are, with no color transform. Accepted (tested).
- bt709: HD video. Accepted by the bundled build (tested).
- unspecified: Never sent, being the dialog's default; the stream then leaves the field unspecified.
- bt470m: Refused by the bundled build, whose value in this slot is `FCC`. Use the Custom box (tested).
- bt470bg: PAL and SECAM, the same matrix as standard-definition BT601. Accepted (tested).
- st170m: Refused by the bundled build, which calls this `BT601`. Use the Custom box (tested).
- st240m: Refused by the bundled build, which calls this `SMPTE240`. Use the Custom box (tested).
- ycgco: Accepted by the bundled build (tested).
- bt2020nonconstantluminance: Refused by the bundled build, which calls it `BT2020NCL`. Use the Custom box (tested).
- bt2020constantluminance: Refused by the bundled build, which calls it `BT2020CL`. Use the Custom box (tested).
- st2085: Refused by the bundled build, which calls it `SMPTE2085`. Use the Custom box (tested).
- chromaticityderivednonconstantluminance: Refused; the bundled build calls it `ChromatNCL`. Use the Custom box (tested).
- chromaticityderivedconstantluminance: Refused; the bundled build calls it `ChromatCL`. Use the Custom box (tested).
- ictcp: Accepted by the bundled build (tested).
Related: rav1e.primaries, rav1e.transfer, rav1e.range, staxrip.custom, concept.color-description
References:
- https://docs.rs/rav1e/0.8.0/rav1e/prelude/enum.MatrixCoefficients.html
Status: reviewed

## rav1e.transfer
Label: Transfer
Summary: Tags the video with its transfer curve, the rule linking stored numbers to light. It tells a player whether the file is SDR, HDR10 or HLG, and changes no pixel.
When to change: Leave it at Unspecified unless you know the source's curve; a wrong tag makes an HDR file look washed out. Only BT470M, BT470BG, Linear and SRGB reach the encoder: the bundled build refuses the other twelve names and the encode stops before it starts (tested). For HDR10, leave this alone and put `--transfer SMPTE2084` in the Custom box.
Values:
- bt1886: Refused by the bundled build, whose value in this slot is `BT709`. Use the Custom box (tested).
- unspecified: Never sent, being the dialog's default; the stream then leaves the field unspecified.
- bt470m: Accepted by the bundled build (tested).
- bt470bg: Accepted by the bundled build (tested).
- st170m: Refused by the bundled build, which calls this `BT601`. Use the Custom box (tested).
- st240m: Refused by the bundled build, which calls this `SMPTE240`. Use the Custom box (tested).
- linear: Accepted by the bundled build (tested).
- logarithmic100: Refused by the bundled build, which calls it `Log100`. Use the Custom box (tested).
- logarithmic316: Refused by the bundled build, which calls it `Log100Sqrt10`. Use the Custom box (tested).
- xvycc: Refused by the bundled build, which calls it `IEC61966`. Use the Custom box (tested).
- bt1361e: Refused by the bundled build, which calls it `BT1361`. Use the Custom box (tested).
- srgb: Accepted by the bundled build (tested).
- bt2020ten: Refused by the bundled build, which calls it `BT2020_10Bit`. Use the Custom box (tested).
- bt2020twelve: Refused by the bundled build, which calls it `BT2020_12Bit`. Use the Custom box (tested).
- perceptualquantizer: The HDR10 curve. Refused by the bundled build, which calls it `SMPTE2084`. Use the Custom box (tested).
- st428: Refused by the bundled build, which calls it `SMPTE428`. Use the Custom box (tested).
- hybridloggamma: The HLG curve. Refused by the bundled build, which calls it `HLG`. Use the Custom box (tested).
Related: rav1e.primaries, rav1e.matrix, rav1e.range, staxrip.custom, concept.color-description, concept.hdr-metadata
References:
- https://docs.rs/rav1e/0.8.0/rav1e/prelude/enum.TransferCharacteristics.html
Status: reviewed

## rav1e.range
Label: Range
Summary: Tags the video with the range its brightness values use: limited (16 to 235 for 8-bit) or full (0 to 255). It is a label and changes no pixel.
When to change: Leave it at Unspecified unless a delivery target asks for a tag; StaxRip then sends nothing and rav1e's own default, limited, applies. Set it to match what your script really produces, not what you would like: a wrong tag makes a player stretch or squash the contrast. The bundled build has only the two named values.
Values:
- unspecified: Never sent, being the dialog's default; rav1e's own default, limited, applies.
- limited: 16 to 235 for 8-bit video, the usual range for broadcast and for most files. Accepted (tested).
- full: 0 to 255 for 8-bit video. Accepted by the bundled build (tested).
Related: rav1e.primaries, rav1e.matrix, rav1e.transfer, concept.color-description
References:
- https://docs.rs/rav1e/0.8.0/rav1e/prelude/enum.PixelRange.html
Status: reviewed
