# SLICE-001 M2 Snapshot and Lifecycle Integration

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Deterministic integration evidence passes; the later reviewed runtime matrix is recorded in `M0-RUNTIME-PLAN.md`.

## Change boundary

M2 adds the production snapshot mapper, coordinator, activation and refresh policies, source-opening completion token, mapped mutation hooks, explicit refresh route, and privacy-safe `Unavailable` conversion. The runtime unit is the managed StaxRip application. The touched external-tool boundary is none: project checks read bounded in-memory values and do not start, select, update, or inspect an executable.

The feature remains transient. It does not change project, settings, template, profile, job, script, command, temp, target, output, package, native FrameServer, or release formats.

## Independent findings and fixes

Independent lifecycle and presentation reviews found six integration findings before this evidence passed:

1. An unconditional refresh could evaluate from `Hidden` and bypass source, job, batch, UI-thread, and startup `-NoFocus` authority.
2. A mutation that began and ended during mapping or evaluation could allow an old result to publish. The original deterministic probe reproduced `stale=True`.
3. Production snapshot mapping did not yet have product-assembly evidence.
4. **Medium:** Process cleanup ran before source and clearing-mutation balance. If cleanup threw, the feature-owned counters could remain active.
5. The Assistant remained narrowed to three columns while project checks were Hidden even though the existing four-column width was available.
6. **Medium:** A mutation Begin wrapper incremented coordinator depth before rendering. If rendering threw before the caller entered its `Try/Finally`, the matching End call could be skipped.

The bounded remediation is:

- `ProjectCheckRefreshPolicy` accepts only `Available`, `RefreshRequired`, or `Unavailable` with zero source and mutation depth, UI-thread entry, and no job, batch, or `-NoFocus` suppressor.
- The coordinator rejects refresh from `Hidden` and while a mutation is active.
- Clearing and invalidating mutations have separate balanced counters. Mismatched end calls fail closed.
- Each mutation advances the generation and revokes an unused initial-evaluation capability.
- Only the outermost clearing completion can issue an initial-evaluation generation token.
- Initial evaluation requires that exact pending token. The token is consumed before mapping.
- Mapping and evaluation run outside the coordinator lock. Publication requires the observed generation to remain current and both mutation counters to be zero.
- The whole source-opening attempt reserves source and mutation depth before save, recovery, or processing work and balances both in `Finally`.
- Source-depth decrement and clearing-mutation completion run before `ProcController.Finished`. Process cleanup sits in an inner `Finally`, so it cannot skip the feature-owned balance.
- Project replacement, source indexing, active target, active muxer, cover configuration, and active encoder replacement use the mapped clearing or invalidating scopes.
- Both mutation Begin wrappers catch a rendering failure, end the exact coordinator mutation they began, and rethrow. Callers retain their normal `Try/Finally` balance after a successful Begin.
- The summary remains attached in the fourth bottom cell. Rendering gives the Assistant all four columns while the state is `Hidden` and three columns for visible project-check states.

The regression suite includes a complete begin/end mutation cycle during an in-flight refresh, invalidation of an unused initial token, and mismatched clearing and invalidating end calls.

## Deterministic evidence

### Pure and coordinator harness

Fresh Debug x64 and Release x64 harness executables produced the same bounded output:

```text
PASS ProjectCheckEvaluatorTests assertions=12199 activation_vectors=8192 refresh_vectors=1280
```

The 8,192 activation vectors cover four source depths, four mutation depths, and all 512 Boolean masks. Exactly one vector is accepted. The 1,280 refresh vectors cover five presentation kinds, four source depths, four mutation depths, and all 16 Boolean masks. Exactly three vectors are accepted, one for each permitted non-hidden presentation kind.

### Production-source contract

Command:

```text
Source\Tests\ProjectChecks\Verify-ProjectCheckIntegration.ps1
```

Bounded output:

```text
PASS project-check-integration source_assertions=87 project_assignments=3 indexing_mutation_scopes=4
```

