# SLICE-001 Isolated Runtime Plan

Date: 2026-08-15. Repository base: `c26e0fa6`. Status: Reviewed v6 paired source-open, stale-state, refresh, handle, and postflight evidence passes; historical harness and runner holds are retained below.

## Clean donor identity

The inspected clean portable donor contains:

```text
files=3928
bytes=3302730093
reparse_points=0
Apps+Fonts+Icons_bytes=3290081981
canonical_content_manifest_sha256=067480EB0BDCF65E483EA2A44300CA414528D0E9FA4E61991E49E304C432BB89
StaxRip.exe_bytes=3861504
StaxRip.exe_version=2.52.5
StaxRip.exe_sha256=2579B20A6600260B5DF777716AE59AA905489409E6AF395D62EF267ECBD05943
```

The donor has no Settings directory. Its location is intentionally omitted from tracked evidence. The complete content manifest reproduced before planning the runtime tree.

## Fixture identity

The tracked fixture recipe was corrected to accept the intentional blank VPY and SRT lines. A fresh run into an empty ignored fixture root with the manifest-pinned PowerShell and FFmpeg identities reproduced all six recorded artifact byte lengths and SHA-256 values. The current recipe identity is 7,484 bytes and SHA-256 `DF5FDCF6DADA54CC68AA4619382DFEDE7DD9B06B5E00B248D05A8791A413E051`. This verifies fixture construction for that pinned toolchain. It does not identify a StaxRip template or exercise source opening.

## Isolation topology

Use ignored `Source/obj/ProjectCheckRuntime/` only. Before creating it, verify its resolved absolute path is inside the current scratch worktree.

1. Create one task-owned physical shared copy of donor `Apps`, `Fonts`, and `Icons`.
2. Create separate baseline and candidate roots with their own executable and root files.
3. Point each root to only the task-owned shared copy. Never create a link to the clean donor.
4. Give every trial fresh Settings, input, temp, and output directories under the ignored runtime root.
5. Preserve donor and runtime-root manifests before and after each block. Stop on an unexpected file, reparse point, or manifest change.
6. Build baseline commit `c26e0fa6` and the candidate sequentially from the same absolute build-source path with direct Release x64 MSBuild. Do not run packaging or release scripts.

No runtime tree existed when this plan was recorded.

## Settings and process guard

StaxRip resolves settings through the current-user `Software\StaxRip\SettingsLocation` mapping at `Source/General/General.vb:140-207`. Settings load and save share the global mutex `staxrip settings file` at `Source/General/GlobalClass.vb:103-129`.

Before changing the isolated mapping or launching either build:

- require zero unrelated StaxRip processes for the current Windows user;
- save the exact prior registry state in task-local memory and restore it in `Finally`;
- fail closed if the prior value cannot be read or restored;
- do not terminate an unrelated process or expose its title, command line, or paths; and
- use a separate Windows account only after explicit authorization.

One unrelated process previously caused this plan to pause safely. A later read-only check found zero StaxRip processes. That removes the environmental hold but is not runtime evidence.

## Partial runtime result

The isolated bootstrap passed after the task runtime received the Release x64 native FrameServer component. The first `FX-AVS-01` source-open attempt did not reach project-check publication. It timed out while evaluating a generated VapourSynth source fragment that referenced `core` before initialization. The bounded failure packet attributes that fragment to the handle-only harness lifecycle; it does not establish the outcome of the complete normal StaxRip lifecycle or a defect in the AVS fixture.

The exact task host was stopped after the timeout. The task's temporary settings-location registry mapping was absent, and a read-only process check found zero remaining StaxRip processes. A corrected harness then passed an independent cleanup-order review and produced the VPY and MP4 smokes below. The first MKV source flow printed `PASS`, but its host did not terminate because that harness disposed MainForm without invoking production `OnFormClosed`, which closes a foreground process form. That source-flow timing is invalid and excluded. The task host was stopped, the mapping was absent, and zero task processes remained.

The final reviewed host sets `BypassProjectSaving`, invokes production close and `OnFormClosed`, drains UI work, rejects a canceled close, and falls back to disposal. Nested `Finally` blocks then dispose the form, remove the task registry mapping, and release the mutex. Independent review found no remaining High or Medium harness-safety issue. The lifecycle label is `production-equivalent-show-first-idle`; it is not exact `Application.Run` or complete interactive-application evidence.

### Bounded route parity smokes

The corrected hosts produced one successful baseline and one successful candidate smoke for each valid source route with these stable identities:

