# Media Inspection Agreed Facts

Version: 0.2 Ratified under D-045. Date: 2026-08-18. Base: `e265c45b`.

This is the agreed-facts list S-PORT-02's exit criteria require: for each fact the
portable inspection will expose, the Windows source and its rule, the proposed portable
source and its rule, and the accepted divergence. It is grounded in the fact-authority
map (`Media-Inspection-Map.md`) and a mechanical extraction of every literal-parameter
`MediaInfo` read: 135 call sites over 36 unique parameters, dominated by nine HDR and
color parameters consumed about ten times each across every encoder. Nothing here grants
execution authority; the adapter decision is D-045, ratified 2026-08-18: the MediaInfo
CLI with `--Output=JSON` is the primary portable authority, and ffprobe JSON is the
named backup with activation triggers recorded in the decision.

Under the ratified primary, the portable source for every row below is the same
MediaInfo parameter name delivered through the CLI JSON track fields, so the primary
divergence class is `none` or `structure` for nearly all rows, and the ground rules
carry the remaining real divergences: the absence rules still apply because the silent
defaults and identifier synthesis live in the Windows wrapper code, not in MediaInfo
itself, and the privacy rule is load-bearing because the CLI JSON includes
`UniqueID`-class fields that must be stripped at the adapter boundary with a
self-tested guard. The tables keep their third column as written: it is the BACKUP
mapping to ffprobe JSON, which is exactly what a backup activation needs already agreed.

## Ground rules

1. **Facts and policy are separate.** The portable contract exposes what a file contains.
   Stream enablement, preferred languages, and demux choices are project policy and stay
   with the layer that owns the project (`MediaInfo.vb:137-151,194-206` is the fused
   behavior being deliberately not ported).
2. **Absence is exposed as absence.** The Windows layer silently defaults a missing frame
   rate to 25 and missing channels to 2 (`MediaInfo.vb:320-352,358-374`). The portable
   contract returns the fact as absent and lets the consumer decide. This is a recorded,
   accepted divergence, not an oversight.
3. **No identifier synthesis.** Windows fabricates stream identifiers when the source
   value is not an integer (`MediaInfo.vb:39-41,67-81`). The portable contract uses the
   probe's native stream index and typed disposition; it never invents identifiers.
4. **Privacy redaction carries over.** The existing product rule strips `UniqueID` and
   `Encoded_Library_Settings` from displayed summaries (`MediaInfo.vb:228-238`). The
   portable payload never includes globally unique media identifiers, library settings
   strings, or absolute paths beyond the user's own selection echo.
5. **Canonical enums, not source spellings.** Color facts are normalized to one canonical
   vocabulary at the adapter boundary, because the two authorities spell the same fact
   differently (`BT.2020` versus `bt2020nc`, `Limited` versus `tv`). The canonical value
   plus the raw source string are both retained; comparison happens on canonical values.

## Exposed fact set, version 1

Divergence classes: `none` (same value expected), `spelling` (canonicalized), `structure`
(same content, different shape), `authority` (sources can genuinely disagree; the listed
side wins and the divergence is recorded), `absence` (portable exposes absent where
Windows defaults).

### Container

| Fact | Windows source (MediaInfo) | Backup source (ffprobe JSON) | Backup divergence |
|---|---|---|---|
| Container format | `General/Format` | `format.format_name` | spelling |
| Duration | `General/Duration` | `format.duration` | structure; ms integer vs seconds decimal |
| File size | `General/FileSize` | `format.size` | none |
| Title | `General/Title` or `Movie` (`MainForm.vb`) | `format.tags.title` | authority: probe wins |
| Chapters | `Menu/Chapters_Pos_*` (`Demux.vb`) | `chapters[]` with `start_time`, `tags.title` | structure |

### Video stream

| Fact | Windows source | Backup source (ffprobe JSON) | Backup divergence |
|---|---|---|---|
| Codec | `Video/Format`, `MPEG Video` renamed `MPEG` (`MediaInfo.vb:310-318`) | `streams[].codec_name` | spelling |
| Profile | `Video/Format_Profile` | `profile` + `level` | structure; Windows fuses profile and level in one string |
| Width, Height | `Video/Width`, `Video/Height` | `width`, `height` | none |
| Pixel aspect ratio | `Video/PixelAspectRatio` decimal | `sample_aspect_ratio` rational | structure; rational is canonical |
| Display aspect ratio | `Video/DisplayAspectRatio` | `display_aspect_ratio` | structure; rational is canonical |
| Frame rate | Five-step ladder, default 25 (`MediaInfo.vb:320-352`) | `r_frame_rate` and `avg_frame_rate` rationals, both exposed | absence + structure; no default |
| Frame rate mode | `Video/FrameRate_Mode` | derived: `r_frame_rate` equals `avg_frame_rate` implies constant | authority: MediaInfo wins on Windows comparison; portable value is marked derived |
| Frame count | `Video/FrameCount` | `nb_frames` when present, else absent | absence; container-dependent |
| Bit depth | `Video/BitDepth` | `bits_per_raw_sample`, else derived from `pix_fmt` | structure |
| Chroma subsampling | `Video/ChromaSubsampling` | derived from `pix_fmt` | structure |
| Color space | `Video/ColorSpace` | `pix_fmt` family | structure |
| Scan type, order | `Video/ScanType`, `ScanOrder` | `field_order` | structure; one field vs two |
| Rotation | `Video/Rotation` | `side_data_list` display matrix rotation | structure |
| Stream size | `Video/StreamSize` | absent in most containers | absence; Windows-only comparison fact |
| Stream bitrate | `Video/BitRate` | `bit_rate` when present | absence |
| Language | `Video/Language` | `tags.language` | spelling; both normalized through the existing `Language` type |

