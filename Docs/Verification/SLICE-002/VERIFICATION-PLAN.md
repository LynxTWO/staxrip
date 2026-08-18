# SLICE-002 Deterministic Verification Plan

Version: 0.3 Pre-freeze. Date: 2026-08-16. Executed base: `940eaba1134e52260a74cb452a86e3e243ed76c9`.

This plan evaluates all twenty anti-dark-code verification capabilities for the Linux engine bootstrap. A selected capability is not evidence until its named gate passes. Commands run from the repository root unless the script changes to the checked-in cross-platform root itself.

## Environment constraints

- Windows build host: .NET SDK 10.0.303, x64, 32 logical processors, about 64 GB RAM.
- WSL runtime: Ubuntu 24.04 x86-64, glibc 2.39, non-root uid 1000, with `file`, `curl`, `python3`, `ss`, `readelf`, `ldd`, `sha256sum`, and systemd user units. No Linux .NET runtime or SDK is installed.
- Browser: Edge 152.0.4191.19 supplied the installed-browser result. Chrome 151 remained an unused fallback, not a second independent implementation.
- GPU: visible in WSL but irrelevant to this capability-only slice.
- Independent Ubuntu peer: reachable over Tailscale SSH as of 2026-08-17. Ubuntu 24.04.4, kernel 7.0.0-28-generic, x86-64, ext4, non-root account, dotnet present. It ran the artifact and passed 27 checks while a host mitigation was temporarily relaxed and then restored. Under its normal configuration unprivileged user units cannot obtain a private network namespace, so second-host evidence is blocked by R-S2-039.
- Dependency restore: the first Linux RID restore used the network and was not hermetic. The evaluated closure was exactly three Microsoft 10.0.11 Linux x64 runtime or host packs. `NuGet.config` requires signed packages, pins the reviewed Microsoft author certificate fingerprint, maps only `Microsoft.*` to the sole `nuget.org` source, and the restore gate runs `dotnet nuget verify` over each retained archive. Dependency schema v2 keeps the NuGet registry `contentHash`, raw archive length and SHA-256 and SHA-512, signature identity, and extracted identity separate. It binds every allowed safe ZIP payload and the complete extracted disk inventory by canonical SHA-256, file count, and total bytes. The final auditor derives the exact three `[10.0.11, 10.0.11]` downloads and five-project membership from five reviewed asset files and five matching lock files. All caches and CLI state stayed below ignored `CrossPlatform/artifacts/`; the gate did not repurpose HOME or the user package cache.

## Capability selection

