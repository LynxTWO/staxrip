# Upstream candidates

Local lessons that may be worth proposing to the shared skill. Proposal only. Nothing here
edits the shared core, and no calibration is copied. Each entry states its evidence and its
limits. A repo fact is not a general lesson, and one incident is an observation, not a law.

## ADC-LOCAL-001: Treat "a check that cannot fail" as a named defect class

- Status: staged
- Scope: repo-agnostic
- Lesson: An assertion that no execution can fail is worse than a missing assertion, because it
  reports coverage that does not exist. For every check, name a concrete, producible input that
  makes it fail. If none exists, the check is a defect. The recurring shapes are: a field written
  as a fixed literal by a producer and pinned to that same literal by a checker; an assertion
  comparing a value to itself, or to a constant it was already compared against; a claimed
  property with no probe behind it; a boolean literal asserted in place of a captured outcome;
  and a checker pinned to a document string that later becomes false. Once the class is named,
  sweep for it across the whole verification surface rather than repairing the one instance that
  surfaced.
- Evidence: Seven independent instances were found in one verification harness over a single
  engagement, each verified by reading the code and, where applicable, by mutation. Two were
  introduced by remediations for earlier instances of the same class, after the class had been
  named. One made an entire acceptance criterion permanently unsatisfiable: the producer could
  emit only one value and the checker required exactly that value, so an honest recording of a
  genuine result would have been rejected. Adversarial review rated this the slice's defining
  failure mode.
- Limits: Not every unfalsifiable assertion is a defect. A restatement of a property already
  proved by a named probe elsewhere is acceptable when the probe is cited at the restatement.
  The danger is the undocumented case, where a value with no probe hides among values that have
  one. Requiring each restatement to name its probe is the cheap discriminator.
- Proposed target: references/07-adversarial-review.md
- Proposed change: Also cross-reference from references/14-deterministic-verification.md. Add a named finding class with the five shapes above and the falsifying-input
  test, plus the rule that naming the class obliges a surface-wide sweep.

## ADC-LOCAL-002: A fix without a guard is a fix that can be deleted

- Status: staged
- Scope: repo-agnostic
- Lesson: When a fix widens a detector, rule set, or matcher, add a case that fails if the
  widening is removed, and prove it by reverting the change and requiring the test to go red. A
  probe an author ran once is not a guard, because it does not run again. State this as part of
  the finding's own smallest-safe-step, and treat the guard as part of the fix rather than
  follow-up work.
- Evidence: Two remediations in one engagement were independently rejected for exactly this. In
  the first, a detector was correctly widened to catch a new credential form, but the only
  self-test case covered a form that already worked before the change; mutation proved the entire
  fix could be deleted with every check still green. In the second, from an earlier session, six
  of seven detectors were repaired and the seventh was missed while the finding recorded the work
  as complete. Both fixes were correct in substance and unguarded in practice.
- Limits: Applies to changes whose effect is detection or matching breadth. A behaviour-preserving
  refactor may not need a new case, though it still needs an existing one to exercise the path.
- Proposed target: references/11-remediation-loop.md
- Proposed change: Require every widening-class fix to ship a guard case and a recorded
  revert-mutation result, and add both to the acceptance checklist.

## ADC-LOCAL-003: Verify an isolation property, never trust the request that asked for it

- Status: staged
- Scope: repo-agnostic
- Lesson: Sandboxing, isolation, and privilege-restriction interfaces can accept a request,
  return success, and silently apply nothing, depending on host policy. Evidence that a property
  was requested is not evidence that it holds. Probe the property from inside the restricted
  context and record the observation, not the request. When a probe cannot run, fail rather than
  pass, because a probe that tests nothing is indistinguishable from a passing probe.
- Evidence: A process-isolation property was requested on two hosts running the same supervisor
  version. On one it applied; on the other it silently did not, while the supervisor returned
  success both times. The difference was a distribution-default kernel hardening setting. Proven
  by intervention: relaxing the setting made the isolation appear and restoring it made the
  isolation vanish. In the same harness, a second isolation property was recorded as a fixed
  literal with no probe at all and was therefore unverifiable on any host.
- Limits: The probe must observe the property, not the configuration that requests it. Reading
  back the requested setting reproduces the original error. Some properties have no cheap
  in-context probe; those should be recorded as unverified rather than asserted.
- Proposed target: references/assurance-contracts.md
- Proposed change: In the native-runtime and claim sections, add an isolation-claim checklist requiring an in-context probe, an explicit
  failure when the probe cannot run, and a recorded observation rather than a restatement of the
  request.

## ADC-LOCAL-004: Keep verification artifacts out of trees that developer tooling indexes

