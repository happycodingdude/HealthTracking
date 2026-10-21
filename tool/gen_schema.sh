#!/usr/bin/env bash
# Sinh apps/server/db/schema.sql = tổng các migration theo thứ tự (06 Bản 3
# ED3-01, TR3-05). Từ Bản 3, cấu trúc database chỉ đổi bằng file migration mới
# trong apps/server/migrations/; schema.sql không sửa tay.
#   tool/gen_schema.sh           ghi lại schema.sql
#   tool/gen_schema.sh --check   báo lỗi nếu schema.sql khác bản sinh ra (CI)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/apps/server/db/schema.sql"

gen() {
  cat <<'HEADER'
-- FILE SINH RA bằng tool/gen_schema.sh từ apps/server/migrations/ — KHÔNG SỬA
-- TAY. Đổi cấu trúc database: thêm migration đánh số mới (chỉ thêm), rồi chạy
-- tool/gen_schema.sh (05 Bản 3 TR3-05, 06 Bản 3 ED3-01). Dòng
-- `-- migrate:commit` tách đoạn phải commit trước (xem migrations/0002_v3.sql).
HEADER
  local f
  for f in "$ROOT"/apps/server/migrations/[0-9][0-9][0-9][0-9]_*.sql; do
    printf '\n-- ===== %s =====\n\n' "$(basename "$f")"
    cat "$f"
  done
}

if [ "${1:-}" = "--check" ]; then
  if ! diff -q <(gen) "$OUT" >/dev/null; then
    echo "apps/server/db/schema.sql khác tổng các migration: không sửa tay schema.sql; thêm migration mới rồi chạy tool/gen_schema.sh" >&2
    exit 1
  fi
  echo "schema.sql: khớp migrations"
else
  gen >"$OUT"
  echo "Đã ghi $OUT"
fi