| ID | Status | Level | Reason and exact evidence |
|---|---|---:|---|
| V01 Mutation testing | candidate | 2 | Host, Origin, session, and catalog helpers are good later targets because the builder authors their tests. Activate after source exists with an approved bounded runner; do not add Stryker merely for this slice. |
| V02 Model-based stateful testing | deferred | 3 | Session absent, present, restart, and two-instance states fit an exhaustive fixed matrix. Activate a state model when media, queue, cancel, retry, or recovery enters scope. |
| V03 Executable invariants | selected | 0-1 | Contract harness checks exact post-start authority, 256-bit token shape, unique bounded ids, fixed errors, and unavailable product capabilities. Production startup fails closed on any address drift. |
| V04 Differential testing | selected | 1 | Normalize documented dynamic host facts, then compare Windows and WSL health, schema, ids, unavailable states, errors, and security headers. Do not compare platform-specific values as equal. |
| V05 Metamorphic testing | selected | 1-2 | Deterministic loops vary Host and Origin case, port, cardinality, malformed forms, catalog input order, and equivalent serialization inputs while enforcing declared relations. |
| V06 Deterministic execution mode | selected | 0-1 | Pin SDK 10.0.303; use UTC and fixed culture in tests; capture the OS-selected port; never capture the token. Replay identity includes base/head, SDK/runtime, configuration/RID, tree-manifest hash, host tuple, and case id. |
| V07 Record and replay corpus | candidate | 2 | Activate on the first reproduced HTTP, browser, or platform failure. Retain the minimized case and artifact hash, never a cookie or user path. |
| V08 Schema and contract validation | selected | 0-1 | Validate semantic JSON keys, ids, counts, lengths, enums, exact endpoint/method inventory, error envelope, and unavailable feature list. Reject query strings and bodies rather than ignoring them. |
| V09 Static architecture enforcement | selected | 0 | Enforce Server -> Platform -> Core -> Contracts, no project package reference, layer API bans, no current project reference, root-subtree scope, embedded asset allowlist, and no symlink or reparse-point surprise. |
| V10 Deterministic quality gate | selected | 0-2 | Exact scripts preserve producer exit codes, use timeouts, collapse green output, and expand one bounded failure packet. A forced-failure self-test must prove wrappers fail. |
| V11 Change-impact analysis | selected | 0 | Props, SDK, NuGet, solution, or gate changes run the full slice. Contracts/Core run harness and both OS semantic APIs. Platform runs both OS facts. Server/security runs all HTTP, browser, and Linux gates. Web assets run asset and browser gates. Code outside `CrossPlatform/` stops. |
| V12 Hermetic builds and tests | selected | 1-2 | Build and tests run without restore from the repository cache. Linux runtime runs in a private-network and read-only-filesystem systemd user sandbox. The initial restore is explicitly non-hermetic and excluded from this claim. |
| V13 Golden and semantic snapshots | selected | 1 | Keep small reviewed semantic fixtures for JSON schema, endpoints, headers, catalogs, and assets. Exclude token, port, path, time, and noisy whole-page output. |
| V14 Performance and leak budgets | candidate | 3 | LNX-018 is a hang timeout and observation, not a performance budget. Activate cold/warm budgets after T540p evidence and a user-relevant flow exist. |
| V15 Fault injection | selected | 2 | Challenge ambient URL and Kestrel config, hostile launch content, duplicate and malformed headers, occupied bind where applicable, read-only/private-network runtime, SIGTERM, and injected capability-provider failure. Record activation separately from outcome. |
| V16 Authoritative project map | selected | 0 | Regenerate project, dependency, endpoint, and asset inventory with base/head and freshness hash. The current portability map is planning evidence until correspondence passes. |
| V17 Separated roles | selected | 2 | Independent challengers reviewed source, build and evidence gates, and runtime security. Their findings and dispositions are recorded without treating the builders' own tests as independent proof. |
| V18 Test-change policing | selected | 0-2 | Pin case ids and minimum assertion count. Reject skipped or disabled cases, swallowed failures, timeout increases, and weakened snapshots without a decision. Run the harness forced-failure mode. |
| V19 Minimal failure packets | selected | 0-2 | Record gate and criterion id, first assertion, bounded expected/actual, argv, exit, base/head, host tuple, tree-manifest hash, replay argv, and redacted log path. Never retain or hash cookie values or Set-Cookie content. |
| V20 Confidence ladder | selected | 0-3 | Level 0 is static and compile feedback. Level 1 is Debug/Release, harness, Windows HTTP, publish, and required WSL runtime. Level 2 is property/fault/browser/adversarial review. Level 3 is the independent Ubuntu and future release matrix. |

No capability is marked not applicable. Each candidate or deferred item has a specific activation trigger.

## Exact gate surface

