#!/usr/bin/env bash
set -u
REPO="$1"
RUN=/tmp/sport02-linux-run
EXPECTED_TOOL_SHA=a802f414b80dc1abc437a918d8849bb390538bc6f520632c7e9a6a56fcda99d6
rm -rf "$RUN"
mkdir -p "$RUN/media" "$RUN/out"

cp "$REPO/CrossPlatform/eng/fixtures/media-inspection/media/"* "$RUN/media/"
cp -r "$REPO/CrossPlatform/artifacts/tools/wsl-mediainfo-24.01" "$RUN/tool"
cp -r "$REPO/CrossPlatform/artifacts/publish/tests-linux-x64" "$RUN/host"
chmod +x "$RUN/host/StaxRip.ContractTests" "$RUN/tool/usr/bin/mediainfo"

TOOL="$RUN/tool/usr/bin/mediainfo"
ACTUAL_SHA=$(sha256sum "$TOOL" | cut -d' ' -f1)
echo "tool_sha=$ACTUAL_SHA"
if [ "$ACTUAL_SHA" != "$EXPECTED_TOOL_SHA" ]; then echo "TOOL HASH MISMATCH"; exit 1; fi
export LD_LIBRARY_PATH="$RUN/tool/usr/lib/x86_64-linux-gnu"
echo "tool_version=$("$TOOL" --Version | tr '\n' ' ')"

ln -s "$RUN/media" "$RUN/media/linkdir"
ln -s "$RUN/media/cfr-h264-aac.mp4" "$RUN/media/linkfile.mp4"
echo "symlinks staged"

# The host keeps the tool's loader path in its environment, because the spawned
# authority child inherits it and a user-prefix extraction needs its own libraries.
mkfifo "$RUN/host-stdin"
"$RUN/host/StaxRip.ContractTests" --serve-configured "$RUN/media" "$TOOL" < "$RUN/host-stdin" > "$RUN/out/host.log" 2>"$RUN/out/host.err" &
HOST_PID=$!
exec 9>"$RUN/host-stdin"
for i in $(seq 1 50); do
  if grep -q '^READY ' "$RUN/out/host.log" 2>/dev/null; then break; fi
  sleep 0.2
done
BASE=$(grep '^READY ' "$RUN/out/host.log" | head -1 | cut -d' ' -f2 | tr -d '\r\n')
BASE=${BASE%/}
echo "base=$BASE"
if [ -z "$BASE" ]; then echo "HOST NOT READY"; cat "$RUN/out/host.err"; exit 1; fi

COOKIE=$(curl -s -i "$BASE/" | grep -i '^set-cookie:' | head -1 | sed 's/^[Ss]et-[Cc]ookie: //' | cut -d';' -f1 | tr -d '\r')
echo "cookie_len=${#COOKIE}"
AUTH=(-H "X-StaxRip-Client: web" -H "Cookie: $COOKIE")

curl -s "${AUTH[@]}" "$BASE/api/v1/capabilities" > "$RUN/out/capabilities.json"
echo "capability_row=$(grep -o '{"id":"media-inspection"[^}]*}' "$RUN/out/capabilities.json")"

post() {
  local path_json="$1"; local out="$2"
  printf '{"path":"%s"}' "$path_json" > "$RUN/out/body.json"
  curl -s -w '\n%{http_code}' -X POST "${AUTH[@]}" -H 'Content-Type: application/json; charset=utf-8' --data-binary @"$RUN/out/body.json" "$BASE/api/v1/media-facts" > "$out"
}

for f in cfr-h264-aac.mp4 cfr-ffv1-10bit-pcm.mkv cfr-vp9-opus.webm vfr-ffv1.mkv cfr-h264-aac-chapters.mp4 cfr-h264-aac-subtitles.mkv; do
  post "$RUN/media/$f" "$RUN/out/happy-$f.txt"
  echo "happy_$f status=$(tail -1 "$RUN/out/happy-$f.txt")"
  echo "happy_$f body=$(head -c 400 "$RUN/out/happy-$f.txt")"
done
echo "authority_version=$(grep -o '"authority":{[^}]*}' "$RUN/out/happy-cfr-h264-aac.mp4.txt" | head -1)"
echo "container_format=$(grep -o '"container":{"format":"[^"]*"' "$RUN/out/happy-cfr-h264-aac.mp4.txt" | head -1)"
for banned in UniqueID Encoded_Library_Settings Encoded_Application File_Created_Date File_Modified_Date CompleteName FolderName; do
  if grep -q "$banned" "$RUN"/out/happy-*.txt; then echo "PRIVACY LEAK: $banned"; fi
done
echo "privacy_grep_done"

i=0
for hostile in "/etc/hostname" "$RUN/media" "$RUN/media/../media/cfr-h264-aac.mp4" "$RUN/media/linkdir/cfr-h264-aac.mp4" "$RUN/media/linkfile.mp4" "relative.mkv" "$RUN/media/absent-2f81aa.mkv"; do
  post "$hostile" "$RUN/out/hostile-$i.txt"
  echo "hostile_$i status=$(tail -1 "$RUN/out/hostile-$i.txt") path=$hostile"
  i=$((i+1))
done
first_body=$(head -1 "$RUN/out/hostile-0.txt")
uniform=yes
for j in 1 2 3 4 5 6; do
  if [ "$(head -1 "$RUN/out/hostile-$j.txt")" != "$first_body" ]; then uniform=no; fi
done
echo "hostile_uniform=$uniform body=$first_body"

exec 9>&-
for i in $(seq 1 50); do
  if ! kill -0 $HOST_PID 2>/dev/null; then break; fi
  sleep 0.2
done
if kill -0 $HOST_PID 2>/dev/null; then echo "host_still_running"; kill $HOST_PID; else echo "host_clean_exit"; fi
grep -c '^STOPPED' "$RUN/out/host.log" | sed 's/^/stopped_lines=/'
echo "orphan_mediainfo=$(pgrep -c -f "$TOOL" 2>/dev/null || echo 0)"
echo RUN-COMPLETE
