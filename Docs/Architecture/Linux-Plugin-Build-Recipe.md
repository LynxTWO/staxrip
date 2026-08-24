# Building VapourSynth Plugins From Source on Linux

Version: 0.1. Date: 2026-08-23. Owner: P-004. Follows D-049 tiering and D-050 sequencing.

The upstream contribution strategy in D-051 was tested and declined: a maintainer's answer
was that Linux users should build from source. This records what that actually costs,
measured rather than estimated, and the recipe that makes it repeatable.

The output of this work is **recipes, not binaries**. These plugins are predominantly GPL,
and publishing built artifacts would take on redistribution obligations under D-051 for
software that is not ours. Nothing here is redistributed.

## Scope: 38 plugins, not 91

Of the 168 `.dll` entries in the catalogue, measured 2026-08-23:

| Group | Count | Action |
|---|---|---|
| Already have a Linux binary in the index | 59 | Pin, do not build |
| Declare VapourSynth filters, no Linux binary | **38** | The build list, per D-050 |
| Declare AviSynth filters only, no Linux binary | 62 | Per-plugin promotion under D-050, deprioritised |
| Declare neither | 9 | Support entries, not filters |

## The recipe

`CrossPlatform/eng/Build-VsPlugin.sh`, run on the verification host. Clones, detects the
build system, configures, builds, installs into the autoload directory, and then **proves
the plugin loads** by diffing VapourSynth's registered namespace set before and after.
Building is not the test; loading is.

Five things it has to get right, each learned by getting it wrong first:

1. **Clone with `--recurse-submodules`.** Configure fails outright otherwise. dfttest2's
   `vectorclass` is a submodule and its absence is a confusing "cannot find source file".
2. **API 3 plugins need headers the wheel does not ship.** The pip wheel carries API 4
   headers only, so a source that includes `VapourSynth.h` needs the R57 source archive.
   Upstream's own workflow fetches R57 for exactly this reason.
3. **meson must run under a Python that has VapourSynth.** Several `meson.build` files call
   `vapoursynth.get_include()`, which fails with a bare toolchain interpreter. Installing
   meson into the VapourSynth virtual environment is the fix.
4. **`PKG_CONFIG_PATH` must point at the wheel's `pkgconfig` directory.** Plugins declaring
   `dependency('vapoursynth')` fail with "not found (tried pkg-config and cmake)" until it
   does. The wheel does ship `vapoursynth.pc`.
5. **`meson` itself is not installed by default** on Ubuntu 24.04 and, under PEP 668, needs
   a virtual environment rather than a bare `pip install`.

## Results, first pass

Eight plugins built and verified loading, on a four-core laptop:

| Plugin | API | Build system | Time | Artifact | Registered namespace |
|---|---|---|---|---|---|
| dfttest2 CPU | 3 | cmake | 15 s | 368,792 B | `dfttest2_cpu` |
| descratch | 4 | meson | 25 s | 32,608 B | `descratch` |
| vivtc | 4 | meson | 3 s | 58,632 B | `vivtc` |
| vfrtocfr | 3 | meson | 2 s | 36,688 B | `vfrtocfr` |
| timecube | 4 | make | 13 s | 150,720 B | `timecube` |
| dotkill | 4 | meson | 4 s | 55,512 B | `dotkill` |
| LibP2P | 4 | meson | 6 s | 359,456 B | `libp2p` |
| MiniDeen | 3 | cmake | 8 s | 162,072 B | `neo_minideen` |

Verified together in one core: `descratch, dfttest2_cpu, dotkill, libp2p, neo_minideen,
timecube, vfrtocfr, vivtc` alongside the built-in `resize, std, text`.

A second pass added three more, all needing hand-compilation because they carry no build
system at all:

| Plugin | API | Build | Artifact | Registered namespace |
|---|---|---|---|---|
| scenechange | 3, bundled | `gcc` one-liner | 20,568 B | `scd` |
| temporalsoften | 3, bundled | same repo, same command | 20,240 B | `focus2` |
| W3FDIF | 3 | `g++` one-liner | 20,424 B | `w3fdif` |

A third pass added four more once triage identified their specific gates:

| Plugin | Gate that had to be found first | Artifact |
|---|---|---|
| BM3DCPU | `-DENABLE_CUDA=OFF`, and API 3 headers passed explicitly | 86,968 B |
| f3kdb Neo | `-DENABLE_PAR=OFF`, else it fails at link on `-ltbb` | 1,140,760 B |
| FFT3D Neo | Same | 688,616 B |
| DFTTest Neo | Same, **plus a non-shallow clone**: its CMake runs `string(STRIP)` on a version tag, which is empty in a `--depth 1` clone and errors out | 241,512 B |

A fourth pass, after the maintainer installed the four system libraries, added three more:
`vcm` on fftw3f, which also covers `vcmod` since they are one artifact; `d2vsource` on the
FFmpeg development headers; and `FixTelecinedFades`.

### The harness had a destructive false negative, and it corrupted one of these findings

Found by an independent session on 2026-08-24, in the script recorded here as the recipe.
The load test snapshotted the registered namespace set, copied the `.so` in, snapshotted
again, and treated an unchanged set as "not loaded". **If a copy of that same plugin was
already in the plugin directory, its namespace was already in the baseline**, so the diff
came back empty, the verdict was "not loaded", and the failure branch then **deleted the
working plugin**. A functioning build was reported broken and then destroyed.

A second defect sat alongside it: both namespace probes redirected errors to `/dev/null`,
so a probe that crashed returned empty on both sides, compared equal, and also read as
"not loaded".

The fix, written by that session and imported here verbatim, clears any stale copy before
taking the baseline and checks both probes for an empty result rather than hiding it. It
also closes the inverse case I had not considered: an empty probe *after* install would
compare unequal to a good baseline and read as a false **"loaded"**.

