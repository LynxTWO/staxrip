# Media Inspection Fact-Authority Map

Version: 0.1. Date: 2026-08-18. Base: `46b50945`. S-PORT-02 pass 02, read-only inventory.

This map records where the current Windows application gets media facts, which rules are
fused into that layer, and what a portable inspection adapter must reproduce, replace, or
explicitly refuse. It changes no behavior. Confidence labels follow the repository
convention; every claim cites its source.

## Fact authorities

There are exactly two, and they are not equals.

### MediaInfo.dll, the dominant authority

A packaged native library driven over P/Invoke with a handle API
(`Source/General/MediaInfo.vb:460-503`), loaded process-globally on first use from the
package path (`MediaInfo.vb:14-18`). Facts are read by string parameter name against a
stream kind and index (`MediaInfo.vb:246-308`). There are **220 call sites** across
`Source/` (count of `MediaInfo.Get` matches), spanning every encoder, the main form, and
support code. Verified.

### ffprobe.exe, the marginal authority

A packaged executable (`Source/General/Package.vb:104-115`, no custom path, no
auto-update) invoked as `-hide_banner -i "<path>"` with the output **regex-parsed from
the human-readable stderr banner**, matching
`Stream #<n>:<id>(<lang>): <type>: <data>` (`Source/General/Misc.vb:4593-4637`). It is
consumed only inside `Misc.vb` itself. It does not use ffprobe's machine-readable JSON
interface at all. Verified.

## The four load-bearing findings

### 1. The fact layer is not pure: user policy is fused into the getters

`AudioStreams` sets each stream's `Enabled` from live project state, `p.DemuxAudio` and
`p.PreferredAudio` (`MediaInfo.vb:137-151`). `Subtitles` does the same from
`p.SubtitleMode` and `p.PreferredSubtitles` (`MediaInfo.vb:194-206`). Reading facts about
a file therefore requires an open project and returns different answers for different
users. A portable inspection adapter must separate the fact, what streams exist, from the
policy, which streams this project enables, or it will rebuild the P-001 boundary problem
on the new side. Verified.

### 2. The FFprobe contract is a regex over prose, and its argv is an interpolated string

The banner format is human-oriented and version-fragile, and the invocation builds one
argument string with the path inside quotation marks (`Misc.vb:4629`), so a path
containing a quotation mark breaks the command. This is precisely the class P-003's argv
rules target. The portable adapter should not port this contract; ffprobe's JSON output
(`-print_format json -show_format -show_streams`) is the machine contract the current
code never adopted. The comparison corpus must therefore expect divergence from the
Windows regex parser and record which side is authoritative per fact. Verified.

### 3. The fact-import moment: where inspection becomes project state

`MainForm` copies facts into the project at one identifiable site: `p.SourceVideoHdrFormat`,
`p.SourceVideoFormat`, `p.SourceVideoBitDepth`, `p.SourceColorSpace`,
`p.SourceChromaSubsampling`, `p.SourceVideoSize`, and the pixel aspect ratio, read
directly from `MediaInfo.GetVideo` (`Source/Forms/MainForm.vb:2689-2725`). Encoders then
read both the imported state and the authority directly, for example the HDR mastering
facts feeding x265 command construction
(`Source/Encoding/x265Enc.vb:179-235,303`). So facts flow by two routes, import-then-read
and direct read, and the two can disagree after a file changes. The portable design gets
to fix this with a single typed snapshot; the map records that the current behavior is
double-sourced. Verified.

### 4. Silent rules live inside the fact reads

An adapter that returns raw facts will disagree with the current application unless it
reproduces, or explicitly supersedes, each of these:

- Frame-rate fallback ladder: rational numerator and denominator, then original rational,
  then decimal, then original decimal, then nominal, then a **default of 25**
  (`MediaInfo.vb:320-352`). Verified.
- Channel fallback ladder: `Channel(s)`, then `Channel(s)_Original`, then the larger side
  of a slash pair, then a **default of 2** (`MediaInfo.vb:358-374`). Verified.
- Identifier synthesis: a non-integer `StreamOrder` becomes index plus one; a non-integer
  audio `ID` becomes index plus two (`MediaInfo.vb:39-41,67-81`). Verified.
- Slash-pair splitting for bitrate and channels into primary and secondary values
  (`MediaInfo.vb:104-133`). Verified.
- Title enrichment from `Language_More` (`MediaInfo.vb:94-102`), format normalization
  `MPEG Video` to `MPEG` (`MediaInfo.vb:310-318`), and codec-list rewrites of MPEG audio
  layer names to MP2 and MP3 (`MediaInfo.vb:380-388`). Verified.
- Privacy redaction in the summary: `UniqueID` and `Encoded_Library_Settings` lines are
  stripped before display (`MediaInfo.vb:228-238`). This is an existing product privacy
  rule and must survive any port. Verified.

## Side effects of inspection as it exists today

Inspection itself writes no files. Its observable effects are: a process-global native
library load (`MediaInfo.vb:14-18`); two unbounded caches keyed by path plus
last-write-time ticks, evicted only by explicit clear (`MediaInfo.vb:414-438`,
`Misc.vb:4599,4626-4635`); a hidden child process per uncached ffprobe call through
`ProcessHelp.GetConsoleOutput` (`Source/General/Help.vb:195-201`); and file metadata
reads for the cache keys. Inferred as complete from reading those sites; no dynamic trace
was run.

The adjacent source-**opening** flow is explicitly out of this slice's scope and is not
read-only: it creates index files and temporary directories and engages the frame
server. The inspection adapter must not inherit any of it. P-001 and P-003 own that
boundary.

## Trust boundaries

- Native boundary: MediaInfo.dll is trusted native code parsing untrusted media bytes in
  process. A portable server-side equivalent inherits that exposure on the new platform;
  ffprobe as a child process keeps the parser out of process. This asymmetry is a design
  input, not a porting detail.
- Path boundary: file paths flow from user selection into a P/Invoke unicode call
  (`MediaInfo.vb:468-470`) and into an interpolated command string (`Misc.vb:4629`). The
  slice's exit criteria already require hostile-path fixtures; the second site is the
  reason.
- Output boundary: ffprobe stderr is untrusted text fed to a regex; MediaInfo returns
  untrusted strings converted with permissive helpers (`ToInt`, `ToDouble`) that default
  on failure rather than fail.

## What the adapter selection must decide, from this evidence

1. Authority: adopt ffprobe JSON as the sole portable authority, with MediaInfo retained
   only on Windows for comparison, or port a MediaInfo binding. The 220-site dominance
   means the comparison corpus must be built from MediaInfo-named facts either way.
2. The agreed-facts list: for each fact the bootstrap will expose, name the Windows
   source (parameter name and rule), the portable source (JSON field and rule), and the
   accepted divergence. The silent rules above are the seed of that list.
3. Fact and policy separation: the portable contract exposes existence facts only;
   enablement policy stays with the project layer that owns `p`.
4. Process contract: argv as a vector, never an interpolated string; bounded output;
   cancellation and no-child guarantees per the slice's exit criteria, under P-003.

## Unknowns

- Whether any consumer depends on the mutable-cache aliasing, where a changed file with a
  preserved timestamp returns stale facts. Unknown; no consumer was found that guards
  against it, and none was exhaustively sought.
- Whether the ffprobe banner regex silently drops streams for inputs whose banner wraps
  lines. Unknown; no fixture corpus exists yet.
- The exact fact set consumed by each encoder beyond the sampled x265 sites. The 220 call
  sites were counted, not individually classified. Classification belongs to the
  agreed-facts step, not this map.
