# S-PORT-02 Verification Record

Version: 0.1. Date: 2026-08-19. Started at base `9cc9bd37`.

## Unit 1: typed payload, normalizer, privacy guard

Delivered under the ratified definition of done in the adapter contract, in this order,
with the evidence quoted from the actual runs.

**Red first.** The eight new cases were written against the committed goldens with the
normalizer as a throwing stub, and the harness was observed failing before any
implementation existed: `FAIL port-contract case=CT-015 type=NotImplementedException`,
exit 1.

**Green.** After implementation, both configurations pass identically:
`PASS port-contract cases=31 assertions=455 failures=0` in Debug and in Release. The
first green attempt failed honestly on a real defect in the tests themselves: a
whole-record equality over the payload compared its immutable-array members by backing
reference, which can never pass, so the cross-range assertion was rewritten per section
with sequence equality. That failure is recorded because the fix changed what the
assertion proves.

**Mutation proofs, each observed and restored.**

- Guard neutralized: `FAIL case=CT-020, banned field survived the guard: UniqueID`.
- Silent default injected: `FAIL case=CT-019, vfr frame rate value must be absent,
  never a default`.
- Canonical range map flipped: `FAIL case=CT-017, canonical colour range,
  expected canonical limited actual full`, caught by a real captured golden value.

After restoration both configurations returned to `cases=31 assertions=455`. The proofs
are wired in permanently: CT-017, CT-019, CT-020, and CT-021 re-run on every gate pass.

**A process failure during the proofs, recorded because it will recur elsewhere.** The
mutation reverts used version-control checkout, which cannot restore an untracked file,
so all three mutations silently persisted and the restored-state run caught it by
failing. Restoration was completed by inverse edit and verified green. The rule this
teaches: run revert-mutations only against a committed baseline, or verify restoration
by a green run rather than trusting the revert, which is what saved this unit.

**Baseline pins.** The reviewed contract baseline moved from 23 cases and 309 assertions
to 31 and 455 in `Verify.ps1` and `Verify-Evidence.ps1`, in the same change as the cases
themselves, per the test-change policing rule. Nothing was skipped, weakened, or
re-recorded; the eight added cases are additive. Two further pins were missed in that
change and caught one sweep apart: the static gate carries its own reviewed test-id
baseline, and the evidence audit carries an independent copy of the same list that it
compares against the static gate's published record. Each failure listed the expected
and actual sets; the actual set was in both cases the reviewed twenty-three plus exactly
the eight manifest-recorded additions. After the second catch the worktree was searched
for the old id list, which located every copy: manifest, test source, static gate,
audit, four sites total, all now moved. The misses confirm the pins are genuinely
independent recorders, and the rule they teach: a pin update is located by searching
the gates for the old value, never by memory of where the pins live.

## Deliberate scope boundaries in this unit

- Chapters are absent from the payload because no committed fixture carries chapters;
  the fixture-first rule forbids shipping a field no golden can assert.
- Subtitle normalization has no golden either; it is covered by the synthetic document
  in CT-020 and CT-021, which is the sanctioned vehicle for shapes real captures cannot
  yet produce. A subtitled fixture upgrade replaces the synthetic coverage when it lands.
- The platform adapter and any process execution remain unimplemented; the port
  interface exists, and the gates are its only caller until D-046 enforcement code
  ships with the endpoint.

**A second process failure, caught before the sweep.** The unit's local builds ran
without `--no-restore`, and the implicit restore silently rewrote all five
`packages.lock.json` files, dropping the `net10.0/linux-x64` target sections the
dependency audit derives its closure from, and the damaged locks were committed. The
repair restored the audited-good locks, validated them through the reviewed locked-mode
restore gate, which passed its full 398 checks without rewriting them, and re-ran both
test configurations under `--no-restore`. The rule this teaches, now binding for local
work in this repository: a build is not a neutral act where lock files are audited
evidence; every local build runs `--no-restore`, and restore happens only through the
reviewed gate.

**A third process failure, introduced by a repair and caught by the fixture manifest.**
The static gate failed naming exactly one file, this document, as lacking a final
newline. The repair swept every changed file instead and appended a newline terminator
to any file not ending in one, which appended two bytes to three binary media fixtures,
breaking their recorded manifest hashes; the damage was committed and pushed before
being noticed. The fixtures were restored from their committed originals and all four
hashes re-verified against the manifest. The rule this teaches: a fix targets exactly
the set the gate names, because a wider sweep re-derives the gate's file classification
without its exclusions, and binary artifacts under a text rule are mutated every time.

