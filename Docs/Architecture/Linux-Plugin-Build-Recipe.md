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

**Blocked on a system library**, needing a package install with root:

| Plugin | Missing | Package |
|---|---|---|
| subtext | `libass` | `libass-dev` |
| libimwri | `Magick++` | `libmagick++-dev` |

**Upstream is gone**, which no build recipe can fix:

| Plugin | Finding |
|---|---|
| W3FDIF | `HomeOfVapourSynthEvolution` org unreachable |
| VagueDenoiser | Same org, same result |

That organisation hosting two catalogue entries has disappeared entirely, not been renamed.
Any remaining catalogue entries pointing at it should be treated as dead until a successor
is identified, and the same check is worth running across the AviSynth list.

## What this changes

The 38-entry build list is not a wall. Eight of them went from clone to loaded in about
fifteen minutes of wall time including the recipe's own debugging, with individual builds
between 2 and 25 seconds. Most needed no external dependency at all.

Honest limits. These eight are the easy end by construction, chosen because they looked
simple. The CUDA and HIP variants need toolkits that are a different order of cost, several
remaining entries have heavier dependencies, and two of the twelve attempted turned out to
have no upstream at all. A first pass that picks the easy ones and reports 8 successes is a
floor on feasibility, not an estimate of the remaining 30.
