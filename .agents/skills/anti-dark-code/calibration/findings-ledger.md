# Anti-Dark-Code Findings Ledger

Keep settled work settled unless new evidence appears.

## Open

| ID | Finding | Risk | Evidence | Reproducer | Approval | Next step | Status |
|---|---|---|---|---|---|---|---|
| F-001 | The approved `autocrop-release-x64` gate rewrites two tracked binaries (`Source/Tools/AutoCrop/bin/x64/Release/AutoCrop.exe`, `.pdb`), so the runner marks its own run stale and the gate can never yield evidence in the main worktree. | medium | run `20260906T125405779522Z-a6af6d6150`: pass, pass, stale; `git status` showed the two tracked files modified; restored with `git checkout --`. | `gates --level 1 --allow-exec` on a clean tree | tracked-binary policy is approval-gated (`Docs/Review/Approval-Packets.md`, AutoCrop tracked Release artifacts) | owner approves the proposed `autocrop-release-x64-scratch` gate, which builds with `-p:OutDir` into `.anti-dark-code/runs/` scratch, or states the artifact contract | open |
| F-002 | The package update path discovers links by scraping HTML, downloads with `WebClient` under a spoofed browser user agent and Referer, extracts with 7-Zip, and checks only that `Package.Filename` exists; no hash, signature, size, or host check exists anywhere in `Source`. Two `DownloadURL` entries are plain `http://`. | high | `Source/General/ToolUpdate.vb:24-45,68-125`, `Source/Forms/DownloadForm.vb:6-18`; `grep` over `Source/**/*.vb`: `DownloadURL = "https://` 158, `"http://` 2 (`haali.su`, `avisynth.nl`), no `Authenticode`, `X509`, `SHA256`, or `checksum` use outside unrelated hashing helpers. | static trace only; no download executed | tool download and update paths are approval-gated (`AGENTS.md`) | owner decides on the packet in `Docs/Review/Approval-Packets.md` (Tool download integrity) | open |

## Fixed

| ID | Fix | Regression guard | Evidence | Closed |
|---|---|---|---|---|

## Refuted

| ID | Original claim | Refuting evidence | Limits | Closed |
|---|---|---|---|---|

## Deferred

| ID | Reason | Trigger to reopen | Owner | Status |
|---|---|---|---|---|