| Item | Identity |
|---|---|
| Baseline product at `c26e0fa6ae504f44a0cbb8e3e763935940e37641` | 3,860,992 bytes; SHA-256 `1CF3044A393E8B505538BEB3BF637DBF8ECC17FEA27E0E3B26409C134254FA2C` |
| Candidate product | 3,900,928 bytes; SHA-256 `13E4887CB33F4E64B5475EC127871048B4D225CA30732264FE7E999656858A7C`; copied-source manifest SHA-256 `EC486FB45D5554E20DF08C6769DA783C20966C71C081496075757D5B3D1FEE00` |
| Automatic Workflow template | 29,709 bytes; SHA-256 `A458A93CBA6DCAF4DC3E220DD2C2E6DA5201D47E636E0377DFFC1B5CA8B02E00` |
| Pre-final reviewed harness source and executable | 46,133 bytes and SHA-256 `81608A677A153089F0150EB0CE31F933402A86AE5755FB20F4C56887282B1DFF`; 29,696 bytes and SHA-256 `DAD2B2725566BAA86D72369E4CC7FBA5F6FACAFBFFDA861FB1A075C0B3368341` |
| Final reviewed harness source | 46,751 bytes; SHA-256 `517DB84E00BF75E562D772DB54794863687D065E45532A1A46DB3F273CF6F429` |
| Final reviewed harness executable | 30,208 bytes; SHA-256 `F2BBA61BFECF40818BB42DF8871024C11D1D5CCDC452BD03E8ED9C5D91DBCB91` |

| Fixture and reviewed host | Template and contract SHA-256 | Baseline source open | Candidate source open | Matched facts |
|---|---|---:|---:|---|
| `FX-VPY-01`, pre-final host | Automatic `A458A93CBA6DCAF4DC3E220DD2C2E6DA5201D47E636E0377DFFC1B5CA8B02E00`; contract `7A87A38BD8BE940A8154ADB8BBF5ABF0215FDAB534CDFB5620A260427E2710F8` | 1021.623 ms | 1098.959 ms, +77.336 ms | 320 by 180, 120 frames, VapourSynth |
| `FX-MP4-01`, pre-final host | Automatic `A458A93CBA6DCAF4DC3E220DD2C2E6DA5201D47E636E0377DFFC1B5CA8B02E00`; contract `58EA330819D6091D47C0D7118E6A9ADD43DA5B9A618F65C84DD6956DCD2FFE75` | 1291.708 ms | 1042.857 ms, -248.851 ms | 640 by 360, 90 frames, VapourSynth |
| `FX-MKV-01`, final host | Automatic `A458A93CBA6DCAF4DC3E220DD2C2E6DA5201D47E636E0377DFFC1B5CA8B02E00`; contract `A46E375C15F659A980C3065D4056872471A55DA1600ED06FA4733F7399F7F15B` | 2489.872 ms | 2444.331 ms, -45.541 ms | 640 by 360, 90 frames, VapourSynth |
| `FX-AVS-01`, final host | Re-mux `2BADFB963612E6E1BCD549B81479C3C5A9CA15BDAA69A9346ED146CEBB777943`; contract `E798CAEA049A7824A5F269F135055E9C9669AEEF92E339ADB1F607053ECA11E1` | 193.977 ms | 238.754 ms, +44.777 ms | 320 by 180, 120 frames, AviSynth |

For every row, baseline and candidate used the same named template, produced the same workflow-contract hash across source, project, target, crop, script, encoder, muxer, and audio-track fields, and reported the same bounded media facts. Each baseline reported the feature absent and passed 16 dynamic assertions. Each candidate published `Available` with exactly three checks and passed 17. Here, `assertions=N` counts successful dynamic `Assert` invocations, not distinct static requirements. The final-host MKV and AVS runs exited normally; all recorded smoke postflights had no temporary registry mapping and zero remaining StaxRip or task-host processes.

These one-pair route smokes did not establish the performance target, refresh p95, malformed-later-open stale publication, or full-application handles. At that stage, U-004 and Q-003 remained Open. The accepted matrix below later closes them.

### Paired-runner safety hold

The first frozen paired driver, SHA-256 `434C84787DF4D10CA85D83D7178925CC5042F55033CD8A39DBACC58DAFF80FE5`, was held before execution. Independent review found that child `TEMP` and `TMP` were not isolated, registry deletion had a check-then-reopen race, PID-based tree termination was not atomic with identity verification and did not track orphaned descendants, and interruption immediately after process start could bypass host termination before mapping cleanup. No acceptance measurement came from that driver. A corrected driver requires a new identity and independent review before execution.

A later corrected revision was also held until registry deletion required both zero active Job Object processes and successful job-handle closure. Its first execution then failed during layout resolution because three `Split-Path` calls bound the wrong parameter. It entered no product work, started zero hosts, left zero task processes and mappings, and created no evidence root. Exact v6 changed only those three path expressions and passed independent review before execution.

## Accepted paired runtime result

The ignored aggregate summary uses schema `staxrip.project-check-runtime.paired.v1`, reports `PASS`, and has evidence id `paired-20260816T032305Z-4b9b5844b1f4`. It is 7,622 bytes with SHA-256 `CBB592D9EB4D215A070F73B349B6E2F51F24BFE2044ACB3CF19BA80A94159F62`. The observation date is 2026-08-16 UTC. The base is `c26e0fa6ae504f44a0cbb8e3e763935940e37641`, and the configuration is Release x64.

