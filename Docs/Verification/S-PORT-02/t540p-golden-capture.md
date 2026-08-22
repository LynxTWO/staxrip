# S-PORT-02 Non-WSL Golden Capture, T540p

Date: 2026-08-21, re-run 2026-08-22 over six fixtures after the corpus grew. Recorded by `Record-T540pGoldenCapture.sh`: the committed
media files and the pinned 24.01 user-prefix tool were transferred to the
independent bare-metal Ubuntu host over the tailnet, the tool hash was verified on
the host before execution, the recorded invocation ran from the media directory
exactly as the fixture manifest specifies, and the captured documents were fetched
back and compared byte for byte against the committed `wsl-24.01` goldens. The host
was cleaned afterward and verified empty. This closes the tool matrix's remaining
open verification row for a non-WSL Linux host.

## Host identity

- Hostname `daniel-boyd-ThinkPad-T540p`, bare metal, Ubuntu 24.04, ext4.
- Machine-id SHA-256
  `08da6e196c2962c12bd964f4f497eef136b8eff4a1ce16e7971dc973a70da697`, which differs
  from the dev WSL host's, the independence discriminator this record requires.
- Tool on host: sha256 verified equal to the manifest's pinned
  `a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6`, version probe
  `MediaInfoLib v24.01`.

## Result

Raw captures measured exactly one byte larger than each committed golden, which is
the capture pipeline's trailing blank line the manifest already documents; after the
manifest's single-trailing-newline normalization, the only differences in all four
documents were the two `File_Modified_Date` and `File_Modified_Date_Local` lines,
filesystem copy-time metadata that sits on the privacy strip list and never enters
the exposed fact set. Every fact byte is identical between the WSL capture and the
bare-metal capture:

| Fixture | Verdict |
|---|---|
| cfr-h264-aac.mp4 | identical modulo the two file-date lines |
| cfr-ffv1-10bit-pcm.mkv | identical modulo the two file-date lines |
| cfr-vp9-opus.webm | identical modulo the two file-date lines |
| vfr-ffv1.mkv | identical modulo the two file-date lines |
| cfr-h264-aac-chapters.mp4 | identical modulo the two file-date lines |
| cfr-h264-aac-subtitles.mkv | identical modulo the two file-date lines |

The committed goldens therefore stand as host-independent at the range floor: the
same tool version produces fact-identical documents on WSL and on independent bare
metal, and the only host-varying content is metadata the privacy guard strips before
anything leaves the adapter.
