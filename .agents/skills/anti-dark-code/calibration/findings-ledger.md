# Anti-Dark-Code Findings Ledger

Keep settled work settled unless new evidence appears.

## Open

| ID | Finding | Risk | Evidence | Reproducer | Approval | Next step | Status |
|---|---|---|---|---|---|---|---|

## Fixed

| ID | Fix | Regression guard | Evidence | Closed |
|---|---|---|---|---|
| F-001 | `autocrop-release-x64-scratch` builds Release x64 with `-p:OutDir` into `.anti-dark-code/runs/`; the in-place `autocrop-release-x64` is disabled. Tracked-binary policy unchanged. | the gate runner's staleness check: any gate that rewrites tracked files is marked stale, so a regression shows in the run record | runs `20260906T160120926988Z-44749924e8` and `20260906T160632590565Z-a40cbaf1a5`: 3 passed, tree clean | 2026-09-06 |
| F-002 | `DownloadIntegrity.vb` plus `ToolUpdate.vb` edits: HTTPS required for page and link, cross-host confirmation with Cancel default, SHA-256 of the archive logged and shown. Fork commit `a512ea89` on `agent/tool-download-integrity`. | `Source/Tests/ToolUpdate/ToolUpdateTests.vbproj`, 17 cases, exit code is the failure count | harness 17/17; Debug and Release x64 rebuilds; packet in `Docs/Review/Approval-Packets.md` | 2026-09-06 (fixed on the fork branch; upstream contract still open) |

## Refuted

| ID | Original claim | Refuting evidence | Limits | Closed |
|---|---|---|---|---|

## Deferred

| ID | Reason | Trigger to reopen | Owner | Status |
|---|---|---|---|---|