The executed v6 driver has SHA-256 `627F49007B81F7ED2004D7420024A57EC1CD8429E1FD7C339B0A76A2E5E50949`. It used the baseline, candidate, final host source, and final host executable identities recorded above. Seed settings have SHA-256 `DADCA5491D4DC22C30DD19AB193DA8E8102A7D0597D4F7E645C651B7B5DEFAB8`. The 3,921-file shared-content manifest has SHA-256 `70834B6708840956474D7F5AD5EED2C641568DABE4A78CA5B6E4AA1AAE99FAC8`, and the protected-metadata fingerprint has SHA-256 `79E3A7DBE0E64BC1A9F9FF16645DA05726C323401278704951F2CC4C91866979`.

The privacy-safe environment record is Windows `10.0.26220.0`, 64-bit OS and process, AMD Ryzen 9 5950X with 32 logical cores, 68,627,591,168 bytes physical memory, fixed storage, balanced power-plan class, .NET Framework release 533509, PowerShell 7.6.4 with executable SHA-256 `DB6DD81183FE57D22E03B911EC9A30A2FD7C40542E97743615355A6FB44F458F`, 96 DPI, 100 percent display scale, and StaxRip UI scale 1.0.

Process temp was separate from project temp. Each host was assigned to a kill-on-close Job Object. Parent fallback mapping deletion required zero active job processes and a successfully closed job handle.

Each fixture discarded three baseline and three candidate warmups, then ran 20 measured baseline/candidate pairs in alternating AB/BA order with fresh settings, input, temp, and output state for each open.

| Fixture | Baseline median | Candidate median | Candidate delta | Allowed delta | Result |
|---|---:|---:|---:|---:|---|
| `FX-AVS-01` | 185.665 ms | 208.793 ms | +23.128 ms | 100.000 ms | Pass |
| `FX-VPY-01` | 308.792 ms | 326.350 ms | +17.558 ms | 100.000 ms | Pass |
| `FX-MP4-01` | 978.984 ms | 1017.510 ms | +38.525 ms | 100.000 ms | Pass |
| `FX-MKV-01` | 2227.068 ms | 2227.798 ms | +0.730 ms | 111.353 ms | Pass |

The four route blocks preserve the fixture, engine, template, workflow-contract, dimensions, and frame-count identities recorded in the smoke table. All 160 measured opens completed successfully after 24 discarded warmups. The complete run used 186 successful host launches and took 1011.378 seconds.

The malformed-later-open challenge opened `FX-MKV-01` and then `FX-BAD-01`. It passed 15 dynamic assertions in 1137.220 ms and left project-check presentation `Hidden`, so the prior current result was not published as current after the failed later open.

The refresh and handle block used `FX-MKV-01`, the slowest candidate fixture. After five warmups, all 50 samples passed. Nearest-rank sample 48 produced p95 1.311 ms against the 100 ms budget. Process handles changed from 625 to 624, delta -1, so no retry was required. The block passed 69 dynamic assertions.

The aggregate postflight and a separate 15-check validation both passed with zero task processes and zero exact baseline or candidate settings-location mappings. The summary reports every protected identity and manifest unchanged. Raw trial paths, generated scripts, commands, logs, and timing samples remain under the ignored task evidence tree and are not published.

This closes Q-003 and U-004 for the approved compatibility, performance, stale-state, and handle protocol. The `production-equivalent-show-first-idle` lifecycle still is not exact `Application.Run`, and the result does not replace the complete MainForm, operating-system accessibility, physical-input, or human walkthrough gates.

## Measurement protocol

### Full source flow

- Record baseline and candidate executable, runtime, tool, template, and fixture hashes.
- For each successful fixture, discard three warmups.
- Run 20 measured fresh-state opens in paired alternating AB/BA order.
- Measure from interactive open entry after selection to the first idle UI turn after presentation publication.
- Report a separate median for each fixture.
- Pass when each candidate delta is no more than the larger of 5 percent of its baseline median or 100 ms.

### Evaluation and rendering

- Load the slowest successful fixture.
- Discard five explicit refreshes.
- Measure 50 unchanged UI-thread refreshes from snapshot start through the first idle turn after publication.
- Sort the values and use sample 48 as nearest-rank p95.
- Require p95 no greater than 100 ms.

### Process handles

- After the same five warmups, drain UI work and record `Process.HandleCount`.
- Run 50 refreshes without opening details.
- Drain UI work with the same GC and finalizer policy and record the final count.
- Require final minus initial no greater than zero.
- Repeat the whole block once if the first block is nonzero. Do not add tolerance.

## Privacy-safe evidence

Record only OS build, CPU and logical-core count, RAM, storage class, power plan, .NET release, display scaling, UI scale, configuration, commit, hashes, fixture ids, counts, and aggregate durations. Do not record user paths, user names, window titles, media names, registry values, scripts, commands, logs, or source metadata.

## Remaining boundary

Q-003 and U-004 are Closed by the accepted paired result. U-011 remains Open until the human walkthrough. Exact `Application.Run`, complete MainForm accessibility, physical DPI and high contrast, Narrator and UI Automation, physical keyboard and focus, abort and recovery branches, and the human value decision remain outside this runtime packet. The slice is not `Done with evidence`.
