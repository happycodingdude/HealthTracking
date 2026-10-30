#!/usr/bin/env bash
# Bộ ảnh so sánh Bản 4 (06 Bản 4 ED4-04, VS43-T11): chụp màn × trạng thái của
# một mốc trên simulator (flutter drive, cỡ chữ mặc định), ghép cạnh vùng tương
# ứng cắt từ docs/specs/v4/04-ui-mockups.pdf → docs/review/v4/<M>.pdf.
#   tool/capture_screens.sh M17 [-d <simulator-id>] [--no-capture]
# Cần: pdftoppm (brew install poppler), swiftc (Xcode).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
M="${1:?Mốc: M17 … M21}"; shift || true
DEVICE=""; CAPTURE=1
while [ $# -gt 0 ]; do
  case "$1" in
    -d) DEVICE="$2"; shift ;;
    --no-capture) CAPTURE=0 ;;
  esac
  shift
done
MOCK="$ROOT/docs/specs/v4/04-ui-mockups.pdf"
OUT="$ROOT/docs/review/v4"
SHOTS="$ROOT/apps/mobile/build/review"
mkdir -p "$OUT" "$SHOTS"

if [ "$CAPTURE" = 1 ]; then
  if [ -z "$DEVICE" ]; then
    DEVICE="$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
    [ -n "$DEVICE" ] || { echo "Chưa có simulator đang bật" >&2; exit 1; }
  fi
  cd "$ROOT/apps/mobile"
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/capture_test.dart --flavor dev -d "$DEVICE" \
    --dart-define=FLAVOR=dev --dart-define=API_BASE_URL=http://localhost:8080 \
    --dart-define=CAPTURE_MILESTONE="$M"
  cd "$ROOT"
fi

# Trang mock → PNG (144 dpi = 2× điểm).
MOCKDIR="$ROOT/apps/mobile/build/review/mock"
mkdir -p "$MOCKDIR"
[ -f "$MOCKDIR/page-1.png" ] || pdftoppm -r 144 -png "$MOCK" "$MOCKDIR/page"

# Danh sách ô của mốc (từ review_matrix.dart) → tsv: id, screen, state, page, x, y, w, h.
TSV="$SHOTS/$M.tsv"
(cd "$ROOT/apps/mobile" && dart run tool/review_matrix_dump.dart "$M") > "$TSV"

# Ghép PDF bằng Swift (CoreGraphics).
BIN="$ROOT/apps/mobile/build/review/review_pdf"
if [ ! -x "$BIN" ] || [ "$ROOT/tool/review_pdf.swift" -nt "$BIN" ]; then
  swiftc -O "$ROOT/tool/review_pdf.swift" -o "$BIN"
fi
"$BIN" "$TSV" "$SHOTS" "$MOCKDIR" "$OUT/$M.pdf" 2
echo "capture_screens: $OUT/$M.pdf"
