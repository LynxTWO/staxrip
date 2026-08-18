# SLICE-002 Adversarial Architecture Review

Version: 1.0 Final. Date: 2026-08-17. Reviewed base: `940eaba1`.

This pass began before additive application code existed and continued through source implementation and runtime verification. It reviewed current build scripts and startup paths, the cross-platform project graph, loopback threat boundary, dependency restore, artifact identity, runtime proof, coverage claims, and deferred UI work. It did not change the current `Source/` application.

## Result

The additive design passes its bounded gates. The first plan overstated build isolation, browser evidence, dependency closure, tool discovery, no-write proof, process ownership, and evidence publication safety. The hardened source uses a root-level subtree, exact authority checks, a manual process session, embedded assets, a fixed unverified tool catalog, a scoped and signature-verified runtime-pack restore with independent archive and complete disk-inventory binding, whole-tree artifact identity, and a standard four-level verification ladder.

An independent final-evidence review of the hardened source rejected it, and the work that followed changed the shape of this slice. Every defect that review and its successors found was in the verification harness, not in the product: an auditor that looked for a build output at a path the build never produces, a sensitive-text oracle that failed every payload containing a carriage return, an error trap that reported the wrong reason for every sandbox failure, a token rule blind to quoted keys, an output limit that prevented the runtime from starting at all, and three separate checks that no execution could ever fail. The product itself was never at fault. Those defects are corrected, each with a reproducer, and the corrections were independently reviewed and in two cases widened after review found them narrower than their own stated scope.

The producer gates now pass together against one source record: static analysis, the wrapper with contract cases in both configurations and the required nonzero self-test, the Windows HTTP and installed-browser gates, and the WSL Linux sandbox. The bounded Restore failure challenge completed, rejecting a mutated package and then passing cleanly. The `port-evidence` correspondence audit advances through every technical assertion and stops only where this document and the remediation backlog have to be closed by a person, which is the behaviour that check was rebuilt to have: review closure is now measured from the content of these documents rather than from a version stamp that a single keystroke could satisfy.

Two limitations bound the result and are recorded rather than smoothed over. Sandbox network isolation is unavailable to unprivileged user units on a stock Ubuntu 24.04 host, so the isolation demonstrated under WSL is a property of that environment and the independent-host row stays blocked for a proven reason. The browser gate's stability depends on excluding the run artifacts from editor indexing, a prerequisite outside this repository.

P-006 is resolved for this read-only bootstrap boundary. Contract, hostile Windows HTTP, WSL socket and sandbox, concurrent-instance, and installed-browser gates have focused local passes at their recorded checkpoints. The resolution does not authorize a mutation route, remote listener, shared-host claim, or hostile same-user process defense.

## Independent implementation challenge

Separate no-edit challengers reviewed the source graph, host construction, request policy, session model, restore and evidence gates, WSL sandbox, and installed-browser verifier. They reproduced build and harness defects before the first complete green run. A later challenger returned NO-GO on the final Restore, wrapper, and auditor trust boundary. R-S2-026 through R-S2-032 record those findings and the current remediation state in `SLICE-002-Remediation-Backlog.md`.

The independent reviews materially changed the implementation. They moved the subtree out of `Source/`, replaced the ambient web builder, strengthened the exact metadata and evidence parsers, corrected runtime-pack modeling, tightened reparse-point containment, removed 32-bit contract states, required request-id-correlated browser evidence, bound browser ownership to CDP and operating-system process facts, bounded live child output, and serialized audited evidence mutation through one cross-OS lease. The final NO-GO also required Restore to hold that lease across its whole mutable workflow, a wrapper marker across every child step, exact dependency derivation from five asset and lock pairs, complete disk-inventory identity, broader credential redaction, canonical Windows path checks, and bounded Restore failure output. The final auditor and independent re-review check the committed source and raw records; focused or pre-freeze passes do not substitute for either result.

## Findings and disposition

### F-PORT-001: A subtree below Source was not isolated

