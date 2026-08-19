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
