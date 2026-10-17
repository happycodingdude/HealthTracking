#!/usr/bin/env bash
# Chạy golden test của app trong container Linux amd64, giống runner CI (ED-09).
#   tool/golden.sh            so sánh
#   tool/golden.sh --update   tạo lại ảnh golden (ghi vào apps/mobile/test/**/goldens)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Cùng phiên bản Flutter với dự án; ảnh dựng một lần từ tool/golden.Dockerfile.
FLUTTER_VERSION="$(sed -n 's/^  flutter: *\([0-9.]*\).*/\1/p' "$ROOT/apps/mobile/pubspec.yaml")"
IMAGE="ironly-golden:flutter-$FLUTTER_VERSION"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker build --platform linux/amd64 --build-arg FLUTTER_VERSION="$FLUTTER_VERSION" \
    -t "$IMAGE" -f "$ROOT/tool/golden.Dockerfile" "$ROOT/tool"
fi
UPDATE=""
[ "${1:-}" = "--update" ] && UPDATE="--update-goldens"

docker run --rm --platform linux/amd64 \
  -v "$ROOT":/src:ro \
  -v "$ROOT/apps/mobile/test":/out \
  -v ironly-golden-pub-cache:/pub-cache \
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
