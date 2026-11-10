#!/usr/bin/env bash
# Generate a 3D model from a radar trailer photo via Meshy API.
# Usage:
#   export MESHY_API_KEY="your_key"
#   ./run_meshy_image_to_3d.sh /path/to/trailer_photo.png
#
# Docs: https://docs.meshy.ai/
set -euo pipefail

if [[ -z "${MESHY_API_KEY:-}" ]]; then
  echo "ERROR: Set MESHY_API_KEY first:"
  echo "  export MESHY_API_KEY=msy_xxxxxxxx"
  exit 1
fi

IMG="${1:-}"
if [[ -z "$IMG" || ! -f "$IMG" ]]; then
  echo "Usage: $0 /path/to/image.png"
  exit 1
fi

OUT_DIR="$(cd "$(dirname "$0")" && pwd)/output"
mkdir -p "$OUT_DIR"

EXT="${IMG##*.}"
EXT_LOWER=$(echo "$EXT" | tr 'A-Z' 'a-z')
MIME="image/png"
[[ "$EXT_LOWER" == "jpg" || "$EXT_LOWER" == "jpeg" ]] && MIME="image/jpeg"

echo "[1/4] Encoding image..."
B64=$(base64 -w0 "$IMG" 2>/dev/null || base64 "$IMG" | tr -d '\n')
DATA_URI="data:${MIME};base64,${B64}"

echo "[2/4] Creating Meshy image-to-3d task..."
RESP=$(curl -sS https://api.meshy.ai/openapi/v1/image-to-3d \
  -X POST \
  -H "Authorization: Bearer ${MESHY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"image_url\": \"${DATA_URI}\",
    \"enable_pbr\": true,
    \"should_remesh\": true,
    \"should_texture\": true
  }")

TASK_ID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result') or d.get('id') or '')" 2>/dev/null || true)
if [[ -z "$TASK_ID" ]]; then
  echo "Failed to create task. Response:"
  echo "$RESP"
  exit 1
fi
echo "  Task ID: $TASK_ID"

echo "[3/4] Polling until done (this can take several minutes)..."
STATUS=""
while true; do
  ST=$(curl -sS "https://api.meshy.ai/openapi/v1/image-to-3d/${TASK_ID}" \
    -H "Authorization: Bearer ${MESHY_API_KEY}")
  STATUS=$(echo "$ST" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  PROG=$(echo "$ST" | python3 -c "import sys,json; print(json.load(sys.stdin).get('progress',0))" 2>/dev/null || echo "0")
  echo "  status=$STATUS progress=$PROG%"
  case "$STATUS" in
    SUCCEEDED|SUCCESS) break ;;
    FAILED|CANCELED|EXPIRED)
      echo "$ST" | python3 -m json.tool 2>/dev/null || echo "$ST"
      exit 1
      ;;
  esac
  sleep 8
done

echo "[4/4] Downloading model files..."
python3 - << PY
import json, urllib.request, os
st = json.loads('''$ST'''.replace("'''", ""))
# re-fetch clean
import os, urllib.request, json
req = urllib.request.Request(
    f"https://api.meshy.ai/openapi/v1/image-to-3d/${TASK_ID}",
    headers={"Authorization": f"Bearer {os.environ['MESHY_API_KEY']}"}
)
with urllib.request.urlopen(req) as r:
    data = json.load(r)
model_urls = data.get("model_urls") or {}
out = "${OUT_DIR}"
os.makedirs(out, exist_ok=True)
for fmt, url in model_urls.items():
    if not url: continue
    dest = os.path.join(out, f"meshy_trailer.{fmt}")
    print(f"  downloading {fmt} -> {dest}")
    urllib.request.urlretrieve(url, dest)
print("Done. Files in:", out)
print("Next: import GLB/OBJ into Blender -> Sollumz -> YDR")
PY

echo ""
echo "Output folder: $OUT_DIR"
