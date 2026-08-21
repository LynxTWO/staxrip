# S-PORT-02 Verification Record

Version: 1.2 Final. Date: 2026-08-21. Started at base `9cc9bd37`; closed at 1.0 by
the exit-criteria review below with its attesting sweep; reopened and re-closed at
1.1 for the certification repair recorded and re-attested below; 1.2 adds the first
post-close fact, audio delay, with its own attesting sweep. The 1.0 feature closure
was never disproved; one concurrency invariant of the certification harness was, and
is repaired and proven.

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

## Unit 4b, second half part 1: the media-facts route and the amended request law

The transport decision D-046 needed: a media path crosses the server boundary in a
bounded JSON POST body on exactly one route, never in a query string or URL segment,
so user paths stay out of URLs, logs, and browser history. The bootstrap's request law
said GET-only, queryless, bodyless everywhere; the amendment is narrow and literal:
the media-facts route requires POST with a declared length within the transport bound
and the exact JSON content type, never chunked and never with a query, and every other
route keeps the full law. The Allow header on a 405 names the path's own method, keyed
on the path part alone, because a rejected query must not flip which method a path
claims to accept. The endpoint answers the session gate first, then says exactly that
the capability is unavailable without reading the body; no configuration path exists
yet, and inventing one belongs to the next unit.

**Red first.** `FAIL port-contract case=ST-003, route allowlist changed`: the tests
demanded the amended law before it existed. Green in both configurations:
`PASS port-contract cases=46 assertions=545 failures=0`.

**Pinned surfaces, all moved in the same commit.** The route allowlist and ST-003;
the ST-004 matrix, which gained ten body-law assertions; ST-010 over real loopback;
the static gate, whose route law now carries a one-entry literal POST inventory
beside the GET inventory with `MapPost` otherwise still banned and the published
routes record as the union; the audit's independent route copy; the http gate's
rejection matrix, rewritten per route with five new body-law cases and the
unconfigured endpoint contract, growing from 4554 to 5182 checks; and the count pins
at six sites. Static passed at 231 and the http gate at 5182 before the sweep.

**Mutation proofs, each observed against the committed baseline and restored.**

- Method map neutralized: `FAIL case=ST-004, well-shaped media-facts request rejected
  by the law`, 405 where the law must admit.
- Body bound removed: `FAIL case=ST-004, oversized body was not refused`.
- Content-type law loosened to the bare media type: `FAIL case=ST-004`, the exact
  charset-qualified value is load bearing, not merely the check's presence.
- Capability answer falsified to 200: `FAIL case=ST-010, unconfigured media-facts
  status, expected ServiceUnavailable actual OK`.

After restoration both configurations returned to `cases=46 assertions=545`.

## Unit 4b-2 part 1 validation sweep

Run against committed head `6f926dce` on 2026-08-20, all six gates in order, green on
the first attempt, the fourth consecutive no-catch sweep:

```
PASS port-static        checks=231
PASS port-verify        checks=1099
PASS port-http-windows  checks=5182
PASS port-browser       checks=691
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64378
```

Audit record `evidence-audit.json` sha256
`438eb090c88f2677999bc1f32f2a59c2a2820dd75c67261ec09c28728d1c18df`. This section
postdates the audited set by construction; it records the audit, it is not covered by
it.

## Unit 4b-2 part 2: the configured pipeline

The endpoint now does the work when configured. The handler reads the bounded body
trusting nothing beyond the declared length the request law admitted, deserializes the
strict request shape, and then judges acceptance under D-046: the pure policy and the
regular-file probe answer together, and every acceptance failure is one uniform
response whose bodies are byte-identical by test, because acceptance is where the
no-oracle rule lives. Past acceptance the ratified error contract takes over: the
authority runs through the bounded primitive, the normalizer strips and types the
document, the version range is enforced on every probed document because the version
travels in the document itself, and failures carry a typed reason class describing
the authority, never tool output or a path. Cancellation propagates.

