# Linux Tool Availability Survey

Version: 0.1. Date: 2026-08-22. Owner: P-004. Feeds Tier C of `Tool-Matrix.md` (D-049).

## What this is, and what it is not

This records what upstream projects say about Linux support for the tools the legacy
catalogue names. It exists so the port does not rebuild what already exists.

Every verdict here is **inferred from upstream documentation**. Nothing in this file has
been executed, hash-pinned, or verified on any host, and none of it is a support claim.
A tool listed as `official-binaries` is a tool whose upstream publishes a Linux artifact,
not a tool the port supports. Promotion to a Tier A row still requires the full bar in
D-045: a decision, an absolute path, a version, a SHA-256, a fixture, a failure-path
result, both range ends, and an independent-host capture.

The distinction this survey keeps throughout is between three different statements:

- **the project supports Linux**, which is a claim about source;
- **upstream publishes a Linux binary**, which is a claim about distribution;
- **it runs on this host**, which is a claim nothing here makes.

The third is where the interesting failures live, and section 5 collects the cases where
the first two are true and the third still fails.

## Headline

Of 33 tools surveyed, the large majority are already available on Linux, most of them
from upstream directly. Four are genuine losses, and one of those is a hard platform
lock with no path at all.

| Verdict | Count | Meaning |
|---|---|---|
| Upstream publishes Linux binaries | 21 | Download and pin, no build needed |
| In major distro repositories | 6 | One package-manager line, build only if the version is too old |
| Source-only, builds on Linux | 2 | Real build work, no upstream artifact |
| No Linux path found | 4 | Needs a replacement strategy |

These four counts are derived from the two tables below rather than asserted beside
them, and they sum to 33. An earlier revision of this summary carried 15, 8, 2, and 4,
which did not reconcile with its own rows; the counts here were recomputed by parsing the
verdict column.

## 1. Encoders

| Tool | Linux | Evidence | Note that changes the port |
|---|---|---|---|
| ffmpeg, ffprobe | distro-packages | https://ffmpeg.org/download.html states upstream provides source only; present in every major distro | Safe to assume present. Identical CLI |
| x264 | official-binaries | https://artifacts.videolan.org/x264/release-debian-amd64/ hosts standalone ELF builds | Binaries are versioned bare ELF files, so a download URL must be built per revision |
| x265 | distro-packages | https://www.videolan.org/developers/x265.html publishes source only; packaged by Debian and Arch | No `x265` tree exists under artifacts.videolan.org, unlike x264 |
| rav1e | official-binaries | https://github.com/xiph/rav1e/releases v0.8.1 ships `linux-{generic,sse4,avx2,aarch64}` tarballs | Prebuilt binaries target musl, not glibc. Release cadence looks dormant since 2025-09 |
| aomenc | distro-packages | Arch `extra/aom`; Debian `aom-tools` | On Debian the CLI is in `aom-tools`, not `libaom3`. A dependency on the library alone does not give you `aomenc` |
| SVT-AV1 | distro-packages | https://gitlab.com/AOMediaCodec/SVT-AV1/-/releases ships source archives only | Debian trixie carries 2.3.0 against upstream 4.2.0. Pin deliberately |
| SVT-AV1-Essential | official-binaries | https://github.com/nekotrix/SVT-AV1-Essential/releases ships `Linux_Generic` and `Linux_Optimized` | **The CLI is not a drop-in.** It adds and redefines options and forces 10-bit. A compatibility flag is planned, not shipped |
| SVT-AV1-HDR | official-binaries | https://github.com/juliobbv-p/svt-av1-hdr/releases | Builds are PGO and march-specific. No generic baseline build exists |
| SVT-AV1-PSYEX | official-binaries, stale | https://github.com/BlueSwordM/svt-av1-psyex/releases, last release 2025-09-27 | Three major versions behind upstream, no commits in months. A drop candidate |
| SVT-AV1-Tritium | official-binaries | https://github.com/Uranite/svt-av1-tritium/releases, built 2026-08-14 | Most active of the psy forks. Same march-specific caveat. `ffms2` variants change accepted input types |
| vvencFFapp | source-only | https://github.com/fraunhoferhhi/vvenc releases carry source only; AUR only | Builds cleanly, but H.266 is patent-encumbered and the Clear-BSD licence grants no patent rights. Needs legal review before bundling |
| NVEncC | official-binaries | https://github.com/rigaya/NVEnc/releases ships `.deb` and `.rpm` | **Linux binary is `nvencc`, not `NVEncC64.exe`.** Requires the proprietary NVIDIA driver; nouveau does not expose NVENC |
| QSVEncC | official-binaries | https://github.com/rigaya/QSVEnc/releases ships `.deb` and `.rpm` | **Linux binary is `qsvencc`.** Needs the Intel media stack. Intel's own OpenCL runtime 24.35+ breaks detection on Gen11 and earlier |
| VCEEncC | official-binaries | https://github.com/rigaya/VCEEnc/releases ships `.deb` and `.rpm` | **Linux binary is `vceencc`.** Needs AMD AMF userspace and `render`/`video` group membership. The most fragile of the three |
| xvid_encraw | source-only | Debian and Arch `xvidcore` packages ship the library only, with no `/usr/bin` entries | The one real gap. It lives in `examples/` and no distro builds it. Upstream has had no release since 2019. Routing Xvid through ffmpeg's `libxvid` is the cheaper answer |

