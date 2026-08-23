#!/usr/bin/env bash
# P-014 Linux baseline. Mirrors CrossPlatform/eng/Measure-Baseline.ps1 so the two hosts are
# comparable: same fixtures, same tool invocation, same statistics, the process-start floor
# measured separately from parse cost, and the first run of each series reported apart from
# the warm ones rather than averaged into them.
#
# Runs the timing ON the host, so the tailnet is never inside a measurement.
set -u
REPO="$1"
REPS="${2:-25}"
TS='/mnt/c/Program Files/Tailscale/tailscale.exe'
HOST=daniel-boyd@daniel-boyd-thinkpad-t540p
EXPECTED_TOOL_SHA=a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6
STAGE=/tmp/t540p-bl-stage
RESULTS=/tmp/t540p-bl-results
rm -rf "$STAGE" "$RESULTS"
mkdir -p "$STAGE/media" "$RESULTS"

cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"*.mp4 "$STAGE/media/"
cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"*.mkv "$STAGE/media/"
cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"*.webm "$STAGE/media/"
cp -r "$REPO/CrossPlatform/artifacts/tools/wsl-mediainfo-24.01" "$STAGE/tool"
chmod +x "$STAGE/tool/usr/bin/mediainfo"

cat > "$STAGE/run.sh" <<'HOSTEOF'
set -u
cd ~/staxrip-baseline
TOOL=~/staxrip-baseline/tool/usr/bin/mediainfo
export LD_LIBRARY_PATH=~/staxrip-baseline/tool/usr/lib/x86_64-linux-gnu
REPS="$1"

ACTUAL=$(sha256sum "$TOOL" | cut -d' ' -f1)
echo "tool_sha256=$ACTUAL"
[ "$ACTUAL" = "EXPECTED_SHA_PLACEHOLDER" ] || { echo "FAIL tool-hash-mismatch"; exit 1; }
echo "tool_version=$("$TOOL" --Version | tr '\n' ' ')"
echo "host=$(hostname) machine_id_sha=$(sha256sum /etc/machine-id | cut -d' ' -f1)"
echo "kernel=$(uname -r) cores=$(nproc) mem_avail_mb=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)"
echo "governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
echo "reps=$REPS"
echo "---"

# One series. Prints: label cold_us min med p90 max spread
series() {
  label="$1"; shift
  s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N)
  cold=$(( (e-s)/1000 ))
  times=""
  i=0
  while [ "$i" -lt "$REPS" ]; do
    s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N)
    times="$times $(( (e-s)/1000 ))"
    i=$((i+1))
  done
  echo "$times" | tr ' ' '\n' | grep -v '^$' | sort -n > /tmp/_t
  n=$(wc -l < /tmp/_t)
  min=$(head -1 /tmp/_t)
  max=$(tail -1 /tmp/_t)
  med=$(awk -v n="$n" 'NR==int((n+1)/2){print; exit}' /tmp/_t)
  p90=$(awk -v n="$n" 'NR==int(n*0.9)+0{print; exit} END{if(NR<int(n*0.9)) print}' /tmp/_t)
  [ -n "$p90" ] || p90=$max
  spread=$(awk -v a="$max" -v b="$min" 'BEGIN{ if(b>0) printf "%.2f", a/b; else print "0" }')
  echo "series label=$label cold_us=$cold min_us=$min median_us=$med p90_us=$p90 max_us=$max spread=$spread"
}

series version-probe "$TOOL" --Version
cd media
for f in cfr-h264-aac.mp4 cfr-ffv1-10bit-pcm.mkv cfr-vp9-opus.webm vfr-ffv1.mkv cfr-h264-aac-chapters.mp4 cfr-h264-aac-subtitles.mkv; do
  series "$f" "$TOOL" --Output=JSON "$f"
done
HOSTEOF
sed -i "s/EXPECTED_SHA_PLACEHOLDER/$EXPECTED_TOOL_SHA/" "$STAGE/run.sh"

echo "=== transfer ==="
"$TS" ssh "$HOST" 'rm -rf ~/staxrip-baseline && mkdir -p ~/staxrip-baseline'
tar -czf - -C "$STAGE" media tool run.sh | "$TS" ssh "$HOST" 'tar -xzpf - -C ~/staxrip-baseline'
echo "transfer_exit=$?"

echo "=== measure on host ==="
"$TS" ssh "$HOST" "bash ~/staxrip-baseline/run.sh $REPS" 2>&1 | tee "$RESULTS/baseline.txt"
echo "measure_exit=$?"

echo "=== cleanup host ==="
"$TS" ssh "$HOST" 'rm -rf ~/staxrip-baseline && ls ~ | wc -l'
echo LINUX-BASELINE-COMPLETE