The activation verdict is made once at the composition root: explicit configuration,
at least one media root, and a tool binary resolvable through the sanctioned probe.
The published capability row and the endpoint share that verdict, so a configured but
unresolvable server publishes unavailable and answers unavailable, proven end to end.
The per-document range check is a recorded deviation from the contract's "version
range holds at startup" wording: a startup check would require an unrecorded
`--Version` invocation shape and a parser for non-JSON output, where the per-document
check reads the same field the goldens already prove parseable, and it catches a tool
swapped after startup, which the startup wording would not.

**Red first.** `FAIL port-contract case=CT-037 type=NotImplementedException`, exit 1.

**Corpus split by cost.** CT-037 through CT-040 drive the handler in process with
injected authorities: the golden happy path with wire-level privacy asserts over the
serialized body; the uniform-shape proof comparing four rejection bodies byte for
byte, outside-root, absent, directory, and traversal-spelled; the malformed-body
corpus; and the typed failures, including a future version synthesized by editing the
golden's creatingLibrary. ST-011 proves the full wire once: a real POST through the
real server spawns the impersonated tool as a real child process, the golden crosses
the adapter and normalizer, the payload arrives privacy-clean, and the capability row
reads available with reason `inspection-configured`. Green in both configurations:
`PASS port-contract cases=51 assertions=601 failures=0`.

**Mutation proofs, each observed against the committed baseline and restored.**

- Probe half of acceptance removed: `FAIL case=CT-038, acceptance rejection status,
  expected 422 actual 200`, an absent file reached the authority.
- Uniform rejection differentiated by echoing the path: `FAIL case=CT-038,
  acceptance rejections diverged in shape`, and the failure output itself shows real
  filesystem paths appearing in the bodies, which is exactly the leak the
  byte-uniformity rule exists to prevent.
- Version range widened past the ceiling: `FAIL case=CT-040, version range status,
  expected 502 actual 200`, the synthesized 27.00 document was admitted.
- Activation verdict ignored by the endpoint: `FAIL case=ST-010, unresolvable
  configuration must read as unavailable, expected ServiceUnavailable actual
  UnprocessableEntity`, the capability-endpoint agreement is load bearing.

After restoration both configurations returned to `cases=51 assertions=601`, no
orphaned children. All six policing pins moved in the same commit as the cases.

## Unit 4b-2 part 2 validation sweep

Run against committed head `c3bd6fb8` on 2026-08-20, all six gates in order, green on
the first attempt, the fifth consecutive no-catch sweep:

```
PASS port-static        checks=240
PASS port-verify        checks=1211
PASS port-http-windows  checks=5182
PASS port-browser       checks=694
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64520
```

Audit record `evidence-audit.json` sha256
`b508af785f7142f05d1d05f6fc4977d58d4179308c64e11db7e0080346944d04`. This section
postdates the audited set by construction; it records the audit, it is not covered by
it.

## Unit 4b-3: the port-inspection gate

A seventh gate joins the sweep. It drives a configured server over real HTTP through
the test binary's `--serve-configured` host, because the shipped binary deliberately
has no configuration surface and inventing one for a gate would be product surface
nobody asked for. The gate stages its own media world under the artifacts tree,
committed media copies, a garbage golden, a sleep probe, and a junction directory
inside the root, and proves at the wire: the capability row reads available; the
happy path answers with normalized golden facts and no banned name in the body; seven
hostile shapes are one byte-uniform 422 with no path echo; malformed authority output
is a typed 502 naming only `document-not-json`; a cancelled hanging probe leaves no
child process behind and the pipeline still answers afterward; and the host shuts
down clean. Producer honesty both ways: the gate invalidates any standing audit
before writing its record, and the audit validates the inspection record's shape and
counts, because a gate pass the audit cannot see is a producer claim outside the
audited set.

**The gate went red before the product was ready, exactly as intended.** Design
review predicted the probe refused reparse leaves but would traverse a junction
directory inside a root, the root-escape shape D-046's corpus names. The gate's first
run confirmed it: `FAIL check=hostile-status-4`, the junction path was admitted. The
probe now walks the whole directory chain and refuses any reparse component, the
suite stayed at `cases=51 assertions=601`, and the gate's junction case is the
standing guard. Removing the walk turns the gate red at the same check, proven and
restored.

