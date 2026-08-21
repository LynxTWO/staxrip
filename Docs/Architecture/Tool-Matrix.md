# Portable Tool Matrix

Version: 0.1. Date: 2026-08-18. Base: `d7e6412e`. Owned by P-004; first row per D-045.

One row per external tool the portable side is approved to know about. A row is not
permission to install, download, or execute anything. Confidence labels follow the
repository convention, and a `configured` claim stays configured until a named gate runs.

## MediaInfo CLI, primary inspection authority (D-045)

| Property | Value | Confidence |
|---|---|---|
| Tool | `mediainfo`, the MediaArea command-line client over MediaInfoLib | verified, upstream identity |
| License | BSD-2-Clause | verified, upstream |
| Role | Sole implemented fact authority for S-PORT-02 read-only inspection | verified, D-045 |
| Invocation contract | `mediainfo --Output=JSON <path>`, path as one argv element, never interpolated | verified as contract, D-045 bounds |
| Version probe | `mediainfo --Version`, and the `creatingLibrary.version` field inside every JSON payload, which is the value gates pin against because it travels with the data | verified by execution at both range ends over the fixture corpus |
| Windows anchor | The application bundles MediaInfoLib 26.05 as `MediaInfo.dll` under `Apps\Support\MediaInfo.NET\` | verified, file version read from the v2.52.5 portable tree |
| Windows CLI | Acquired 2026-08-19 under maintainer approval: MediaInfo CLI 26.05 from MediaArea, archive SHA-256 `f7f80620ce6d14f4995f0de6f98e3ef18ad29496db01899571152ee3311229f9`, executable SHA-256 `30f2828a45a1895b033c3cd7784581033327e7b393033c55f4a03bb15cab0d89`, kept in the ignored tools tree, version probe passed | verified |
| Linux, distro path | Ubuntu 24.04 `mediainfo` 24.01.1 acquired by package download and user-prefix extraction, no system install, no root; binary SHA-256 `a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6`; version probe passed | verified by execution |
| Linux, upstream path | MediaArea publishes per-distro packages and static builds current with 26.x | inferred from the upstream download matrix the maintainer cited; exact versions unverified |
| Version skew | Resolved by ratification 2026-08-19: range-first. Cross-range fixtures over the four-file corpus show the exposed fact set is schema-stable across `[24.01, 26.05]`; the only field-set difference anywhere is 26.05 adding `File_Created_Date` and `File_Created_Date_Local`, which are filesystem metadata joining the privacy strip list, not exposed facts | verified over the corpus |
| Proposed pinned range | `creatingLibrary.version` within `[24.01, 26.05]`, floor and ceiling both inclusive, ceiling raised only with the Windows bundle | verified for the exposed set over the fixture corpus; widens only with new fixtures |
| Resolver policy | Explicit configured absolute path only, no search-path resolution, existence and regular-file and non-reparse checks before first use, capability reported `unavailable` on any resolver failure. As delivered, the version range is enforced on every probed document through `creatingLibrary.version` rather than by a startup `--Version` invocation; the deviation and its reasons are recorded in the unit 4b-2 part 2 record | verified as delivered; deviation recorded |
| Privacy obligations | JSON output serializes display fields including `UniqueID`-class identifiers and `Encoded_Library_Settings`; the adapter strips them behind a self-tested guard before any payload leaves | verified obligation, D-045 |
| Execution bounds | Bounded captured output, hard timeout, kill-on-cancel with process-group termination, no writes, no network | verified as contract, D-045 |
| Harness integrity | Any gate that executes an acquired tool copy verifies the binary against the SHA-256 recorded here and in the fixture manifest before running it, the same discipline the restore gate applies to archives. The product resolver deliberately does not hash-pin, because users supply their own builds; it pins the version range through the probe. The two policies are different on purpose and this row is the record of why | discipline, binding on the port-inspection gate |
| Verification pending | Done 2026-08-19: eight goldens captured, four fixtures at each range end, committed under `eng/fixtures/media-inspection/` with a provenance manifest. Done 2026-08-21: non-WSL capture on the independent bare-metal Ubuntu host, fact-identical to the committed floor goldens with only stripped file-date metadata differing (`Docs/Verification/S-PORT-02/t540p-golden-capture.md`), and the configured pipeline verified on Linux with the real floor tool (`linux-configured-run.md`), including the reparse walk on genuine symlinks and the loader-path note for user-prefix extractions. Remaining open: re-verify when either range end moves | verified on two independent Linux hosts |
| Windows comparison | Recorded 2026-08-20 over the four committed fixtures: the installed product library was v26.05, the exact pinned ceiling, so the comparison ran at matched versions; 85 facts equal, 79 absent on both sides, zero one-sided absences, and 7 divergences, all structure class (text-API milliseconds versus JSON decimal seconds on `Duration` and `Video_Delay`; text-API fused profile@level), never a value disagreement. Full record in `Docs/Verification/S-PORT-02/comparison-record.md` | verified by execution, recorder committed |

## ffprobe, named backup (D-045)

Recorded, not implemented. Activation triggers and the swappable-authority requirement
live in D-045; the backup field mapping is already agreed in
`Media-Inspection-Agreed-Facts.md`. A full row is written when a trigger fires or the
ffmpeg family arrives with the encoding slices.

## Everything else

The fixed tool catalog the bootstrap reports remains `unverified` by design
(`SLICE-002-LINUX-ENGINE-BOOTSTRAP.md` section 3). No other tool gains a row until a
slice needs it and a decision names it.
