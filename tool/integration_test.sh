#!/usr/bin/env bash
# Integration test trên iOS simulator, chạy trên Mac trước khi đóng slice và trước tag (ED-10).
#   tool/integration_test.sh [-d <simulator-id>]
# Bật PostgreSQL + server test riêng (cổng 18080) để luồng đăng nhập/đồng bộ chạy thật.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE=""; PORT=18080
[ "${1:-}" = "-d" ] && DEVICE="$2"

[ -d "$ROOT/apps/mobile/integration_test" ] || { echo "Chưa có integration_test/"; exit 0; }

"$ROOT/tool/test_db.sh" ensure
DBNAME="itest_$(date +%s)"
docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U health -d health -c "CREATE DATABASE $DBNAME" >/dev/null
mkdir -p "$ROOT/build"
(cd "$ROOT/apps/server" && DATABASE_URL="postgres://health:***REMOVED***@localhost:55432/$DBNAME" HOST=127.0.0.1 PORT=$PORT \
  JWT_SECRET="***REMOVED***" BCRYPT_COST=4 \
  exec dart run bin/server.dart >"$ROOT/build/itest-server.log" 2>&1) &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
  sleep 1
  docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U health -d health -c "DROP DATABASE IF EXISTS $DBNAME WITH (FORCE)" >/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done

if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
  if [ -z "$DEVICE" ]; then
    DEVICE="$(xcrun simctl list devices available | grep -E '^\s+iPhone' | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
    xcrun simctl boot "$DEVICE"
  fi
fi

cd "$ROOT/apps/mobile"
flutter test integration_test --flavor dev -d "$DEVICE" \
  --dart-define=FLAVOR=dev --dart-define=API_BASE_URL="http://localhost:$PORT"
