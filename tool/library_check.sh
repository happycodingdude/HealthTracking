#!/usr/bin/env bash
# Cổng thư viện (06 Bản 2 VS21-T09, IR2-06, §6.11): `admin library import
# --check-only` trên data/v2__exercises.json — 6 nhóm cơ đủ F18-R1, mọi bài có
# ngày duyệt, độ dài video đã đo ≤ 60 giây, hướng dẫn đúng LIB-R4. Không ghi gì
# vào database. CI chạy khi PR đổi file thư viện.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${1:-$ROOT/data/v2__exercises.json}"
cd "$ROOT/apps/server"
DATABASE_URL="${DATABASE_URL:-postgres://health:***REMOVED***@localhost:55432/health}" \
JWT_SECRET="${JWT_SECRET:-library-check-library-check-library-check}" \
  dart run bin/admin.dart library import --check-only "$FILE"
