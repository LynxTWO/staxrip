# Proposal: continuous integration for the fork

Status: approved by the owner on 2026-09-06 and implemented as fork commit `fb5a1efc` (`.github/workflows/gates.yml`, `Source/Tools/Gates/msbuild.cmd`, tracked calibration). Decisions taken: the AutoCrop Release gate runs the scratch-output variant; the restore verifies each `.nupkg` against its recorded SHA-256; the check is not required. The text below is the proposal as approved.

## What it would do

Run the four approved deterministic gates on every pull request to the fork and on every push to `master`, on a GitHub-hosted Windows runner, and publish the compact result as the check named `Gates`:

| Gate | Command | Local duration, warm compiler | Expected on a cold runner |
|---|---|---|---|
| working-tree-whitespace | `git diff --check` | under 1 s | seconds |
| autocrop-debug-x64 | MSBuild `Source\Tools\AutoCrop\AutoCrop.sln` Rebuild Debug x64 | 2.4 s | about 1 min including compiler start |
| main-solution-debug-x64 | MSBuild `Source\StaxRip.sln` Rebuild Debug x64 | 6.7 s | 3 to 6 min |
| main-solution-release-x64 | MSBuild `Source\StaxRip.sln` Rebuild Release x64 | 5.0 s | 3 to 6 min |

Local durations are from the runs recorded under `.anti-dark-code/runs/` on 2026-09-06. A runner starts cold, restores packages, and has no compiler server, so the cold column is an estimate to be replaced by the first measured run.

The gates would run through the same runner as locally, `adc.py gates --level 3 --allow-exec`, reading the same `gates.json`, so the commands CI executes are the commands the owner approved and nothing else. A `--changed-from` of the pull request base would let documentation-only changes finish at level 0.

## What it needs

- **Toolchain.** The `windows-latest` image carries Visual Studio Build Tools with MSBuild, the v143 C++ toolset, a Windows 10 SDK, and .NET Framework 4.8 reference assemblies. The gate commands name the Build Tools MSBuild path; CI would need the same path or a `vswhere` lookup recorded in the gate.
- **Packages.** `Source/packages.config` declares three packages. Restore from nuget.org with `-locked-mode` semantics, exactly as the isolated worktree did on 2026-08-11. Restore is the only network access the job performs.
- **VapourSynth headers.** FrameServer includes `VapourSynth4.h`, `VSHelper4.h`, and `VSScript4.h` from an ignored path under `Source/bin/Apps`. Stage them from the VapourSynth R79 source tag at commit `acabf605b2205b32d65859bb2736405719d2fafd` and verify the three SHA-256 values recorded in `Docs/Verification/Clean-Build-Dry-Run.md` before the build. A mismatch fails the job before any compile.
- **The AutoCrop Release gate.** `autocrop-release-x64` rewrites two tracked binaries. In CI that would show as a dirty tree after the build, and the gate runner already marks it stale locally (finding F-001). CI should run the proposed `autocrop-release-x64-scratch` variant, which redirects output with `-p:OutDir` to an ignored directory, or skip the Release AutoCrop build until the tracked-artifact policy is decided.

## What it would not do

- No release scripts. `Source/Build.ps1`, `Source/BuildAndPack.ps1`, and `Source/Release.ps1` stay out of CI.
- No packaging, no archive, no upload, no publication, no tag.
- No hardware encoding, no real media, no downloaded tools beyond the three NuGet packages and three headers.
- No secrets. The job needs the default read token only.
- No required-check enforcement at first. Run it as a non-required check for a few weeks, read the failures, then decide whether to require it.

## Why it is worth doing

- The four gates are the only executable verification this repository has, and today they run on one machine. A pull request from anyone else has no check at all.
- The verification plan holds V10 and V12 as selected on local evidence only. A recorded run per pull request turns that into shared evidence and lets the coverage ledger cite a run instead of a person.
- The anti-dark-code routing and shadow-evidence features need a CI record to have anything to measure. Without CI they stay not applicable here.

## Costs and limits

- Two heavy builds per pull request, roughly ten Windows-runner minutes per run at the cold estimates above. GitHub's free tier for public repositories covers this comfortably; private repositories bill Windows minutes at twice the Linux rate.
- The main solution build proves compilation, not behavior. There is still no test project; V21 stays deferred until one exists.
- A green check on the fork says nothing about the upstream repository's build, which uses different scripts and a maintainer-controlled Apps tree.

## Decision requested

1. Approve adding a non-required `Gates` workflow with the scope above, or decline.
2. If approved, decide the AutoCrop Release handling: the scratch-output variant, or skip until the artifact policy is settled.
3. Decide whether restore should pin a NuGet source hash or accept the locked-mode restore as sufficient.

Nothing in this document changes until those answers exist.