## 2. Containers, audio, subtitles, and metadata

| Tool | Linux | Evidence | Note that changes the port |
|---|---|---|---|
| mkvmerge, mkvextract, mkvinfo, mkvtoolnix-gui | official-binaries | https://mkvtoolnix.download/downloads.html runs signed apt and dnf repos, plus AppImage and Flatpak | Best case in the survey. The GUI is Qt, so it is native on Linux too. CLI identical |
| MP4Box, GPAC | official-binaries | https://gpac.io/downloads/ runs an APT repo | **The URL in the legacy source is dead.** `gpac.wp.mines-telecom.fr` moved to `gpac.io` |
| 7za | official-binaries | https://www.7-zip.org/download.html ships `linux-x64`, `arm64` console builds | Upstream has shipped Linux builds since 21.x. The old p7zip assumption is out of date |
| MediaInfo | official-binaries | https://mediaarea.net/en/MediaInfo/Download covers most distros plus AppImage, Flatpak, Snap | The legacy app consumes `MediaInfo.dll` by P/Invoke, which becomes `libmediainfo.so.0` with different string marshalling. See section 6 |
| opusenc, opusdec | distro-packages | https://opus-codec.org/downloads/ publishes source and Windows builds only; every major distro packages `opus-tools` | Textbook case of upstream support without an upstream binary |
| truehdd | official-binaries | https://github.com/truehdd/truehdd/releases ships gnu and musl, x86-64 and aarch64 | Cleanest target in the survey. Static musl builds run across distros without packaging work |
| dovi_tool | official-binaries | https://github.com/quietvoid/dovi_tool/releases ships musl static builds | The prebuilt `libdovi` is Windows-only; on Linux the C library is built from the same repo |
| hdr10plus_tool | official-binaries | https://github.com/quietvoid/hdr10plus_tool/releases ships musl static builds | No action beyond path handling |
| DeeZy | official-binaries | https://github.com/jlw4049/DeeZy/releases ships linux x64 and arm64 | It wraps DEE, so it inherits every DEE constraint below |
| Subtitle Edit | official-binaries | https://github.com/SubtitleEdit/subtitleedit/releases ships Linux x64, ARM64, and Flatpak | **The biggest positive surprise.** 5.x is an Avalonia rewrite, genuinely cross-platform, and ships `SeConv`, a headless CLI converter. A port should drive `SeConv`, never the GUI |
| chapterEditor | official-binaries, fragile | https://forum.doom9.org/showthread.php?t=169984 offers a Linux build as a forum attachment | A binary-only forum attachment with no versioned channel and no public source, so it cannot be rebuilt or patched. MKVToolNix covers the common chapter workflows natively |
| fdkaac | distro-packages | Debian ships `fdkaac` in contrib because `libfdk-aac` is non-free | Licensing, not portability. It cannot be bundled the way the Windows build is; it has to stay user-supplied |
| DEE | official-binaries, licensee-only | https://ott.dolby.com/DEE/ release notes list Ubuntu and CentOS alongside Windows | A native Linux binary exists but is never redistributable. Reports indicate TrueHD encoding still needs the Windows build under Wine, so Linux parity is not established |
| BDSup2Sub++ | official-binaries, abandoned | https://github.com/amichaeltm/BDSup2SubPlusPlus/releases, sole release 2018, last push 2022 | Portable in principle, Qt, but the AppImage is eight years old. Subtitle Edit 5 is the maintained substitute |
| qaac | **none-found** | https://github.com/nu774/qaac README states "On Linux, only refalac is available" | See section 4. The hard block |
| NeroAAC | **none-found** | Discontinued 2010, upstream distribution gone, licence was non-commercial freeware | Nothing to carry forward |
| eac3to | **none-found** | https://forum.doom9.org/showthread.php?t=125966, DirectShow-based, source never released | Windows-only by construction, not by accident |
| VSRip | **none-found** | https://sourceforge.net/projects/guliverkli/ last active 2013 | Nothing to salvage |