- Status: staged
- Scope: repo-agnostic
- Lesson: A gate that needs exclusive file access must not run inside a directory an editor
  indexer, search service, anti-malware scanner, backup agent, or sync client is walking. Such a
  tool can hold a handle without share-delete and make an unrelated gate fail intermittently, and
  the failure presents as a defect in the code under test. Record the exclusion as an
  environmental prerequisite of the gate, because a result that depends on it is not reproducible
  without it.
- Evidence: A cleanup step failed roughly two runs in three with a timeout deleting a single file,
  on identical source. Two investigations misattributed it, first to leaked child processes and
  then to anti-malware, and an adversarial review rejected the proposed remedy. A live capture
  using a handle-enumeration API named the holder: an editor language-service indexer walking the
  workspace, holding one cache file at a time. The single-survivor pattern matched an indexer and
  ruled out the process-based hypotheses. Adding a workspace exclusion resolved it, and the
  elapsed time of the passing gate dropped by roughly half.
- Limits: The diagnosis needs a handle-enumeration mechanism; where none is available, absence of
  a user-mode holder is itself evidence pointing at a kernel filter. The exclusion is a property
  of the developer environment and cannot be enforced from inside the repository, so it must be
  documented as a prerequisite rather than assumed.
- Proposed target: references/10-maintenance-harness.md
- Proposed change: Add environment contention to the harness prerequisites, with the guidance to
  identify the holder before proposing a timing remedy, and to record any required exclusion
  alongside the gate.

## ADC-LOCAL-005: A sequence of passing producers is not audited evidence

- Status: staged
- Scope: repo-agnostic
- Lesson: Producers passing in sequence and an audit certifying them as a set are different
  claims, and only the second supports a release decision. Treat any producer record written after
  an audit attempt as unaudited. Where an audit emits an artifact, require that artifact on disk
  before describing a set as passing, and require every producer record to predate it.
- Evidence: A set of producer gates was reported as "passing together" while the audit artifact
  had never been written and one producer record had been regenerated twenty-six minutes after the
  audit failed. The same report quoted check counts that did not match the files on disk, and one
  gate's count varied across runs, so no single number described it. An independent review
  identified the absence of the audit artifact, rather than any individual defect, as the decisive
  reason the set could not be accepted.
- Limits: Applies where an audit or correspondence step exists and emits a durable artifact. Where
  none exists, the equivalent discipline is to record the ordering and completeness of the run
  explicitly, since no artifact can carry it.
- Proposed target: references/00-conventions.md
- Proposed change: In the evidence and negative-search section, define audited-set evidence separately from per-gate evidence, and add the rule
  that a record written after an audit attempt is unaudited.

## ADC-LOCAL-006: Verify that review is complete, not that it says it is complete

- Status: staged
- Scope: repo-agnostic
- Lesson: A checker satisfied by editing the artifact it checks is a ritual, not evidence. Binding
  closure to a version stamp, status word, or single declarative line lets one keystroke on the
  reviewed document turn a whole verification green while its body still records the opposite.
  Verify substantive properties instead: no finding left in an open state, no unresolved verdict
  language in the document, and a hash binding so any edit is visible. Where a document must be
  scanned for an unresolved verdict, distinguish a live claim from an accurate historical record,
  so closing the check never requires deleting true history.
- Evidence: An evidence auditor pinned one literal version line as its only review-closure signal.
  The pinned constant had also gone stale, so satisfying it would have required decrementing a
  version number on a document whose body reported rejection. Replacing it with substantive checks
  immediately exposed a further defect in the replacement: the first version scanned only one
  section, and the document's live verdict lived in another, so the new check passed over a
  document that still declared the work unaccepted. Tense proved a reliable discriminator between
  a live verdict and a historical one in the same document.
- Limits: Substantive checks need a stable vocabulary for statuses and section structure. Where a
  project has no such convention, the first step is to establish one, not to add the check.
- Proposed target: references/assurance-contracts.md
- Proposed change: In the publication and claim sections, add a self-certification anti-pattern with the substitution above, including
  the requirement that closure checks must not be satisfiable by editing the checked artifact.

## ADC-LOCAL-007: A value produced in a child context must cross the boundary as an artifact

- Status: staged
- Scope: repo-agnostic
- Lesson: When verification runs part of its work in a separate process, container, sandbox, or
  job, values computed there are invisible to the parent unless they cross as a file, stream, or
  structured result. An in-memory assignment silently leaves the parent holding its initial value.
  Follow whatever handoff mechanism the surrounding code already uses, and have the reader
  validate the received value rather than assume it arrived.
