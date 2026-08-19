# Media Inspection Adapter Contract

Version: 0.1 Draft. Date: 2026-08-18. Base: `d7e6412e`. Implements D-045; consumes the
agreed-facts list; introduces one new decision, D-046, which is proposed and not
ratified. No code exists yet; this contract is what the code must satisfy.

## Layering

- `StaxRip.Contracts` gains the typed payload: `MediaFactsResponse` and its parts. Pure
  DTOs, versioned schema id `staxrip-media-facts-v1`, no behavior.
- `StaxRip.Core` gains the port: `IMediaFactAuthority` with one operation, probe a path
  under a cancellation token and return the raw authority document plus authority
  identity. Core also owns normalization from raw fields to the typed payload, because
  normalization rules are product rules, not adapter details.
- `StaxRip.Platform` gains the adapter: the MediaInfo CLI implementation of the port,
  owning process execution under the D-045 bounds. The backup activates by adding a
  second adapter class here; nothing above this layer changes, which is the swappable
  boundary D-045 requires.
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

Sections mirror the agreed-facts list exactly: `container`, `video[]`, `audio[]`,
`subtitles[]`, `chapters[]`, with the exposed fact set of
`Media-Inspection-Agreed-Facts.md` version 1 and nothing else. A fact not in that list
does not ship until the list gains it first. Enablement policy fields do not exist here
at all.

## The privacy guard

The adapter strips, before anything leaves it: `UniqueID` and every `UniqueID/*`
variant, `Encoded_Library_Settings`, `Encoded_Application` command-line style strings,
`File_Created_Date`, `File_Created_Date_Local`, `File_Modified_Date`,
`File_Modified_Date_Local`, and any field whose value embeds a filesystem path other
than the probed path itself. The file-date fields entered the list from captured
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

## Path acceptance, the new boundary this slice opens (D-046, proposed)

The bootstrap's standing rule is that the server accepts no user path. Inspection cannot
exist without accepting one, so the rule must be replaced deliberately, not eroded. The
proposed policy is in D-046: configured media roots, canonical containment, regular
files only. Until D-046 is ratified, no endpoint accepts a path and the capability stays
`unavailable`; the adapter can still be built and tested against fixtures, because the
port takes a path from its caller and the gates are the caller.

## Gate plan

A new `port-inspection` gate, level 1, joining the wrapper after the contract gates:

1. Golden fixtures: one captured `--Output=JSON` document per pinned-range end, checked
   in under `eng/fixtures/`, with the normalization output asserted field by field
   against the agreed-facts list. Capture is blocked on tool acquisition approval and is
   the matrix's named pending verification.
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
   cite. Blocked on Windows CLI acquisition approval.

## What this contract deliberately does not do

No thumbnailing, no summary prose block, no write of any kind, no PATH search, no
environment-variable tool discovery, no fact caching in version 1 because the Windows
cache's mtime-aliasing is a recorded unknown, and no second authority.