## 3. Frameservers and the plugin catalogue

This is the largest part of the catalogue, 244 of 299 entries, and it produced the
survey's most consequential result: **the two frameservers are not comparable on Linux,
and the difference lines up almost exactly with the extension census.**

### AviSynth+

Upstream supports Linux and has since 3.5, and Ubuntu 22.04 and 24.04 are built in CI.
But support is source-only in every practical sense:

- No upstream Linux binaries. Release assets across the last three releases are Windows
  installers and macOS artifacts, and nothing else.
- Not in Debian, Ubuntu, or Fedora official repositories. Arch, openSUSE, and nixpkgs
  carry it. The Arch package installs the library, headers, and four bundled plugins,
  with no CLI at all.
- A Windows plugin `.dll` cannot be loaded on Linux, and not for a fixable reason. The
  POSIX loader uses `dlopen` and filters for `.so`; `dlopen` cannot load a PE file. The
  plugin API is a C++ vtable interface, so it also crosses the MSVC-against-Itanium C++
  ABI boundary. Upstream ships `avs/posix.h`, a source-level shim, which makes porting a
  plugin's *source* tractable and does nothing for its binary.
- Of 17 well-known plugin repositories sampled, 17 publish Windows-only assets and none
  publishes a `.so`. Linux availability comes entirely from source builds: the AUR
  carries 49 `avisynth-plugin-*` packages and every one of them is a `-git` recipe.
- No index anywhere records per-plugin Linux availability for AviSynth+. That is a
  searched-for absence, not an assumption.

### VapourSynth

The distribution problem is solved. Since R74, `pip install vapoursynth` works on Linux,
and the published wheels cover manylinux and musllinux on both x86-64 and aarch64. The
wheel is not a stub: it carries `vspipe`, `libvapoursynth.so.4`, the filter libraries,
the Python module, the SDK headers, and a pkg-config file. Python 3.12 or newer.

The plugin API is platform-neutral by construction rather than by porting effort. In
`VapourSynth4.h` the only platform conditionals are the calling convention, which is
`__stdcall` solely on 32-bit Windows and empty everywhere else, and the export attribute.
It is a plain C ABI with an explicit version, and the loader resolves the same entry-point
names on both platforms. A plugin must be recompiled for Linux; it does not need to be
rewritten.

**Verified by installation, 2026-08-22, on the T540p.** D-050 is ratified and rests on this
claim, so it was worth executing rather than citing. On bare-metal Ubuntu 24.04.4 with
Python 3.12.3, in a throwaway virtual environment and without root, `pip install
vapoursynth` fetched
`vapoursynth-79-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl`, 4.5 MB, and
installed R79. What the wheel actually contains, listed rather than assumed:

- `libvapoursynth.so.4`, `libvsscript.so`, and three filter libraries including AVX2 and
  Zen 4 variants
- `vapoursynth.abi3.so`, the Python module
- `include/VapourSynth4.h`, `VSHelper4.h`, `VSScript4.h`, so the plugin SDK is present
- `pkgconfig/vapoursynth.pc`
- `bin/vspipe`

Total footprint 25 MB. The core reports R79 and API R4.2 from Python.

**One caveat the survey missed, and it matters to anyone scripting an install.** `vspipe`
ships in the wheel but does **not** work immediately. Invoking it fails with `Failed to
initialize VSScript ... Python executable and library path couldn't be determined despite
automatic configuration`. The remedy is a documented one-time `vapoursynth config`, which
writes `~/.config/vapoursynth/vapoursynth.toml` recording the interpreter and libpython
path; after that `vspipe --version` reports Core R79 and API R4.2 normally. So the claim
"pip install delivers vspipe" is true about delivery and false about readiness, and an
automated Linux setup needs both steps. Note also that the config is written per user, not
per environment, which is worth knowing before assuming a virtual environment is fully
self-contained.

