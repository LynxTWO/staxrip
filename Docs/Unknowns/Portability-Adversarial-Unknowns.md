# SLICE-002 Adversarial Unknowns

This file records questions first found during the pre-implementation adversarial pass and their bounded runtime disposition. It supplements, and does not duplicate ownership from, `Portability-Unknowns.md`.

## Entries

### Browser enforcement of the local session boundary

- **Area or file:** Implemented `CrossPlatform/src/StaxRip.Server` and embedded web shell
- **Concern:** Headers and HTTP clients do not prove HttpOnly, SameSite, preflight, CSP, framing, or same-origin browser enforcement.
- **Why it matters:** A local malicious page could attempt to read capability data or drive future local authority if the browser boundary differs from the server-only model.
- **Evidence found so far:** Source implements an exact authority, manual per-instance session, no CORS, canonical CSP, and the embedded web shell. The latest pre-freeze installed Edge gate passed 758 checks against the same-origin shell and hostile second-origin fixture. The gate observed the connected marker, a script-inaccessible cookie, correlated preflight denial and CORS failure, CSP rejection, framing denial, and no third-party selected-page-target request after network monitoring began. It also bound `Browser.getVersion`, `SystemInfo.getProcessInfo` operating-system PIDs, exact PID/start/executable/argument receipts, and the reviewed browser-file hash.
- **Confidence:** verified
- **Likely owner:** SLICE-002 security verifier
- **Next best check:** Reopen and extend the browser threat model before any mutation route, media authority, remote listener, or session-policy change.
- **Risk level:** high
- **Status:** resolved for SLICE-002
- **Notes:** This resolves the browser-specific part of P-006 only for the read-only bootstrap. It does not cover a hostile same-user process, extension, or every browser-process background subsystem.

### Evaluated Linux runtime-pack closure

- **Area or file:** `CrossPlatform/NuGet.config`, lock files, restore script, restore assets, and repository-local package cache
- **Concern:** The exact implicit dependency closure, its authoritative project inputs, and the distinct registry, archive, signature, and extracted identities were unknown before the first evaluated RID restore and final-evidence challenge.
- **Why it matters:** A broader or unpinned closure would contradict D-044 and weaken repeatability and provenance evidence.
- **Evidence found so far:** The evaluated closure is exactly `Microsoft.AspNetCore.App.Runtime.linux-x64`, `Microsoft.NETCore.App.Host.linux-x64`, and `Microsoft.NETCore.App.Runtime.linux-x64`, all at 10.0.11. The sole source is official NuGet, source mapping permits only `Microsoft.*`, signature validation is required, one reviewed Microsoft author fingerprint is pinned, and `dotnet nuget verify` passed for all three retained archives. Restore now holds the shared evidence lease for its complete mutable workflow. Dependency schema v2 separates the registry hash, raw archive digests, signature identity, and extracted identity and records a canonical complete disk inventory SHA-256, file count, and total bytes. A focused final-auditor probe derives the exact three `[10.0.11, 10.0.11]` downloads and five-project membership from five reviewed asset files and five matching lock files and passes 1,520 checks. Focused independent inventory comparisons pass for all three current package directories. A nuspec byte and line-ending mutation failed closed; the affected ignored cache was quarantined intact and restored from the approved signed source before the latest clean 398-check pass.
- **Confidence:** verified
- **Likely owner:** SLICE-002 build verifier
- **Next best check:** Regenerate every producer from one committed checkpoint, run all three final-auditor snapshots, and repeat independent evidence review. Then re-run the initial restore when the SDK feature band, reviewed project input, target, or pack version changes. Treat signer rotation as a failing review gate until a new fingerprint is independently verified and approved.
- **Risk level:** high
- **Status:** in progress
- **Notes:** The exact closure is verified at focused checkpoints, but final committed-source correspondence and independent re-review are pending. The first network restore is not a hermetic gate. `NuGetAudit=false` keeps the exact restore deterministic but means this slice makes no package-vulnerability-audit claim. Public release provenance remains P-009.

### Final evidence correspondence after verifier hardening

