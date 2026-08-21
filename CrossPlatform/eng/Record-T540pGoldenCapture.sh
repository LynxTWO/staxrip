#!/usr/bin/env bash
set -u
REPO="$1"
TS='/mnt/c/Program Files/Tailscale/tailscale.exe'
HOST=daniel-boyd@daniel-boyd-thinkpad-t540p
EXPECTED_TOOL_SHA=a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6
STAGE=/tmp/t540p-stage
RESULTS=/tmp/t540p-results
rm -rf "$STAGE" "$RESULTS"
mkdir -p "$STAGE/media" "$RESULTS"

cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"*.mp4 "$STAGE/media/"
cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"*.mkv "$STAGE/media/"
cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"*.webm "$STAGE/media/"
cp -r "$REPO/CrossPlatform/artifacts/tools/wsl-mediainfo-24.01" "$STAGE/tool"
chmod +x "$STAGE/tool/usr/bin/mediainfo"

echo "=== transfer to host ==="
"$TS" ssh "$HOST" 'rm -rf ~/staxrip-verify && mkdir -p ~/staxrip-verify'
tar -czf - -C "$STAGE" media tool | "$TS" ssh "$HOST" 'tar -xzpf - -C ~/staxrip-verify'
echo "transfer_exit=$?"

echo "=== capture on host ==="
"$TS" ssh "$HOST" '
set -u
cd ~/staxrip-verify
TOOL=~/staxrip-verify/tool/usr/bin/mediainfo
ACTUAL=$(sha256sum "$TOOL" | cut -d" " -f1)
echo "host_tool_sha=$ACTUAL"
if [ "$ACTUAL" != "'"$EXPECTED_TOOL_SHA"'" ]; then echo "TOOL HASH MISMATCH ON HOST"; exit 1; fi
export LD_LIBRARY_PATH=~/staxrip-verify/tool/usr/lib/x86_64-linux-gnu
echo "host_tool_version=$("$TOOL" --Version | tr "\n" " ")"
echo "host_identity hostname=$(hostname) machine_id_sha=$(sha256sum /etc/machine-id | cut -d" " -f1) os=$(. /etc/os-release && echo $PRETTY_VERSION $VERSION_ID) kernel=$(uname -r) fs=$(stat -f -c %T ~/staxrip-verify)"
mkdir -p out
cd media
for f in cfr-h264-aac.mp4 cfr-ffv1-10bit-pcm.mkv cfr-vp9-opus.webm vfr-ffv1.mkv; do
  "$TOOL" --Output=JSON "$f" > "../out/$f.t540p-24.01.json"
  echo "captured $f bytes=$(wc -c < ../out/$f.t540p-24.01.json)"
done
'
echo "capture_exit=$?"

echo "=== fetch results ==="
"$TS" ssh "$HOST" 'tar -czf - -C ~/staxrip-verify out' | tar -xzf - -C "$RESULTS"
ls -la "$RESULTS/out"

echo "=== byte-exact comparison vs committed wsl-24.01 goldens ==="
GOLD="$REPO/CrossPlatform/eng/fixtures/media-inspection"
for f in cfr-h264-aac.mp4 cfr-ffv1-10bit-pcm.mkv cfr-vp9-opus.webm vfr-ffv1.mkv; do
  cap="$RESULTS/out/$f.t540p-24.01.json"
  ref="$GOLD/$f.wsl-24.01.json"
  # Normalize the capture to a single trailing newline per the manifest rule.
  perl -0pi -e 's/\s+\z/\n/' "$cap"
  if cmp -s "$cap" "$ref"; then
    echo "$f: IDENTICAL"
  else
    echo "$f: DIFFERS -- diff follows"
    diff "$ref" "$cap" | head -12
  fi
done

echo "=== cleanup host ==="
"$TS" ssh "$HOST" 'rm -rf ~/staxrip-verify && echo host-cleaned'
echo T540P-COMPLETE
