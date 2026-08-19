# Media Inspection Golden Fixtures

Captured 2026-08-19 under the D-045 ratification and the maintainer's tool-acquisition
approval. Eight documents: four synthetic media fixtures, each probed by both ends of
the pinned version range. Every `@ref` is a relative filename; no absolute path, host
name, or user identifier appears in any document, verified by scan before commit.

## Capture identities

- Range ceiling: MediaInfo CLI 26.05, Windows x64, downloaded from MediaArea.
  Archive SHA-256 `f7f80620ce6d14f4995f0de6f98e3ef18ad29496db01899571152ee3311229f9`,
  executable SHA-256 `30f2828a45a1895b033c3cd7784581033327e7b393033c55f4a03bb15cab0d89`.
  Matches the MediaInfoLib version the Windows application bundles.
- Range floor: MediaInfo CLI 24.01.1 from Ubuntu 24.04 `noble/universe`, acquired by
  package download and user-prefix extraction with no system installation and no root.
  Binary SHA-256 `a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6`.
- Invocation, both ends: `mediainfo --Output=JSON <relative-filename>` from the media
  directory, path as one argv element.

## Media provenance

Synthetic fixtures generated during the earlier portable-validation work from bundled
tools; no personal media, no real-world content. The media files stay out of the
repository; these hashes bind the documents to their exact inputs.

| File | Bytes | SHA-256 |
|---|---|---|
| cfr-ffv1-10bit-pcm.mkv | 426480 | be499502e007ce2b (leading 16 hex; full hash in the capture record) |
| cfr-h264-aac.mp4 | 215647 | 01d6599df1c1006d |
| cfr-vp9-opus.webm | 111915 | cd0516b6df0685a3 |
| vfr-ffv1.mkv | 225586 | 4b29fedfb1dccdbb |

## What the captures established

1. `creatingLibrary.version` is present in every document at both ends and matches the
   probing tool, so the version-pinning contract in the tool matrix is verifiable from
   the payload itself.
2. The pinned range `[24.01, 26.05]` is schema-stable for the exposed fact set over this
   corpus: the only field-set difference anywhere is that 26.05 adds
   `File_Created_Date` and `File_Created_Date_Local` to the General track.
3. Those two added fields are filesystem metadata, not media facts, and they join the
   privacy strip list together with the empirically confirmed `UniqueID` (every MKV and
   WebM here), `Encoded_Library_Settings` (the MP4), and `Encoded_Application` (all).
   These documents deliberately retain those fields: they are the raw inputs the privacy
   guard's self-test must prove it strips.
4. Genuine absences the adapter must pass through as absence, identical at both ends:
   FFV1 carries no `Format_Profile`; AAC audio carries no `BitDepth`; VP9 carries no
   `ColorSpace` or `ScanType`; Opus carries no `BitRate`; and `vfr-ffv1.mkv` carries no
   `FrameRate` and no `FrameCount`, which is the exact vector for the no-silent-default
   rule, because the current Windows wrapper would report 25 for it.