## Unit 1 validation sweep

Run against committed head `313979bb` on 2026-08-19, all six gates in order, each
against the same committed state:

```
PASS port-static        checks=200
PASS port-verify        checks=919
PASS port-http-windows  checks=4554
PASS port-browser       checks=694
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=63818
```

Audit record `evidence-audit.json` sha256
`0d823e32cde9c43785d062e82279cb441c4dd4d757956194a0320ffbc052be5f`. The sweep reached
green on its fifth attempt; the four failed attempts were each stopped by a gate naming
a real defect, and every catch and repair is recorded above. This section postdates the
audited set by construction, since the audit hashed this document as it stood at
`313979bb`; the section records the audit, it is not covered by it.

## Unit 2: the bounded-execution primitive

The one process-execution path of the cross-platform tree, in `StaxRip.Platform`,
implementing the D-045 bounds the adapter contract requires: explicit fully qualified
executable path with no search, argv vector with no shell, hard wall-clock timeout,
per-stream output byte caps, and kill-the-tree-then-reap on every failure path. The
ownership receipt crosses as data: the typed exception carries the killed process id,
never in its message, and the reason classes are the ratified vocabulary. A nonzero
exit code is a result, not an error; that judgment belongs to the caller.

**Red first.** CT-023 through CT-028 were written against a throwing stub and observed
failing: `FAIL port-contract case=CT-023 type=NotImplementedException`, exit 1. The
cases drive the primitive through this test binary re-invoked as a controllable child,
which keeps the corpus deterministic with no external tool dependency.

**Green, with one honest failure on the way.** The first implementation run failed
CT-023 on the unicode argument: a redirected console child writes the platform codepage
by default while the capture contract is UTF-8, so the child fixture now declares UTF-8
explicitly, which is also what the real tool emits. Both configurations then pass:
`PASS port-contract cases=37 assertions=486 failures=0`.

**A design flaw found by the mutation exercise, not by the tests.** The second
mutation, neutralizing the kill, did not turn the harness red on the first attempt; it
hung it. The emit child blocked forever writing to a full pipe, and the reap was an
unbounded wait, so a silently failed kill would wedge the caller behind a child that
never exits. The reap is now bounded at fifteen seconds and a surviving child surfaces
as typed `reap-failed`, the one reason class whose receipt names a process that may
still be alive. The bound is unreachable after a successful tree kill; it exists for
exactly the failure the mutation simulated.

**Mutation proofs, each observed against the committed baseline and restored by
checkout, per the unit 1 rule.**

- Overflow bound neutralized: `FAIL case=CT-025, overflow must throw typed,
  expected BoundedProcessException actual no exception`.
- Kill neutralized: `FAIL case=CT-025, overflow reason class, expected output-overflow
  actual reap-failed`, red in fifteen seconds where the unbounded reap had hung.
- Path rejection neutralized: `FAIL case=CT-028, bare name reason class, expected
  executable-path-not-absolute actual executable-missing`, proving the no-search rule
  rejects before the filesystem is consulted.

After restoration both configurations returned to `cases=37 assertions=486`, and no
orphaned child processes remained. All six policing pins moved in the same commit as
the cases: manifest, test source, wrapper counts, audit counts, and both reviewed id
lists.

**The boundary law, amended deliberately, not eroded.** The validation sweep stopped on
the bootstrap's boundary ban: product source may not use process APIs, and the
primitive exists to use them. That collision is the ratified D-045 decision meeting the
gate that predates it, and the resolution follows the adapter contract's own words for
D-046: the rule is replaced deliberately. The static gate now sanctions process APIs in
exactly one named product file, the primitive, which keeps every other ban including
all filesystem access except the single `File.Exists` its no-search rule requires. The
carve-out resolver fails when the named file is absent, so the exemption cannot outlive
the file. Four proofs, run and restored:

- With the primitive present, the amended gate passes: `PASS port-static checks=210`.
- A `Process.Start(` token added to a Core file stops the gate via the Core layer rule,
  which fires before the product ban.
- The same token added to a Server file, which no layer rule covers, stops the gate via
  the product ban itself, naming the file.
- An `HttpClient` token added to the primitive stops the gate naming the primitive,
  proving the narrowed ban inside the sanctioned file is load bearing.

