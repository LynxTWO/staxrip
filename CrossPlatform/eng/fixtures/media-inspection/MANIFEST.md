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

Synthetic fixtures; no personal media, no real-world content. Provenance differs by
generation and the difference matters. The first four were generated during the earlier
portable-validation work from bundled tools with no recorded recipe: their goldens carry
a writing-application string identifying the ffmpeg build now named in the tool matrix,
which recovers the authoring identity, but they were not authored bit-exactly and their
exact bytes are not reproducible. The two fixtures added 2026-08-21 were authored under
D-047 by `CrossPlatform/eng/New-MediaFixtures.ps1`, which verifies the authoring tool's
SHA-256 before running it and uses bit-exact flags; running that script twice into
separate directories produced byte-identical files, which is a reproducibility claim
only those two carry. The media files are committed beside
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
   corpus: the only field-set difference across these four fixtures is that 26.05 adds
   `File_Created_Date` and `File_Created_Date_Local` to the General track.

   Scope correction, 2026-08-21. That sentence said "anywhere" and was measured only
   over this corpus, which carries no subtitle track. A probe of a chaptered,
   dual-subtitle Matroska file with both pinned binaries found a second and larger
   difference: 26.05 reports `ServiceKind` on a Text track, carrying `HI` for a
   hearing-impaired track and `C` for a commentary track, and 24.01 does not report the
   field at all. That is a media fact, not filesystem metadata, so the schema-stability
   claim holds for the exposed set as delivered and does not extend to subtitle
   disposition facts. The consequence is recorded in the verification record: the
   agreed commentary and hearing-impaired facts are blocked by range instability, not
   by the absence of a carrying fixture. The probe file is not committed; committing a
   fixture that carries it needs the tool-provenance approval named in the decision
   log.
3. Those two added fields are filesystem metadata, not media facts, and they join the
   privacy strip list together with the empirically confirmed `UniqueID` (every MKV and
   WebM here), `Encoded_Library_Settings` (the MP4), and `Encoded_Application` (all).
   These documents deliberately retain those fields: they are the raw inputs the privacy
   guard's self-test must prove it strips.

   Variant correction, 2026-08-21. The same probe established that 26.05 splits the
   writing-application fact across `Encoded_Application`, `Encoded_Application_Name`,
   and `Encoded_Application_Version` for a file written by a real muxer. None of these
   four fixtures carries the split form, so the corpus could not have surfaced it. The
   privacy guard now bans each listed name as a family head matched by prefix, the rule
   the identifier family already had, and the guard's self-test carries the split form
   directly.
4. Genuine absences the adapter must pass through as absence, identical at both ends:
   FFV1 carries no `Format_Profile`; AAC audio carries no `BitDepth`; VP9 carries no
   `ColorSpace` or `ScanType`; Opus carries no `BitRate`; and `vfr-ffv1.mkv` carries no
   `FrameRate` and no `FrameCount`, which is the exact vector for the no-silent-default
   rule, because the current Windows wrapper would report 25 for it.