**One reported result was wrong because of this.** `FixTelecinedFades` was never blocked by
yasm. It builds in four seconds and needs no assembler at all; the harness was misreporting
it, and because that misreport coincided with a genuine `libavcodec` block on `d2vsource`,
both were attributed to the same missing-dependency batch. Only `d2vsource` was really
blocked.

`yasm` still earned its install for a different reason: it flips `HAVE_YASM` in the bundle
repo used to recover W3FDIF, which un-gates assembly paths in fluxsmooth, nnedi3,
imagereader and mvtools that had been building without SIMD. Reported by that session and
not independently confirmed here.

The general lesson is worth more than the fix: **a verification step that takes destructive
action on a negative result must be certain the negative is real.** This one deleted the
artifact it was testing, on a condition that occurs every time the harness is re-run against
an already-installed plugin, which is the normal case during iteration.

**Eighteen third-party plugins now load together** in one core: `bm3dcpu, d2v, descratch,
dfttest2_cpu, dotkill, focus2, ftf, libp2p, neo_dfttest, neo_f3kdb, neo_fft3d,
neo_minideen, scd, timecube, vcm, vfrtocfr, vivtc, w3fdif`.

That is **18 of the 38-entry build list**, verified by namespace registration rather than
by builds exiting zero. State re-confirmed after the harness fix: 18 registered namespaces
against 18 `.so` files in the plugin directory, so nothing was lost to the deletion bug.

**One caveat on `ftf` specifically.** It is an API 3 plugin running against a core that
reports API R4.2. It loads and registers through the compatibility path, which the load
check confirms, but loading is not functioning. Before anything depends on it, it needs a
functional test against real footage rather than trust in the namespace appearing. The same
caution applies to every API 3 plugin in the list above, which is most of them; the load
check proves the entry point resolves and nothing more.

Two more rules, and the first one contradicts rule 4:

8. **The `neo_*` family must be built with `vapoursynth.pc` OFF `PKG_CONFIG_PATH`.** Their
   CMake does "if pkg-config found VapourSynth, use its include dir, *else* use our
   vendored headers" as an either/or. Those plugins are API 3 and vendor their own headers,
   so a pip-wheel `.pc` on the path wins the branch, drops the vendored API 3 headers, and
   the build dies on `VapourSynth.h: No such file`. Rule 4 and rule 8 are opposites and
   which applies depends on whether the plugin vendors its headers.
9. **A shallow clone is not always safe.** Build files that derive a version from
   `git describe` or a tag list fail on `--depth 1`. Clone fully when a configure step
   mentions tags or versions.

Two more recipe rules, again learned by getting them wrong:

6. **Some of these are C, not C++.** `scenechange.c` and `temporalsoften.c` fail under
   `g++` with "jump to label crosses initialization", which is a C++ rule and legal C.
   Compile them with `gcc`.
7. **Include prefixes vary.** W3FDIF includes `<vapoursynth/VapourSynth.h>`, so an include
   root containing the headers directly does not satisfy it. A prefixed root, with a
   `vapoursynth/` directory in it, serves both styles.

**Blocked on a system library**, needing a package install with root. Consolidated, since
these are the only root-level actions the plugin work requires:

| Need | Package | Unblocks |
|---|---|---|
| `libass` | `libass-dev` | subtext, and it is also the replacement path for the blocked VSFilterMod |
| `Magick++` | `libmagick++-dev` | libimwri |
| `libfftw3f` | `libfftw3-dev` | vcm, which also covers vcmod |
| `nasm` | `nasm` | A real x265 build, and SVPFlow1 |

**Upstream is gone or was never published.** No build recipe fixes these:

| Plugin | Finding |
|---|---|
| W3FDIF | `HomeOfVapourSynthEvolution` deleted, confirmed 404 rather than renamed. **Recovered** from an archived 2018 mirror and built, but the source is eight years stale and predates the final upstream version, so behaviour may differ from the shipped DLL. Provenance risk, not a build risk |
| VagueDenoiser | Same deleted org. No mirror identified yet |
| SVPFlow 2 | Closed source by vendor statement. A prebuilt Linux `.so` is shipped, or `open-svpflow` is a reimplementation |
| DGDecode | The released GPL source has no VapourSynth interface at all, and the version that added one was never published. `d2vsource` is the maintained replacement |
| vcfreq, vcmove | Binary-only distributions, verified by downloading and listing the archives. Both folded into `vcm`, under different namespaces, so scripts referencing them need rewriting |

**Architecturally blocked**, confirmed rather than assumed:

| Plugin | Reason |
|---|---|
| VSFilterMod | The VapourSynth entry point itself calls `AFX_MANAGE_STATE`, and its `StdAfx.h` pulls in MFC, ATL and DirectShow. Plus MASM and DirectX 7/9. Not a port, a rewrite. `subtext` is libass-based and already Linux-native, which is the answer |

That an organisation hosting two catalogue entries disappeared entirely is worth acting on
beyond these two: the same reachability check should be run across the whole catalogue,
including the AviSynth list, before anyone plans work against a URL in it.

## What this changes

The 38-entry build list is not a wall. Eight of them went from clone to loaded in about
fifteen minutes of wall time including the recipe's own debugging, with individual builds
between 2 and 25 seconds. Most needed no external dependency at all.

Honest limits. These eight are the easy end by construction, chosen because they looked
simple. The CUDA and HIP variants need toolkits that are a different order of cost, several
remaining entries have heavier dependencies, and two of the twelve attempted turned out to
have no upstream at all. A first pass that picks the easy ones and reports 8 successes is a
floor on feasibility, not an estimate of the remaining 30.
