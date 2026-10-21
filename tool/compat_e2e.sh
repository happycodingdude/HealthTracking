#!/usr/bin/env bash
# compat_e2e (06 Bản 3 VS32-T08, IR3-10, TAC3-01): app 2.x đã phát hành với
# server Bản 3. Lấy code app 2.x từ commit đã lên TestFlight (build 2.0.0,
# chưa có tag mobile-v2.x), chạy tool/compat/v2_client_test.dart bằng chính
# contract, SyncEngine, Drift của bản đó, gọi tới server của cây code hiện tại
# chạy ở tiến trình riêng với database tạo bằng migration.
#   tool/compat_e2e.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
# Database: CI dùng PostgreSQL riêng của job (container test-db, không mật
# khẩu); trên Mac dùng deploy/docker-compose.dev.yml.
if [ -n "${CI:-}" ]; then
  psql_admin() { docker exec -i test-db psql -U postgres -d postgres "$@"; }
  db_url() { printf 'postgres://postgres@localhost:5432/%s' "$1"; }
else
  dev_env_require POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
  "$ROOT/tool/test_db.sh" ensure
  psql_admin() {
    docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db \
      psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"
  }
  db_url() { dev_db_url "$1"; }
fi

# Code của bản 2.0.0 đã lên TestFlight (build 37, 19/10/2026).
V2_COMMIT=2306a02
PORT=18090
JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
OUT="$ROOT/build/compat_v2"

echo "==> Lấy code app 2.x ($V2_COMMIT)"
rm -rf "$OUT" && mkdir -p "$OUT"
git -C "$ROOT" archive "$V2_COMMIT" | tar -x -C "$OUT"
cp "$ROOT/tool/compat/v2_client_test.dart" "$OUT/apps/mobile/test/compat_v2_test.dart"
(cd "$OUT" && flutter pub get >/dev/null 2>&1)

DBNAME="compat_$(date +%s)"
psql_admin -c "CREATE DATABASE $DBNAME" >/dev/null
(cd "$ROOT/apps/server" && DATABASE_URL="$(db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" \
  dart run bin/admin.dart migrate >/dev/null)

mkdir -p "$ROOT/build"
(cd "$ROOT/apps/server" && DATABASE_URL="$(db_url "$DBNAME")" HOST=127.0.0.1 PORT=$PORT \
  JWT_SECRET="$JWT_SECRET" BCRYPT_COST=4 \
  exec dart run bin/server.dart >"$ROOT/build/compat-server.log" 2>&1) &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
  sleep 1
  psql_admin -c "DROP DATABASE IF EXISTS $DBNAME WITH (FORCE)" >/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done

echo "==> App 2.x ↔ server Bản 3"
cd "$OUT/apps/mobile"
COMPAT_SERVER_URL="http://127.0.0.1:$PORT" \
COMPAT_DATABASE_URL="$(db_url "$DBNAME")?sslmode=disable" \
COMPAT_ROOT="$ROOT" \
  flutter test -r expanded test/compat_v2_test.dart