- Evidence: A newly added probe assigned its result to a variable inside a supervised child
  context while the consumer ran in the parent. The consumer therefore always saw the initial
  placeholder and refused to publish, which would have made the gate unable to succeed at all.
  Every other result in the same script already crossed the boundary as a file; the new one did
  not. The defect was found by review before the gate ran, so the author never observed it.
- Limits: Obvious once stated, and easy to miss when adding a value to code that reads as one
  continuous script. The reliable check is to trace the value from where it is produced to where
  it is read and confirm the two points are in the same process.
- Proposed target: references/14-deterministic-verification.md
- Proposed change: Add a boundary-handoff caution to the gate-authoring guidance, with the trace
  rule and the instruction to reuse the existing handoff mechanism.

## ADC-LOCAL-008: Anchor repository identity to immutable history, and report which component failed

- Status: staged
- Scope: repo-agnostic
- Lesson: Repository identity should be anchored to something the repository cannot change
  casually, such as its root commit set. A remote URL is mutable and legitimately changes with a
  protocol switch, rename, mirror, or fork, so a binding that leans on it will report a mismatch
  for a repository that is plainly the same. When a binding has several components, report which
  one failed, because "binding mismatch" otherwise conflates "this is a different repository" with
  "you changed how you clone it". The first must stop a flow-back; the second should refresh the
  binding and continue.
- Evidence: A binding check failed on its remote-URL component while the root-commit component
  matched exactly, in a repository whose history was demonstrably continuous. Treating the
  combined result as a stop condition would have discarded valid local learning; treating it as a
  pass would have skipped a real staleness signal. Distinguishing the components resolved it
  without weakening either safeguard.
- Limits: Root commits are stable but not universally unique: forks share them by design, so they
  establish continuity rather than exclusivity. A binding should keep both signals and weigh them
  differently rather than replacing one with the other.
- Proposed target: references/15-dogfeeding-flowback.md
- Proposed change: Update the reference and the binding logic in the bundled script. Require per-component binding results, treat a root-commit match as continuity,
  treat a remote-URL mismatch alone as a refresh trigger rather than a stop condition, and stop
  only when the immutable component disagrees.

## ADC-LOCAL-009: Revert-mutation proofs need a committed baseline

- Status: staged
- Scope: repo-agnostic
- Lesson: A revert-mutation proof restores the code by version-control checkout, and
  checkout cannot restore a file the version control does not yet track. Running mutation
  proofs on a brand-new unit before its first commit leaves every mutation silently in
  place while the operator believes it reverted. Either commit the unit before the
  proofs, or close every proof session with a full green run, which converts a silent
  failed revert into a loud test failure.
- Evidence: Three mutation proofs on a new, uncommitted unit each produced the expected
  red, and each checkout-based revert failed with an unknown-pathspec error that scrolled
  past unnoticed. The mandatory restored-state green run then failed, exposing that all
  three mutations were still present; restoration was completed by inverse edit and
  verified green. The closing green run is what contained the damage.
- Limits: One incident. The closing-green-run discipline is the load-bearing half and is
  cheap everywhere; the commit-first half trades commit granularity for revert safety and
  teams may reasonably differ.
- Proposed target: references/11-remediation-loop.md
- Proposed change: In the guard-and-mutation guidance, require either a committed
  baseline before revert-mutations or a mandatory full green run after restoration, and
  state why checkout is not a revert for untracked files.

## ADC-LOCAL-010: Whole-record equality over collection members is a hidden reference comparison

- Status: staged
- Scope: repo-shape:managed-desktop
- Lesson: In runtimes where a record or value type delegates member equality to the
  default comparer, a collection-typed member compares by backing reference, so a
  whole-record equality between two separately built instances can never pass even when
  every element agrees. An assertion built on it reports false divergence, and its
  inverse, an inequality guard, is a check that cannot fail. Compare structured payloads
  per section, with sequence equality over the collections and value equality over the
  leaves.
- Evidence: A cross-version stability assertion compared two normalized payload records
  whole; it failed while every field agreed, because the payload's immutable-array
  members compared by reference. Rewritten per section with sequence equality, the same
  data passed, and the sectioned form also names which section diverges when one truly
  does.
- Limits: One incident, in one runtime family. The general shape, default equality
  silently comparing references inside an assertion, appears in several managed runtimes
  but the candidate is scoped to the shape it was proven on.
- Proposed target: references/14-deterministic-verification.md
- Proposed change: Add a caution to the gate-authoring guidance: equality assertions over
  structured payloads must state what the comparer actually compares, and collection
  members need sequence comparison, not container equality.

