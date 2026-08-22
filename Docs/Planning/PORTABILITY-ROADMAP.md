# StaxRip Community Portability Roadmap

Version: 0.2. Date: 2026-08-16. Direction: Linux now, macOS later.

## Outcome

StaxRip keeps its current Windows x64 application while a separate modern engine becomes usable from a local web shell and, later, a native cross-platform client. The port reuses external encoders and script engines through explicit adapters. It does not rewrite codecs or send user media to a service.

Stages 1 and 2 are complete as of 2026-08-22, superseding this paragraph's earlier NO-GO status. Stage 1 closed with all forty-seven review findings resolved and a passing final audit. Stage 2 closed with read-only media inspection reaching typed facts over real HTTP, then reopened once for a certification repair an independent review found, and re-closed at 1.4 Final: seven gates green, an evidence audit certifying the set, the configured pipeline proven on Linux with the real floor tool, goldens proven host-independent on an independent bare-metal host, and a Windows comparison at matched library versions with zero value disagreements. This remains a capability result on two Linux hosts, not Linux product support: no encode authority exists yet, and Stage 3 is the next slice.

## Architecture direction

```text
WinForms client (current)       Web shell (first)       Native client (later)
           \                         |                         /
            +--------------- versioned local API ------------+
                                      |
                              application coordinator
                                      |
                 contracts and platform-neutral workflow core
                                      |
              process | tools | scripts | storage | native adapters
                                      |
                     Windows | Linux | macOS operating systems
```

The ComfyUI comparison applies to local startup, browser access, visible work state, and an extensible service boundary. It does not select a node canvas, arbitrary Python execution, a remote service, or an untrusted plugin model.

## Sequence

| Stage | User value | New authority | Main proof |
|---|---|---|---|
| 1. Linux engine bootstrap | Opens a distinctive local StaxRip shell and reports honest host capabilities | Loopback HTTP only | Security, redaction, no-write, no-child, Linux runtime |
| 2. Media inspection | Opens media read-only and shows streams, duration, dimensions, codecs, and probe failures | One approved probe process | Hostile paths, bounded parser, cancel, no child leak, Windows comparison |
| 3. Portable project model | Creates and validates a new cross-platform project representation | Optional new-format save; legacy import stays separate | Schema, validation, backup, downgrade, no legacy bytes over HTTP |
| 4. Script and command preview | Shows the exact planned graph, scripts, tools, and argv | No execution | Golden Windows/Linux fixtures and rule ownership |
| 5. Single Linux encode | Runs one approved pipeline with progress and cancel | Process, temp, output publication | Process group, no-clobber, failure matrix, deterministic media oracle |
| 6. Workflow and queue | Adds jobs, resource limits, restart recovery, and better graph editing | Durable state and concurrency | State-machine, crash, idempotency, CPU/GPU/disk contention tests |
| 7. Windows parity adapter | Uses the proven core beside the current app | Controlled Windows rollout | Shadow comparisons and rollback without data conversion |
| 8. Native desktop client | Adds deeper desktop integration and accessibility | Desktop APIs | Linux and Windows UI/runtime proof; no duplicated engine rules |
| 9. macOS adapter | Runs supported workflows on macOS arm64 | macOS native and distribution boundaries | Real-host tools, UI, signing, notarization, clean install |
| 10. Public release | Publishes supported platform artifacts | Release and update authority | Provenance, SBOM, signatures, rollback, two-host Linux evidence |

## Parallel work that lowers future port cost

- Put new rules in UI-neutral typed modules. Keep forms and web rendering downstream.
- Represent processes as executable identity, separate argv, explicit environment changes, working directory, owned outputs, and cancellation policy.
- Replace ambient registry and global reads in new code with narrow platform interfaces.
- Keep path values structured until the final tool adapter. Do not normalize Windows and Unix paths through string replacement.
- Give every tool adapter a version policy, capability probe, executable source, license/provenance record, golden fixtures, and bounded diagnostics.
- Keep legacy readers behind a Windows-only compatibility adapter. Build a new versioned representation before considering new cross-platform persistence.
- Treat temp directories and outputs as capabilities with explicit ownership. Cleanup may remove only paths created and recorded by the current operation.
- Keep events structured and privacy-bounded. UI text, logs, and exception prose never become workflow truth.
- Test slow-host behavior on the T540p once access is available. Use the 5950X for fast matrices and GPU work, not as the minimum supported machine.
- Reuse the same immutable artifact across WSL and the independent Linux host so a rebuild cannot hide environmental differences.

## Near-zero-budget posture

- Use installed .NET SDKs and first-party projects with no project package references. Keep required self-contained runtime packs in an ignored repository-local cache and record their provenance.
- Use WSL for immediate Linux runtime proof and the existing network machine for a second host.
- Add hosted CI only after a focused build-security decision. Do not add release credentials or public publication in early slices.
- Prefer synthetic and tiny redistributable media fixtures. Do not commit user media, logs, paths, commands, or tool binaries.
- Keep macOS work deferred until stable contracts make scarce runner time useful.

## Success measures

- A clean Linux user can reach a truthful local shell without Windows compatibility layers.
- The same typed project and tool plan produces reviewed platform-specific scripts and argv.
- Cancellation leaves no owned child process, temp leak, or partial published output.
- Unsupported capabilities are visible before work begins and never silently substituted.
- Windows users retain current project and settings compatibility during migration.
- Each platform claim names its artifact, host tuple, tool versions, fixtures, and untested boundary.

## Deferred decisions

- Native client framework. Avalonia is the current candidate; it is not selected by the bootstrap.
- Linux distribution formats and system integration.
- macOS x64 demand and support.
- Plugin sandbox and extension API.
- Remote or multi-user access. The initial backend is local-only.
- Public release, update, signing, and tool bundling.

The detailed slice order is in `../Architecture/Repo-Slices.md`. Current unknowns are in `../Unknowns/Portability-Unknowns.md`.