| Gate | Level | Timeout | Command | Required compact result |
|---|---:|---:|---|---|
| `port-static` | 0 | 60 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Static.ps1 -BaseCommit 940eaba1134e52260a74cb452a86e3e243ed76c9` | Project graph, scope, API bans, routes, assets, cases, citations |
| `port-restore-initial` | 1 | 300 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Restore.ps1 -Initial` | Evaluated closure and repository-local cache; network declared |
| `port-restore` | 1 | 300 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Restore.ps1` | Whole-workflow shared lease; exact graph; signed archives; complete disk inventory; no lock drift or user-cache mutation |
| `port-build-debug` | 0 | 180 s | `dotnet build CrossPlatform/StaxRip.CrossPlatform.slnx --configuration Debug --no-restore --warnaserror --nologo` | Real build exit |
| `port-build-release` | 1 | 180 s | Same command with `Release` | Real build exit |
| `port-contract-debug` | 1 | 120 s | `dotnet run --project CrossPlatform/tests/StaxRip.ContractTests/StaxRip.ContractTests.csproj --configuration Debug --no-build --no-restore -- --concise` | Exact case/assertion/failure counts |
| `port-contract-release` | 1 | 120 s | Same command with `Release` | Exact case/assertion/failure counts |
| `port-contract-failure` | 0 | 30 s | Same Release command with `--self-test-failure` | Nonzero is required |
| `port-http-windows` | 1 | 180 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Http.ps1 -Configuration Release` | Route, method, session, authority, header, restart, two-instance, exact process ownership, output bound, cleanup, and task-root matrix |
| `port-publish-linux` | 1 | 300 s | Locked RID restore, then `dotnet publish CrossPlatform/src/StaxRip.Server/StaxRip.Server.csproj --configuration Release --runtime linux-x64 --self-contained true --no-restore --output CrossPlatform/artifacts/publish/linux-x64 --nologo` | Self-contained publish tree |
| `port-artifact-manifest` | 1 | 120 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Write-ArtifactManifest.ps1 -Root CrossPlatform/artifacts/publish/linux-x64 -OutputPath CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv -WslDistribution Ubuntu -ModeSource Wsl` | Canonical whole-tree manifest, Linux modes, and companion SHA-256 |
| `port-linux-sandbox` | 1-2 | 180 s | `wsl.exe -d Ubuntu -- /usr/bin/bash --noprofile --norc <absolute-mounted-repo>/CrossPlatform/eng/verify-linux.sh <absolute-mounted-repo>/CrossPlatform/artifacts/publish/linux-x64 <absolute-mounted-repo>/CrossPlatform/artifacts/evidence/artifact-linux-x64.tsv` | ELF, manifest, uid, socket, HTTP, sandbox, child sample, filesystem, shutdown |
| `port-browser` | 2 | 180 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Browser.ps1 -BrowserPath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"` | Real browser session, JS, CORS, CSP, framing, page-target requests, CDP-to-OS process binding, bounded output, cleanup, and empty task root |
| `port-evidence` | 2 | 60 s | `pwsh -NoProfile -NonInteractive -File CrossPlatform/eng/Verify-Evidence.ps1` | Every LNX field; exact five-input dependency derivation; independent archive and disk-inventory binding; absent workflow marker; canonical empty task roots at primary and both closeouts |

Scripts print one line on success: `PASS <gate-id> checks=<n> elapsed_ms=<n> evidence=<relative-path-or-none>`. Failures retain a bounded packet below ignored `CrossPlatform/artifacts/failures/` and return the producer's nonzero exit.

## Pre-freeze recorded outcomes

- The latest clean `port-restore` passed 398 checks after acquiring the shared lease before every mutable restore boundary, deriving the exact three-package closure, verifying every archive signature against the pinned author fingerprint, and binding both archive payloads and the canonical complete disk inventory. An extracted nuspec byte and line-ending mutation failed closed. The affected ignored package cache was quarantined intact and restored from the approved signed source before the clean pass.
- The earlier locked Windows wrapper passed 627 checks. Debug and Release builds completed with zero warnings and zero errors. Each contract run passed 23 cases and 309 assertions; the deliberate failure mode returned nonzero as required. This wrapper result must be regenerated after the final commit.
- The latest hardened `port-http-windows` gate passed 4,532 checks against the Release server.
- `port-linux-sandbox` passed 27 checks against the exact self-contained manifest. It observed zero runtime writes, zero children across 200 samples, and a clean shutdown and released socket.
- The latest hardened `port-browser` gate passed 758 checks with installed Edge. It also binds the exact owned process receipt to `Browser.getVersion`, CDP `SystemInfo.getProcessInfo` operating-system PIDs, and the reviewed executable hash. Its request claim remains limited to the selected page target after network monitoring was enabled.
- Old test-owned browser run directories were moved intact to ignored recoverable quarantine after an exact-path process-reference check returned none.
- The bidirectional evidence-lease contention challenge passed. While Windows held the exact 33-byte CreateNew receipt, WSL noclobber creation exited 1 without changing it. While WSL held the receipt, Windows CreateNew reported the expected collision. The exact owner removed each receipt, and the final lock was absent.
- A later independent final-evidence review returned NO-GO on whole-workflow Restore ownership, partial lease state, exact asset and lock derivation, complete disk inventory identity, redaction edge cases, Windows case handling, wrapper continuity, and bounded Restore failure output. Source remediations are present. Focused probes pass 1,520 exact graph checks, 11 Restore redaction cases, four final-auditor redaction cases, lease ownership checks, and canonical task-root and marker checks. These focused results are not a substitute for the full producer sequence.
- `Verify.ps1` now creates canonical `CrossPlatform/artifacts/tmp/.port-verify-running` under the shared lease, retains its exact receipt across every child step, and removes it under the lease only after publication or an owned failure closeout. `port-evidence` rejects the marker at its primary read and both closeouts.
- `port-evidence` is the final freshness and correspondence audit. It has not yet passed for the final committed-source rerun, and independent re-review remains pending.
- LNX-019 is blocked by R-S2-039, not by P-007. The second Linux host ran the artifact on 2026-08-17 while a host mitigation was temporarily relaxed and then restored; under its normal configuration the gate fails `sandbox-activation-network-not-private`.