## ADC-LOCAL-011: An implicit restore is a silent mutation of audited dependency state

- Status: staged
- Scope: repo-agnostic
- Lesson: Where dependency lock files are audited evidence, a routine build that
  implicitly restores can rewrite them for the build's own narrower context, for example
  dropping a cross-compilation target the audit requires, and the damage travels into the
  next commit unnoticed. Local builds in such a repository must run with restore
  disabled, and restore must happen only through the reviewed path that validates the
  locks. The cheap tripwire is any version-control status check after a build: a modified
  lock file after a supposedly read-only build is the alarm.
- Evidence: A test build without the no-restore flag rewrote five lock files, removing
  the cross-target sections the final dependency audit derives its closure from, and the
  rewritten locks were committed. The commit's own file list exposed them; the repair
  restored the audited versions, and the reviewed locked-mode restore gate then passed
  its full check count against them without rewriting, proving the restored state and the
  gate agree.
- Limits: One incident, one package manager. The general mechanism, a build tool
  mutating its own declared-state files as a side effect, exists across ecosystems, but
  the flag names differ and some ecosystems make lock rewriting opt-in rather than
  default.
- Proposed target: references/10-maintenance-harness.md
- Proposed change: Add audited dependency state to the harness prerequisites: name the
  no-restore or equivalent flag for local builds, route all restores through the
  reviewed gate, and add the modified-lock-after-build tripwire to the review checklist.

## ADC-LOCAL-012: A remediation must fix exactly the set the gate names

- Status: staged
- Scope: repo-agnostic
- Lesson: When a gate names the artifacts that violate a rule, the fix must target that
  named set and nothing wider. A remediation loop that re-derives its own candidate set,
  for example "every changed file", silently re-implements the gate's file classification
  without the gate's exclusions, and applies a text rule to artifacts the gate
  deliberately exempted. Binary artifacts under a text rule are the sharp case: they
  almost never satisfy a trailing-newline or encoding invariant, so a sweeping fixer
  mutates them every time, and hash-pinned fixtures are corrupted by exactly the two
  bytes the fixer believed were a repair.
- Evidence: A whitespace gate failed naming one markdown file lacking a final newline.
  The repair iterated all changed files instead and appended a newline terminator to any
  file not ending in one, which appended two bytes to three binary media fixtures whose
  hashes are recorded in a committed manifest. The corruption was committed and pushed
  before being noticed; restoration from the committed originals re-verified all four
  fixture hashes against the manifest. The gate itself had classified correctly and
  flagged only the text file.
- Limits: One incident. The narrow rule, fix only what the gate names, trades off
  against genuinely proactive cleanup; where a wider sweep is intended, it must reuse
  the gate's own classifier rather than approximate it.
- Proposed target: references/11-remediation-loop.md
- Proposed change: In the fix-application guidance, require the fix set to equal the
  finding set, and state that any wider sweep must invoke the gate's classification
  logic rather than re-derive it.

## ADC-LOCAL-013: A mutation proof that hangs is a defect in the code, not the proof

- Status: staged
- Scope: repo-agnostic
- Lesson: A revert-mutation proof expects red; a third outcome exists: the suite never
  finishes. When a mutation neutralizes a safety action, any unbounded wait downstream
  of that action, a reap, a join, a drain, converts the neutralization into a hang, and
  a hang is worse evidence than a pass because it also blocks every later proof. The
  hang is not a flaw in the mutation exercise; it is the exercise finding that the
  system's failure handling depends on the very action being tested, with no bound
  behind it. The fix is in the product: bound every cleanup wait and surface expiry as
  a typed failure, which simultaneously makes the mutation observable as ordinary red.
- Evidence: Neutralizing a process-tree kill did not turn the harness red; the suite
  wedged behind a child blocked writing to a full pipe while the reap waited on it
  without a bound, and an external timeout had to kill the run. Bounding the reap and
  surfacing a surviving child as a typed reason class made the same mutation fail the
  suite cleanly in seconds, and the bound is unreachable when the kill works.
- Limits: One incident. Bounding a cleanup wait needs a bound chosen honestly: long
  enough that expiry cannot occur in legitimate operation, or the typed failure becomes
  a new flake source.
- Proposed target: references/11-remediation-loop.md
- Proposed change: In the guard-and-mutation guidance, name the hang as the third
  proof outcome, require it to be treated as a product defect in cleanup bounding, and
  require cleanup waits downstream of any mutated safety action to be bounded and
  typed.

## ADC-LOCAL-014: A surviving mutant demands a diagnosis, and the diagnosis is a finding

