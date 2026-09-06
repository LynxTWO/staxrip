# Architecture Pass Unknowns

These entries describe evidence gaps found while mapping commit `198223ea` on `master`.

### Release configuration maps the main project to Debug

- **Area or file:** `Source/StaxRip.sln:25-28`, `Source/Build.ps1:56`, `Source/BuildAndPack.ps1:56`, `Source/Release.ps1:57`
- **Concern:** The scripts request Release configurations, but the solution maps the main StaxRip project to Debug while mapping FrameServer to Release.
- **Why it matters:** Release archives may contain binaries built with unintended compiler constants, optimization, or debugging behavior.
- **Evidence found so far:** The solution mapping is verified and dates to commit `2d16c9adf` from 2021. Isolated builds confirmed that solution Release compiles StaxRip with Debug constants and full debug information while compiling FrameServer with `/O2`, `NDEBUG`, and the release CRT. Direct StaxRip Release omits the `Trace.TraceInformation` call used by `WriteDebugLog`; solution Release retains it. No matching earlier issue or pull request was found.
- **Confidence:** verified for the shipped artifact, as of 2026-08-24. Intent remains `unknown`.
- **Likely owner:** StaxRip maintainer
- **Next best check:** Report the measurement upstream and ask whether an unoptimised release is intended. Do not edit either the mapping or the project until that is answered.
- **Risk level:** high
- **Status:** open
- **Notes 2026-08-24, measured, and the original entry understated this.** The finding is not only the solution mapping. `Source/StaxRip.vbproj` has a `Release|x64` property group that sets warning options and `PlatformTarget` but no `Optimize`, `DebugType` or `DefineTrace`. (An earlier draft of this note said it contained "only `OutputPath`"; that was wrong, though the evaluated values below are not.) MSBuild evaluates `Optimize`, `DefineDebug`, `DefineTrace` and `DebugType` all to empty for that configuration, so `Optimize` falls back to false and **a direct Release build is unoptimised too**. The solution mapping and the incomplete property group are two independent causes of the same outcome.

  Measured with `DebuggableAttribute` read from each assembly, one process per file:

  | binary | `DebuggingModes` | JIT optimizer disabled | size |
  |---|---|---|---|
  | direct `Debug\|x64` | Default, IgnoreSymbolStoreSequencePoints, EnableEditAndContinue, DisableOptimizations | true | 3,861,504 |
  | direct `Release\|x64` | identical to Debug | true | 3,860,992 |
  | **shipped v2.52.5 x64** | identical to Debug | **true** | 3,840,512 |
  | `Release\|x64` plus `-p:Optimize=true` | IgnoreSymbolStoreSequencePoints | false | 3,640,832 |

  So **the officially released StaxRip binary runs with the JIT optimizer disabled.** The
  release archive was hash-matched against GitHub's published digest by an earlier pass, so
  this is the artifact users actually run. Supplying `Optimize=true` produces a properly
  optimised assembly about 220 KB, or 5.4 percent, smaller.

  **What is NOT established:** the user-visible cost. StaxRip spends most wall-clock time in
  external encoders, which are unaffected. An unoptimised managed layer would matter for UI
  responsiveness, preview frame handling, and AutoCrop rather than for encode throughput, and
  none of that was measured. Do not repeat this finding as a performance claim.

  **FIXED on the fork, 2026-08-24**, on the maintainer's instruction, as commit `b65df804` on
  branch `agent/release-build-configuration` (based on `origin/master`, pushed, no PR). Five
  lines: the solution mapping now points `Release|x64` at `Release|x64`, and the project's
  `Release|x64` gains `Optimize=true`, `DefineTrace=true`, and `DebugType=pdbonly`. After the
  change, Release reports `IgnoreSymbolStoreSequencePoints` only and the JIT optimizer is
  enabled; Debug is unchanged; both configurations build with zero warnings.

  **`DefineTrace` turned out to be load bearing, which is the part worth remembering.**
  `GlobalClass.WriteDebugLog` calls `Trace.TraceInformation` behind the user-facing
  `s.WriteDebugLog` setting. Scanning each assembly for the `TraceInformation` member
  reference found it present in the shipped binary and in the fixed Release build, and
  **absent from the old unfixed direct Release build**. So anyone who built the project
  directly in Release silently lost that setting, and a fix that only set `Optimize` would
  have shipped that regression to everyone. `DebugType=pdbonly` likewise preserves the
  `StaxRip.pdb` the release archive ships.

  Reported upstream on 2026-08-26 as issue #2001, at the fork maintainer's direction, after
  the fix had been carried on the fork first. The issue asks whether the configuration is
  deliberate and offers the tested five-line fix as a PR. The intent question stays open
  until the upstream maintainer answers.