## Mandatory runtime matrices

- **Authority:** exact Host; no Host alias; wrong or missing port; IPv6; dotted or suffixed IPv4; hostile `--urls`; every ASP.NET port variable; Kestrel endpoint variables; all routes, not API only.
- **Origin and CORS:** absent valid case; exact valid Origin; `null`; duplicate; malformed; wrong scheme, host, and port; OPTIONS and Private Network Access preflight; zero `Access-Control-Allow-*` headers on every response.
- **Session:** no cookie; wrong cookie; duplicate cookie; no, wrong, or duplicate client header; root-only issuance; attributes without printing the value; restart invalidation; two simultaneous instance separation.
- **Request grammar:** five exact GET routes; every other method; query; content length; transfer encoding; trailing slash; encoded traversal; unknown path.
- **Privacy and failure:** sentinel in cwd, environment, fake content root, request, and forced provider error; quoted and unquoted credential headers after short or long prefixes; no sentinel, path, stack, token, request body, credential value, or environment value in body, stdout, stderr, or bounded failure packets.
- **Lifecycle:** Register ownership before readiness; retain exact PID, start time, executable, and argument vector; cap stdout and stderr while reading live pipes; revalidate the receipt before forced termination; prove process reap, exact socket release, and empty task root, task unit, or cgroup before success.
- **Browser:** Same-origin page reaches the deterministic connected marker; cookie is not visible to page script; hostile second loopback origin cannot read or invoke API; inline script and framing fail; `Browser.getVersion`, `SystemInfo.getProcessInfo`, OS PID receipts, and browser-file hash agree. Network absence is claimed only for the selected page target, not browser-process background traffic.
- **Evidence publication:** Every audited producer uses atomic create-new on the shared `.evidence-writer.lock`, verifies an exact lowercase 32-hex plus LF receipt before release, never steals a lock, and invalidates the audit sidecar before the audit JSON under the lease. Restore holds the lease across its complete mutable workflow and distinguishes acquired, validated, and prior-audit-invalidated states. The wrapper's canonical `.port-verify-running` marker covers its complete child sequence. Final evidence rejects the marker and case-drifted, colliding, or nonempty HTTP and browser task roots at its primary read and both closeouts.

## Whole-tree artifact identity

The canonical artifact manifest sorts ordinal UTF-8 relative paths. Each row contains path, file type, byte length, lowercase SHA-256, and Linux mode. It contains no absolute path. The SHA-256 of the canonical manifest identifies the output. WSL verifies every row before execution. The independent host later receives the same tree or a canonical archive and repeats the manifest without rebuilding.

## Bounded claims

- `file` proves the apphost format, not self-contained behavior. WSL has no dotnet; successful execution plus dependency inspection supplies the bounded self-contained evidence.
- Repeated `/proc` and cgroup observation proves no child was observed during the tested workload. It cannot prove no deliberately detached process could ever exist.
- A successful read-only sandbox proves no required product write for the workload. Static guards and manifests supplement it; they do not prove all possible paths.
- A headless connected marker does not prove screen-reader quality, contrast perception, or usability. Those stay inferred or manual. No accessibility assertion exists in any gate, so accessibility is not claimed at any level for this slice.
- LNX-019 stays `blocked`, never a passing result, until an independent host whose unprivileged user units can obtain a private network namespace runs the artifact (R-S2-039).