- Status: staged
- Scope: repo-agnostic
- Lesson: When a mutation survives, the possibilities are a missing test or an
  equivalent mutant, and both are findings, never noise. An equivalent mutant means
  the mutated code was not load bearing on any observable path: a dead branch, or a
  check whose refusal is silently duplicated by a neighboring mechanism. Leaving the
  code as written after such a diagnosis records a claim the code does not keep; the
  honest close is to rewrite the code to say what is actually true, delete the dead
  branch, document which mechanism really owns each behavior, and re-prove with a
  mutation that is load bearing. A guard that survives mutation because a neighbor
  masks it will also mislead every future reader about where the enforcement lives.
- Evidence: Two mutations of a filesystem probe both survived a corpus that
  genuinely exercised the mutated behaviors. Diagnosis showed one refusal branch was
  unreachable, the platform's existence test already refuses directories, and one
  masked, a missing file reads its attributes as all bits set, so a later attribute
  refusal also refuses absence. The probe was rewritten to name the true mechanisms,
  the dead branch deleted, and the surviving proof, a verdict flip, went red
  correctly.
- Limits: One incident. Distinguishing equivalent mutants from missing tests requires
  reading the runtime's actual semantics, not re-running the suite harder; the
  diagnosis cost is real and worth budgeting.
- Proposed target: references/11-remediation-loop.md
- Proposed change: In the guard-and-mutation guidance, add the surviving-mutant rule:
  every survivor is dispositioned in writing as missing-test or equivalent-mutant,
  equivalent mutants trigger a rewrite that removes the dead or masked claim, and the
  unit is not done until a load-bearing mutation goes red.

## ADC-LOCAL-015: A new producer is born under the audit, or its pass is not evidence

- Status: staged
- Scope: repo-agnostic
- Lesson: Where an audit certifies gate evidence as a set, adding a new gate is not
  done when the gate passes; it is done when the audit validates the gate's record
  inside the set and the gate participates in the audit's freshness protocol. Three
  obligations arrive together with any new producer: the audit gains validation of
  the new record's shape and counts, the producer invalidates any standing audit
  before writing new evidence, and the record obeys the evidence canon of the
  existing family, encodings and line discipline included, because the audit will
  hold the newcomer to the same law as the incumbents. A new gate that skips any of
  the three reports passes the release decision cannot use.
- Evidence: A seventh gate was added to a six-gate sweep whose audit certifies the
  evidence set. The audit was extended to validate the new record and the gate was
  given the standing-audit invalidation the incumbent producers already had. On the
  first full sweep the audit rejected the new record for carriage-return line
  endings, because the platform's JSON serializer does not emit the family's
  canonical form; the writer was normalized and the next sweep produced the first
  audit certifying the newcomer inside the set. A second incident then proved the
  deeper rule: an independent review found the same gate had skipped the family's
  writer lease, its invalidation order, its atomic publish, and its receipt-bound
  task cleanup, because the author had enumerated obligations from the one failure
  already observed instead of reading an incumbent producer end to end. The repair
  replicated the incumbent's full evidence discipline and proved the exclusion by a
  contention run and a create-new-weakening mutation.
- Limits: Two incidents in one family. The specific canon, line endings and strict
  UTF-8 and leases, is one family's law; the general rule is that the audit's
  existing record requirements bind new producers from their first write, and that
  the obligation list comes from reading an incumbent end to end, not from memory or
  from the failures that happened to surface.
- Proposed target: references/14-deterministic-verification.md
- Proposed change: In the gate-authoring guidance, add the new-producer checklist:
  audit-side validation of the new record, producer-side invalidation of stale
  audits, and conformance to the family's evidence canon, all landing in the same
  change as the gate itself.

## ADC-LOCAL-016: A finding that crossed a context boundary is a hypothesis again

- Status: staged
- Scope: repo-agnostic
- Lesson: A claim carried across a summary, a handoff, or a session boundary loses the
  thing that made it a finding, which is the act of having looked. It arrives as a
  sentence with a file and a line number attached, and it is indistinguishable in form
  from a claim that was verified. Treat every such claim as unverified until re-measured,
  and re-measure before it is written anywhere durable. The cost of re-checking is
  seconds; the cost of a wrong line citation in a committed document is that a reader
  trusts it, and the document's other claims inherit the doubt when it is found.
- Evidence: Five defects carried across a context summary were re-checked against the
  source before being filed. Three held exactly, and one of those turned out to be worse
  than recorded once the enum values behind it were read. Two did not survive: a claimed
  asymmetry between two encoders was absent, because both files did the same thing at the
  same position, and a claimed cross-thread UI write rested on a parallel construct that
  does not appear in the named file at all. Both had precise-looking line citations. The
  two refuted claims were then recorded as refuted in the same document, with what was
  actually found, so the same wrong lead could not be reopened later as though it were
  new.
