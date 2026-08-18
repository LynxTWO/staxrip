# Repository working guidance

## Purpose

This file defines how AI-assisted work happens in this repository. Keep changes explainable, ground reviews in repository evidence, and stop for approval before risky work.

## Product promises

- Preserve StaxRip's role as a configurable Windows video and audio processing front end.
- Preserve the current Windows x64 application while cross-platform behavior is added behind explicit contracts and platform adapters.
- Do not silently change generated command lines, project or settings compatibility, template behavior, temp-file handling, or bundled-tool contracts.
- Treat user-selected paths, jobs, profiles, scripts, and encoder settings as user-owned data.
- Keep documentation honest about supported versions, tools, and operating systems.

## What dark code means here

Dark code is behavior whose purpose, owner, side effects, failure modes, or verification path cannot be determined from the repository. In StaxRip this includes command construction, external process execution, generated AviSynth or VapourSynth scripts, native frame-server behavior, settings and project persistence, job concurrency, file cleanup, tool download or update paths, and release packaging that lacks a clear contract.

Legacy code is not defective merely because it is old. Record an unknown when intent is unclear. Do not replace uncertainty with a guessed explanation.

## Repository profile

- Type: mixed Windows desktop application and supporting tools.
- Main application: VB.NET Windows Forms targeting .NET Framework 4.8 in `Source/StaxRip.vbproj`.
- Native component: C++17 `Source/FrameServer/FrameServer.vcxproj` using the Visual Studio v143 toolset and Windows SDK.
- Supporting executable: VB.NET `Source/Tools/AutoCrop/AutoCrop.vbproj`.
- Supported application build platform: x64 only. The project and solution files expose x64 configurations only. Do not require x86 as a contributor verification gate. Reintroducing x86 or Win32 configurations requires separate approval and verification.
- Additive portability work: C# .NET 10 projects under root-level `CrossPlatform/`. Linux x64 is the first runtime target. macOS is deferred until Linux contracts stabilize and a real macOS runner exists. Keep this subtree outside `Source/` because the legacy build scripts recursively scan selected files below `Source/`.
- Portability client shape: a loopback-only engine host and first-party web shell come first. The current WinForms client remains supported. A native cross-platform client is a later, separate slice.
- Runtime model: a portable GUI generates scripts and command lines and coordinates external encoders, muxers, frame servers, and support tools.
- Documentation: `README.md`, `Docs/`, and the changelogs.
- Ownership: no `CODEOWNERS` file is currently present. Contributor guidance lives in `Docs/Contribution/README.md`. Treat code ownership as unknown unless Git history or maintainer review establishes it.

## Working modes

1. Read-only inventory: inspect and report. Do not change files or execute repository code.
2. Docs and comments: change documentation, maps, manifests, or ordinary comments only. Do not alter behavior, dependencies, project configuration, or broad formatting.
3. Behavior-preserving cleanup: proceed only after the touched path is mapped and a deterministic verification method exists. Do not mix cleanup with feature work.
4. Feature, security, or release work: proceed only when explicitly requested and after relevant unknowns, tests, approval gates, and rollback notes are in place.

Treat comments that affect compilation, project metadata, resources, encodings, scripts, or generated artifacts as code.

## Evidence, coverage, and unknowns

- Use only `verified`, `inferred`, or `unknown` for confidence claims.
- Cite the file, line, command, test, or artifact behind each important claim.
- Do not claim whole-repository coverage from one clean build or one exercised encoder path.
- Keep risk-ranked coverage in `Docs/Architecture/Coverage-Ledger.md` when broad review begins.
- Record unresolved questions under `Docs/Unknowns/` using a consistent evidence, risk, owner, and next-check format.
- Keep generated, vendored, mirrored, binary, and bundled-tool content out of broad comment or formatting passes.

## Deterministic verification