Two independent measurements of how much of the ecosystem is actually available:

| Channel | Population | Ship Linux binaries |
|---|---|---|
| vsrepo, the platform-keyed index | 206 native plugins | 82, about 40 percent. 123 are Windows-only in every release |
| PyPI, wheels matching `vapoursynth` | 91 native plugin projects | 85, about 93 percent. Five are Windows-only, one is source-only |

Combining both channels puts roughly 115 of 206 native plugins, about 56 percent, within
reach of a prebuilt Linux binary. That figure is a floor rather than a measurement,
because matching a vsrepo identifier to a PyPI name is heuristic and misses cases where
the namespace and the package name differ.

The gap between the two columns is the survey's sharpest methodological point: the
ecosystem has been migrating plugin distribution from GitHub Releases, which carry
Windows binaries only, to PyPI wheels, which carry Linux. **A survey that inspects
GitHub Releases concludes there are no Linux builds, and is substantially wrong.** The
clearest illustration found was a plugin family whose Linux CI is green across eight
workflows and which has never attached a single Linux byte to a GitHub release, because
those workflows end at an artifact upload while only the Windows workflow cuts releases.

### Use the existing index

`https://www.vapoursynth.com/vsrepo/vspackages3.zip` is a 254 KB download containing 259
package definitions with per-release, platform-keyed binary blocks. Observed platform keys
include `win64`, `win32`, `linux-glibc-x86_64`, `linux-glibc-x86_64-v3`,
`linux-glibc-aarch64`, `darwin-x86_64`, `darwin-aarch64`, `wheel`, and `script`. Joining
the catalogue against it on identifier or namespace answers the per-plugin availability
question mechanically, and the `pypiname` field gives a second signal.

Two alternatives were checked and rejected: `vsdb.top` is live but records no operating
system field at all and its data stops around 2022, and the official plugin list at
`vapoursynth.com/doc/pluginlist.html` returns 404.

### The script entries, and the traps that are real

The 21 `.py` entries are platform-independent. Of the vsrepo packages that are Python
rather than native, all sampled wheels are `py3-none-any`, meaning no compiled code at
all. The Linux-binary question does not apply to them.

The 55 `.avsi` entries are portable text with three real traps, two of which fail
silently and both of which are specific to Linux:

1. **Autoload is case-sensitive on POSIX and case-insensitive on Windows.** The POSIX
   path compares the extension exactly against `.avsi`. A file named `Foo.AVSI`
   autoloads on Windows and simply does not on Linux, with no error. The same applies to
   `.so` against `.DLL`, and to base-name deduplication. Windows-authored plugin packs
   mix casing freely, so all 55 filenames need auditing rather than assuming.
2. **The byte-order-mark guard is inside the Windows branch.** On Windows, importing a
   UTF-16 or BOM-carrying UTF-8 script produces a clear diagnostic telling the author to
   re-save. The POSIX branch has no such check, so the same file yields a cryptic parse
   error instead. Windows-authored files commonly carry BOMs.
3. **Backslash paths degrade into file-not-found rather than a syntax error**, because
   AviSynth strings are literal and a backslash is a legal character in a Linux filename.

One commonly assumed trap is not real: the tokenizer handles carriage returns explicitly
and collapses CRLF pairs, so Windows line endings in `.avsi` files are fine.

The dominant risk for both script classes is transitive rather than textual. An `.avsi`
is a thin wrapper over native plugin calls and a `.py` module calls into a plugin
namespace, so each is only as portable as what it invokes. That is the whole asymmetry:
the 21 `.py` entries sit on an ecosystem with about 93 percent Linux wheel coverage, and
the 55 `.avsi` entries sit on one where the sampled plugins ship no Linux binaries at all.

### The AviSynth+ plugin ecosystem, measured rather than assumed

A survey of roughly 160 plugin repositories across the three main publishing
organizations found the gap is not capability but release engineering:

