# Media Inspection Adapter Contract

Version: 0.3. Date: 2026-08-26. Base: `0ce3594d`. Implements D-045; consumes the
agreed-facts list; D-046 was ratified on 2026-08-19 and amended on 2026-08-21. The
implementation now exists: the adapter and normalization layers in `StaxRip.Core` and
`StaxRip.Platform`, the server wiring in `StaxRip.Server`, the contract corpus in
`StaxRip.ContractTests`, and the `port-inspection` gate. This contract remains what
the code must satisfy, and the golden fixtures it tests against are captured and
committed under `eng/fixtures/media-inspection/`. Configured runs beyond Windows are
recorded in `Docs/Verification/S-PORT-02/linux-configured-run.md` and
`Docs/Verification/S-PORT-02/t540p-golden-capture.md`.

Ratified-design note, 2026-08-26: D-055 through D-059 are implemented on top of this
contract. The authority options gain an optional `LoaderLibraryPath`, which is the only
way a loader path reaches the tool, because the child environment is now constructed
from a per-platform base set and nothing is inherited (D-056). The port gains
`ProbeVersionAsync`, which the composition root executes once at activation so an
available capability is one whose tool has run (D-058); the activation verdict,
inspection-unconfigured, inspection-tool-unresolvable, inspection-tool-unready, or
inspection-version-unsupported, is recorded in process while the wire keeps the pinned
bootstrap vocabulary, because widening it is a contract decision. An admitted file is bound to
its identity across the probe and refused publication if the binding breaks (D-055);
probes are cancelled by application shutdown (D-057); and only members of the closed
reason vocabulary reach the wire (D-059). The two new boundary crossings, the
environment read in `ConstructedEnvironment.cs` and the held handle in
`MediaFileIdentity.cs`, are each a named sanctioned crossing in the static gate with a
narrowed ban of its own, exactly as the probe and the execution primitive are.

## Layering

- `StaxRip.Contracts` gains the typed payload: `MediaFactsResponse` and its parts. Pure
  DTOs, versioned schema id `staxrip-media-facts-v1`, no behavior.
- `StaxRip.Core` gains the port: `IMediaFactAuthority` with one operation, probe a path
  under a cancellation token and return the raw authority document plus authority
  identity. Core also owns normalization from raw fields to the typed payload, because
  normalization rules are product rules, not adapter details.
- `StaxRip.Platform` gains the adapter: the MediaInfo CLI implementation of the port,
  owning process execution under the D-045 bounds. Process execution lives in exactly
  one bounded-execution primitive that the adapter calls, with the D-045 bounds tested
  once on the primitive; a future tool reuses it rather than rolling its own, because
  duplicated process rules across adapters are the drift risk the repository's
  cross-pass rules already name. The backup activates by adding a second adapter class
  here; nothing above this layer changes, which is the swappable boundary D-045
  requires.
- `StaxRip.Server` gains one read-only endpoint behind the existing session model.
  Capability `media-inspection` moves from `unavailable` to `available` only when the
  resolver, version range, and gates all hold at startup.

## The typed payload

Shape rules, before field lists: absence is an omitted property, never a default; every
canonicalized fact carries both `canonical` and `raw`; every response names its
authority, the tool version from `creatingLibrary.version`, and the schema id; stream
order is the authority's native order with the authority's native index; no field ever
contains an absolute path other than the request's own echo, and no field contains a
globally unique media identifier.

Sections mirror the agreed-facts list: `container`, `video[]`, `audio[]`, the
subtitle section serialized as `text[]`, and `chapters[]`, with the exposed fact set of
`Media-Inspection-Agreed-Facts.md` version 1 and nothing else. A fact not in that list
does not ship until the list gains it first. Enablement policy fields do not exist here
at all.

## The privacy guard

The adapter strips, before anything leaves it: `UniqueID` and every `UniqueID/*`
variant, `Encoded_Library_Settings`, `Encoded_Application` command-line style strings,
`File_Created_Date`, `File_Created_Date_Local`, `File_Modified_Date`,
`File_Modified_Date_Local`, and any field whose value embeds a filesystem path other
than the probed path itself. Amended 2026-08-21: each listed name is a family head
matched by prefix, not an exact name, because the authority splits one display fact
across variants and adds variants across the supported range; a measured ceiling
capture of a muxer-written file reports `Encoded_Application_Name` and
`Encoded_Application_Version` beside `Encoded_Application`. The value-embedded-path
rule was implemented 2026-08-22: the guard removes any member whose value carries an
absolute path in drive-letter, doubled-separator, or rooted-POSIX form, and recognizes
only those forms, because a looser rule would strip legitimate titles that merely
contain a colon or a slash. CT-044 proves both directions. The file-date fields entered the list from captured
evidence: 26.05 emits them and they describe the user's filesystem, not the media.
The guard is a named function with a self-test that feeds a synthetic raw document
containing every stripped field and fails if any survives, and the self-test is wired
into the contract test harness so reverting the guard turns the harness red. That is the
R-S2-036 rule applied in advance.

