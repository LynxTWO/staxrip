# StaxRip Community Repository Slices

Version: 0.3. Date: 2026-08-16. Repository base: `940eaba1`.

This ledger breaks the current application and the portability target into reviewable units. A completed slice proves only its listed exit criteria.

## Slice entries

### S-PORT-01: Cross-platform bootstrap

- **Scope (repo paths):** `CrossPlatform/`; the SLICE-002 records under `Docs/Architecture/`, `Docs/Planning/`, `Docs/Review/`, `Docs/Unknowns/`, and `Docs/Verification/`; approved steering and repo-local anti-dark-code calibration. Current runtime code under `Source/` is excluded.
- **Why this slice:** It proves that an isolated engine host and first-party web shell can build on Windows and run on Linux without changing the current application.
- **Risk class:** high
- **Classification:** owned-clear, approval-gated
- **Related runtime units or flows:** Loopback host startup, browser session bootstrap, capability response, shutdown
- **Blockers:** The prior independent evidence review returned NO-GO and has been worked. The committed-source producer rerun and the bounded Restore failure challenge have completed. The `port-evidence` audit and an independent re-review remain. The two-direction Windows/WSL evidence-lock contention check passes. R-S2-039 blocks only the second Linux host; access to that host is no longer the obstacle.
- **Exit criteria:** Builds with no project `PackageReference` and an exact three-package signed Microsoft dependency closure derived from five reviewed asset and lock pairs; schema v2 separates registry, archive, signature, and extracted identities and binds the complete disk inventory by canonical SHA-256, count, and total bytes; contract tests pass; the self-contained Linux x64 output is ELF; it runs as non-root in WSL; socket is loopback-only; session, Host, Origin, redaction, bounded no-child, sandboxed no-write, clean-shutdown, and installed-browser checks pass. Restore holds the shared lease across its whole mutable workflow. The wrapper retains canonical `.port-verify-running` across all child steps, and the final auditor rejects it and case-drifted or nonempty task roots at its primary read and both closeouts. HTTP and browser verifiers register exact process ownership before readiness, cap live pipes, prove reap and empty task roots, and publish evidence only under the shared atomic lease. Legacy projects and solutions remain unchanged. LNX-019 may remain blocked through R-S2-039 without being reported as an independent-host pass.
- **Verification capability ids:** V03, V04, V05, V06, V08, V09, V10, V11, V12, V13, V15, V16, V17, V18, V19, V20
- **Confidence-ladder level:** 2
- **Exact gate or next check:** Latest provisional pre-freeze results are indexed by `../Verification/SLICE-002/README.md`; run every producer and final evidence from one committed checkpoint, then repeat the independent evidence review
- **Invalidated by:** Any file in `CrossPlatform/`; its target framework, endpoint contract, security middleware, static assets, or build scripts; or a change to the slice acceptance, verification, evidence, or unknowns records
- **Next pass:** Map S-PORT-02 read-only media inspection; repeat the immutable bootstrap artifact on an independent host whose unprivileged user units can obtain a private network namespace (R-S2-039)
- **Status:** in progress for final local acceptance; independent-host criterion blocked by R-S2-039

### S-PORT-02: Portable media inspection

- **Scope (repo paths):** Future cross-platform FFprobe adapter, typed media facts, fixtures, and read-only UI presentation
- **Why this slice:** Source inspection is the first useful workflow capability and can be separated from encoding and persistence.
- **Risk class:** high
- **Classification:** owned-risky, approval-gated
- **Related runtime units or flows:** Source selection, path validation, FFprobe execution, bounded progress, cancellation, media-fact rendering
- **Blockers:** P-001, P-003, and the FFprobe row of P-004
- **Exit criteria:** One explicit version range and resolver for the ratified primary authority, the MediaInfo CLI (D-045), are approved; argv and output schemas have golden fixtures; hostile paths and malformed output pass; cancellation leaves no process; no project or output file is written; Windows comparison records agreed facts; the identifier-stripping privacy guard has a self-test that fails if the stripping is removed.
- **Verification capability ids:** V01, V02, V04, V05, V06, V08, V09, V10, V11, V12, V14, V17, V18
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Map, agreed-facts list, D-045 ratification, tool-matrix row, and adapter contract complete. Next: maintainer ratifies D-046 path policy and approves tool acquisition, then fixture capture and the Contracts payload under the port-inspection gate plan
- **Invalidated by:** Probe executable/version, schema, resolver, process runner, path policy, or media-fact contract changes
- **Next pass:** 02 architecture map
- **Status:** in progress

### S-PORT-03: Portable workflow representation

