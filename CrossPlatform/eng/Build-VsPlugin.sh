#!/usr/bin/env bash
# Build one VapourSynth plugin from source on Linux and prove it loads.
#
# The output is the recipe, not the binary: most of these are GPL and we are not
# redistributing them (D-051). What this establishes per plugin is whether a documented
# build works, what it costs, and what it needs installed first.
#
# Usage: build-vs-plugin.sh <name> <repo-url> [extra cmake/meson args...]
set -u
export PATH=$HOME/vs-probe/bin:$HOME/buildtools/bin:$PATH
export PKG_CONFIG_PATH=$HOME/vs-probe/lib/python3.12/site-packages/vapoursynth/pkgconfig:${PKG_CONFIG_PATH:-}
NAME="$1"; REPO="$2"; shift 2
ROOT=~/vs-plugin-builds
VENV=~/vs-probe
PLUGDIR="$VENV/lib/python3.12/site-packages/vapoursynth/plugins"
# API 3 headers, which the wheel does not ship. Fetched once, reused.
VS3=~/vs-headers-r57
mkdir -p "$ROOT" "$PLUGDIR"

if [ ! -d "$VS3" ]; then
  wget -q -O /tmp/vs57.zip https://github.com/vapoursynth/vapoursynth/archive/refs/tags/R57.zip
  unzip -q /tmp/vs57.zip -d /tmp && mv /tmp/vapoursynth-R57 "$VS3"
fi
VSINC="$VS3/include"

D="$ROOT/$NAME"
rm -rf "$D"
echo "PLUGIN=$NAME"
START=$(date +%s)

if ! git clone --quiet --depth 1 --recurse-submodules "$REPO" "$D" 2>/tmp/clone.err; then
  echo "RESULT=clone-failed"; sed -n '1,3p' /tmp/clone.err; exit 0
fi
cd "$D"
echo "COMMIT=$(git rev-parse --short HEAD)"
echo "LICENSE=$(ls LICENSE* COPYING* 2>/dev/null | head -1 || echo none)"
API=$(grep -rl 'VapourSynth4\.h' --include=*.c --include=*.cpp --include=*.h --include=*.hpp . 2>/dev/null | head -1)
if [ -n "$API" ]; then echo "API=4"; else echo "API=3"; fi

BUILD=unknown
if   [ -f meson.build ];    then BUILD=meson
elif [ -f CMakeLists.txt ]; then BUILD=cmake
elif [ -f configure.ac ] || [ -f autogen.sh ]; then BUILD=autotools
elif [ -f Makefile ];       then BUILD=make
fi
echo "BUILD_SYSTEM=$BUILD"

set +e
case "$BUILD" in
  meson)
    meson setup build --buildtype=release -Dcpp_args="-I$VSINC" "$@" >/tmp/cfg.log 2>&1
    CFG=$?
    [ $CFG -eq 0 ] && ninja -C build >/tmp/bld.log 2>&1
    BLD=$?
    ;;
  cmake)
    cmake -S . -B build -G Ninja -D CMAKE_BUILD_TYPE=Release \
          -D VS_INCLUDE_DIR="$VSINC" -D CMAKE_CXX_FLAGS="-I$VSINC" "$@" >/tmp/cfg.log 2>&1
    CFG=$?
    [ $CFG -eq 0 ] && cmake --build build >/tmp/bld.log 2>&1
    BLD=$?
    ;;
  autotools)
    ( [ -f autogen.sh ] && ./autogen.sh || autoreconf -i ) >/tmp/cfg.log 2>&1
    ./configure CPPFLAGS="-I$VSINC" "$@" >>/tmp/cfg.log 2>&1
    CFG=$?
    [ $CFG -eq 0 ] && make -j"$(nproc)" >/tmp/bld.log 2>&1
    BLD=$?
    ;;
  make)
    make -j"$(nproc)" CPPFLAGS="-I$VSINC" >/tmp/bld.log 2>&1
    CFG=0; BLD=$?
    ;;
  *) CFG=1; BLD=1 ;;
esac
set -e

if [ "${CFG:-1}" -ne 0 ]; then
  echo "RESULT=configure-failed"
  grep -iE 'error|not found|missing|No such file' /tmp/cfg.log | head -4
  echo "ELAPSED=$(( $(date +%s) - START ))"; exit 0
fi
if [ "${BLD:-1}" -ne 0 ]; then
  echo "RESULT=build-failed"
  grep -iE 'error|fatal|No such file' /tmp/bld.log | head -4
  echo "ELAPSED=$(( $(date +%s) - START ))"; exit 0
fi

SO=$(find . -name '*.so' -newer CMakeLists.txt 2>/dev/null | head -1)
[ -n "$SO" ] || SO=$(find . -name '*.so' | head -1)
if [ -z "$SO" ]; then echo "RESULT=no-artifact"; echo "ELAPSED=$(( $(date +%s) - START ))"; exit 0; fi
echo "ARTIFACT=$(basename "$SO") BYTES=$(stat -c %s "$SO")"
echo "ELAPSED=$(( $(date +%s) - START ))"

# The real test: does VapourSynth load and register it?
NSLIST='import vapoursynth as vs; print(",".join(sorted(p.namespace for p in vs.core.plugins())))'
probe_ns() { "$VENV/bin/python" -c "$NSLIST" 2>/tmp/ns.err; }

# A stale copy of this same plugin already in PLUGDIR would put its namespace in
# BEFORE_NS, making the diff empty and the verdict a false "not loaded" - which then
# deletes a plugin that actually works. Clear it before taking the baseline.
rm -f "$PLUGDIR/$(basename "$SO")"

BEFORE_NS=$(probe_ns)
if [ -z "$BEFORE_NS" ]; then
  echo "RESULT=probe-failed (baseline namespace query returned nothing)"
  sed -n '1,3p' /tmp/ns.err; exit 0
fi
cp "$SO" "$PLUGDIR/"
AFTER_NS=$(probe_ns)
if [ -z "$AFTER_NS" ]; then
  # Empty here would compare unequal to a good baseline and read as "loaded".
  echo "RESULT=probe-failed (namespace query returned nothing after install)"
  sed -n '1,3p' /tmp/ns.err
  find "$PLUGDIR" -name "$(basename "$SO")" -delete; exit 0
fi

if [ "$AFTER_NS" != "$BEFORE_NS" ]; then
  NEW=$("$VENV/bin/python" -c "
b=set(x for x in '$BEFORE_NS'.split(',') if x)
a=[x for x in '$AFTER_NS'.split(',') if x]
print(','.join(x for x in a if x not in b) or 'none')")
  echo "RESULT=loaded NEW_NAMESPACE=$NEW"
else
  echo "RESULT=built-but-not-loaded (namespace set unchanged)"
  find "$PLUGDIR" -name "$(basename "$SO")" -delete
fi
