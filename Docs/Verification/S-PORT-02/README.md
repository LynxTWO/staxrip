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