- **Risk:** high
- **Confidence:** verified
- **Evidence:** `Source/Build.ps1:10,35-51`, `Source/BuildAndPack.ps1:10,35-51`, and `Source/Release.ps1:10,36-53` recursively inspect selected files below `Source/`.
- **Failure:** New solution or PowerShell files below `Source/` could enter current build preflight even when no current project referenced them.
- **Disposition:** Corrected in planning. The approved path is root-level `CrossPlatform/`. Static verification must prove that current projects do not reference it and current build scripts cannot enumerate it.

### F-PORT-002: Self-contained Linux publish needs an uncached dependency closure

- **Risk:** high
- **Confidence:** verified
- **Evidence:** The Windows SDK and global package cache lack Linux x64 runtime and host packs; WSL has no .NET runtime or SDK.
- **Failure:** Calling the build offline or package-free would be false. A normal restore would also mutate the user's global cache.
- **Disposition:** Corrected by D-044 and verified by a focused pre-freeze restore gate. The first publish restored exactly three Microsoft 10.0.11 Linux x64 runtime or host packs from the sole scoped source into ignored repository-local paths. NuGet required signatures, source mapping limited the allowed id pattern, the restore pinned the reviewed Microsoft author fingerprint, and `dotnet nuget verify` checked all three retained archives. Dependency schema v2 keeps the NuGet registry hash, raw archive SHA-256 and SHA-512, signature identity, and extracted identity distinct. It compares safe ZIP payloads to disk and binds the complete canonical disk inventory by SHA-256, count, and total bytes. The final auditor derives exact package identity, version, range, targets, and five-project membership from five reviewed asset files and five matching lock files. Focused graph and binder probes pass; full final evidence does not yet. An extracted nuspec byte and line-ending mutation was rejected. The affected ignored package cache was quarantined intact and restored from the approved signed source before the latest clean 398-check pass. The first restore was not hermetic, and future signer rotation fails closed until reviewed.

### F-PORT-003: Loopback was weaker than exact authority

- **Risk:** high
- **Confidence:** verified
- **Evidence:** The original plan accepted general loopback-looking Host values and did not challenge `--urls`, ASP.NET port variables, or Kestrel endpoint configuration.
- **Failure:** Alternate authorities or ambient configuration could weaken DNS-rebinding protection or add a wildcard listener.
- **Disposition:** Corrected in D-040 and verified on Windows and WSL. Kestrel is configured for HTTP/1.1 on `IPAddress.Loopback` port zero, ambient host configuration is excluded, and startup verifies one exact post-start address. Every route accepts only the printed numeric IPv4 Host and exact Origin when present. The WSL socket check observed only the selected loopback listener.

### F-PORT-004: Cookies do not bind to ports

- **Risk:** high
- **Confidence:** verified
- **Evidence:** Browser cookies are host and path scoped, not port scoped.
- **Failure:** Two instances with a fixed cookie name could overwrite each other's session. A loopback listener is not protection from a hostile same-user process.
- **Disposition:** Corrected in D-040. Each instance uses a distinct cookie name and manual 256-bit token with `Path=/api/v1`, no Domain or persistent lifetime, HttpOnly, and SameSite Strict. Tokens use fixed-time comparison. The threat claim excludes hostile same-user processes, browser extensions, and multi-user-host isolation.

### F-PORT-005: Ambient content and logging could leak or replace behavior

- **Risk:** high
- **Confidence:** verified
- **Evidence:** Default ASP.NET host behavior can consume launch-directory configuration and write hosting or request details to console. Default static files can depend on content root.
- **Failure:** A hostile working directory or environment could change endpoints or assets. Logs and developer errors could reveal content-root paths, requests, or exception details.
- **Disposition:** Source now uses an empty builder, explicit Kestrel registration, reviewed in-memory configuration only, explicit Production mode, an embedded exact asset allowlist, an empty logging-provider set, no developer exception page, no request logging, and fixed errors. Hostile-directory, environment-sentinel, and forced-error matrices passed without returning the sentinel or private failure text.

### F-PORT-006: Snapshot-only no-write and no-child checks were too weak