- Limits: One session, five claims. The ratio is not the point and should not be quoted;
  the point is that form does not distinguish a remembered claim from a verified one, so
  the boundary crossing itself is the trigger to re-measure.
- Proposed target: references/00-conventions.md
- Proposed change: In the confidence-label guidance, state that a claim inherited across
  a context boundary carries no label until re-verified in the current session, and that
  refuted claims are recorded as refuted rather than deleted, so a wrong lead cannot
  return as a new one.

## ADC-LOCAL-017: An unaudited producer needs its own output root

- Status: staged
- Scope: repo-agnostic
- Lesson: When a repository has an audited artifact tree, anything that writes there must
  participate in the tree's discipline, and the way a new tool acquires that obligation is
  simply by choosing the directory. A diagnostic, a benchmark, or a scratch recorder that
  writes into the audited directory has silently joined a protocol it does not implement:
  no lease, no invalidation, no atomic publish, and an auditor that must now either
  account for the file or be surprised by it. The fix is a separate output root, chosen
  deliberately and commented with the reason, so the next author does not "helpfully"
  move it back.
- Evidence: A measurement harness was written to record timings beside the gate evidence,
  because that is where artifacts in the repository live. It held no writer lease and was
  explicitly not a gate, so its first successful run placed an unaudited file inside a
  tree published under a shared lease and certified as a set. The path was moved to a
  sibling measurements root before the harness was committed, the stray file was removed,
  and the reason was recorded in the script beside the path so the choice reads as
  deliberate rather than arbitrary.
- Limits: One repository with an unusually strict evidence protocol. The general rule is
  weaker and still useful: the output directory is part of a tool's contract, and writing
  into a protected tree is an opt-in to that tree's obligations whether or not the author
  noticed.
- Proposed target: references/10-maintenance-harness.md
- Proposed change: In the harness-installation guidance, require that a non-gate producer
  declare an output root outside any audited or lease-protected tree, and that the choice
  be commented at the path definition.

## ADC-LOCAL-018: Enumerate the channels before reporting an absence

- Status: staged
- Scope: repo-agnostic
- Lesson: An availability survey inherits the blind spots of whatever channel it looks
  at. When an ecosystem is mid-migration between distribution channels, inspecting the
  channel that is being abandoned yields a confident, well-cited, and wrong conclusion of
  absence, because the artifacts genuinely are not there. Before concluding that
  something is unavailable, enumerate which channels could carry it and say which were
  checked. An absence is only reportable as an absence when its scope is stated.
- Evidence: A survey of a plugin ecosystem's platform support found close to zero support
  for a target platform in the projects' release pages. The same ecosystem had been
  migrating distribution to a package index, where over ninety percent of the same
  projects published artifacts for that platform. The two channels disagreed by roughly an
  order of magnitude, and the release-page figure would have been reported as the answer.
  The clearest single case built the target platform's artifacts in continuous integration
  on every change and attached none of them to any release, so the artifacts existed,
  were current, and were invisible to the obvious survey.
- Limits: One ecosystem, one migration. The general rule is that a negative result about
  availability is a claim about the channels searched, and it should be written that way.
- Proposed target: references/00-conventions.md
- Proposed change: In the unknowns and evidence guidance, require that a reported absence
  name the sources searched, and note that mid-migration ecosystems make single-channel
  surveys systematically negative.

## ADC-LOCAL-019: A profiler must stop at a nested checkout

- Status: staged
- Scope: repo-agnostic
- Lesson: A deterministic profile is only as honest as its scan scope. Agent harnesses
  keep linked Git worktrees inside the repository they belong to (Claude Code keeps them
  under `.claude/worktrees/`), and each one is a complete second checkout of some
  branch. A profiler that descends into them counts every file, manifest, and steering
  file once per checkout, and its signal detection, gate discovery, and capability
  selection then describe the union of several branches rather than the tree under
  audit. Treat any directory below the root that carries its own `.git` entry as a
  separate repository and do not descend, and name the harness worktree roots in the
  ignore rule beside the skill trees.
