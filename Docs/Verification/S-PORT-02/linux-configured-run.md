# S-PORT-02 Configured Linux Pipeline Run

Date: 2026-08-21. Recorded by `Record-LinuxConfiguredRun.sh` under WSL Ubuntu on the
dev machine, driving the self-contained linux-x64 test host in `--serve-configured`
mode with the pinned real MediaInfo 24.01, the range floor, hash-verified in place
before execution: `a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6`.
The test host was published from the audited locks with restore disabled and the
locks verified untouched afterward. Until this run, Linux evidence proved only that
inspection is unavailable by default; this run proves the configured pipeline itself
on Linux with the real tool.

## Observations

- Capability row over the wire:
  `{"id":"media-inspection","availability":"available","reasonCode":"inspection-configured"}`.
- All four committed media files answered 200 through the full pipeline with
  `authority: MediaInfoLib v24.01`: MPEG-4, Matroska, WebM facts correct, and the
  vfr fixture reported `frameRateMode: VFR` with frame rate, frame rate value, and
  frame count all absent, the no-silent-default rule live on Linux with the real
  tool.
- The seven-shape hostile corpus returned one byte-identical 422 body with no path
  echo: outside-root, the root itself, a traversal spelling, a path through a real
  symlinked directory inside the root, a symlinked file inside the root, a relative
  name, and an absent file. The symlink shapes prove the reparse-component walk on
  genuine Linux symlinks, which the Windows gate can prove only with junctions.
- Privacy greps over all four response bodies found no banned name.
- The host shut down clean on stdin end-of-file, printed its `STOPPED` line, and no
  `mediainfo` process survived the run.

## An operational finding, recorded for operators and for the adversarial queue

The first attempt failed every happy path with 502 `authorityFailure` while the
hostile corpus behaved perfectly: the host had been started with an empty loader
path, and the authority child inherits the server's environment, so the user-prefix
tool could not load its own libraries. Starting the host with
`LD_LIBRARY_PATH` pointing at the extracted prefix resolved it. The rule this
records: the bounded primitive deliberately passes no environment of its own, so a
user-prefix tool needs its loader path present in the environment the server starts
with; a system-installed tool does not. This is a concrete data point for the
independent review's open inherited-child-environment item.

One environment note for reruns: WSL wipes `/tmp` when its VM restarts between
invocations, so run outputs that must survive belong on a Windows-backed mount or in
the captured console stream, which is what this record is built from.

## Covering sweep

The commit carrying this record and its companion capture record was attested by the
full seven-gate sweep on 2026-08-21 against `1579cb91`: static 253, verify 1223, http
5182, browser 694, inspection 97, linux sandbox 27 with zero runtime writes, evidence
audit 65088, audit sha256
`3a712c982f10f44eb4526fbadaab2e5dfb498a41af2f9f5e6ed38291833e8a31`. The first sweep
attempt failed at the http gate twice at two different transient points, a mid-flight
connection error and a process-identity capture miss, each with a complete clean
teardown per its own failure packet, then passed at the identical check count after
the machine settled; the shifting points, clean teardowns, and unchanged product
surface classify the pair as environmental load, consistent with the recorded
developer-environment contention lesson. This paragraph postdates the audited set by
construction.
