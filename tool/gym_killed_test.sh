#!/usr/bin/env bash
# Thẻ theo vị trí khi app đã tắt hẳn, trên simulator (06 Bản 5 VS60-T05, D5-3 /
# D5-4 phần simulator, TAC5-08; 05 Bản 5 §6.4.6, §6.9.1): tài khoản thật trên
# server test có lịch hôm nay (buổi 23:59, chưa đánh dấu) và token thẻ; app đã
# lưu vị trí phòng gym (tool/gym/seed_gym_test.dart) → tắt hẳn app → dời vị
# trí giả ra ~1 km rồi vào lại → iOS mở app ở nền → app báo
# POST /v1/me/gym-arrival → server mở buổi sớm (`days.opened_at`) và quyết
# định bật thẻ `session` (APNs không cấu hình ở server test → `apns_disabled`).
# Không gửi tọa độ: chỉ kiểm log server không có lat / lng.
#   tool/gym_killed_test.sh [-d <simulator-id>]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
dev_env_require POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
DEVICE=""; PORT=18087; BUNDLE=com.happycodingdude.ironly.dev
OUT="$ROOT/build/gym_killed"
SEED="$ROOT/apps/mobile/integration_test/gym_killed_seed_test.dart"
[ "${1:-}" = "-d" ] && DEVICE="$2"
JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
SEED_PASSWORD="$(openssl rand -base64 18 | tr -d '\n=/+')"
PHONE="0966$(date +%s | tail -c 7)"
# Điểm thử (không phải vị trí của ai) và điểm cách ~1 km.
GYM_LAT=10.7700; GYM_LNG=106.7000; FAR="10.7790,106.7000"
mkdir -p "$OUT"
psql_dev() { docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$@"; }

"$ROOT/tool/test_db.sh" ensure
DBNAME="gymkilled_$(date +%s)"
psql_dev -d "$POSTGRES_DB" -c "CREATE DATABASE $DBNAME" >/dev/null
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" JWT_SECRET="$JWT_SECRET" dart run bin/admin.dart migrate >/dev/null)
(cd "$ROOT/apps/server" && DATABASE_URL="$(dev_db_url "$DBNAME")" HOST=127.0.0.1 PORT=$PORT JWT_SECRET="$JWT_SECRET" BCRYPT_COST=4 \
  exec dart run bin/server.dart >"$OUT/server.log" 2>&1) &
SERVER_PID=$!
cleanup() {
  rm -f "$SEED"
  [ -n "$DEVICE" ] && xcrun simctl location "$DEVICE" clear 2>/dev/null || true
  kill "$SERVER_PID" 2>/dev/null || true
  sleep 1
  psql_dev -d "$POSTGRES_DB" -c "DROP DATABASE IF EXISTS $DBNAME WITH (FORCE)" >/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done
if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()' || true)"
  [ -n "$DEVICE" ] || { echo "Chưa có simulator đang bật" >&2; exit 1; }
fi

echo "==> 1. Cài app sạch, đăng nhập, lưu vị trí phòng gym"
xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl keychain "$DEVICE" reset
xcrun simctl location "$DEVICE" set "$GYM_LAT,$GYM_LNG"
cp "$ROOT/tool/gym/seed_gym_test.dart" "$SEED"
# Quyền "Luôn luôn" đặt ngay khi app được cài (gỡ app ở trên xóa quyền).
( for _ in $(seq 1 600); do
    xcrun simctl get_app_container "$DEVICE" "$BUNDLE" >/dev/null 2>&1 && {
      xcrun simctl privacy "$DEVICE" grant location-always "$BUNDLE" 2>/dev/null; break; }
    sleep 0.5
  done ) &
(cd "$ROOT/apps/mobile" && flutter test integration_test/gym_killed_seed_test.dart --no-uninstall --flavor dev -d "$DEVICE" \
  --dart-define=FLAVOR=dev --dart-define=API_BASE_URL="http://localhost:$PORT" \
  --dart-define=SEED_PASSWORD="$SEED_PASSWORD" --dart-define=SEED_PHONE="$PHONE" \
  --dart-define=GYM_LAT="$GYM_LAT" --dart-define=GYM_LNG="$GYM_LNG" 2>&1 | tee "$OUT/seed.log" | grep -E "SEED_GYM|All tests passed|Some tests failed" )
USER_ID="$(grep -o 'SEED_GYM user=[0-9a-f-]*' "$OUT/seed.log" | head -1 | cut -d= -f2)"
[ -n "$USER_ID" ] || { echo "Bước 1 không in user" >&2; exit 1; }
rm -f "$SEED"

echo "==> 2. Tắt hẳn app; server có lịch hôm nay (buổi 23:59 chưa đánh dấu) và token thẻ"
xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
TODAY="$(TZ=Asia/Ho_Chi_Minh date +%Y-%m-%d)"; DOW="$(TZ=Asia/Ho_Chi_Minh date +%u)"
[ "$DOW" != 7 ] || { echo "Chủ nhật không có buổi (F05-R7): chạy lại ngày khác" >&2; exit 1; }
psql_dev -q -d "$DBNAME" <<SQL
INSERT INTO profiles (user_id, onboarding_step, timezone, server_version, client_updated_at)
  VALUES ('$USER_ID', 1, 'Asia/Ho_Chi_Minh', nextval('sync_version_seq'), now())
  ON CONFLICT (user_id) DO UPDATE SET timezone = 'Asia/Ho_Chi_Minh';
INSERT INTO weekly_templates (user_id, days, content_hash, server_version, client_updated_at)
  VALUES ('$USER_ID', '{}'::jsonb, repeat('a', 64), nextval('sync_version_seq'), now());
INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at, server_version, client_updated_at)
  VALUES ('$USER_ID', to_char('$TODAY'::date, 'YYYY-MM'), date_trunc('month', '$TODAY'::date), repeat('a', 64), now(), nextval('sync_version_seq'), now());
INSERT INTO days (user_id, date, kind, time, muscles, server_version, client_updated_at)
  VALUES ('$USER_ID', '$TODAY', 'workout', '23:59', ARRAY['back']::muscle_group[], nextval('sync_version_seq'), now());
INSERT INTO live_activity_tokens (user_id, push_to_start_token, environment, app_version)
  VALUES ('$USER_ID', 'simulator-token', 'sandbox', '5.0.0') ON CONFLICT (user_id) DO NOTHING;
SQL

echo "==> 3. Dời vị trí ra ~1 km 20 giây rồi vào lại vùng"
xcrun simctl location "$DEVICE" set "$FAR"
sleep 20
xcrun simctl location "$DEVICE" set "$GYM_LAT,$GYM_LNG"
FOUND=""
for i in $(seq 1 90); do
  sleep 2
  if grep -q '"gym_arrival"' "$OUT/server.log"; then FOUND="$((i * 2))"; break; fi
  # iOS đôi khi bỏ lần vào vùng đầu: dời ra / vào lại.
  if [ $((i % 15)) -eq 0 ]; then
    xcrun simctl location "$DEVICE" set "$FAR"; sleep 8; xcrun simctl location "$DEVICE" set "$GYM_LAT,$GYM_LNG"
  fi
done
[ -n "$FOUND" ] || { echo "Server không nhận gym-arrival trong 180 giây" >&2; exit 1; }
LINE="$(grep '"gym_arrival"' "$OUT/server.log" | head -1)"
echo "Server nhận sau ~${FOUND}s: $LINE"
FAIL=0
grep -q '"result":"session"' <<<"$LINE" || { echo "Phải quyết định bật thẻ session" >&2; FAIL=1; }
OPENED="$(psql_dev -At -d "$DBNAME" -c "SELECT opened_at IS NOT NULL FROM days WHERE user_id = '$USER_ID' AND date = '$TODAY'")"
[ "$OPENED" = t ] || { echo "days.opened_at chưa ghi (FD5-01)" >&2; FAIL=1; }
if grep -qiE '"(lat|lng)"|10\.77|106\.7' "$OUT/server.log"; then echo "Log server có tọa độ (TAC5-10)" >&2; FAIL=1; fi
C="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)"
DB="$(find "$C" -name 'ironly.sqlite' | head -1)"
ARRIVED="$(sqlite3 "$DB" "SELECT count(*) FROM gym_arrivals WHERE date = '$TODAY';")"
[ "$ARRIVED" = 1 ] || { echo "Máy chưa ghi gym_arrivals hôm nay ($ARRIVED)" >&2; FAIL=1; }
[ "$FAIL" = 0 ] || exit 1
echo "gym_killed_test: OK (app tắt hẳn → vào vùng → server nhận gym-arrival sau ~${FOUND}s, quyết định session, opened_at ghi; log không có tọa độ)"