**A surviving mutant, dispositioned in writing.** Neutralizing the privacy strip left
the gate green: the wire greps cannot fail while the typed payload's fixed schema
structurally excludes banned fields, so the strip is defense in depth ahead of a
projection that already blocks the wire. The suite run under the same mutation went
red at `CT-020, banned field survived the guard: UniqueID`, which is the load-bearing
proof at the guard itself. Per the restatement rule, the gate's record now cites
CT-020 and the structural projection as the proofs its wire greps restate. The gate
also records its reliance on CT-038 for the no-authority-call property of rejected
paths, proven in process against an injected authority.

The gate passes at 43 checks. The comparison recorder, real CLI against the existing
Windows MediaInfo library over the committed media files, remains the one open item
of the ratified gate plan and is deliberately its own unit: it needs the current
product's native wrapper, which no cross-platform gate should build.

## Unit 4b-3 validation sweep, the first with seven gates

Attempt 1 against `e5430523` reached the audit with six gates green and was stopped
by the audit itself, rejecting the new inspection record for CRLF line endings where
the evidence law is canonical LF: the newest gate's writer violated the house rule
and the audit named it exactly. Fixed at the write, verified zero CRLF pairs.
Attempt 2 against committed head `6ea92edc` on 2026-08-20, all seven gates in order:

```
PASS port-static        checks=244
PASS port-verify        checks=1211
PASS port-http-windows  checks=5182
PASS port-browser       checks=694
PASS port-inspection    checks=43
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64716
```

Audit record `evidence-audit.json` sha256
`9c5307a8b1901b685d6b4e088e0e09785bab2c54bc0eeef0e6429226168014b5`, the first audit
that certifies the inspection record inside the set. This section postdates the
audited set by construction; it records the audit, it is not covered by it.

## Exit-criteria review

Each ratified requirement, its delivered evidence, and its verdict. Confidence
follows the repository convention; nothing below is a claim without a pointer.

**D-045, the authority decision.** The MediaInfo CLI in JSON mode is the sole
implemented authority, invoked exactly as the fixture manifest records, only through
the bounded-execution primitive, behind the swappable `IMediaFactAuthority` port; the
ffprobe backup is named, mapped in the agreed-facts tables, and deliberately not
implemented, with its activation triggers recorded in the decision. Evidence: units
2 and 3, the adapter and primitive sources, CT-023 through CT-033. Met.

**D-045 privacy exit criterion.** The strip list is enforced before any field is
read, self-tested by CT-020 and CT-021, proven red-on-revert in unit 1 and again by
the surviving-mutant diagnosis in unit 4b-3, and the wire carries no banned name,
asserted in process, in the wire case, and at the gate. The typed payload's fixed
schema is the recorded second, structural layer. Met.

**D-046, path acceptance.** Configured roots with an admit-nothing default, canonical
containment on one spelling, regular files only with the reparse refusal walking the
whole directory chain, uniform byte-identical rejection with no existence oracle,
proven in process (CT-034, CT-035, CT-038), at the wire (ST-010, ST-011), and at the
gate including the junction case that first exposed the component gap. The endpoint
ships only with the policy enforced, and the capability is `unavailable` on any other
path, sharing one composition-root verdict with the endpoint, mutation-proven. Met.

**The error contract.** Three outcomes, never conflated: facts on success, absence as
omission (the vfr fixture is the standing no-silent-default proof), and typed reason
classes for authority failures that carry no tool output and no path. Cancellation
propagates as cancellation with kill-and-reap proven at the primitive and no residue
proven at the gate. Met.

**The comparison protocol.** Recorded at matched library versions over the four
committed fixtures: zero value disagreements; seven structure-class divergences, all
explained and recorded as migration rules in the agreed-facts list. Met, with the
corpus growth per container family remaining a standing instruction rather than a
one-time act.

