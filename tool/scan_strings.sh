#!/usr/bin/env bash
# Quét câu chữ Swift của widget (06 Bản 3 VS39-T07) và thẻ màn hình khóa
# (VS41-T01): không chữ nào mang nghĩa khuyên, xếp hạng, kết luận (UX-AC62,
# UR3-13); widget không có chữ về cân nặng, calo, thực đơn, mức tạ (F24-AC6,
# F24-R3); thẻ không có cân nặng, calo, ghi chú (F25-R8). Chỉ xét chuỗi trong
# dấu nháy, bỏ chú thích.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGET=(
  "$ROOT/apps/mobile/ios/IronlyWidgets/IronlyWidget.swift"
  "$ROOT/apps/mobile/ios/IronlyWidgets/WidgetContentView.swift"
)
ACTIVITY=(
  "$ROOT/apps/mobile/ios/IronlyWidgets/IronlySessionActivity.swift"
)
ADVICE='nên|hãy|tốt hơn|yếu|tăng tạ|giảm tạ|mục tiêu|xu hướng|xếp hạng|kỷ lục|chúc mừng'
WIDGET_ONLY='cân nặng|calo|thực đơn|mức tạ|kg'
ACTIVITY_ONLY='cân nặng|calo|thực đơn|ghi chú'
FAIL=0
scan() {
  local f="$1" banned="$2" strings hits
  strings="$(sed -E 's#//.*$##' "$f" | grep -oE '"[^"]*"' || true)"
  if hits="$(printf '%s\n' "$strings" | grep -inE "(^|[^[:alpha:]])($banned)([^[:alpha:]]|$)")"; then
    echo "scan_strings: $(basename "$f") có chữ không được dùng:" >&2
    printf '%s\n' "$hits" >&2
    FAIL=1
  fi
}
for f in "${WIDGET[@]}"; do scan "$f" "$ADVICE|$WIDGET_ONLY"; done
for f in "${ACTIVITY[@]}"; do scan "$f" "$ADVICE|$ACTIVITY_ONLY"; done
[ "$FAIL" = 0 ] && echo "scan_strings: OK (${#WIDGET[@]} file Swift của widget, ${#ACTIVITY[@]} file của thẻ)"
exit "$FAIL"