- **Roughly two-thirds of sampled plugins build on Linux from source today.** Of 18
  AviSynth-native plugins examined closely, 12 build. One publisher's house CMake style
  puts a Linux install target in 48 of 50 files, so Linux-buildable is close to the
  default.
- **Almost none publish a Linux binary.** Across 258 release assets in one publisher's 44
  repositories, zero match any Linux marker. Exactly one project in the whole survey ships
  installable Linux artifacts. One further third-party plugin, ffms2, is available
  prebuilt from a first-tier distribution.
- The `.so` files frequently exist and are thrown away: two plugins build Linux binaries
  in CI on every push and attach Windows-only archives to their releases.
- Four plugin families are **architecturally blocked**, not merely unported: the VSFilter
  subtitle family depends on MFC, ATL, DirectShow, and GDI, which is a rewrite rather
  than a port; nnedi3 is MASM assembly plus Win32; and KNLMeansCL compiles its AviSynth
  interface out entirely behind a `_WIN32` guard.
- The ecosystem's own directory of external filters carries 712 entries and no mention of
  Linux, POSIX, or `.so` anywhere in it.

Two artifacts look like AviSynth-on-Linux binaries and are not: a VapourSynth wheel that
builds with the AviSynth plugin explicitly disabled, and an AUR package that installs one
`.so` into both frameservers' directories while its source guards prevent it exporting the
AviSynth entry point.

One useful positive: for subtitles specifically, assrender is a viable migration target.
It is libass-based with no GDI or DirectShow dependency, and its CI already produces
`libassrender.so`.

### What this means for our catalogue specifically

Classifying all 299 entries by which frameserver's filter names they declare, measured
2026-08-22:

| Declares | Count |
|---|---|
| AviSynth filter names only | 132 |
| VapourSynth filter names only | 91 |
| Both | 13 |
| Neither, so executables, runtimes, and support entries | 63 |

So 145 entries expose AviSynth filters and 104 expose VapourSynth filters. A further 26
entries declare `.Dependencies`, which pulls in additional plugins by name and multiplies
the surface beyond the entry count.

Set against the ecosystem measurements above, the 145 AviSynth-exposing entries sit on a
plugin ecosystem with effectively no published Linux binaries, and the 104
VapourSynth-exposing entries sit on one where roughly half have a prebuilt Linux binary
already and the Python-packaged part is above 90 percent. That asymmetry is the input to
D-050.

One piece of good news the repository already owns: `Source/FrameServer/avs/posix.h` is
present and vendored, so the AviSynth+ POSIX shim is in the tree rather than something
that would need acquiring.

### The catalogue joined against the index, measured

The ecosystem percentages above describe the ecosystem. Joining our own 168 `.dll`
entries against `vspackages3.zip` on 2026-08-22, matching on the Windows filename
recorded in each package's `win64` release block, gives the figure for this catalogue
specifically:

| Result | Count |
|---|---|
| Catalogue `.dll` entries | 168 |
| Matched in the index by filename | 93 |
| Of those, a Linux binary exists | 59 |
| Of those, Windows-only in the index | 34 |
| Not in the index at all | 75 |

So 59 of our plugin entries already have a Linux binary that can simply be pinned. That
is a floor rather than a measurement of availability: the survey found several packages
in the Windows-only column that publish Linux wheels the index has not picked up, and the
75 unmatched entries are largely the AviSynth side, which this index does not cover at
all. The join is reproducible from the committed catalogue and the published index; it
requires no credentials and downloads 254 KB.

### A concentration risk worth recording before depending on it

Of the 82 vsrepo packages carrying a Linux binary, 78 get it from a single volunteer
build project rather than from the plugin's own author. Linux plugin availability for
VapourSynth is therefore not 82 independent upstreams; it is close to one upstream with a
long tail. That project is real and its output is real, and it is also one person's
release cadence. Any plan that treats the 40 percent figure as a stable platform property
should record that it is currently a single point of failure. The PyPI channel is more
distributed, which is a further argument for preferring it.

## 4. The one hard block, and the three losses

**qaac's AAC encoder has no Linux path at all**, and this is worth stating precisely
because it is the only entry in the survey where even a source build does not help. qaac
is a front end to Apple's CoreAudioToolbox, a Windows DLL distributed with Apple
Application Support. There is no Linux CoreAudio. Upstream says so directly. The `refalac`
ALAC encoder in the same repository does build natively, so if the legacy app's qaac usage
includes ALAC, that half survives and the AAC half does not.