**The exposed fact set, version 1, against the agreed tables.** The delivered payload
covers the container, video, and color-and-HDR tables completely. Four agreed facts
are not exposed in this version, enumerated here so the delta is a record, not a
discovery: container chapters and the subtitle commentary, hearing-impaired, and
stream-size flags have no committed fixture or synthetic coverage and are excluded by
the fixture-first rule until a carrying fixture lands; audio delay (`Video_Delay`) is
carried by the committed goldens but was not selected in unit 1, and is the first
v1.1 addition candidate, a small test-first unit. No exposed field lacks a golden or
synthetic assertion; the reverse gap is exactly these four, with these reasons.

**Verification discipline.** Every unit red-first with the red quoted; every
load-bearing rule mutation-proven against committed state and restored; every pin
moved in the same commit as its cases across all six sites; every sweep run against
committed heads with the audit last; surviving mutants dispositioned in writing. The
sweep grew from six to seven gates and the audit certifies the seventh's record.

**Deliberately out of scope, confirmed still out.** No thumbnailing, no summary
prose, no writes, no PATH search, no environment discovery, no fact caching, no
second authority, no enablement policy. The shipped production binary carries no
configuration surface; the capability activates only by explicit composition.

**Open rows carried forward.** Golden capture on a non-WSL Linux host when
convenient; corpus growth per container family; the v1.1 fact additions above; the
backup adapter on its recorded triggers.

## Slice close

S-PORT-02 delivered, on top of the SLICE-002 foundation: the typed media-facts
contract and its normalizer with the privacy guard; the bounded-execution primitive
as the tree's single process path under a deliberately amended boundary law; the
MediaInfo CLI adapter behind a swappable port; the pure and filesystem halves of
D-046 under a second sanctioned crossing; the amended request law and the media-facts
endpoint with capability honesty; the port-inspection gate as the seventh sweep gate,
audited inside the set; and the Windows comparison record at matched versions with
zero value disagreements. Every catch, repair, deviation, and surviving mutant along
the way is recorded above in the unit it belongs to.

**The attesting sweep**, run against the Final-stamped commit `41201691` on
2026-08-20, all seven gates green on the first attempt:

```
PASS port-static        checks=247
PASS port-verify        checks=1211
PASS port-http-windows  checks=5182
PASS port-browser       checks=694
PASS port-inspection    checks=43
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64839
```

Audit record `evidence-audit.json` sha256
`910da30061b87af14b0b291e2cb4767fd8938cec99c08381ca5d2d00d59d40d4`. This paragraph
postdates the audited set by construction; it records the attestation, it is not
covered by it. The slice is closed.

## Certification repair, 2026-08-21: reopened and closed

An independent adversarial review, run read-only in a parallel session, disproved one
claimed concurrency invariant while leaving the sequential attestation standing: the
inspection gate published audited evidence without the shared writer lease every other
audited producer holds, invalidated the audit JSON before its sidecar, wrote its
record non-atomically, and swept a fixed task root without the ownership and reparse
safeguards, while the auditor never checked that task root. The classification is
accepted exactly as the reviewer framed it: feature closed, certification repair
reopened. The finding is the ADC-LOCAL-015 class recurring on its own unit of origin,
and it sharpens that lesson: the family's obligations are enumerated by reading an
incumbent producer end to end, never inferred from the one failure already observed.

**The repair.** The gate now carries the family obligations in full: the shared
writer lease with create-new, share-none semantics and the exact 33-byte receipt that
owns removal; sidecar-then-JSON audit invalidation with a publication-readiness
proof; atomic canonical publish through a temp-and-move under safety revalidation; a
receipt-named `run-` directory under the family task root `tmp/port-inspection` with
junction-aware validated cleanup, where exactly the one expected link is removed
non-recursively and any other reparse entry stops the gate; and a failure path that
releases the lease only on proven exact-receipt ownership, leaving it otherwise. The
auditor enforces the inspection task root at its primary read and both closeouts. Two
determinism defects found while repairing were fixed the same way: stale-audit
invalidation and stale-run recovery both enforce uncounted, so the gate's check count
and its published record value, 97 and 66, do not depend on prior-run state, proven
by paired runs across a deliberately crashed predecessor.

**Contention proofs, observed against the committed baseline and restored.**