### Clean-checkout build and shipping graph is incomplete

- **Area or file:** `Source/StaxRip.sln`, `Source/Tools/AutoCrop/AutoCrop.sln`, `Source/FrameServer/FrameServer.vcxproj`, `.gitignore`, `Source/*.ps1`
- **Concern:** The main build omits the separate AutoCrop solution, and required SDK or runtime inputs are expected under ignored `Source/bin` paths.
- **Why it matters:** A contributor may be unable to reproduce the application or the shipped archive from a clean clone.
- **Evidence found so far:** The two solution files, project output paths, FrameServer include paths, ignored bin directories, and all three build scripts were inspected. The first no-restore build failed on the expected missing inputs. An isolated worktree restored the three declared NuGet packages, staged three headers from the official VapourSynth R79 source tag, and successfully built both x64 solution configurations plus both x64 AutoCrop configurations. The exact official v2.52.5 portable tree was later used for runtime and packaging-equivalent validation, but it was not reconstructed from tracked source.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Obtain maintainer review of the contributor guide and establish the authoritative process and provenance that prepares the complete ignored Apps tree from source inputs.
- **Risk level:** medium
- **Status:** open
- **Notes:** Dependency preparation, x64 source compilation, representative portable runtime, and scratch packaging closure are verified separately. The unresolved gap is reproducing every bundled binary from authoritative inputs, not whether the tested portable candidate can run or archive.

### Unsupported x86 retirement boundary

- **Area or file:** `Source/StaxRip.sln`, `Source/StaxRip.vbproj`, `Source/FrameServer/FrameServer.vcxproj`, `Source/Tools/AutoCrop/AutoCrop.sln`, `Source/Tools/AutoCrop/AutoCrop.vbproj`, `Source/General/GlobalClass.vb`, `Source/General/Package.vb`, `Source/General/StaxRipUpdate.vb`, `Source/General/ToolUpdate.vb`, `Source/Forms/MainForm.vb`
- **Concern:** StaxRip now supports x64 builds only, but coordinated x86 application, Win32 FrameServer, x86 AutoCrop, package-selection, update-filtering, and display branches remain in source and project configuration.
- **Why it matters:** Partial removal could leave an unbuildable solution mapping, an architecture-mismatched in-process FrameServer, stale AutoCrop output paths, or inconsistent executable and update selection.
- **Evidence found so far:** A tracked configuration scan found the coordinated x86 or Win32 blocks in exactly five solution and project files. All three checked-in build or release scripts explicitly select x64. The updater accepts only x64 archives, and the reviewed release inventory exposed no x86 or 32-bit asset. Phase 1 commit `e10d99cf` removes the five configurations and corrects direct-project defaults. Phase 2 commit `ed32aae0` removes the internal runtime branches while preserving `Package.Filename32` as an obsolete compatibility property. The stacked candidate passed six direct x64 builds, two integrated solution builds, IL and compatibility probes, representative GUI/runtime cases, a 10,000-session soak, and packaging-equivalent closure.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Obtain maintainer review of draft pull request #1992, then dependent draft pull request #1994. Keep the public compatibility property unless the maintainer explicitly approves a breaking removal.
- **Risk level:** medium
- **Status:** open
- **Notes:** The technical retirement boundary is resolved and recorded in `Docs/Verification/X86-Phase1.md` and `X86-Phase2.md`; upstream merge approval is still pending. Non-configuration `Win32Proj`, bootstrapper text, and the Windows DLL name `avifil32.dll` are intentionally not treated as supported 32-bit build paths.