## Unit 2 validation sweep

Run against committed head `8f40096a` on 2026-08-19, all six gates in order:

```
PASS port-static        checks=200 -> 210 under the amended boundary law
PASS port-verify        checks=981
PASS port-http-windows  checks=4554
PASS port-browser       checks=694
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=63962
```

Audit record `evidence-audit.json` sha256
`a497f35788e408df8a1a53141f60f3c1171ea4aec918ed4700a381cf75e53645`. Green on the third
attempt; the two failed attempts were the static gate naming the non-ASCII fixture
literal and the boundary crossing, both recorded above with their resolutions. This
section postdates the audited set by construction; it records the audit, it is not
covered by it.

## Unit 3: the MediaInfo CLI adapter

The primary implementation of the authority port, in `StaxRip.Platform`, owning
exactly two things: the recorded invocation shape, one flag and the media path as a
single argv element per the committed fixture manifest, and the mapping from execution
outcomes to the ratified reason classes. It executes only through the bounded
primitive. The typed error, `MediaFactAuthorityException` beside the port in core,
carries a reason class alone: resolver-failure, timeout, output-overflow, nonzero-exit,
execution-failure. A child killed on cancellation surfaces as cancellation, not as an
error, because the kill and reap already happened and the caller asked for it.

**Red first.** `FAIL port-contract case=CT-029 type=NotImplementedException`, exit 1.

**Hermetic corpus.** CT-029 through CT-033 spawn this test binary as the impersonated
tool: it answers only the exact recorded invocation, one flag and one path, and rejects
anything else with a diagnostic exit. That rejection is what makes the invocation shape
load bearing rather than asserted. The golden pass-through case feeds the adapter's
verbatim document to the real normalizer and asserts known golden facts, so the
adapter-to-normalizer seam is exercised, not assumed. Exact reason-class equality is
the sanitization proof: the fake writes detail to its error stream that must never
surface. The real tool never runs in these cases; that integration belongs to the
port-inspection gate. Green in both configurations:
`PASS port-contract cases=42 assertions=500 failures=0`.

**Mutation proofs, each observed against the committed baseline and restored.**

- Invocation flag drifted to `--Output=XML`: `FAIL case=CT-029`, the impersonated tool
  rejects the drifted shape and the case fails on the resulting typed error.
- Nonzero-exit mapping removed: `FAIL case=CT-030, nonzero exit must throw typed,
  expected MediaFactAuthorityException actual no exception`.
- Cancellation collapsed into an error class: `FAIL case=CT-032`, the case demands the
  runtime's cancellation exception and receives the typed error instead.

After restoration both configurations returned to `cases=42 assertions=500`, no
orphaned children. All six policing pins moved in the same commit as the cases. One
proof-harness slip is recorded because the guard that caught it earned its keep: the
first flag-drift attempt bound both replacement strings to one parameter through a
stray list comma, and the missed-anchor guard refused to run a proof that would have
mutated nothing, which is exactly the check-that-cannot-fail rule applied to the proof
machinery itself.

## Unit 3 validation sweep

Run against committed head `c10823e6` on 2026-08-19, all six gates in order, green on
the first attempt, the first sweep of this slice with no gate catch:

```
PASS port-static        checks=219
PASS port-verify        checks=1009
PASS port-http-windows  checks=4554
PASS port-browser       checks=694
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64104
```

Audit record `evidence-audit.json` sha256
`7bd650ce608a3c1f9744c57e1c933c75cafa0b94a7a93f967e56f9679ef89971`. This section
postdates the audited set by construction; it records the audit, it is not covered by
it.

## Unit 4a: the D-046 path policy engine, the pure half

The ratified path acceptance policy as pure string judgment in core: configured media
roots with an admit-nothing empty default, canonical containment judged on exactly one
spelling of each path, and a bare boolean verdict with no reason classes at all, so
the rejection shape cannot be used to probe the policy. The engine never touches the
filesystem, which makes the ratified no-existence-oracle property hold by
construction rather than by discipline. The regular-file requirement needs a
filesystem probe and belongs to unit 4b, behind this check, alongside the endpoint
whose route additions move the pinned route baselines. Deliberate strictness, recorded
here because each rejects something a looser policy would admit: the caller presents
the canonical spelling or is refused, so a traversal that would land inside a root is
refused for its spelling alone; a trailing separator is refused explicitly because
canonicalization preserves it; a colon is admitted only as a drive prefix's second
character, which refuses device names and alternate stream spellings in one rule; UNC
and extended-prefix namespaces are outside the v1 policy; and a configured root that
is not itself canonical is dead, never repaired, because repairing configuration would
move a security boundary somewhere the operator did not write down.