- Correct gate under a foreign lock: exit 1 at `evidence-lease-unavailable`, the lock
  byte-intact and the standing record untouched, which is the fail-closed exclusion
  and the receipt-ownership rule in one observation.
- Exclusion mutation, create-new weakened to create: the gate ran green, clobbered
  the foreign lock, and overwrote the record, exactly the pre-repair defect, caught
  red by the contention expectations, so the create-new mode is the load-bearing
  exclusion.
- Restored: fail-closed again with everything intact, then a clean green run and an
  empty task root.

**A process failure, recorded because the rule is now three incidents old.** The
first proof round ran its mutation restore while the reworked gate was uncommitted;
checkout silently resurrected the old gate, and the "restored" observation measured
the wrong code. The committed-baseline rule for revert-mutations was violated by its
own author while repairing a finding about producer discipline. The sequence was
redone commit-first and every observation above is against committed code.

**Sharper accounting, from the same review, all applied.** The shell previously
rejected any capability payload reporting media inspection available; it now accepts
and renders both honest states, so a configured server and the shipped shell no
longer contradict. The version-range judgment moved behind the authority port as
`IsSupportedDocumentVersion`, so no layer above the port names a concrete adapter,
and the adapter contract records that backup activation includes a per-authority
normalization strategy. D-046 is amended rather than half-implemented: the capability
payload deliberately carries availability and reason only, never configured roots,
and the amendment supersedes the original payload sentence with its privacy
rationale. The open queue gains a configured Linux pipeline run with the real
MediaInfo, distinct from the non-WSL golden capture already queued, because the
sandbox proves inspection unavailable-by-default on Linux while the configured
pipeline has only run on Windows. The reviewer's remaining adversarial items, path
check-and-use races, inherited child environment, shutdown cancellation, activation
with unusable roots, and path-like metadata values, stay with the continuing
read-only audit.

**The re-attesting sweep**, run against the 1.1 Final commit `f0edda08` on
2026-08-21, all seven gates green on the first attempt:

```
PASS port-static        checks=247
PASS port-verify        checks=1211
PASS port-http-windows  checks=5182
PASS port-browser       checks=694
PASS port-inspection    checks=97
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64842
```

Audit record `evidence-audit.json` sha256
`e20829799bc4f5a658da91a1afad6dce4f94dc46fe2b29664299c911be5380f6`, the first audit
whose certified set includes a lease-serialized inspection record and whose task-root
law covers all three producer roots. This paragraph postdates the audited set by
construction; it records the attestation, it is not covered by it. The certification
repair is closed.

## v1.1 fact addition, 2026-08-21: audio delay

The first post-close addition the exit-criteria review named. The audio stream's
delay against video joins the exposed set as `videoDelay` beside typed
`videoDelaySeconds`, golden-backed at both range ends on the matroska and webm
fixtures and absent on the mp4 fixture, so the absence rule is asserted alongside the
values. Red first: the payload gained the members before the normalizer read them,
observed as `FAIL case=CT-017, audio delay raw, expected 0.000 actual null`. Green in
both configurations at `cases=51 assertions=607`; the read was mutation-proven by a
parameter-name flip that reproduced the same red, restored against the committed
baseline. Assertion pins moved at both count sites in the same commit. The
exposed-set delta against the agreed tables now stands at three facts, chapters and
the subtitle commentary and hearing-impaired flags plus subtitle stream size, all
waiting on carrying fixtures per the fixture-first rule.

**The attesting sweep**, run against the 1.2 Final commit `d5aea9e2` on 2026-08-21,
all seven gates green on the first attempt:

```
PASS port-static        checks=247
PASS port-verify        checks=1223
PASS port-http-windows  checks=5182
PASS port-browser       checks=694
PASS port-inspection    checks=97
PASS port-linux-sandbox checks=27    runtime_writes=0
PASS port-evidence      checks=64842
```

Audit record `evidence-audit.json` sha256
`c04f67e756dfe1c3cc40035839029e9791ad992b6a524d82736a06ddd4c2c7b0`. This paragraph
postdates the audited set by construction; it records the attestation, it is not
covered by it.
