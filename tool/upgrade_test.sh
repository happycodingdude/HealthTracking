#!/usr/bin/env bash
# Kiểm thử nâng cấp 3.0.0 → 4.0.0 trên simulator (06 Bản 4 ED4-10, VS51-T03,
# TAC4-02): cài app 3.0.0 (code từ tag mobile-v3.0.0) với v3DataSet + outbox 2
# mutation (tool/upgrade/seed_v3_test.dart chạy trong cây 3.0.0, server test
# thật), cài đè 4.0.0 từ cây hiện tại, mở app → database giữ nguyên (không
# migration: user_version không đổi, số dòng từng bảng không đổi), 2 mutation
# đã gửi (server có tên mới), cursor không về 0.
#   tool/upgrade_test.sh [-d <simulator-id>]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
dev_env_require POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
DEVICE=""; PORT=18085; BUNDLE=com.happycodingdude.ironly.dev
V3_TAG=mobile-v3.0.0
V3="$ROOT/build/upgrade_v3"
OUT="$ROOT/build/upgrade"
[ "${1:-}" = "-d" ] && DEVICE="$2"
JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
SEED_PASSWORD="$(openssl rand -base64 18 | tr -d '\n=/+')"
mkdir -p "$OUT"

echo "==> 0. Server test (cổng $PORT)"
"$ROOT/tool/test_db.sh" ensure
DBNAME="upgrade_$(date +%s)"
docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE $DBNAME" >/dev/null
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" dart run bin/admin.dart migrate >/dev/null)
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" dart run bin/admin.dart library import "$ROOT/data/v3__exercises.json" >/dev/null)
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" HOST=127.0.0.1 PORT=$PORT JWT_SECRET="$JWT_SECRET" BCRYPT_COST=4 \
  exec dart run bin/server.dart >"$OUT/server.log" 2>&1) &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
  sleep 1
  docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "DROP DATABASE IF EXISTS $DBNAME WITH (FORCE)" >/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done

if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
  [ -n "$DEVICE" ] || { echo "Chưa có simulator đang bật" >&2; exit 1; }
fi

echo "==> 1. Code 3.0.0 ($V3_TAG)"
if [ ! -f "$V3/apps/mobile/pubspec.yaml" ]; then
  rm -rf "$V3" && mkdir -p "$V3"
  git -C "$ROOT" archive "$V3_TAG" | tar -x -C "$V3"
  (cd "$V3" && flutter pub get >/dev/null)
fi
cp "$ROOT/tool/upgrade/seed_v3_test.dart" "$V3/apps/mobile/integration_test/seed_v3_test.dart"

echo "==> 2. Cài 3.0.0 sạch, tạo v3DataSet + outbox 2 mutation"
xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl keychain "$DEVICE" reset
(cd "$V3/apps/mobile" && flutter test integration_test/seed_v3_test.dart --no-uninstall --flavor dev -d "$DEVICE" \
  --dart-define=FLAVOR=dev --dart-define=API_BASE_URL="http://localhost:$PORT" \
  --dart-define=SEED_PASSWORD="$SEED_PASSWORD" 2>&1 | tee "$OUT/seed.log" | grep -E "SEED_V3|All tests passed|Some tests failed" )
CURSOR_BEFORE="$(grep -o 'SEED_V3 cursor=[0-9]*' "$OUT/seed.log" | head -1 | cut -d= -f2)"
[ -n "$CURSOR_BEFORE" ] || { echo "Bước 1 không in cursor" >&2; exit 1; }

