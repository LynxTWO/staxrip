# SLICE-002 Linux Engine Bootstrap Verification

Version: 0.3 Pre-freeze. Date: 2026-08-16. Base: `940eaba1`.

The additive .NET 10 bootstrap has pre-freeze local passes for its Windows x64 build, self-contained Linux x64 publish, local WSL Ubuntu sandbox, hardened Windows HTTP gate, and hardened installed Edge boundary. A later independent final-evidence review returned NO-GO. Its source remediations and focused probes are present, but the full committed-source rerun, `port-evidence` correspondence audit, bounded Restore failure challenge, and independent re-review are still pending. This is local engineering evidence. It is not a Linux product release, an independent-host result, a media workflow, or a current Windows application regression claim.

The exact acceptance table is the frozen schema consumed by the final audit. Its status cells are target acceptance values, not committed-source results. No row, including LNX-020, becomes a final claim until the committed-source rerun and `port-evidence` pass.

## Acceptance record

| ID | Status | Evidence | Host | Artifact | Unknown | Impact | Approval | Rollback |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LNX-001 | passed | port-static+port-restore+port-build | windows-x64 | CrossPlatform/artifacts/evidence/verify-summary.json | none | additive-only | D-041+D-044 | bounded-revert |
| LNX-002 | passed | port-contract-debug+port-contract-release+port-contract-failure | windows-x64 | CrossPlatform/artifacts/evidence/verify-summary.json | none | additive-only | D-041 | bounded-revert |
| LNX-003 | passed | port-static | repository | CrossPlatform/artifacts/evidence/static-gate.json | none | Source-unchanged | D-041 | bounded-revert |
| LNX-004 | passed | port-restore+port-publish-linux+port-artifact-manifest | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv | none | additive-only | D-041+D-044 | bounded-revert |
| LNX-005 | passed | port-linux-sandbox | wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-038+D-041 | bounded-revert |
| LNX-006 | passed | port-http-windows+port-linux-sandbox | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-040+D-041 | bounded-revert |
| LNX-007 | passed | port-contract-release+port-linux-sandbox | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-040 | bounded-revert |
| LNX-008 | passed | port-http-windows | windows-x64 | CrossPlatform/artifacts/evidence/http-windows.json | none | additive-only | D-040 | bounded-revert |
| LNX-009 | passed | port-http-windows | windows-x64 | CrossPlatform/artifacts/evidence/http-windows.json | none | additive-only | D-040 | bounded-revert |
| LNX-010 | passed | port-http-windows | windows-x64 | CrossPlatform/artifacts/evidence/http-windows.json | none | additive-only | D-040 | bounded-revert |
| LNX-011 | passed | port-contract-release+port-linux-sandbox | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-039+D-041 | bounded-revert |
| LNX-012 | passed | port-static+port-linux-sandbox | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-039+D-040 | bounded-revert |
| LNX-013 | passed | port-linux-sandbox | wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-041 | bounded-revert |
| LNX-014 | passed | port-static+port-linux-sandbox | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-011+D-041 | bounded-revert |
| LNX-015 | passed | port-linux-sandbox | wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/linux-runtime.json | none | additive-only | D-017+D-041 | bounded-revert |
| LNX-016 | passed | port-static+port-browser | windows-x64 | CrossPlatform/artifacts/evidence/browser.json | none | additive-only | D-040+D-041 | bounded-revert |
| LNX-017 | passed | port-http-windows | windows-x64 | CrossPlatform/artifacts/evidence/http-windows.json | none | additive-only | D-040 | bounded-revert |
| LNX-018 | passed | port-verify+port-linux-sandbox | windows-x64+wsl-Ubuntu-x64 | CrossPlatform/artifacts/evidence/verify-summary.json | none | hang-timeout-only | D-015+D-041 | bounded-revert |
| LNX-019 | blocked | port-linux-sandbox+R-S2-039 | independent-Ubuntu-isolation-unavailable | CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv | R-S2-039 | independent-host-claim-blocked | D-038+D-043 | bounded-revert |
| LNX-020 | pending | port-evidence | repository | Docs/Review/SLICE-002-Adversarial-Review.md | none | documentation-only | D-043 | bounded-revert |
| LNX-021 | passed | port-http-windows | windows-x64 | CrossPlatform/artifacts/evidence/http-windows.json | none | additive-only | D-040 | bounded-revert |
| LNX-022 | passed | port-browser | windows-x64 | CrossPlatform/artifacts/evidence/browser.json | none | browser-security-verified-under-documented-editor-exclusion | D-040+D-043 | bounded-revert |

## Measured results

