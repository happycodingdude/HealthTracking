#!/usr/bin/env bash
# Kiểm thử nâng cấp 4.0.0 → 5.0.0 trên simulator (06 Bản 5 ED5-11, VS60-T04,
# TAC5-02): cài app 4.0.0 (code từ tag mobile-v4.0.0) với v4DataSet + outbox 2
# mutation (tool/upgrade/seed_v4_test.dart chạy trong cây 4.0.0, server test
# thật), cài đè 5.0.0 từ cây hiện tại, mở app → Drift lên schema 3 (chỉ thêm
# bảng / cột: số dòng bảng cũ không đổi, bảng mới rỗng), 2 mutation đã gửi
# (server có tên mới), cursor về 0 một lần rồi pull hết (bộ entity đã biết
# thêm 4 entity, TA5-10); buổi "Không tập" ngày đã qua còn hạn cũ giờ khóa
# (tool/upgrade/check_v5_test.dart, FC5-12). Cuối cùng thử quay lui (05 Bản 5
# §6.12): cài đè 4.0.0 rồi 5.0.0 lần nữa → app mở được, schema 3.
#   tool/upgrade_test.sh [-d <simulator-id>]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
dev_env_require POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
DEVICE=""; PORT=18085; BUNDLE=com.happycodingdude.ironly.dev
V4_TAG=mobile-v4.0.0
V4="$ROOT/build/upgrade_v4"
OUT="$ROOT/build/upgrade"
CHECK="$ROOT/apps/mobile/integration_test/upgrade_check_v5_test.dart"
[ "${1:-}" = "-d" ] && DEVICE="$2"
JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
SEED_PASSWORD="$(openssl rand -base64 18 | tr -d '\n=/+')"
mkdir -p "$OUT"

echo "==> 0. Server test Bản 5 (cổng $PORT)"
"$ROOT/tool/test_db.sh" ensure
DBNAME="upgrade_$(date +%s)"
docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE $DBNAME" >/dev/null
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" dart run bin/admin.dart migrate >/dev/null)
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" dart run bin/admin.dart library import "$ROOT/data/v3__exercises.json" >/dev/null)
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" HOST=127.0.0.1 PORT=$PORT JWT_SECRET="$JWT_SECRET" BCRYPT_COST=4 \
  exec dart run bin/server.dart >"$OUT/server.log" 2>&1) &
SERVER_PID=$!
cleanup() {
  rm -f "$CHECK"
  kill "$SERVER_PID" 2>/dev/null || true
  sleep 1
  docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "DROP DATABASE IF EXISTS $DBNAME WITH (FORCE)" >/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done

if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()' || true)"
  [ -n "$DEVICE" ] || { echo "Chưa có simulator đang bật" >&2; exit 1; }
fi
DEFINES=(--dart-define=FLAVOR=dev --dart-define=API_BASE_URL="http://localhost:$PORT")

echo "==> 1. Code 4.0.0 ($V4_TAG)"
if [ ! -f "$V4/apps/mobile/pubspec.yaml" ]; then
  rm -rf "$V4" && mkdir -p "$V4"
  git -C "$ROOT" archive "$V4_TAG" | tar -x -C "$V4"
  (cd "$V4" && flutter pub get >/dev/null)
fi
cp "$ROOT/tool/upgrade/seed_v4_test.dart" "$V4/apps/mobile/integration_test/seed_v4_test.dart"

echo "==> 2. Cài 4.0.0 sạch, tạo v4DataSet + outbox 2 mutation"
xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl keychain "$DEVICE" reset
(cd "$V4/apps/mobile" && flutter test integration_test/seed_v4_test.dart --no-uninstall --flavor dev -d "$DEVICE" \
  "${DEFINES[@]}" --dart-define=SEED_PASSWORD="$SEED_PASSWORD" 2>&1 | tee "$OUT/seed.log" | grep -E "SEED_V4|All tests passed|Some tests failed" )
CURSOR_BEFORE="$(grep -o 'SEED_V4 cursor=[0-9]*' "$OUT/seed.log" | head -1 | cut -d= -f2)"
PAST="$(grep -o 'past=[0-9-]*' "$OUT/seed.log" | head -1 | cut -d= -f2)"
[ -n "$CURSOR_BEFORE" ] && [ -n "$PAST" ] || { echo "Bước 1 không in cursor / ngày đã qua" >&2; exit 1; }
# App 4.0.0 thật (không phải app chạy test) để dành cho bước quay lui.
(cd "$V4/apps/mobile" && flutter build ios --simulator --flavor dev "${DEFINES[@]}" >/dev/null)
V4_APP="$OUT/Runner-4.0.0.app"
rm -rf "$V4_APP" && cp -R "$V4/apps/mobile/build/ios/iphonesimulator/Runner.app" "$V4_APP"

# Thư mục dữ liệu của app (iOS đổi mã thư mục sau mỗi lần cài, tìm lại sau khi cài đè).
find_db() {
  local c; c="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)"
  DB="$(find "$c" -name 'ironly.sqlite' | head -1)"
  [ -n "$DB" ] || { echo "Không thấy ironly.sqlite trong $c" >&2; exit 1; }
}
OLD_TABLES=(profiles weekly_templates month_plans days lift_logs exercise_units exercise_notes weights menus exercises dish_images)
NEW_TABLES=(session_exercises exercise_feels schedule_pauses gym_locations gym_arrivals)
snapshot() {
  for t in "${OLD_TABLES[@]}"; do
    printf '%s=%s\n' "$t" "$(sqlite3 "$DB" "SELECT count(*) FROM $t;" 2>/dev/null || echo '?')"
  done
}
installed_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" app)/Info.plist"
}
find_db
snapshot > "$OUT/before.txt"
UV_BEFORE="$(sqlite3 "$DB" 'PRAGMA user_version;')"
OUTBOX_BEFORE="$(sqlite3 "$DB" 'SELECT count(*) FROM outbox;')"
MARK_BEFORE="$(sqlite3 "$DB" "SELECT mark FROM days WHERE date = '$PAST';")"
echo "Trước: version=$(installed_version) user_version=$UV_BEFORE cursor=$CURSOR_BEFORE outbox=$OUTBOX_BEFORE $PAST=$MARK_BEFORE"; cat "$OUT/before.txt"
[ "$UV_BEFORE" = 2 ] || { echo "app 4.0.0 phải ở schema 2" >&2; exit 1; }
[ "$OUTBOX_BEFORE" = 2 ] || { echo "outbox phải có 2 mutation" >&2; exit 1; }
[ "$MARK_BEFORE" = skipped ] || { echo "ngày $PAST phải là Không tập" >&2; exit 1; }

