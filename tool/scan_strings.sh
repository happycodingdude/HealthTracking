#!/usr/bin/env bash
# Quét câu chữ Swift của widget (06 Bản 3 VS39-T07): không chữ nào mang nghĩa
# khuyên, xếp hạng, kết luận (UX-AC62, UR3-13) và không có chữ về cân nặng,
# calo, thực đơn, mức tạ (F24-AC6, F24-R3). Chỉ xét chuỗi trong dấu nháy, bỏ
# chú thích.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGET=(
  "$ROOT/apps/mobile/ios/IronlyWidgets/IronlyWidget.swift"
  "$ROOT/apps/mobile/ios/IronlyWidgets/WidgetContentView.swift"
)
ADVICE='nên|hãy|tốt hơn|yếu|tăng tạ|giảm tạ|mục tiêu|xu hướng|xếp hạng|kỷ lục|chúc mừng'
WIDGET_ONLY='cân nặng|calo|thực đơn|mức tạ|kg'
FAIL=0
for f in "${WIDGET[@]}"; do
  strings="$(sed -E 's#//.*$##' "$f" | grep -oE '"[^"]*"' || true)"
  if hits="$(printf '%s\n' "$strings" | grep -inE "(^|[^[:alpha:]])($ADVICE|$WIDGET_ONLY)([^[:alpha:]]|$)")"; then
    echo "scan_strings: $(basename "$f") có chữ không được dùng:" >&2
    printf '%s\n' "$hits" >&2
    FAIL=1
  fi
done
[ "$FAIL" = 0 ] && echo "scan_strings: OK (${#WIDGET[@]} file Swift của widget)"
exit "$FAIL"