- **Area or file:** `CrossPlatform/eng/Restore.ps1`, `Verify.ps1`, `Verify-Evidence.ps1`, producer records, and ignored task roots
- **Concern:** The latest source remediations have not yet been exercised as one committed producer sequence followed by the complete final auditor and independent re-review.
- **Why it matters:** Focused tests can miss a mixed checkpoint, incomplete wrapper workflow, stale path, or mismatch between a regenerated producer record and the final audit.
- **Evidence found so far:** The latest independent review returned NO-GO on full-workflow Restore ownership, partial lease state, exact asset and lock derivation, complete disk inventory identity, redaction edge cases, Windows case handling, wrapper continuity, and bounded Restore failure output. Source remediations are present. The latest Restore passes 398 checks; focused graph, inventory, lease, redaction, marker, and task-root probes pass. Full `port-evidence` was intentionally not run before all producers were regenerated.
- **Confidence:** verified
- **Likely owner:** SLICE-002 evidence verifier and independent challenger
- **Next best check:** From one committed checkpoint, run Restore, static, wrapper, Windows HTTP, WSL, installed browser, and final evidence in the documented order; run the bounded Restore output challenge; then give the raw records and changed scripts to an independent challenger.
- **Risk level:** high
- **Status:** in progress
- **Notes:** No acceptance-table row becomes a final result until this sequence passes. R-S2-039 is the separate independent-host blocker, superseding P-007, which is resolved.

### Framework-owned runtime artifacts

- **Area or file:** Linux .NET host under isolated HOME, XDG, temp, and working directories
- **Concern:** The exact files or sockets created by the self-contained .NET runtime under the supported diagnostics-disabled mode were not known before runtime observation.
- **Why it matters:** An absolute no-write claim could hide product persistence or misclassify a runtime diagnostic socket.
- **Evidence found so far:** Source defines no application writer and uses no ASP.NET Data Protection. The supported Linux gate disables runtime diagnostics with `DOTNET_EnableDiagnostics=0`, constrains HOME, XDG, temp, working, and product paths in a read-only sandbox, and observed zero runtime-state writes and an unchanged application tree during the tested workload.
- **Confidence:** verified
- **Likely owner:** SLICE-002 Linux verifier
- **Next best check:** Repeat the sandbox on an independent host whose unprivileged user units can obtain a private network namespace (R-S2-039). A diagnostics-enabled comparison remains a separate follow-up, not a SLICE-002 acceptance requirement.
- **Risk level:** medium
- **Status:** resolved for SLICE-002
- **Notes:** The result is a bounded observation under the supported environment plus a sandbox prevention result. It does not prove every future path is write-free.

### Browser enforcement of the deliberate non-Secure loopback cookie

- **Area or file:** `CrossPlatform/src/StaxRip.Server/ProcessSession.cs` and installed-browser verification
- **Concern:** Browser enforcement of the deliberately non-Secure, HttpOnly, SameSite=Strict cookie on exact plain-HTTP numeric loopback required observation.
- **Why it matters:** The source decision is bounded to plain loopback HTTP; browser evidence is still required before claiming the complete session boundary works as designed.
- **Evidence found so far:** Source sets `Secure=false`, `Path=/api/v1`, HttpOnly, and SameSite=Strict, with no Domain, Expires, or Max-Age. Static guards, contract assertions, and installed Edge confirmed the cookie is issued for the exact loopback session, is not readable from page script, authorizes the same-origin API with the exact client header, and does not grant the hostile origin access. No TLS boundary exists.
- **Confidence:** verified
- **Likely owner:** SLICE-002 browser verifier
- **Next best check:** Revisit `Secure`, transport, and session design before local TLS, remote access, or any state-changing endpoint.
- **Risk level:** medium
- **Status:** resolved for SLICE-002
- **Notes:** The deliberate omission of `Secure` and its browser outcome are resolved only for exact plain-HTTP numeric loopback. This slice does not add local TLS.

## Closed items

- **Nested Source build coupling** - resolved 2026-08-16 by D-044, the root-level `CrossPlatform/` boundary, and the passing static scope gate. The result does not verify the current Windows application.
- **Bootstrap executable probing** - resolved for this slice 2026-08-16 by returning a fixed `unverified` tool catalog and deferring discovery to P-004.