echo "==> 3. Build 5.0.0 (cây hiện tại) và cài đè"
(cd "$ROOT/apps/mobile" && flutter build ios --simulator --flavor dev "${DEFINES[@]}" >/dev/null)
# Chép ra ngoài: bước 5 (flutter test) build đè app chạy test vào cùng chỗ.
APP="$OUT/Runner-5.0.0.app"
rm -rf "$APP" && cp -R "$ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app" "$APP"
xcrun simctl install "$DEVICE" "$APP"
find_db
INSTALLED="$(installed_version)"
echo "Đã cài: $INSTALLED"
[ "$INSTALLED" = 5.0.0 ] || { echo "Bản cài không phải 5.0.0" >&2; exit 1; }
xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
for _ in $(seq 1 40); do
  sleep 1
  [ "$(sqlite3 "$DB" 'SELECT count(*) FROM outbox;')" = 0 ] && break
done
sleep 3
xcrun simctl io "$DEVICE" screenshot "$OUT/after_5.0.0.png" >/dev/null

echo "==> 4. Kiểm sau nâng cấp"
snapshot > "$OUT/after.txt"
UV_AFTER="$(sqlite3 "$DB" 'PRAGMA user_version;')"
OUTBOX_AFTER="$(sqlite3 "$DB" 'SELECT count(*) FROM outbox;')"
CURSOR_AFTER="$(sqlite3 "$DB" 'SELECT cursor FROM sync_state WHERE id = 1;')"
KNOWN="$(sqlite3 "$DB" 'SELECT known_entities FROM sync_state WHERE id = 1;')"
MARK_AFTER="$(sqlite3 "$DB" "SELECT mark FROM days WHERE date = '$PAST';")"
echo "Sau: user_version=$UV_AFTER cursor=$CURSOR_AFTER outbox=$OUTBOX_AFTER $PAST=$MARK_AFTER"; cat "$OUT/after.txt"
FAIL=0
[ "$UV_AFTER" = 3 ] || { echo "user_version phải là 3 (schema Bản 5): $UV_AFTER" >&2; FAIL=1; }
diff "$OUT/before.txt" "$OUT/after.txt" || { echo "Số dòng bảng cũ thay đổi sau nâng cấp" >&2; FAIL=1; }
for t in "${NEW_TABLES[@]}"; do
  n="$(sqlite3 "$DB" "SELECT count(*) FROM $t;" 2>/dev/null || echo '?')"
  [ "$n" = 0 ] || { echo "Bảng mới $t phải có và rỗng: $n" >&2; FAIL=1; }