### AutoCrop tracked Release artifact staging policy

- **Area or file:** `Source/Tools/AutoCrop/AutoCrop.vbproj:42-75`, `Source/Tools/AutoCrop/bin/x64/Release`, `Source/Build.ps1`, `Source/BuildAndPack.ps1`, `Source/Release.ps1`
- **Concern:** Release x64 writes to a tracked binary directory, but the repository does not show how those files are staged into the ignored portable Apps tree or a release archive.
- **Why it matters:** Contributors can accidentally commit toolchain-generated binary changes, while redirecting or removing the tracked output could break an external maintainer workflow.
- **Evidence found so far:** A Release x64 rebuild modified the tracked executable and PDB. Git history shows that they were introduced with an AutoCrop source fix in 2024 and updated with five later AutoCrop feature commits. In a negative search, 275 tracked text files were candidates; three matching build-path occurrences were found in one file, `AutoCrop.vbproj`. Binary blobs, untracked files, and ignored trees were excluded. No tracked script invokes `AutoCrop.sln` or references its Release directory.
- **Confidence:** unknown
- **Likely owner:** StaxRip maintainer
- **Next best check:** Confirm whether the tracked binary pair is the canonical AutoCrop artifact and identify the exact staging command or external process that copies it into `Source/bin/Apps/Support/AutoCrop`.
- **Risk level:** medium
- **Status:** open
- **Notes:** The official v2.52.5 archive was downloaded, hash-verified, opened, and used as the portable runtime base. It contains the packaged AutoCrop host, but the tracked source-to-AutoCrop-binary staging command is still absent. Keep the current project and binary policy unchanged without owner confirmation.

### Trust policy for serialized project and settings files

- **Area or file:** `Source/General/General.vb:294-400`, `Source/Forms/MainForm.vb:1739-1787`, `Source/General/JobManager.vb`, `Source/General/GlobalClass.vb`, `Source/UI/Theme.vb`
- **Concern:** User-selectable `.srip` projects and several local state files are read through BinaryFormatter-backed paths, but the repository does not state which files must be trusted.
- **Why it matters:** Malformed or hostile serialized data could affect object construction, command-bearing project state, availability, or user data.
- **Evidence found so far:** Five VB files contain `BinaryFormatter`; 25 formatter or deserialize occurrences were found. `.srip` input is accepted through file dialogs, drag/drop, and command-line paths. A binder line in `SafeSerialization.GetObjectInstance` is commented out.
- **Confidence:** unknown
- **Likely owner:** StaxRip maintainer
- **Next best check:** Establish the supported trust model and compatibility requirements, then create non-executing parser fixtures and an approved migration plan before changing the format.
- **Risk level:** high
- **Status:** open
- **Notes:** This entry does not claim a demonstrated exploit. No serialized input was executed in this pass.

### Tool download and executable integrity contract

- **Area or file:** `Source/General/ToolUpdate.vb`, `Source/General/Package.vb`, `Source/Forms/DownloadForm.vb`, `Source/Forms/AppsForm.vb`
- **Concern:** The inspected update path downloads or accepts archives, extracts them, checks for an expected filename, and copies content into the runtime Apps tree; an archive hash or signature verification step was not found in those files.
- **Why it matters:** Replaced upstream assets, compromised download locations, or unexpected archive content could become executable application dependencies.
- **Evidence found so far:** Four candidate files were content-scanned. A known-positive download/extract query produced 181 occurrences. A targeted SHA, Authenticode, certificate, signature, and checksum query produced zero occurrences in those candidates.
- **Confidence:** inferred
- **Likely owner:** StaxRip maintainer
- **Next best check:** Trace one supported package update end to end, including URL selection, redirects, archive layout, overwrite scope, and any integrity control outside these four files.
- **Risk level:** high
- **Status:** open
- **Notes:** The negative scan covers only the named files and patterns. It does not prove that every package lacks external provenance controls.
- **Notes 2026-09-06, traced.** The end-to-end path is: page fetch, first matching `href`, relative-link resolution against the page host, `WebClient` download to the Desktop with a browser user agent and Referer, 7-Zip extraction, presence check for `Package.Filename`, user-confirmed delete of the current files to the Recycle Bin, user-confirmed copy. Deterministic counts: 160 `DownloadURL` entries, 158 HTTPS, 2 plain HTTP (`Package.vb:87`, `Package.vb:1204`); no hash, signature, host, or size check anywhere in `Source`. The smallest safe edits are written up as the "Tool download integrity" packet in `Docs/Review/Approval-Packets.md` and as finding F-002 in the calibration findings ledger. Status stays open pending the owner's decision on that packet.

