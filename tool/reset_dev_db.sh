#!/usr/bin/env bash
# Tạo lại database dev từ apps/server/db/schema.sql rồi nạp dữ liệu thử
# (06 Bản 1 VS00-T13, 06 Bản 2 ED2-18). Dùng mỗi khi cấu trúc database đổi.
# Dữ liệu thử cũ trên database dev bị xóa; app trên simulator/iPhone cần cài lại.
#   tool/reset_dev_db.sh            tạo lại + nạp dữ liệu thử
#   tool/reset_dev_db.sh --no-seed  chỉ tạo lại, database trống
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
dev_env_require POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
DB="${DEV_DB_NAME:-$POSTGRES_DB}"
SCHEMA="$ROOT/apps/server/db/schema.sql"
PSQL=(docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 -q)

"$ROOT/tool/test_db.sh" ensure
"${PSQL[@]}" -d postgres -c "DROP DATABASE IF EXISTS \"$DB\" WITH (FORCE)"
"${PSQL[@]}" -d postgres -c "CREATE DATABASE \"$DB\""
"${PSQL[@]}" -d "$DB" < "$SCHEMA"
# Đánh dấu bản schema.sql đã dùng để tool/run_device.sh phát hiện cấu trúc cũ.
HASH="$(shasum -a 256 "$SCHEMA" | cut -d' ' -f1)"
"${PSQL[@]}" -d postgres -c "COMMENT ON DATABASE \"$DB\" IS 'schema:$HASH'"
echo "Đã tạo lại database $DB từ apps/server/db/schema.sql."

if [ "${1:-}" != "--no-seed" ]; then
  (cd "$ROOT" && DATABASE_URL="$(dev_db_url "$DB")" dart run tool/seed_dev.dart)
fi
echo "Nhớ cài lại app dev trên simulator/iPhone (database trên máy dùng cấu trúc cũ)."