- **Scope (repo paths):** Future versioned JSON representation, validators, legacy import adapter, and synthetic compatibility corpus
- **Why this slice:** The engine needs a typed cross-platform source of truth that is not the legacy BinaryFormatter object graph.
- **Risk class:** critical
- **Classification:** owned-risky, approval-gated
- **Related runtime units or flows:** New project creation, legacy import, validation, preview, future save and downgrade
- **Blockers:** P-001 and P-002
- **Exit criteria:** Schema, versioning, unknown-field, validation, import, backup, downgrade, and no-clobber rules are approved; legacy bytes never cross HTTP; synthetic fixtures cover every retained field; no legacy writer changes without separate evidence.
- **Verification capability ids:** V01, V02, V03, V04, V05, V06, V07, V08, V09, V12, V13, V14, V17, V18, V19
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Complete the persistence reader/writer and subtype map
- **Invalidated by:** Legacy serialized types, schema, importer, validator, project identity, or write policy changes
- **Next pass:** 02 architecture map
- **Status:** open

### S-PORT-04: Command and script preview

- **Scope (repo paths):** Future typed tool plan, AviSynth and VapourSynth renderers, argv renderer, and golden fixtures
- **Why this slice:** Users need to inspect the exact planned scripts and commands before the engine gains execution authority.
- **Risk class:** high
- **Classification:** owned-risky, approval-gated
- **Related runtime units or flows:** Tool selection, filter graph, script rendering, command preview
- **Blockers:** P-003 through P-005 and S-PORT-03
- **Exit criteria:** Script and argv structures are separated from display text; no shell string is authoritative; Windows and Linux golden fixtures are reviewed; previews redact only diagnostics, not the user's own explicit command view; no process starts.
- **Verification capability ids:** V01, V02, V04, V05, V06, V08, V09, V12, V14, V17, V18
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Map one current encode command and one script path end to end
- **Invalidated by:** Tool version, script engine, macro, path, quoting, renderer, or filter-rule changes
- **Next pass:** 02 architecture map
- **Status:** open

### S-PORT-05: Single-job Linux execution

- **Scope (repo paths):** Future process runner, process group, cancellation, owned temp area, atomic publication, one approved encode adapter, and event stream
- **Why this slice:** It introduces the smallest real encode authority after inspection and preview contracts exist.
- **Risk class:** critical
- **Classification:** owned-risky, approval-gated
- **Related runtime units or flows:** Start, progress, cancel, failure, cleanup, output publication
- **Blockers:** P-003 through P-005 and S-PORT-02 through S-PORT-04
- **Exit criteria:** Exact PID, start time, executable identity, and argv are registered before readiness; stdout and stderr are bounded while read; hostile paths pass; cancellation revalidates identity and terminates the full owned process group; failure never publishes partial output; cleanup touches only owned paths and proves empty task state; restart behavior is explicit; one real fixture matches its approved media oracle.
- **Verification capability ids:** V01 through V19 except any capability recorded not applicable in the slice plan
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Write and approve the process, path-ownership, and publication invariants before code
- **Invalidated by:** Runner, adapter, signal, timeout, temp, output, retry, or tool-version changes
- **Next pass:** 07 adversarial review
- **Status:** open

### S-PORT-06: Queue, recovery, and parallel work

- **Scope (repo paths):** Future portable queue, scheduler, recovery journal, resource model, and UI
- **Why this slice:** Multi-job work introduces concurrency and durable recovery beyond single-process execution.
- **Risk class:** critical
- **Classification:** owned-risky, approval-gated
- **Related runtime units or flows:** Queue mutation, scheduling, crash recovery, GPU and disk arbitration, pause and cancel
- **Blockers:** S-PORT-05 plus a separate persistence and concurrency approval
- **Exit criteria:** State machine and crash matrix pass; idempotency and no-double-start rules are tested; CPU, GPU, disk, and process limits are configurable; recovery never guesses publication state.
- **Verification capability ids:** V01 through V19
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Model-check the queue state machine before implementing concurrency
- **Invalidated by:** Queue schema, state transition, lock, retry, recovery, resource, or publication changes
- **Next pass:** 08 scenario stress-test
- **Status:** deferred

### S-PORT-07: Windows core adapter and parity

- **Scope (repo paths):** Future WinForms anti-corruption adapter and modern Windows tool adapters
- **Why this slice:** The portable core must be proven against current Windows outcomes without forcing the existing GUI to migrate first.
- **Risk class:** high
- **Classification:** legacy-unclear, approval-gated
- **Related runtime units or flows:** Source inspection, preview, one-job execution, existing project compatibility
- **Blockers:** Stable contracts from S-PORT-02 through S-PORT-05
- **Exit criteria:** Paired Windows old/new results pass for approved fixtures; rollout can be disabled without converting user data; current WinForms remains usable; unsupported differences are named.
- **Verification capability ids:** V01, V02, V03, V04, V05, V06, V07, V08, V09, V12, V13, V14, V17, V18, V19
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Select a read-only shadow comparison before routing authority to the new core
- **Invalidated by:** Legacy workflow owner, portable contract, adapter, fixture, tool, or rollout flag changes
- **Next pass:** 08 scenario stress-test
- **Status:** deferred