- Evidence: With 2026.09.04-unified.9 installed in this repository, `probe` reported 1383
  files seen; the working tree holds 387 files outside `.git`, the run store, the skill
  trees, and build output, and 1029 more under `.claude/worktrees/`. The profile listed
  an `AGENTS.md` inside `.claude/worktrees/` as a second steering file and bound its one
  discovered gate to six solution files, four of them inside `.claude/worktrees/`.
  `plan` on that profile selected all 22 capabilities and deferred none, against the
  human-reviewed plan of 10 selected, 7 candidate, and 3 deferred. The installed
  `IGNORED_DIRS` set names neither `.claude` nor a nested-repository rule, and neither
  `probe` nor `plan` accepts an exclusion argument, so the only way to obtain an honest
  profile was to not run `--write`.
- Limits: One repository and one harness convention. Other harnesses may place worktrees
  elsewhere; the `.git`-marker rule covers those, the name rule does not. A repository
  that vendors another project as a plain directory without a `.git` marker is still
  scanned, which is the correct default.
- Proposed target: scripts/adc.py
- Proposed change: In the profiler's walk, skip any subdirectory below the root that
  contains a `.git` file or directory, add `.claude/worktrees` to the ignore rule, record
  the skipped nested repositories in the profile's scan block so the exclusion is visible,
  and give `probe` and `plan` an `--exclude` argument for the cases no rule can know.

## ADC-LOCAL-020: An unrecognized language is an unknown, not an absence

- Status: staged
- Scope: repo-agnostic
- Lesson: A source-extension table is an allow-list. A language missing from it is not
  merely uncounted; it vanishes from the language list, contributes nothing to repo-type
  classification, and the repository is then classified from whatever secondary languages
  the table does know. A profiler that sees a large count of one unrecognized extension
  must report it as an unknown in the profile rather than omit it, because the omission
  reads as a confident inventory.
- Evidence: 2026.09.04-unified.9 recognizes neither `.vb` as a source extension nor
  Visual Basic .NET as a language. Its probe of this repository put 451 `.vb` files in the
  extension histogram of the same scan, yet reported 87 source files across C/C++,
  PowerShell, C++, C#, and Python, and collapsed the repo types from four to `mixed`
  alone. The working tree holds 147 `.vb` files outside build output and nested
  checkouts; the human-calibrated profile it would have replaced lists Visual Basic .NET
  as the primary language.
- Limits: The table gap is one line to fix. The general rule is the reporting one: any
  allow-list inventory should surface what it declined to count when that residue is
  large.
- Proposed target: scripts/adc.py
- Proposed change: Add `.vb` to `SOURCE_EXTENSIONS` and the language map, treat
  `.vbproj` as a .NET manifest, and emit an `unrecognized_source_extensions` note in the
  profile whenever an unlisted extension's count exceeds the largest recognized language.

## ADC-LOCAL-021: Documentation is not evidence that code does a thing

- Status: staged
- Scope: repo-agnostic
- Lesson: A content-signal scan that reads every text file treats a design note, a
  steering file, or a user guide as proof that the product has the behavior the note
  mentions. Prose describes intentions, risks, other systems, and things that were ruled
  out; source and configuration describe what runs. A planner that selects a capability
  because documentation mentions billing or simulation is planning verification for code
  that may not exist. Record where each piece of signal evidence came from, and let a
  signal whose only backing is documentation reach the planner as a question, not an
  observation.
- Evidence: With 2026.09.05-unified.10 installed, the deterministic profile of a media
  processing desktop repository reported 23 of 30 signals present, including financial
  entitlement and simulation, and every citation for those two was a Markdown steering or
  audit document rather than a source file. The automatic plan selected 21 of 22
  capabilities on that basis, against a human-reviewed plan of 10. The profiler already
  classifies files by extension for counting, so the class of each evidence path was
  available and simply not recorded.
- Limits: Some repositories keep truth in prose on purpose, such as a specification
  repository or a policy corpus; there the documentation class is the source class and the
  rule should be applied with that mapping. Configuration files sit between the two and
  are treated as code-side evidence here because they change runtime behavior.
- Proposed target: scripts/adc.py
- Proposed change: Record `evidence_classes` (source, config, structure, prose) and a
  `documentation_only` flag on every signal; in the planner, a non-core capability whose
  matched signals are all documentation-only becomes `candidate` with a reason that names
  them, instead of `selected`. Document the flag in `references/14-deterministic-verification.md`.

## ADC-LOCAL-022: A line-ending override plus a sweep commit rewrites the repository

- Status: staged
- Scope: repo-agnostic
- Lesson: On a checkout whose line endings are normalized on the way in and out, a commit
  that both overrides the normalization setting and stages everything modified will see
  every normalized text file as changed and commit whole-file rewrites of them. The status
  view that was checked beforehand ran without the override and showed only the intended
  files, so the review that should have caught it was performed under a different rule
  than the commit. Stage explicit paths, commit without a sweep flag, let the attribute
  file decide line endings, and read the diff stat of every commit against its base
  before pushing.