The three losses each have a replacement path rather than a port:

- **eac3to** splits into ffmpeg for demux, decode, and delay handling; mkvextract for
  track extraction; tsMuxeR for Blu-ray and M2TS; and truehdd for the TrueHD path.
- **VSRip** is replaced by mencoder's VobSub output, or by remuxing with ffmpeg and
  extracting with mkvextract.
- **NeroAAC** is replaced by fdkaac, ffmpeg's native AAC encoder, or Opus.

## 5. Where "a Linux build exists" is not enough

These are the cases where upstream ships a Linux binary and the port can still fail, and
they are the reason a Tier C record must never be read as an availability claim.

1. **The binary has a different name.** The three rigaya encoders are `nvencc`,
   `qsvencc`, and `vceencc` on Linux against `NVEncC64.exe`, `QSVEncC64.exe`, and
   `VCEEncC64.exe` on Windows. A catalogue carrying one filename per entry will look for
   the Windows name on Linux and report a correctly installed tool as missing. This is a
   schema problem, not a lookup bug, and it is recorded against D-049.
2. **The build targets a narrower CPU than the platform.** SVT-AV1-HDR and
   SVT-AV1-Tritium publish PGO builds compiled for `x86-64-v3` and `znver2` with no
   generic baseline. On an older processor these do not run slowly, they fault. Presence
   on disk proves nothing.
3. **The CLI is not the same CLI.** SVT-AV1-Essential renames and redefines options and
   forces 10-bit output. A wrapper that assumes upstream syntax produces wrong output or
   an error, not a clean unavailability.
4. **The library is not in the package you depended on.** On Debian, `aomenc` lives in
   `aom-tools`; depending on `libaom3` gets the library and no encoder.
5. **The prebuilt links a different libc.** rav1e's published binaries are musl.
6. **The licence forbids the distribution model.** fdkaac depends on non-free
   `libfdk-aac`, and DEE is licensee-only. Both run on Linux; neither can ship inside a
   package the way the Windows tree bundles them.

## 6. Two findings that touch decisions already made

**D-045's choice of the CLI over the library is independently supported.** The legacy app
reaches MediaInfo through `MediaInfo.dll` by P/Invoke. On Linux that becomes
`libmediainfo.so.0`, and the string marshalling conventions differ between the Windows and
POSIX builds, so the `DllImport` surface does not carry across unchanged. The portable
side chose the command-line client with a JSON contract instead, which sidesteps that
entirely. This was decided on other grounds; it happens to also avoid the marshalling
problem the legacy path would have hit.

**D-049's Tier C schema is wrong as written** and is amended in the decision log. It
records a single `filename` per entry, and finding 1 in section 5 shows filename is
platform-dependent for at least three entries in the execution path.

## 7. Upstream contribution targets, verified 2026-08-22

D-051 proposed spending the first effort upstream, on projects that already build Linux
artifacts in continuous integration and never attach them to their releases. Six candidates
were checked by reading every workflow file, querying the releases API across all releases
rather than the latest, and extracting the published archives to confirm their contents.
**The premise held for four of six, and the check changed the plan in three ways.**

**Two must be dropped, because they already solved this better than the proposed fix.**
L-SMASH-Works publishes to PyPI as `vapoursynth-lsmas` with four Linux wheels, built by
cibuildwheel and released on tag. vapoursynth-zip publishes as `vapoursynth-vszip`, and
did so deliberately: releases R6 to R13 used to carry Linux zip assets and those were
removed, with the release workflow now creating an empty tag marker and pushing everything
to PyPI. A pull request there would ask a maintainer to revert a decision they made on
purpose, which is worse than not contributing at all.

**One premise was simply wrong.** neo_f3kdb's workflow is build verification only: it has
no `upload-artifact` step and no install step, so the Linux binary is compiled and
discarded. It does not exist even transiently as a downloadable artifact, so the framing
of "the artifact exists and is merely unattached" is false there and the change is larger
than advertised.