## The error contract

Three outcomes, never conflated: `facts` on success; `absent` when the authority ran
clean but a fact is missing, expressed by omission; `error` with a typed reason when the
authority could not answer, covering resolver failure, version out of range, timeout,
kill-on-cancel, nonzero exit, output overflow, and JSON that does not parse. Error
payloads carry the reason class and bounded sanitized detail, never raw stderr, never
the command line. Cancellation must leave no process and no partial state, proven by the
same ownership-receipt pattern the SLICE-002 harness already uses.

## Path acceptance, the new boundary this slice opens (D-046, ratified)

The bootstrap's standing rule was that the server accepts no user path. Inspection
cannot exist without accepting one, so the rule was replaced deliberately, not eroded:
D-046, ratified 2026-08-19, sets configured media roots, canonical containment, regular
files only, and a uniform rejection shape with no existence oracle. The endpoint ships
only with that policy enforced, and the hostile-path corpus is its enforcement
evidence; until the endpoint exists the capability stays `unavailable`.

Transport note, 2026-08-20: the path crosses the boundary in a bounded JSON POST body
on the one POST route the request law admits, never in a query string or URL segment,
so user paths stay out of URLs, logs, and browser history. The bootstrap's
queryless-and-bodyless request law was amended for exactly that route: declared length
within the transport bound, exact JSON content type, never chunked. The route exists
and answers `capability-unavailable` behind the session gate while unconfigured. The
configured pipeline exists and is exercised at the wire by the `port-inspection` gate;
the shipped production entrypoint still supplies no inspection configuration, so a
production host answers unavailable by design until a configuration surface is
decided.

Swappability note, 2026-08-21, from the certification review; qualified 2026-08-26:
the swappable boundary is the port plus the version vocabulary, which travels through
the port's `IsSupportedDocumentVersion` so request handling names no concrete adapter.
The composition root is the deliberate exception: `ServerApp` constructs
`MediaInfoCliAuthority` from `MediaInfoCliOptions`, which is ordinary composition-root
coupling and means an ffprobe activation changes the composition root and its
configuration surface in addition to adding the second adapter. The
normalization layer itself parses the primary authority's JSON shape by design;
activating the ffprobe backup therefore adds a per-authority normalization strategy
alongside the second adapter, and that work is part of the recorded activation cost,
not a surprise.

## Gate plan

A new `port-inspection` gate, level 1, joining the wrapper after the contract gates:

1. Golden fixtures: captured and committed, one `--Output=JSON` document per fixture
   per pinned-range end under `eng/fixtures/media-inspection/` with a provenance
   manifest. The gate asserts the normalization output field by field against the
   agreed-facts list over these documents.
2. Hostile path corpus: traversal shapes, reparse points, device names, overlong paths,
   quote and control characters, paths outside the configured roots. Every one must
   produce the typed error, never an execution attempt, proven by the no-process check.
3. Malformed output corpus: truncated JSON, wrong schema, missing `creatingLibrary`,
   oversized output. Typed errors, bounded capture, no crash.
4. Cancellation: kill mid-probe, require process-group reap, port of the ownership
   receipt discipline, and no temporary file residue.
5. Privacy self-test: the guard's mutation-proof, red on revert.
6. Comparison recorder: on Windows, run the same fixture files through the existing
   MediaInfo.dll wrapper and the CLI, record per-fact agreement per the protocol in the
   agreed-facts list, and store the recorded divergences as data the exit criteria can
   cite. The CLI is acquired and hash-recorded; this recorder is now unblocked.

## Definition of done for the first code unit

Ratified by the maintainer on 2026-08-19. The typed payload, normalization layer, and
privacy guard are done only when all four hold, in this order:

1. Red first. Every test was observed failing before its implementation existed. A test
   born passing is the check-that-cannot-fail class wearing a test's clothing, and it
   does not count toward done.
2. Green against the goldens. The tests pass field by field over all eight committed
   documents in `eng/fixtures/media-inspection/`.
3. Mutation proofs, recorded and wired into the harness so they re-run on every gate
   pass, one per load-bearing rule: reverting the privacy guard must turn the harness
   red, with the goldens' retained `UniqueID`, `Encoded_Library_Settings`, and
   file-date fields as the proving inputs; injecting a silent default into the
   normalizer must be caught by the `vfr-ffv1.mkv` tests, which is why that fixture has
   no frame rate; and flipping any canonical mapping must fail the field-by-field
   assertions. A proof run once by the author and remembered is not a proof.
4. Full automated mutation tooling stays deferred per V01 of the verification plan:
   activate after source exists with an approved bounded runner, and do not add a
   mutation framework merely for this slice.

## What this contract deliberately does not do

No thumbnailing, no summary prose block, no write of any kind, no PATH search, no
environment-variable tool discovery, no fact caching in version 1 because the Windows
cache's mtime-aliasing is a recorded unknown, and no second authority.