- Evidence: A release commit meant to change four lines in four files was made with a
  normalization override and a sweep flag on a Windows checkout. The pull request then
  listed 58 changed files with roughly 10,000 line deltas, all whole-file line-ending
  rewrites of files no attribute rule pinned. The pre-commit status had shown four files.
  It was caught from the pull-request file list, the branch was rebuilt from the intended
  paths with a plain add, and the rebuilt diff was 8 files, 10 insertions, 10 deletions.
- Limits: The specific flags belong to one version-control system, but the shape, review
  under one rule and commit under another, is general. Repositories that pin every text
  path with an attribute rule are immune to this particular sweep and still benefit from
  the diff-stat check.
- Proposed target: references/00-conventions.md
- Proposed change: Under bounded execution and commit hygiene, require explicit staging,
  forbid sweep commits combined with environment overrides, and require a diff stat against
  the base before any push, with the 58-file rewrite as the named failure shape.

## ADC-LOCAL-023: A required job at the edge of its timeout is a flake waiting for contention

- Status: staged
- Scope: repo-agnostic
- Lesson: A continuous-integration job whose normal duration sits within a few percent of
  its timeout passes alone and fails whenever runners are shared, and the failure reads as
  a defect in the change under review. Measure each required job's duration against its
  ceiling and keep at least a two-to-one margin, or split the job, before opening several
  pull requests at once. A timeout that has never fired is not evidence that it is
  generous.
- Evidence: A mutation-replay job with a 25-minute ceiling had completed in 24 to 25
  minutes on every recorded run. Three pull requests opened within an hour ran it
  concurrently; one was canceled at 25 minutes 15 seconds with no verdict, while the same
  tree passed the job on another pull request. The failing pull request carried a one-file
  documentation proposal.
- Limits: One workflow on one hosted-runner platform. Some jobs cannot be split, and some
  ceilings exist to bound cost; the rule is to know the margin, not to remove ceilings.
- Proposed target: references/10-maintenance-harness.md
- Proposed change: In the harness prerequisites, add a duration-to-timeout margin check
  for every required job, with the concurrent-pull-request case as the trigger to review it.

## ADC-LOCAL-024: A refusal must name a repair that does not destroy something else

- Status: staged
- Scope: repo-agnostic
- Lesson: When a guard refuses because a bound input drifted, the message names the
  repair the operator will run. If the named repair is a broad regeneration that also
  overwrites human-reviewed records, the guard has traded one loss for another, and an
  operator in a hurry will take the trade. Offer a targeted repair for the one binding
  that drifted, and keep the broad regeneration for the case where nothing reviewed exists
  yet.
- Evidence: Gates bound to a hash of their build files refused after a branch switch with
  the message to rerun the planner and re-approve. Rerunning the planner would have
  replaced a hand-merged verification plan and profile. The operator instead recomputed
  the four bindings with the tool's own hashing function from a script, recorded the
  previous digests and the drift, and reran the dry run; this happened twice in two days
  because every branch whose build files differ trips it again. No command existed for
  that targeted repair.
- Limits: One tool. The general rule applies to any guard whose only suggested remedy is
  wider than the fault.
- Proposed target: scripts/adc.py
- Proposed change: Add a `gates --rebind GATE` operation that recomputes one gate's
  source binding, keeps the previous digest, requires an owner note, and leaves the
  profile and plan untouched; change the refusal message to name it first and the planner
  second. Document the branch-switch case in `references/14-deterministic-verification.md`.

## ADC-LOCAL-025: Keyword signals over source are presence, not weight

- Status: observing
- Scope: repo-agnostic
- Lesson: A content signal that fires on one keyword match in any source file cannot
  separate a repository whose product is built around a concern from one that mentions it
  once. When almost every signal fires, the planner's selection collapses to everything,
  and the human plan carries all the discrimination. Recording how many files matched, and
  how concentrated the matches are, would let the planner rank instead of toggle.
- Evidence: After documentation-only evidence was separated out, a desktop media
  repository still fired 29 of 30 signals from source hits, and the automatic plan
  selected 22 of 22 capabilities against a reviewed 11. A single package-description line
  satisfied the simulation signal; one save-related identifier satisfied persistence.
- Limits: One repository so far. Density thresholds risk hiding a real concern in a large
  codebase; any change should report the counts first and change selection only after a
  second repository confirms the shape.
- Proposed target: scripts/adc.py
- Proposed change: Record per-signal match counts and the share of scanned source files
  that matched, surface them in the plan reasons, and revisit selection once a second
  repository provides evidence.