| Target | Gap real | Shape | Note |
|---|---|---|---|
| vs-dfttest2 | yes | Smallest. One file, roughly 25 lines, mirroring a release pattern the Windows workflow already uses | Active, pull requests merged in about two days |
| assrender | yes | Small diff, but the workflow has no tag trigger and one must be added | The repository is itself a fork; its many open pull requests are stale bot dependency bumps, not a stalled queue |
| vs-mlrt | yes | Not small. Eight workflows plus an orchestrator, because the Linux ones lack the `workflow_call` and tag inputs the Windows ones have | Highest impact of the four. Open an issue first, or send one workflow as a proof of concept |
| neo_f3kdb | yes, different shape | Largest. Needs an install step, an upload, and a release attach | Slowest cadence of the four |

**No policy anywhere, verified three ways.** None of the six has a `CONTRIBUTING.md`, code
of conduct, pull request template, DCO, or CLA, and none states any policy on
tool-assisted contributions. Checked against repository contents, the community profile
API, and organization-level `.github` repositories. No `Signed-off-by` trailers appear in
recent history and no DCO or CLA bot appears in any check run. So under D-051 there is
nothing to disclose and nothing to withhold: contribute in each project's conventions,
sign as the author, and answer honestly if anyone asks.

**The objection to expect, which is legitimate.** A raw `.so` attached to a GitHub release
is glibc and ABI sensitive, and therefore distro-specific in a way a wheel is not. That is
exactly why the two dropped projects chose manylinux wheels instead. Any pull request here
should state which runner image and glibc version the binary is built against, or it reads
as naive. This is also a real argument that the better contribution, where a project is
willing, is a wheel rather than a release asset. That is a larger change and a separate
judgment per project.

### Tested against a real maintainer, 2026-08-22, and the strategy did not survive

The vs-dfttest2 pull request was opened, built and verified end to end in a fork, and
**declined**. The maintainer's reason was exactly the objection predicted above, in one
sentence: *"Because of the glibc requirement, I would recommend building from source on
Linux in general."* The pull request was closed with thanks and an open offer to look at a
manylinux wheel instead, which was left as an offer rather than a promise.

That answer very likely settles all three targets, which is why the other two were held
back rather than sent together. It also explains the two drops from the other direction:
L-SMASH-Works and vapoursynth-zip both migrated to manylinux wheels, and manylinux exists
precisely to solve the glibc pinning this maintainer named. The ecosystem's answer is not
"attach a `.so` to a release", it is "ship a wheel". D-051 identified the gap correctly and
proposed the wrong remedy for it.

### So how expensive is building a plugin from source? Measured, not estimated

The maintainer's recommendation was taken literally and tested on the T540p, because the
catalogue join found roughly 91 plugins with no Linux binary anywhere and the port had no
idea what one costs. Building the dfttest2 CPU plugin, on a four-core laptop:

| Step | Result |
|---|---|
| Clone with submodules | Required. `cpu_source/vectorclass` is a submodule and configure fails without it |
| Headers | **API 3.** The source includes `VapourSynth.h`, which the pip wheel does not ship; the wheel carries API 4 headers only. Upstream's own workflow fetches the R57 source archive for this reason |
| Configure and build, CPU only | **15 seconds**, `cmake` plus `ninja` plus `g++`, all already present |
| Artifact | `libdfttest2_cpu.so`, 368,792 bytes |
| Install | Copy into `<site-packages>/vapoursynth/plugins`, which the wheel does not create |
| Load | Registers as namespace `dfttest2_cpu`, "DFTTest2 (CPU)", exposing `DFTTest`, `RDFT` and `Version` |

**The 91-plugin gap is not the wall it looked like.** One representative plugin went from
clone to loaded in a few minutes, and the build itself was 15 seconds. That materially
changes the Tier C outlook: a documented recipe per plugin is a plausible answer where
publishing binaries is not.

Honest limits on that conclusion. This is one plugin and a simple one: CPU only, no CUDA or
HIP, and its only dependency was a header-only submodule. The GPU variants need the CUDA or
ROCm toolchains, which is a different order of cost. Other plugins carry heavier
dependencies such as FFTW or libass. One sample sets a floor, not an average, and the
API 3 header requirement is a per-plugin discovery rather than a general rule.

## 8. What this file does not license

Nothing here authorizes downloading, installing, or executing any tool. Acquisition is
approval-gated at every tier per `AGENTS.md`, and this survey changes none of that. It
narrows what would need approving, and in several cases shows that nothing needs building
at all, which is its whole purpose.