done
sqlite3 "$DB" 'SELECT opened_at FROM days LIMIT 1;' >/dev/null || { echo "Thiếu cột days.opened_at" >&2; FAIL=1; }
[ "$OUTBOX_AFTER" = 0 ] || { echo "Outbox chưa gửi hết ($OUTBOX_AFTER)" >&2; FAIL=1; }
[ "$CURSOR_AFTER" -ge "$CURSOR_BEFORE" ] || { echo "Cursor chưa pull hết sau khi về 0: $CURSOR_BEFORE → $CURSOR_AFTER" >&2; FAIL=1; }
for e in session_exercise exercise_feel schedule_pause gym_location; do
  grep -q "$e" <<<"$KNOWN" || { echo "known_entities thiếu $e: $KNOWN" >&2; FAIL=1; }
done
[ "$MARK_AFTER" = skipped ] || { echo "Trạng thái ngày $PAST đổi: $MARK_AFTER" >&2; FAIL=1; }
# Cursor về 0 một lần (TA5-10): lần pull đầu của 5.0.0 bắt đầu từ cursor=0.
grep -q '"path":"/v1/sync/pull".*"appVersion":"5.0.0"' "$OUT/server.log" || { echo "5.0.0 chưa pull" >&2; FAIL=1; }
TOKEN="$(curl -sf -X POST "http://127.0.0.1:$PORT/v1/auth/login" -H 'Content-Type: application/json' \
  -d "{\"phone\":\"0977777778\",\"password\":\"$SEED_PASSWORD\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])')"
NAME="$(curl -sf "http://127.0.0.1:$PORT/v1/me" -H "Authorization: Bearer $TOKEN" | python3 -c 'import json,sys; print(json.load(sys.stdin)["displayName"])')"
echo "Server displayName=$NAME"
[ "$NAME" = "Minh Hai" ] || { echo "Server chưa nhận đủ 2 mutation (tên: $NAME)" >&2; FAIL=1; }
[ "$FAIL" = 0 ] || exit 1

echo "==> 5. Buổi ngày đã qua khóa trong app 5.0.0 (FC5-12)"
cp "$ROOT/tool/upgrade/check_v5_test.dart" "$CHECK"
(cd "$ROOT/apps/mobile" && flutter test integration_test/upgrade_check_v5_test.dart --no-uninstall --flavor dev -d "$DEVICE" \
  "${DEFINES[@]}" --dart-define=PAST_DAY="$PAST" 2>&1 | tee "$OUT/check.log" | grep -E "CHECK_V5|All tests passed|Some tests failed" )
grep -q "CHECK_V5 ok" "$OUT/check.log" || { echo "Bước 5 trượt" >&2; exit 1; }
rm -f "$CHECK"

echo "==> 6. Quay lui (05 Bản 5 §6.12): cài đè 4.0.0 rồi 5.0.0 lần nữa"
xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$V4_APP"
[ "$(installed_version)" = 4.0.0 ] || { echo "Không cài lại được 4.0.0" >&2; exit 1; }
xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
sleep 12
find_db
xcrun simctl io "$DEVICE" screenshot "$OUT/rollback_4.0.0.png" >/dev/null
UV_ROLLBACK="$(sqlite3 "$DB" 'PRAGMA user_version;')"
app_running() {
  xcrun simctl spawn "$DEVICE" launchctl list | grep "UIKitApplication:$BUNDLE" | awk '{print $1}' | grep -qE '^[0-9]+$'
}
app_running || { echo "App 4.0.0 không chạy trên schema 3" >&2; exit 1; }
snapshot > "$OUT/rollback.txt"
diff "$OUT/before.txt" "$OUT/rollback.txt" || { echo "App 4.0.0 làm mất dữ liệu" >&2; exit 1; }
xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
sleep 12
find_db
xcrun simctl io "$DEVICE" screenshot "$OUT/reinstall_5.0.0.png" >/dev/null
UV_AGAIN="$(sqlite3 "$DB" 'PRAGMA user_version;')"
app_running || { echo "App 5.0.0 không chạy sau quay lui" >&2; exit 1; }
echo "Quay lui: 4.0.0 user_version=$UV_ROLLBACK → 5.0.0 user_version=$UV_AGAIN"
[ "$UV_AGAIN" = 3 ] || { echo "5.0.0 không mở lại được database sau quay lui (user_version $UV_AGAIN)" >&2; exit 1; }
snapshot > "$OUT/again.txt"
diff "$OUT/before.txt" "$OUT/again.txt" || { echo "Mất dữ liệu sau quay lui" >&2; exit 1; }

echo "upgrade_test: OK (4.0.0 → 5.0.0: schema 2 → 3, dữ liệu nguyên, 2 mutation đã gửi, cursor $CURSOR_BEFORE → 0 → $CURSOR_AFTER, ngày $PAST khóa; quay lui 4.0.0 ↔ 5.0.0 mở được). Ảnh: $OUT/after_5.0.0.png"