- The earlier locked Windows wrapper passed static analysis, restore, Debug and Release builds, 23 contract cases with 309 assertions in each configuration, the required nonzero failure self-test, Linux x64 publish, and whole-tree manifest generation. Final wrapper evidence must be regenerated from the committed checkpoint after the hardening edits.
- The latest pre-freeze Windows HTTP gate passed 4,532 checks against the Release server.
- The latest pre-freeze Edge 152 gate passed 758 browser checks for the connected shell, HttpOnly session behavior, same-origin API access, hostile-origin CORS denial, CSP, framing denial, and page-target network scope.
- WSL Ubuntu 24.04 passed 27 checks against the unchanged self-contained artifact. It ran as non-root with no `dotnet` command, wrote no observed runtime state, exposed only the selected loopback socket, showed zero children across 200 samples, shut down cleanly, and released the port.
- The latest clean restore passed 398 checks after the NO-GO remediation. It holds the shared evidence lease across its complete mutable workflow and distinguishes partial acquisition, validated ownership, and prior-audit invalidation. Dependency schema v2 keeps registry content hashes, raw archive digests, signature identity, and extracted identity distinct. It binds every retained signed `.nupkg` payload and the canonical complete disk inventory by SHA-256, file count, and total bytes. The only accepted archive-to-disk differences are the reviewed three OPC archive-only metadata files, the exact three NuGet disk-only files, and the case-normalized nuspec filename mapping.
- A negative mutation introduced extracted nuspec byte and line-ending drift. Restore rejected it. The affected ignored package cache was moved intact to recoverable ignored quarantine and restored from the approved signed source before the 398-check clean pass.
- Old test-owned browser run directories were moved intact to recoverable ignored quarantine only after the cleanup check proved that no process referenced any exact run path.
- The latest focused final-auditor graph probe passes 1,562 checks across exactly five reviewed asset files, five matching lock files, three `[10.0.11, 10.0.11]` downloads, project-only targets and libraries, and exact direct dependency edges in every lock record. Focused redaction probes cover quoted JSON and a 40-character prefix. Focused task-root checks accept only canonical case and reject case drift. These are source-level and focused results, not a full `port-evidence` pass.

Every audited producer now acquires the same cross-OS atomic `CrossPlatform/artifacts/evidence/.evidence-writer.lock`. Its receipt is lowercase 32-hex plus LF. Under the lease, a producer invalidates the audit sidecar and then the audit JSON before its first audited mutation. Restore holds the lease throughout restore mutation. `Verify.ps1` creates canonical `CrossPlatform/artifacts/tmp/.port-verify-running` under the lease and retains the marker across every child step. The bidirectional Windows/WSL contention challenge passed and left no lock. The final auditor rejects that marker and case-drifted, colliding, or nonempty HTTP and browser task roots at its primary read and both closeouts. It independently derives the exact five-project dependency graph and recomputes the archive and complete disk-inventory bindings. That audit has not yet passed for the final committed checkpoint. Raw evidence remains under the ignored `CrossPlatform/artifacts/evidence/` directory; this report keeps only stable, privacy-bounded facts.

## Untested boundaries and unknowns

- P-007 connectivity is resolved and superseded by R-S2-039. The gate ran on an independent Ubuntu 24.04.4 host, non-root, over Tailscale SSH. It failed its own `sandbox-activation-network-not-private` check before the application started, because on that host `kernel.apparmor_restrict_unprivileged_userns` is set to 1 and an unprivileged user unit cannot obtain a private network namespace, while `systemd-run` still returns 0. The isolation the WSL result demonstrates is therefore a property of the WSL environment and is not portable as written, so no product runtime evidence exists from any non-WSL kernel and WSL is still not promoted to second-host evidence. The maintainer accepted this as a documented limitation rather than weaken the host. Tracked as R-S2-039.
- The LNX-016 criterion originally claimed accessibility structure checks. No gate asserts anything about accessibility, confirmed by exhaustive search, so the clause was removed from the criterion rather than left as an unverifiable claim. Accessibility is not claimed at any level for this slice.
- No media path, project import, tool discovery, process execution, encoding, persistence, plugin, queue, remote access, native desktop UI, macOS runtime, packaging, signing, or public distribution behavior exists in this slice.
- Browser evidence binds the launched browser by exact PID, start time, executable, and argument vector; confirms `Browser.getVersion`; and correlates CDP `SystemInfo.getProcessInfo` operating-system PIDs with the reviewed browser executable hash. Network evidence still covers only the selected page target after monitoring was enabled. It does not claim that every browser-process subsystem made no background request.
- The no-child and no-write results are bounded observations for the tested workload and sandbox, not proofs about future code paths.
- The current WinForms application and its protected build and release scripts were not changed or executed by this slice.

## Security, privacy, logging, and rollback

The server adds a local loopback-only read-only capability surface. It stores no account, project, media, or session state on disk; starts no external tool; writes no product log; and keeps the process token out of evidence. HTTP and browser verifiers register owned processes before readiness, cap live stdout and stderr pipes, revalidate exact PID, start time, executable, and arguments before forced cleanup, and require process reap, port release, and empty task roots before success. Verifier redaction covers quoted and unquoted credential headers anywhere in bounded text, long prefixes, credential schemes, token fields, and URI user information. Its session does not defend against a hostile process already running as the same operating-system user. Any mutation route or listener beyond loopback requires a new threat model and approval.

Rollback is a bounded revert of the additive `CrossPlatform/` subtree and its planning, review, unknown, and verification documents. No current project, user file, persisted format, registry value, installed dependency, or public artifact requires migration or cleanup.
