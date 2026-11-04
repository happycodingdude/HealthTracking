#!/usr/bin/env bash
# compat_v4_e2e (06 Bản 5 ED5-11, VS60-T03, TAC5-01): app 4.0.0 đã phát hành
# với server Bản 5. Lấy code app 4.0.0 từ tag mobile-v4.0.0, chạy
# tool/compat/v4_client_test.dart bằng chính contract, SyncEngine, Drift của
# bản đó, gọi tới server của cây code hiện tại chạy ở tiến trình riêng với
# database tạo bằng migration (0001 → 0003) và thư viện Bản 3.
#   tool/compat_v4_e2e.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
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

V4_TAG=mobile-v4.0.0
PORT=18091
JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
OUT="$ROOT/build/compat_v4"

echo "==> Lấy code app 4.0.0 ($V4_TAG)"
rm -rf "$OUT" && mkdir -p "$OUT"
git -C "$ROOT" archive "$V4_TAG" | tar -x -C "$OUT"
cp "$ROOT/tool/compat/v4_client_test.dart" "$OUT/apps/mobile/test/compat_v4_test.dart"
(cd "$OUT" && flutter pub get >/dev/null 2>&1)

DBNAME="compat_v4_$(date +%s)"
psql_admin -c "CREATE DATABASE $DBNAME" >/dev/null
(cd "$ROOT/apps/server" && DATABASE_URL="$(db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" \
  dart run bin/admin.dart migrate >/dev/null)
(cd "$ROOT/apps/server" && DATABASE_URL="$(db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" \
  dart run bin/admin.dart library import "$ROOT/data/v3__exercises.json" >/dev/null)

mkdir -p "$ROOT/build"
(cd "$ROOT/apps/server" && DATABASE_URL="$(db_url "$DBNAME")" HOST=127.0.0.1 PORT=$PORT \
  JWT_SECRET="$JWT_SECRET" BCRYPT_COST=4 \
  exec dart run bin/server.dart >"$ROOT/build/compat-v4-server.log" 2>&1) &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
  sleep 1
  psql_admin -c "DROP DATABASE IF EXISTS $DBNAME WITH (FORCE)" >/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done

echo "==> App 4.0.0 ↔ server Bản 5"
cd "$OUT/apps/mobile"
COMPAT_SERVER_URL="http://127.0.0.1:$PORT" \
COMPAT_DATABASE_URL="$(db_url "$DBNAME")?sslmode=disable" \
  flutter test -r expanded test/compat_v4_test.dart