- Use local enumeration, parsers, diffs, compilers, and focused tests for facts they can settle exactly.
- Inspect a script before running it. Do not run `Source/BuildAndPack.ps1` or `Source/Release.ps1` without explicit approval.
- Do not install or update dependencies automatically because a suggested verification command needs them.
- Run the cheapest relevant check first. Keep successful output compact and preserve a bounded failure packet for failures.
- Record the exact configuration and platform for build evidence. A Debug x64 build does not verify Release x64.
- Keep current Windows and additive cross-platform build evidence separate. A cross-platform build does not verify the legacy application, and a WSL run does not verify an independent Linux or macOS host.
- Do not treat executable presence as tool compatibility. A support claim needs an approved version, source, invocation, fixture, and failure-path result.
- New cross-platform process plans use executable identity and separate argv. Do not make a shell command string the portable source of truth.
- A verifier that launches a process must register ownership before readiness, cap output while reading it, bind cleanup to revalidated PID, start time, executable, and exact arguments, and prove exit plus task-state removal before recording success or retention fields. Final evidence must reject stale task roots.
- An evidence producer must invalidate the prior pass pair under the shared writer lease before its first protected mutation. If child producers cannot borrow that lease, keep an atomic workflow marker for the full mutable window and make the final auditor reject it at every closeout.
- Treat a registry content hash, a raw package archive digest, a package signature, and extracted-file identity as separate claims. Bind every accepted archive payload to a safe extracted path, length, and digest, and recompute that binding independently before publication.
- On Windows, enumerate task and marker names case-insensitively, reject case drift or collisions, and then require the one canonical entry to be safe and empty.
- Separate branch activation evidence from outcome evidence for retries, fallbacks, concurrency, and external-tool invocation.

## Approval-gated areas

Document the finding and smallest proposed edit, then obtain explicit human approval before changing:

- build, packaging, release, or distribution behavior, including `Source/Build.ps1`, `Source/BuildAndPack.ps1`, `Source/Release.ps1`, and solution configuration mappings;
- deletion, temp cleanup, overwrite, recovery, output publication, or no-clobber behavior;
- project, job, template, profile, or application-settings persistence and compatibility;
- process coordination, cancellation, retries, shared resources, or concurrency;
- tool download, update, provenance, executable selection, or command-line escaping;
- native frame-server ABI, registration, inter-process, AviSynth, or VapourSynth boundaries;
- privileged CI or automation if it is added later;
- auth, secrets, cryptography, billing, regulated data, migrations, or repair tooling if any enters scope;
- any listener beyond loopback, remote control, state-changing HTTP endpoint, upload, arbitrary plugin execution, or browser session weakening;

## Sensitive data

Do not copy passwords, tokens, keys, connection strings, private certificates, personal data, or full request and response bodies into source, tests, documentation, screenshots, prompts, commit messages, or failure packets.

StaxRip logs and issue reports can contain user names, source and destination paths, system details, media metadata, scripts, and complete command lines. Use synthetic paths and redact unrelated machine or media details in fixtures and reports.

## Change requirements

For each non-trivial change:

- state what changed and why;
- name the affected runtime unit and external-tool boundary;
- add or identify verification tied to intended behavior;
- note security, privacy, logging, failure-handling, and rollback impact when relevant;
- update documentation when a command contract, persisted format, workflow, or supported tool changes;
- keep commits and pull requests small and single-purpose.

Tests changed in the same patch need added scrutiny. Explain removed assertions, broader mocks, skipped cases, timeout increases, snapshot updates, or reduced coverage.

## Writing rules

Use short sentences, plain words, active voice, ASCII punctuation, and direct names for the subject, risk, and safeguard. Avoid hype, boilerplate, vague openings, apology filler, and explanations that assert intent without evidence.

## Pull request close-out

End each pull request with a short record of:

- the behavior or documentation changed;
- checks run and the untested boundary;
- unknowns found;
- security, privacy, and logging impact;
- documentation touched;
- approval gates crossed or still pending;
- follow-up work.

## High-risk paths

- External process and command control: `Source/General/Proc.vb`, `Source/General/ProcController.vb`, `Source/General/Package.vb`, and encoder, muxer, demuxer, and frame-server integrations.
- Persistence and job execution: project, settings, template, and job code under `Source/General/` and `Source/Forms/`.
- Native boundary: `Source/FrameServer/`.
- Release boundary: the solution and PowerShell build or packaging scripts under `Source/`.
- Portability boundary: `CrossPlatform/`, its local HTTP security policy, platform adapters, future portable persistence, and any cross-platform artifact assembly.
- Documentation and user-visible contracts: `README.md`, `Docs/`, and both changelogs.

Keep this file as the canonical steering document unless the repository later adopts tool-specific instruction files.
