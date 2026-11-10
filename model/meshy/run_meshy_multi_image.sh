#!/usr/bin/env bash
# Meshy multi-image-to-3d (1-4 photos). Better accuracy than single image.
# Usage:
#   export MESHY_API_KEY=msy_xxx
#   ./run_meshy_multi_image.sh photo1.png photo2.png [photo3.png] [photo4.png]
set -euo pipefail
[[ -n "${MESHY_API_KEY:-}" ]] || { echo "Set MESHY_API_KEY"; exit 1; }
[[ $# -ge 1 ]] || { echo "Usage: $0 img1.png [img2.png ...]"; exit 1; }

OUT_DIR="$(cd "$(dirname "$0")" && pwd)/output"
mkdir -p "$OUT_DIR"

# Build JSON array of data URIs
IMGS_JSON="["
first=1
for f in "$@"; do
  [[ -f "$f" ]] || { echo "Missing: $f"; exit 1; }
  EXT=$(echo "${f##*.}" | tr 'A-Z' 'a-z')
  MIME="image/png"; [[ "$EXT" == "jpg" || "$EXT" == "jpeg" ]] && MIME="image/jpeg"
  B64=$(base64 -w0 "$f" 2>/dev/null || base64 "$f" | tr -d '\n')
  [[ $first -eq 1 ]] || IMGS_JSON+=","
  IMGS_JSON+="\"data:${MIME};base64,${B64}\""
  first=0
done
IMGS_JSON+="]"

echo "[1/3] Creating multi-image task ($# images)..."
# Meshy multi-image endpoint (image-to-3d with image_urls array where supported)
RESP=$(curl -sS https://api.meshy.ai/openapi/v1/multi-image-to-3d \
  -X POST \
  -H "Authorization: Bearer ${MESHY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"image_urls\": ${IMGS_JSON}, \"should_remesh\": true, \"should_texture\": true}" 2>/dev/null || true)

TASK_ID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result') or d.get('id') or '')" 2>/dev/null || true)
if [[ -z "$TASK_ID" ]]; then
  echo "Multi-image endpoint failed or unavailable. Response:"
  echo "$RESP"
  echo ""
  echo "Fall back to single best photo:"
  echo "  ./run_meshy_image_to_3d.sh $1"
  exit 1
fi
echo "  Task: $TASK_ID"

echo "[2/3] Polling..."
while true; do
  ST=$(curl -sS "https://api.meshy.ai/openapi/v1/multi-image-to-3d/${TASK_ID}" \
    -H "Authorization: Bearer ${MESHY_API_KEY}")
  STATUS=$(echo "$ST" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  echo "  $STATUS"
  case "$STATUS" in SUCCEEDED|SUCCESS) break ;; FAILED|CANCELED|EXPIRED) echo "$ST"; exit 1 ;; esac
  sleep 10
done

echo "[3/3] Download..."
python3 - << PY
import json, urllib.request, os
req = urllib.request.Request(
    f"https://api.meshy.ai/openapi/v1/multi-image-to-3d/${TASK_ID}",
    headers={"Authorization": f"Bearer {os.environ['MESHY_API_KEY']}"}
)
with urllib.request.urlopen(req) as r:
    data = json.load(r)
out = "${OUT_DIR}"
for fmt, url in (data.get("model_urls") or {}).items():
    if url:
        dest = os.path.join(out, f"meshy_multi.{fmt}")
        print(" ", fmt, "->", dest)
        urllib.request.urlretrieve(url, dest)
print("Done:", out)
PY