# Thư mục dữ liệu của app (iOS đổi mã thư mục sau mỗi lần cài, tìm lại sau khi cài đè).
find_db() {
  local c; c="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)"
  DB="$(find "$c" -name 'ironly.sqlite' | head -1)"
  [ -n "$DB" ] || { echo "Không thấy ironly.sqlite trong $c" >&2; exit 1; }
}
find_db
snapshot() {
  sqlite3 "$DB" "PRAGMA user_version;" | sed 's/^/user_version=/'
  for t in profiles weekly_templates month_plans days lift_logs exercise_units exercise_notes weights menus exercises dish_images; do
    printf '%s=%s\n' "$t" "$(sqlite3 "$DB" "SELECT count(*) FROM $t;" 2>/dev/null || echo '?')"
  done
}
snapshot > "$OUT/before.txt"
OUTBOX_BEFORE="$(sqlite3 "$DB" 'SELECT count(*) FROM outbox;')"
echo "Trước: cursor=$CURSOR_BEFORE outbox=$OUTBOX_BEFORE"; cat "$OUT/before.txt"
[ "$OUTBOX_BEFORE" = 2 ] || { echo "outbox phải có 2 mutation" >&2; exit 1; }
VER_BEFORE="$(sqlite3 "$DB" "SELECT CFBundleShortVersionString FROM (SELECT '3.0.0' AS CFBundleShortVersionString);")"

echo "==> 3. Build 4.0.0 (cây hiện tại) và cài đè"
(cd "$ROOT/apps/mobile" && flutter build ios --simulator --flavor dev \
  --dart-define=FLAVOR=dev --dart-define=API_BASE_URL="http://localhost:$PORT" >/dev/null)
APP="$ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
xcrun simctl install "$DEVICE" "$APP"
find_db
INSTALLED="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" app)/Info.plist")"
echo "Đã cài: $INSTALLED (trước: $VER_BEFORE)"
[ "$INSTALLED" = 4.0.0 ] || { echo "Bản cài không phải 4.0.0" >&2; exit 1; }
xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
for i in $(seq 1 40); do
  sleep 1
  [ "$(sqlite3 "$DB" 'SELECT count(*) FROM outbox;')" = 0 ] && break
done
xcrun simctl io "$DEVICE" screenshot "$OUT/after_4.0.0.png" >/dev/null

echo "==> 4. Kiểm sau nâng cấp"
snapshot > "$OUT/after.txt"
OUTBOX_AFTER="$(sqlite3 "$DB" 'SELECT count(*) FROM outbox;')"
CURSOR_AFTER="$(sqlite3 "$DB" 'SELECT cursor FROM sync_state WHERE id = 1;')"
KNOWN="$(sqlite3 "$DB" 'SELECT known_entities FROM sync_state WHERE id = 1;')"
echo "Sau: cursor=$CURSOR_AFTER outbox=$OUTBOX_AFTER"; cat "$OUT/after.txt"
FAIL=0
diff "$OUT/before.txt" "$OUT/after.txt" || { echo "Số dòng / user_version thay đổi sau nâng cấp" >&2; FAIL=1; }
[ "$OUTBOX_AFTER" = 0 ] || { echo "Outbox chưa gửi hết ($OUTBOX_AFTER)" >&2; FAIL=1; }
[ "$CURSOR_AFTER" -ge "$CURSOR_BEFORE" ] || { echo "Cursor giảm / về 0: $CURSOR_BEFORE → $CURSOR_AFTER" >&2; FAIL=1; }
grep -q "exercise_note" <<<"$KNOWN" && grep -q "exercise_unit" <<<"$KNOWN" || { echo "known_entities đổi: $KNOWN" >&2; FAIL=1; }
# Server đã nhận 2 mutation (tên cuối "Minh Hai").
TOKEN="$(curl -sf -X POST "http://127.0.0.1:$PORT/v1/auth/login" -H 'Content-Type: application/json' \
  -d "{\"phone\":\"0977777777\",\"password\":\"$SEED_PASSWORD\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])')"
NAME="$(curl -sf "http://127.0.0.1:$PORT/v1/me" -H "Authorization: Bearer $TOKEN" | python3 -c 'import json,sys; print(json.load(sys.stdin)["displayName"])')"
echo "Server displayName=$NAME"
[ "$NAME" = "Minh Hai" ] || { echo "Server chưa nhận đủ 2 mutation (tên: $NAME)" >&2; FAIL=1; }
grep -c "sync/push" "$OUT/server.log" >/dev/null || true
if [ "$FAIL" = 0 ]; then
  echo "upgrade_test: OK (3.0.0 → 4.0.0: dữ liệu nguyên, 2 mutation đã gửi, cursor $CURSOR_BEFORE → $CURSOR_AFTER, user_version không đổi). Ảnh: $OUT/after_4.0.0.png"
else
  exit 1
fi