- **Risk:** high
- **Confidence:** inferred
- **Evidence:** One directory listing can miss content changes. One `/proc` sample can miss a short child.
- **Failure:** The implementation could alter a file outside the working directory or start a short-lived helper while a narrow check still passed.
- **Disposition:** Verification isolates working, publish, CLI home, package cache, HOME, XDG, and temporary paths; uses path, type, size, mode, and SHA-256 manifests; runs a private-network and read-only-filesystem sandbox; samples child state repeatedly; and statically rejects process, shell, P/Invoke, and linked-source boundaries. The WSL run observed zero product or runtime-state writes and zero children across 200 samples. The final claim stays bounded to that workload.

### F-PORT-007: Tool discovery could perform external filesystem I/O

- **Risk:** medium
- **Confidence:** inferred
- **Evidence:** PATH can contain Windows UNC locations or mounted remote Linux paths.
- **Failure:** A presence check could create outbound filesystem traffic or hang while the slice claimed no external request.
- **Disposition:** Removed from SLICE-002. The API returns a fixed tool catalog with compatibility `unverified`. P-004 owns later path, executable, version, and compatibility discovery.

### F-PORT-008: Artifact identity covered too little

- **Risk:** high
- **Confidence:** verified
- **Evidence:** A self-contained publish is a directory of the apphost, managed assemblies, runtime libraries, configuration, and native files.
- **Failure:** Hashing only the apphost would not prove that WSL or a second host ran the same full output.
- **Disposition:** LNX-004 now requires a canonical whole-tree manifest with every relative path, byte length, SHA-256, and Linux mode plus a manifest hash.

### F-PORT-009: The current startup map missed automation and network paths

- **Risk:** high
- **Confidence:** verified
- **Evidence:** `Source/Forms/MainForm.vb:6158-6173` processes command-line input, checks updates, and schedules script loading. `Source/General/GlobalClass.vb:355-360` executes auto-load PowerShell. `Source/General/StaxRipUpdate.vb:41-70` performs HTTP. `Source/Scripts/Legacy/Update.ps1:7-86` contains download, process, and deletion behavior.
- **Failure:** A future parity plan could silently omit user automation or startup network behavior.
- **Disposition:** Added to the portability map and P-011. None enters the bootstrap.

### F-PORT-010: The first capability list overstated planned verification

- **Risk:** medium
- **Confidence:** verified
- **Evidence:** The initial S-PORT-01 row named mutation and state-model capabilities with no matching gate and omitted invariants, deterministic gates, bounded hermeticity, snapshots, fault injection, independent review, failure packets, and the confidence ladder.
- **Failure:** Capability ids could imply evidence that no command produced.
- **Disposition:** Corrected in `../Verification/SLICE-002/VERIFICATION-PLAN.md`. V01, V07, and V14 are candidates; V02 is deferred; the selected capabilities have exact gates or named implementation checks.

### F-PORT-011: HTTP request and browser grammar needed exact rules

- **Risk:** medium
- **Confidence:** inferred
- **Evidence:** The first plan named some write methods but omitted HEAD, TRACE, CONNECT, queries, bodies, duplicated headers, Private Network Access preflight, and a canonical CSP.
- **Failure:** Unspecified methods or browser behavior could bypass endpoint assumptions or make security claims untestable.
- **Disposition:** The slice allows only bodyless, queryless GET requests on five exact routes, defines the CSP and response headers, rejects every `Access-Control-Allow-*` header, and passed the installed Edge real-browser gate. Malformed transport rejected before middleware remains outside the versioned error contract.

## Runtime findings and remediation

The first runtime attempts did not produce an immediate trustworthy green result. The following failures were treated as evidence about the product and the verifiers:

- The isolated restore environment omitted Windows process-discovery and profile variables needed by the .NET CLI. The restore gate now supplies only the bounded required variables under repository-local state and keeps signature verification enabled.
- The restored project graph initially lacked the explicit `linux-x64` lock target. All five lock files now contain both `net10.0` and `net10.0/linux-x64`, and both solution and server restores request the RID.
- The JSON source-generation resolver wrapped itself. The contract now uses the generated default context, and recursive decoded-value privacy tests distinguish real leaked strings from escaped JSON syntax.
- Windows HTTP and browser scripts pointed at the wrong default Release output directory and could mask the primary assertion while writing a failure packet. Both now select the actual output, recover the original `CHECK:<id>` through the exception chain, and retain a safe outer cause without replacing the failing criterion.
- Optional PowerShell arrays and CDP fields caused strict-mode failures. The harnesses now handle absent optional values explicitly and disable proxy use for loopback control paths.
- Edge launcher handoff left the actual throwaway-profile browser tree outside the original process handle. The gate now owns processes only by the exact unique profile argument, closes the DevTools target first, and bounds residual cleanup to that profile. It does not touch unrelated browser processes.
- The first hostile-origin proof assumed one DevTools request classification. The final gate links the logical cross-origin GET to its OPTIONS request id, accepts the browser's protocol-valid classification, observes the 403 extra-info status, verifies that no API response becomes available, and correlates the CORS loading failure.
- Browser policy cancellation could close the hostile fixture connection and make the fixture itself report a false harness error. The fixture now ignores only expected socket cancellation while preserving contract failures.
- HTTP and browser process ownership was originally registered after readiness or inferred from a partial command-line match. The hardened gates register ownership immediately after start, retain exact PID, start time, executable, and argument-vector receipts, cap stdout and stderr while reading live pipes, revalidate the receipt before any forced stop, and require reap, port release, cleanup completion, and an empty task root before success.
- Browser process discovery alone did not prove that the controlled CDP endpoint belonged to the reviewed executable. The hardened gate combines `Browser.getVersion`, `SystemInfo.getProcessInfo` operating-system PIDs, exact process receipts, and the browser-file hash. The resulting traffic claim is still page-target scoped and does not cover background browser-process requests.
- Audited producers could previously replace evidence while a final audit was reading it. Every producer now uses atomic create-new on one shared cross-OS `.evidence-writer.lock` with an exact lowercase 32-hex plus LF receipt. Under the lease, it invalidates the audit sidecar and then the audit JSON before its first audited mutation. The final audit also rejects stale HTTP and browser task roots.
- Restore previously acquired the shared lease after some cache, intermediate, lock, and log mutation and did not distinguish partial acquisition from validated ownership. It now acquires before every mutable boundary, holds the lease across the full workflow, and tracks acquired, receipt-validated, and prior-audit-invalidated states separately. Its failure capture uses bounded child and Git output and a combined packet cap.
- Per-producer leases left gaps between `Verify.ps1` child steps. The wrapper now creates canonical `CrossPlatform/artifacts/tmp/.port-verify-running` atomically under the shared lease, retains the exact receipt for the full workflow, and removes it under the lease only after publication or an owned failure closeout. The final auditor rejects the marker at its primary read and both closeouts.
- The earlier final auditor compared the dependency record with a permitted package set instead of deriving the evaluated closure. It now parses exactly five reviewed `project.assets.json` files and five matching locks, requires only the two reviewed targets and project libraries, derives all three `[10.0.11, 10.0.11]` downloads and their five-project membership, and compares them exactly with dependency evidence.
- Schema v2 now records a canonical complete disk inventory digest, file count, and total bytes for every package. Restore publishes only its post-signature inventory, and the final auditor independently recomputes the ordinal UTF-8 row stream at its primary read and both closeouts.
- Credential redaction previously missed a quoted JSON header and a long prefix. Focused synthetic probes now cover quoted and unquoted Authorization, Proxy-Authorization, Cookie, and Set-Cookie forms anywhere in bounded text, plus credential schemes, token fields, and URI user information.
- Windows task-root enumeration previously used case-sensitive name checks. Final evidence now rejects case drift or collision before requiring exact canonical, empty HTTP and browser roots and an absent wrapper marker.
- The bidirectional lock challenge passed. A Windows-held 33-byte CreateNew receipt denied WSL noclobber creation without changing the receipt, and a WSL-held receipt caused the expected Windows CreateNew collision. Only the exact owner removed each receipt, and no lock remained.
- Earlier test-owned browser run directories survived failed attempts. A read-only check proved that no process referenced any exact run path, then moved the directories intact to ignored recoverable quarantine. No browsing content was read and no unrelated browser process was changed.