### Cross-process job and shared-state coordination

- **Area or file:** `Source/General/JobManager.vb`, `Source/General/GlobalClass.vb:453-805`, `Source/General/ProcController.vb`
- **Concern:** Jobs and processing can span multiple StaxRip processes and parallel child actions, while jobs, logs, temp files, settings, and outputs share filesystem state.
- **Why it matters:** Collisions or stale ownership could cancel the wrong work, corrupt state, publish the wrong output, or delete data still in use.
- **Evidence found so far:** The settings file uses a named mutex. `Jobs.dat` uses exclusive file access and retry loops. Job processing can relaunch StaxRip and uses `Parallel.Invoke`; temp deletion checks visible jobs and a `_temp` suffix.
- **Confidence:** unknown
- **Likely owner:** StaxRip maintainer
- **Next best check:** Map process identity, job leases, output publication, cancellation, crash recovery, and same-resource denial for two concurrent StaxRip instances.
- **Risk level:** high
- **Status:** open
- **Notes:** No concurrency scenario was executed.

### PowerShell auto-load ownership and provenance

- **Area or file:** `Source/General/GlobalClass.vb:355-362`, `Source/General/PowerShell.vb:10-54`, settings folder creation in `Source/General/General.vb`
- **Concern:** PowerShell from packaged and user settings Auto Load folders executes during startup with process execution policy set to Unrestricted.
- **Why it matters:** Unexpected modification or inheritance of either script folder changes application behavior with the current user's authority.
- **Evidence found so far:** Startup calls `LoadPowerShellScripts`; it enumerates both folders and executes every `.ps1`. The runspace sets Unrestricted policy for the process. The settings directory can be user-selected.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer and local user
- **Next best check:** Document intended folder ownership, distribution provenance, ordering, failure behavior, and whether startup should show or record which scripts ran.
- **Risk level:** high
- **Status:** open
- **Notes:** The feature is an explicit extension mechanism. The unknown is its trust and audit contract.

### Raw log sharing and redaction boundary

- **Area or file:** `Source/General/LogBuilder.vb`, `Source/General/GlobalClass.vb:1185`, `Source/Forms/LogForm.vb:50`, `.github/ISSUE_TEMPLATE/01-bug_report.yml`
- **Concern:** Normal logs contain paths, machine information, scripts, media metadata, and complete command lines. Obfuscation is confirmed for one export action, while issue guidance asks users to attach logs.
- **Why it matters:** Users may publish personal paths, system details, or sensitive command content unintentionally.
- **Evidence found so far:** A 184-file source and issue-form scan found 177 central log calls in 23 files. `LogBuilder.Save` and archived history write raw text. `LogForm` offers raw and obfuscated exports. A synthetic replay verified that obfuscation removes the current source directory and base name but retains an unrelated target path and machine detail. The issue template identifies the raw job log without a review warning.
- **Confidence:** verified
- **Likely owner:** StaxRip maintainer
- **Next best check:** Draft pull request #1991 updates the issue guidance. Use synthetic runtime workflows to classify external-tool output that survives the current obfuscation.
- **Risk level:** medium
- **Status:** resolved
- **Notes:** The source-path redaction boundary is mapped in `Docs/Security/Logging-Audit.md`, and commit `62ba4d86` proposes safer public guidance. External-tool output remains a separate open unknown. Do not place real user logs in test fixtures.