**Red first.** `FAIL port-contract case=CT-034 type=NotImplementedException`, exit 1.

**Green.** CT-034 and CT-035, an eighteen-shape hostile corpus plus the containment
and empty-default asserts, pass in both configurations:
`PASS port-contract cases=44 assertions=522 failures=0`.

**Mutation proofs, each observed against the committed baseline and restored.** The
corpus design earned its keep here: each mutation was caught by a different named
shape.

- Canonical spelling rule removed: `FAIL case=CT-035, hostile shape was admitted:
  index 4`, the dot-segment traversal.
- Containment separator rule neutralized: `FAIL case=CT-035, hostile shape was
  admitted: index 16`, the sibling-root prefix trap.
- Empty default flipped to admit: `FAIL case=CT-035, the empty default policy
  admitted a path`.

After restoration both configurations returned to `cases=44 assertions=522`. All six
policing pins moved in the same commit as the cases.

## Unit 4a validation sweep

Run against committed head `5406ad1b` on 2026-08-19, all six gates in order, green on
the first attempt, the second consecutive no-catch sweep:

```
PASS port-static        checks=225
PASS port-verify        checks=1053
PASS port-http-windows  checks=4554
PASS port-browser       checks=694
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64240
```

Audit record `evidence-audit.json` sha256
`7f7ccf48073944eece9220f78090a0864d984095bf4b0b6fd9d888a6b3cc5641`. This section
postdates the audited set by construction; it records the audit, it is not covered by
it.

## Unit 4b, first half: the regular-file probe and the second sanctioned crossing

The filesystem half of D-046: a path the pure policy admitted must also name an
existing ordinary file. The probe is the boundary law's second named crossing,
narrowed to file-metadata reading and nothing else; process APIs and every File static
stay banned inside it. Proven in four directions against the committed baseline and
restored: the gate passes at 230 checks with both crossings present; a `FileInfo`
token in a Server file stops the gate naming that file; a `Process` token and a
`File.ReadAllText` token inside the probe each stop the gate naming the probe.

**Red first.** `FAIL port-contract case=CT-036 type=NotImplementedException`, exit 1.
CT-036 drives the probe from the committed fixture tree, nothing created or deleted:
the media fixture is the file, the fixture directory is the directory, an impossible
child of a file is the through-a-file shape.

**Two equivalent mutants, and what they taught.** The first two mutation attempts,
removing the existence check and removing a directory-attribute refusal, both
survived: every case stayed green. Diagnosis, not dismissal: `FileInfo.Exists` is
false for a directory, so the separate directory branch was unreachable dead code; and
a missing file reads its attributes as all bits set, so the reparse refusal also
refuses absence. The false verdicts were real but flowed through different branches
than the code claimed. The probe was rewritten to say what is true, the dead branch
removed and the two refusal mechanisms documented at the check that owns them. The
surviving proof is the verdict flip: `FAIL case=CT-036, committed media fixture must
be a regular file, expected True actual False`, red then restored green at
`cases=45 assertions=527` in both configurations.

**A process failure repeated, and its rule now absolute.** The first proof attempt ran
gate mutations while the probe was still untracked; checkout could not restore it and
both mutation comments accumulated, caught by inspecting the file. This is the unit 1
lesson recurring at the first opportunity: revert-mutation proofs run against
committed state only, with no exception for one-line comment probes. The reparse
refusal remains gate-proven territory: the contract corpus cannot produce a junction,
and the port-inspection gate can and will.

## Unit 4b first-half validation sweep

Run against committed head `30cfcc0c` on 2026-08-19, all six gates in order, green on
the first attempt, the third consecutive no-catch sweep:

```
PASS port-static        checks=230
PASS port-verify        checks=1063
PASS port-http-windows  checks=4554
PASS port-browser       checks=694
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64374
```

Audit record `evidence-audit.json` sha256
`764acad45366d6ef32e9072d272dfefded73b6006df4c2372c0cd81b7ac201d1`. This section
postdates the audited set by construction; it records the audit, it is not covered by
it.
