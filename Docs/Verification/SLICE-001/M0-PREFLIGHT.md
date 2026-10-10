# SLICE-001 M0 Anti-Dark-Code Preflight

Date: 2026-08-15. Repository base: `c26e0fa6`. Pass: 00. Status: Complete.

This file is the time-bounded preflight snapshot. Its file and unknown counts describe the start of M0, not current repository state. Current milestone and unknown status is indexed in `README.md`.

## Repository shape

- **verified:** This is a mixed Windows desktop repository. The primary runtime units are the VB.NET .NET Framework 4.8 WinForms application, the C++17 native FrameServer, and the VB.NET AutoCrop support executable. Evidence: `Source/StaxRip.vbproj`, `Source/FrameServer/FrameServer.vcxproj`, and `Source/Tools/AutoCrop/AutoCrop.vbproj`.
- **verified:** Runtime work crosses local filesystem, Windows process, AviSynth, VapourSynth, Python, encoder, muxer, demuxer, probe, plugin, and GitHub update boundaries. Evidence: `README.md`, `Docs/Planning/ARCHITECTURE.md`, and `Docs/Architecture/Coverage-Ledger.md`.
- **verified:** Project, settings, profiles, templates, jobs, generated scripts, generated commands, temp files, and outputs are user-owned compatibility surfaces. Evidence: `AGENTS.md` and `Docs/Planning/SLICE-001.md`.
- **verified:** Release tooling with machine and publication reach exists in `Source/BuildAndPack.ps1` and `Source/Release.ps1`. Neither script was run.

## Existing artifacts and freshness

| Artifact | State | Freshness evidence |
|---|---|---|
| Root steering | Present | `AGENTS.md` matches the x64-only candidate and names the active approval gates |
| Architecture and Engineering plans | Present | Commit `c26e0fa6` records the approved current slice and Phase 6 pass |
| Decision Log | Present | D-001 through D-036 are Confirmed at commit `c26e0fa6` |
| Coverage Ledger | Present | Current through Phase 6 and carries the M0 unknowns and next checks |
| Unknowns Ledger | Present | Fourteen records: twelve Open and two Closed |
| Repo-local anti-dark-code calibration | Absent | No `.agents/skills/anti-dark-code/` or repo-local `calibration/` directory exists |

No code or planning commit follows `c26e0fa6`, so the approved planning artifacts are current for M0 entry.

## Deterministic probe

The inspected shared probe ran read-only:

```text
python C:\DEV\skills\anti-dark-code-dev\anti-dark-code\scripts\adc.py probe --repo .
PROFILE types=mixed source_files=26 tests=0 manifests=2 ...
```

The `mixed` classification agrees with repository evidence. The source and test counts are not repository coverage evidence because the probe's inspected source-extension set omits `.vb`. The probe therefore cannot support an absence claim about managed tests or total source size for this repository.

## Entry decision

Use full mode and run pass 02 next, scoped to `SLICE-001` M0. Steering, slice selection, and broad architecture exist, but the approved catalog, activation seam, full source-opening call graph, lifecycle ownership, failure seam, fixtures, and timing protocol do not.

Mini-mode does not apply. The repository has managed and native runtime units, multiple language families, external process boundaries, user-owned persisted state, and release tooling with production reach.

## Stop conditions

No preflight stop condition fired. Current source evidence does not contradict the approved slice. Protected release scripts remain closed. M0 stays read-only except for documentation and ignored disposable probes allowed by the Slice Brief.

## Next pass

Run pass 02 as a bounded architecture and trust-boundary map for the M0 questions. Do not edit production feature files.

## D-037 continuation check

On 2026-08-15, LynxTWO confirmed D-037 after pass 02 surfaced the authority, successful-job evidence, and form-position contradictions. At that continuation check, the repository base and product source remained `c26e0fa6`; only planning and M0 evidence files were uncommitted. No runtime, control-plane path, protected-area edit, telemetry path, locale contract, or sensitive-data finding invalidated the M0 map.

**verified at M0:** Those artifacts were fresh enough for bounded pass 11 reconciliation and pass 14 verification planning on `SLICE-001`. No preflight stop condition fired. D-037 supplied the required approval for the default-preserving `FormBase.RememberPosition` guard, while the other root approval gates remained unchanged. Later production evidence is recorded separately.
