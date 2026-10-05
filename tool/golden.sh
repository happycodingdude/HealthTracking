#!/usr/bin/env bash
# Chạy golden test của app trong container Linux amd64, giống runner CI (ED-09).
#   tool/golden.sh            so sánh
#   tool/golden.sh --update   tạo lại ảnh golden (ghi vào apps/mobile/test/**/goldens)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="ghcr.io/cirruslabs/flutter:3.32.6"
UPDATE=""
[ "${1:-}" = "--update" ] && UPDATE="--update-goldens"

docker run --rm --platform linux/amd64 \
  -v "$ROOT":/src:ro \
  -v "$ROOT/apps/mobile/test":/out \
  -v health-golden-pub-cache:/pub-cache \
  -e PUB_CACHE=/pub-cache \
  "$IMAGE" bash -c "
    set -euo pipefail
    mkdir -p /repo
    tar -C /src --exclude='./.git' --exclude='*/.dart_tool' --exclude='./.dart_tool' --exclude='*/build' -cf - . | tar -C /repo -xf -
    cd /repo && flutter pub get >/dev/null
    cd apps/mobile
    flutter test -r failures-only --tags golden $UPDATE || STATUS=\$?
    # Chép ảnh golden mới và ảnh lỗi (failures/) ra máy.
    (cd test && find . -path '*goldens/*.png' -o -path '*failures/*.png' | tar -cf - -T - | tar -C /out -xf -) 2>/dev/null || true
    exit \${STATUS:-0}
  "