### S-PORT-08: Native desktop client

- **Scope (repo paths):** Future cross-platform desktop UI and accessibility fixtures
- **Why this slice:** A native client can provide desktop integration while the web shell remains a local lightweight client.
- **Risk class:** high
- **Classification:** owned-clear
- **Related runtime units or flows:** Project editing, workflow graph, queue, progress, previews, accessibility, desktop integration
- **Blockers:** P-010 and stable UI-neutral contracts
- **Exit criteria:** An early disposable feasibility spike records Linux display, keyboard, accessibility-tree, scaling, and packaging behavior after media inspection exists. A later Linux and Windows production decision requires real runtime evidence and one representative workflow with keyboard, screen reader, high contrast, scaling, and low-resource checks. macOS UI and runtime validation remains owned by S-PORT-09 and cannot be inferred from that decision. No engine rule is duplicated in controls.
- **Verification capability ids:** V01, V02, V04, V05, V08, V09, V11, V12, V14, V17, V18
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Avalonia prototype after portable media inspection is complete
- **Invalidated by:** UI framework, API contract, accessibility rule, renderer, or deployment changes
- **Next pass:** 07 adversarial review
- **Status:** deferred

### S-PORT-09: macOS runtime and distribution

- **Scope (repo paths):** Future macOS adapters, native dependencies, desktop client, packaging, signing, and notarization
- **Why this slice:** macOS requires runtime and distribution proof that Linux and Windows cannot provide.
- **Risk class:** high
- **Classification:** cross-repo-boundary, approval-gated
- **Related runtime units or flows:** All approved portable flows on macOS arm64, optional x64, signing and launch
- **Blockers:** P-008, macOS runner access, and stable Linux contracts block the local macOS adapter and runtime work. P-009 blocks distribution, not a local macOS test artifact.
- **Exit criteria:** Supported versions and architectures are named; tools and native libraries pass; signed and notarized test artifact runs on a clean host; unsupported features fail honestly; rollback is documented.
- **Verification capability ids:** V01, V02, V03, V04, V05, V06, V08, V09, V11, V12, V14, V17, V18, V19
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Acquire a macOS arm64 runner and execute the capability and tool matrix
- **Invalidated by:** macOS version, architecture, entitlement, certificate, native dependency, UI, or packaging changes
- **Next pass:** 08 scenario stress-test
- **Status:** deferred

### S-PORT-10: Public cross-platform release

- **Scope (repo paths):** Future CI, artifact assembly, dependency provenance, SBOM, signing, release notes, update and rollback
- **Why this slice:** Local test artifacts do not establish a safe public distribution contract.
- **Risk class:** high
- **Classification:** approval-gated, external-control-plane
- **Related runtime units or flows:** Build, sign, publish, download, update, downgrade, support
- **Blockers:** U-001, U-006, U-009, P-009, and platform runtime evidence
- **Exit criteria:** Reproducible artifact identities, provenance, licenses, SBOM, signatures, clean-host runs, update and downgrade rules, rollback, and publication approval are recorded.
- **Verification capability ids:** V01, V02, V03, V04, V05, V06, V08, V09, V11, V13, V14, V17, V18, V19, V20
- **Confidence-ladder level:** 3
- **Exact gate or next check:** Approve a release-specific slice after two-host Linux evidence
- **Invalidated by:** Build image, SDK, tool bundle, dependency, signing, packaging, update, or publication workflow changes
- **Next pass:** 07 adversarial review
- **Status:** deferred

## Slice order

1. S-PORT-01, prove the isolated runtime and trust boundary.
2. S-PORT-02, deliver read-only media inspection.
3. S-PORT-03, establish portable project truth without changing legacy writers.
4. S-PORT-04, show exact scripts and argv before execution.
5. S-PORT-05, execute one Linux job with strict ownership.
6. S-PORT-08 feasibility spike, test Linux display and accessibility after media inspection without selecting a production framework.
7. S-PORT-06 and S-PORT-07, add queue behavior and Windows parity after the single-job contract is stable.
8. S-PORT-08 production client, add a native client without moving engine rules into UI code.
9. S-PORT-09, adapt and verify macOS.
10. S-PORT-10, define public distribution only after runtime proof.

## Exclusions

- **Ignored `Source/bin` and bundled binaries:** Binary or asset-heavy. Describe them through a future provenance manifest, not source comment passes.
- **Generated designer and resource output:** Generated. Review ownership and user-visible contracts at the form or resource boundary.
- **Third-party tools and plugins:** Vendored or external. Record exact identity, license, and adapter behavior in the platform matrix.
- **External release and signing systems:** External control plane. Cover them with a release runbook and recorded provider evidence when authorized.