This source check verifies the mapped assignment counts, self-balancing mutation Begin wrappers, balanced source and mutation scopes before process cleanup, success-only completion placement, startup suppression, coordinator capabilities, stale-publication guard, fixed menu wiring, selected production row, four-column Hidden and three-plus-one visible layouts, dynamic result accessibility text, stale-details closure, high-contrast button borders, position opt-out, privacy boundaries, and one production compile entry per feature file. It is static evidence, not source-opening branch activation.

Direct `Source/StaxRip.vbproj` rebuilds pass in Debug x64 and Release x64 with package restore disabled after the final GUI fixes. `Source/StaxRip.sln` rebuilds also pass in Debug x64 and Release x64, including `FrameServer.dll` and `StaxRip.exe`. The existing solution Release x64 mapping builds the managed StaxRip project as Debug x64; that historical upstream mapping was reported and not changed. The separate direct Release x64 project rebuild supplies the managed Release evidence.

The first solution rebuild attempt failed because the task-owned production UI probe still held `Source/bin/StaxRip.exe`. The probe exited normally, releasing the expected assembly lock, and the unchanged solution commands then passed. This was a verification-process ordering failure, not a product compile failure. These builds prove compilation in the named configurations. They do not prove source-opening or GUI runtime behavior.

### Product-assembly mapper and coordinator probe

An ignored package-free .NET Framework 4.8 x64 probe loaded the isolated Debug x64 production assembly without constructing the main window or launching StaxRip. Two consecutive runs produced the same bounded result:

```text
IDENTITY sha256=D41F6CCF86EAA67849CE4205C5629046784826BDEE783636284CF5D6C5A7177E length=3901440 mvid=3fa10b3e-4a88-4104-831b-db85f41a585f pe=PE32Plus machine=AMD64 process=x64 configuration=Debug
MAPPING source-target=distinct+identical target=valid+invalid cover=na+valid+invalid+unknown
COORDINATOR initial-token=accepted hidden-refresh=rejected available-refresh=accepted unavailable-refresh=accepted active-clearing=no-calls active-invalidating=no-calls stale-token=no-calls
FAULTS mapper=actual-null-project evaluator=injected null-factory=covered null-evaluator=covered state=same-unavailable prose=absent mutation-fields=175
BOUNDARIES window-handle=none new-staxrip-processes=0 probe-root-file-delta=0
PASS ProjectCheckIntegrationProbe assertions=1999 skips=0
```

The probe verifies exact binary source-target mapping, target-character mapping, bounded MKV cover mapping, capability enforcement, mapper and evaluator fault convergence, absence of exception prose, and unchanged values for 175 shallow project fields. It does not execute a successful source-opening transaction or prove visible GUI behavior.

Probe source identity:

```text
Program.cs                              34A8E386259B8C2DA60A0EE918DF517F1EDB741098F4E394F0F1278BBDEFCF5A
ProjectCheckIntegrationProbe.csproj    936DF9B11A7534E2E5085C7E7A16A9DA4A4B0027C29D803217E5D8DFD57419A8
```

## Security, privacy, logging, and failure impact

- Project-check mapping and evaluation add no log, telemetry, clipboard, network, process, package, or filesystem call.
- Results and failure states contain no path, media title, script, command, external output, or exception prose.
- Mapper or evaluator failure becomes the same payload-free `Unavailable` state and does not replace the loaded project.
- A presentation failure during either mutation Begin wrapper balances the exact coordinator depth and then rethrows into the existing application failure route. It is not converted to `Unavailable` or silently swallowed.
- Publication and rendering remain outside the narrow mapper/evaluator catch, as required by D-036.

## Remaining boundary

- **unknown:** Real success, abort, failed-later-open, nested event-command, and interactive refresh outcomes in an isolated portable runtime.
- **unknown:** Production GUI publication, keyboard, UI Automation, high contrast, and physical DPI behavior.
- **unknown:** External hostile in-process reflection can bypass repository-owned mutation hooks.
- No successful real `ProcessJob` equivalence is claimed or required by D-037.

Rollback removes the feature-owned production files and reverses only the mapped lifecycle hooks and compile entries. It does not require data migration because no project-check state is persisted.