### Color and HDR (the encoder nine)

These nine are the most-consumed facts in the application and the comparison bar for any
future encoding slice. S-PORT-02 exposes them read-only.

| Fact | Windows source | Backup source (ffprobe JSON) | Backup divergence |
|---|---|---|---|
| Transfer characteristics | `Video/transfer_characteristics` | `color_transfer` | spelling |
| Color primaries | `Video/colour_primaries` | `color_primaries` | spelling |
| Matrix coefficients | `Video/matrix_coefficients` | `color_space` | spelling |
| Color range | `Video/colour_range` `Limited`/`Full` | `color_range` `tv`/`pc` | spelling |
| Chroma location | `Video/ChromaSubsampling_Position` | `chroma_location` | spelling |
| Mastering display primaries | `Video/MasteringDisplay_ColorPrimaries` prose | side data `Mastering display metadata` rationals | structure; canonical form is the rational set |
| Mastering display luminance | `Video/MasteringDisplay_Luminance` prose | same side data, `min_luminance`, `max_luminance` | structure |
| MaxCLL | `Video/MaxCLL` | side data `Content light level metadata`, `max_content` | none after unit normalization |
| MaxFALL | `Video/MaxFALL` | same side data, `max_average` | none after unit normalization |
| HDR format label | `Video/HDR_Format_Commercial`, `HDR_Format/String` | derived from transfer plus side data presence | authority: MediaInfo wins for the display label; portable label marked derived |

### Audio stream

| Fact | Windows source | Backup source (ffprobe JSON) | Backup divergence |
|---|---|---|---|
| Codec | `Audio/Format`, layer names rewritten MP2, MP3 (`MediaInfo.vb:380-388`) | `codec_name` | spelling |
| Profile | `Audio/Format_Profile`, SBR flag from `Format/String` (`MediaInfo.vb:88,92`) | `profile` | structure |
| Channels | Ladder with slash split, default 2 (`MediaInfo.vb:120-133,358-374`) | `channels`, `channel_layout` | absence; no default, layout is additional |
| Sampling rate | `Audio/SamplingRate` | `sample_rate` | none |
| Bit depth | `Audio/BitDepth` | `bits_per_raw_sample` or absent | absence |
| Bitrate | `Audio/BitRate` with slash split and stats fallback (`MediaInfo.vb:104-116`) | `bit_rate` when present | absence + structure; no secondary value |
| Language | `Audio/Language` via `Language` type | `tags.language` | spelling |
| Title | `Audio/Title` plus `Language_More` enrichment (`MediaInfo.vb:94-102`) | `tags.title` only | authority: portable does not enrich; divergence recorded |
| Default, Forced | `Audio/Default`, `Forced` yes-strings | `disposition.default`, `disposition.forced` | structure; boolean is canonical |
| Delay | `Audio/Video_Delay` | `start_time` delta against video | authority: MediaInfo wins; portable value marked derived |
| Lossy | `Compression_Mode` equals `Lossy` (`MediaInfo.vb:83`) | derived from codec identity | structure |

### Subtitle stream

| Fact | Windows source | Backup source (ffprobe JSON) | Backup divergence |
|---|---|---|---|
| Format | `Text/Format`, `Codec/String` fallback (`MediaInfo.vb:185-191`) | `codec_name` | spelling |
| Language, Title | as audio | as audio | spelling |
| Default, Forced | yes-strings | `disposition` booleans | structure |
| Commentary, Hearing impaired | `Text/Commentary`, `HearingImpaired` | `disposition.comment`, `disposition.hearing_impaired` | structure |
| Size | `Text/StreamSize` | absent in most containers | absence |

## Out of scope for version 1

Enablement policy, preferred-language matching, demux mode, thumbnail-oriented reads, the
`GetSummary` prose block (replaced by the typed payload), and every write-adjacent fact of
the opening flow. The 36-parameter extraction is the checked inventory; any consumer
found later reading a parameter not listed here extends this document before the adapter
grows.

## Comparison protocol

The Windows comparison the exit criteria require runs both authorities over the shared
fixture corpus and records, per fact: equal, spelling-equal after canonicalization,
structure-equal after normalization, absent-on-one-side, or genuinely divergent with the
winning side named. The corpus starts from the synthetic fixtures already proven in
SLICE-002 runtime testing and grows per container family. No fixture carries personal
media, real paths, or unique identifiers, per the sensitive-data rules in `AGENTS.md`.