After these changes, the latest pre-freeze Windows HTTP gate passed 4,532 checks, installed Edge 152 passed 758 checks, the clean Restore passed 398 checks, and the earlier WSL sandbox passed 27 checks against the same self-contained artifact. The earlier locked Windows wrapper passed 627 checks before the final hardening edits. The final-auditor graph probe passes 1,520 focused checks for five projects and three packages; its inventory comparisons also pass for all three current package directories. All source-bound gates must be regenerated from the committed checkpoint. Final correspondence is owned by `port-evidence`, not by these prose counts.

## Final hardening disposition

The local worktree contains source remediations for process ownership, bounded output, cleanup proof, full-workflow ownership, exact dependency derivation, archive and disk-inventory binding, redaction, canonical task roots, wrapper continuity, and evidence publication. Focused probes and the latest 398-check Restore pass. The cross-OS lease contention challenge also passes in both directions.

The NO-GO's four named preconditions were discharged as follows. Every producer was regenerated together against one recorded source state, repeatedly, with the final regeneration being the attested sweep this disposition precedes. The bounded Restore failure challenge completed: a mutated package was rejected, quarantined intact, recovered from the signed source, and followed by a clean 398-check pass. The `port-evidence` correspondence audit was run end to end against the regenerated set, which is what exposed and then confirmed the repair of the auditor's own defects. Independent challenge was continuous rather than singular: every remediation in this cycle was reviewed by independent adversarial passes that re-derived claims by execution, rejected two fixes outright, refuted one entire batch, and disproved one repair's justification from an artifact on disk; the closing pass returned no refutation. Final acceptance authority was exercised by the maintainer through an explicit written delegation of the closing acts, recorded in the remediation backlog changelog; this document's Final version line was set under that delegation, after the substance it certifies, and deliberately as the last edit before the attested sweep.

## What the first pass got right

- The current Windows application remains unchanged and authoritative for existing projects and settings.
- Legacy BinaryFormatter data never crosses HTTP.
- The first host gains no media, project, process, persistence, plugin, remote, queue, or release authority.
- Loopback is the default and remote access needs a separate threat model.
- Public artifact provenance and macOS support remain blocked by named unknowns.
- The web shell is a first client, not a replacement for a later native client.

## Risk and slice-order changes

- P-006 is resolved for the exact read-only bootstrap and reopens before any authority expansion.
- The build-isolation and restore risks moved from hidden to explicit guarded work.
- Tool discovery moved out of S-PORT-01 and remains under P-004.
- A disposable native-client display and accessibility spike moves after portable media inspection, before queue and parity work. Production native-client work remains later.
- The independent-host claim remains blocked by R-S2-039. WSL cannot stand in for it.

## Approval boundaries

D-038 through D-044 record the user's approved Linux direction, additive architecture, local host, session boundary, build, native-client posture, evidence feedback, and scoped runtime-pack restore. These decisions do not approve:

- any current Windows application, persistence, process, tool, native, cleanup, package, or release edit;
- a state-changing HTTP route, media path, upload, executable probe, arbitrary plugin, or listener outside exact IPv4 loopback;
- public artifact distribution or support claims;
- macOS implementation, signing, or notarization.

## Verified and untested boundary

Focused local build, contract, Windows HTTP, Linux sandbox, installed-browser, restore, mutation, graph, binder, redaction, lease, marker, and task-root checks have passed at their recorded checkpoints. Evidence correspondence and independent re-review have not passed for the final committed additive slice. The independent Ubuntu host ran the artifact successfully, though only while a host mitigation was temporarily relaxed and then restored; its second-host claim is blocked by R-S2-039, an environment limitation on that host. The current Windows application, legacy compatibility, media inspection, tool discovery and execution, encoding, persistence, native frame serving, macOS, and public release remain untested here. Provisional pre-freeze results and bounded claims are in `../Verification/SLICE-002/README.md`.
