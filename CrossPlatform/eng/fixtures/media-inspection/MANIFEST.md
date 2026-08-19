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
  directory, path as one argv element. Committed documents are normalized to a single
  trailing newline per the repository whitespace rule; the capture pipeline emitted a
  trailing blank line that carries no fixture meaning, and re-captures must apply the
  same normalization.

## Media provenance

Synthetic fixtures generated during the earlier portable-validation work from bundled
tools; no personal media, no real-world content. The media files are committed beside
these documents under `media/`, so the whole chain, input bytes to golden output, is
reproducible from the repository alone, and the comparison recorder can run on any
checkout. These hashes bind the documents to their exact inputs.

| File | Bytes | SHA-256 |
|---|---|---|
| cfr-ffv1-10bit-pcm.mkv | 426480 | `be499502e007ce2b2405523deca913c889e444703f3c2c79ba35f7acf346daf1` |
| cfr-h264-aac.mp4 | 215647 | `01d6599df1c1006d7df29bcd2a3462cb1943b4294e243f3e9d84eb402b99a12b` |
| cfr-vp9-opus.webm | 111915 | `cd0516b6df0685a36919bad2a886a50f657255eb71fe746e6c727090b1d645c0` |
| vfr-ffv1.mkv | 225586 | `4b29fedfb1dccdbbf30a739d426a4d3e7d9656863e5451ecc931d66456b45491` |

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
