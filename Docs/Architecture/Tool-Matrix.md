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
| Version probe | `mediainfo --Version`, and the `creatingLibrary.version` field inside every JSON payload, which is the value gates pin against because it travels with the data | verified as contract; field presence pending first captured fixture |
| Windows anchor | The application bundles MediaInfoLib 26.05 as `MediaInfo.dll` under `Apps\Support\MediaInfo.NET\` | verified, file version read from the v2.52.5 portable tree |
| Windows CLI | Not bundled today. The comparison harness needs the CLI on Windows for same-authority-both-sides comparison; acquisition from MediaArea requires maintainer approval | verified absent; acquisition pending approval |
| Linux, distro path | Ubuntu 24.04 offers `mediainfo` 24.01.1 with `libmediainfo0v5` 24.01 from `noble/universe` | verified from local package metadata, not installed |
| Linux, upstream path | MediaArea publishes per-distro packages and static builds current with 26.x | inferred from the upstream download matrix the maintainer cited; exact versions unverified |
| Version skew | Bundled Windows 26.05 versus Ubuntu distro 24.01. Two resolutions exist: pin a range spanning both and verify JSON schema stability across it with fixtures from each end, or require the upstream build on Linux for parity. The range option is recommended first because it avoids adding a download path before fixtures exist; the parity option activates if cross-range fixtures diverge on any agreed fact | verified skew; resolution pending fixtures |
| Proposed pinned range | `creatingLibrary.version` within `[24.01, 26.05]`, floor and ceiling both inclusive, ceiling raised only with the Windows bundle | candidate until cross-range fixtures pass |
| Resolver policy | Explicit configured absolute path only, no search-path resolution, existence and regular-file and non-reparse checks before first use, version probe before first fact, capability reported `unavailable` on any resolver failure | verified as contract, D-045 bounds |
| Privacy obligations | JSON output serializes display fields including `UniqueID`-class identifiers and `Encoded_Library_Settings`; the adapter strips them behind a self-tested guard before any payload leaves | verified obligation, D-045 |
| Execution bounds | Bounded captured output, hard timeout, kill-on-cancel with process-group termination, no writes, no network | verified as contract, D-045 |
| Verification pending | Capture `--Version` and one `--Output=JSON` golden fixture per range end on a real host; verify `creatingLibrary.version` presence; verify agreed-fact field presence for the exposed set | open; blocked on tool acquisition approval |

## ffprobe, named backup (D-045)

Recorded, not implemented. Activation triggers and the swappable-authority requirement
live in D-045; the backup field mapping is already agreed in
`Media-Inspection-Agreed-Facts.md`. A full row is written when a trigger fires or the
ffmpeg family arrives with the encoding slices.

## Everything else

The fixed tool catalog the bootstrap reports remains `unverified` by design
(`SLICE-002-LINUX-ENGINE-BOOTSTRAP.md` section 3). No other tool gains a row until a
slice needs it and a decision names it.
