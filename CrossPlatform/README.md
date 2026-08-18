# StaxRip Cross-Platform Bootstrap

This subtree contains the additive Linux-first engine foundation. It does not replace or enter the current Windows solution.

The bootstrap serves a local StaxRip shell and reports bounded host and capability facts. It cannot open media, import projects, execute tools, encode, persist product state, load plugins, accept remote requests, or publish media output.

## Build boundary

- SDK: .NET 10.0.303 or a later 10.0 patch selected by `global.json`.
- Project packages: none.
- Linux self-contained dependency packs: `Microsoft.AspNetCore.App.Runtime.linux-x64`, `Microsoft.NETCore.App.Host.linux-x64`, and `Microsoft.NETCore.App.Runtime.linux-x64` at 10.0.11, restored through `NuGet.config` into ignored `artifacts/` paths. The config requires signatures and the restore gate verifies all retained archives against the reviewed Microsoft author fingerprint. The final auditor derives this closure from exactly five reviewed asset and lock pairs. Dependency schema v2 keeps registry, archive, signature, and extracted identities distinct and binds both archive payloads and the canonical complete disk inventory by SHA-256, count, and total bytes.
- Build outputs and evidence: ignored `artifacts/` only.
- Current `Source/` projects and scripts: unchanged.

## Verification boundary

HTTP and browser gates register exact PID, start time, executable, and argument-vector ownership before readiness. They cap stdout and stderr while reading, revalidate before forced cleanup, and require process reap, port release, cleanup completion, and empty task roots. The browser also correlates `Browser.getVersion`, CDP `SystemInfo.getProcessInfo` operating-system PIDs, and the reviewed browser-file hash. Its network claim covers only the selected page target, not browser-process background traffic.

Every audited PowerShell and Bash producer serializes evidence mutation through the atomic cross-OS `artifacts/evidence/.evidence-writer.lock`. The exact lowercase 32-hex plus LF receipt owns removal. A producer invalidates the final audit sidecar and then its JSON before changing audited records. Restore holds the lease across its complete mutable workflow and distinguishes partial from validated ownership. `Verify.ps1` retains canonical `artifacts/tmp/.port-verify-running` across its complete child sequence. The final auditor rejects that marker and case-drifted or nonempty task roots at its primary read and both closeouts. The bidirectional Windows and WSL contention challenge passed.

Run the reviewed gates from the repository root through scripts under `eng/`. The latest focused pre-freeze results and independent NO-GO remediation state are in `../Docs/Verification/SLICE-002/README.md`; the final committed-source rerun, evidence audit, and independent re-review remain pending. Do not distribute `artifacts/publish/linux-x64`; it is local verification output, not a supported release.
