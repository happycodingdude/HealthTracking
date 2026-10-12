#!/usr/bin/env bash
# Chạy bản dev (flavor dev, ED-15) từ Mac xuống iPhone qua cáp/Wi-Fi hoặc simulator (D-33).
#
#   tool/run_device.sh                    iPhone, build --profile (thử thủ công, ED-16)
#   tool/run_device.sh --debug            iPhone, build --debug (hot reload khi code UI)
#   tool/run_device.sh --simulator        simulator (luôn --debug)
#   tool/run_device.sh -d <device-id>     chọn thiết bị cụ thể (xem: flutter devices)
#   tool/run_device.sh --no-server        không bật server dev (đã chạy sẵn)
#
# Script bật PostgreSQL dev + server dev (lắng nghe 0.0.0.0:8080) rồi chạy app với
# API_BASE_URL = http://<LocalHostName>.local:8080 (iPhone) hoặc http://localhost:8080 (simulator).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"

MODE="--profile"; DEVICE=""; SIM=0; SERVER=1; PORT=8080
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) MODE="--profile" ;;
    --debug) MODE="--debug" ;;
    --simulator) SIM=1 ;;
    --no-server) SERVER=0 ;;
    -d) DEVICE="$2"; shift ;;
    *) echo "Tham số không hợp lệ: $1" >&2; exit 2 ;;
  esac
  shift
done

# 1. Database + server dev
# apps/server/.env không có trong git và không có file mẫu.
ENV_FILE="$ROOT/apps/server/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Thiếu apps/server/.env cho server dev: tạo theo danh sách biến trong docs/runbook.md." >&2
  exit 1
fi

SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT

if [ "$SERVER" = 1 ]; then
  dev_env_require POSTGRES_USER POSTGRES_DB
  "$ROOT/tool/test_db.sh" ensure
  # Database dev phải được tạo từ đúng bản apps/server/db/schema.sql (ED2-18).
  PSQL=(docker compose -f "$ROOT/deploy/docker-compose.dev.yml" exec -T db psql -U "$POSTGRES_USER" -tA)
  HASH="schema:$(shasum -a 256 "$ROOT/apps/server/db/schema.sql" | cut -d' ' -f1)"
  CURRENT="$("${PSQL[@]}" -d postgres -c "SELECT shobj_description(oid, 'pg_database') FROM pg_database WHERE datname = '$POSTGRES_DB'")"
  if [ "$CURRENT" != "$HASH" ]; then
    TABLES="$("${PSQL[@]}" -d "$POSTGRES_DB" -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'")"
    if [ "$TABLES" = 0 ]; then
      "$ROOT/tool/reset_dev_db.sh"
    else
      echo "Cấu trúc database dev cũ hơn apps/server/db/schema.sql." >&2
      echo "Chạy tool/reset_dev_db.sh (xóa dữ liệu thử, nạp lại), cài lại app, rồi chạy lại script này." >&2
      exit 1
    fi
  fi
  if curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null; then
    echo "Server dev đã chạy sẵn ở cổng $PORT."
  else
    mkdir -p "$ROOT/build"
    (cd "$ROOT/apps/server" && HOST=0.0.0.0 PORT=$PORT exec dart run bin/server.dart >"$ROOT/build/dev-server.log" 2>&1) &
    SERVER_PID=$!
    for _ in $(seq 1 60); do
      curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break
      sleep 1
    done
    curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null || { echo "Server dev không khởi động được, xem build/dev-server.log" >&2; exit 1; }
    echo "Server dev: http://0.0.0.0:$PORT (log: build/dev-server.log)"
  fi
fi

# 2. Địa chỉ server cho app
if [ "$SIM" = 1 ]; then
  MODE="--debug"   # Flutter chỉ chạy được bản debug trên simulator
  API="http://localhost:$PORT"
  if [ -z "$DEVICE" ]; then
    DEVICE="$(xcrun simctl list devices booted | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
    if [ -z "$DEVICE" ]; then
      DEVICE="$(xcrun simctl list devices available | grep -E '^\s+iPhone' | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')"
      xcrun simctl boot "$DEVICE"
    fi
    # Xcode 27 thay Simulator.app bằng DeviceHub.app; không mở được cửa sổ thì vẫn chạy tiếp.
    open -a Simulator 2>/dev/null || open -a DeviceHub 2>/dev/null || true
  fi
else
  API="http://$(scutil --get LocalHostName).local:$PORT"
fi
echo "API_BASE_URL=$API"

# 3. Chạy app
cd "$ROOT/apps/mobile"
flutter run --flavor dev "$MODE" ${DEVICE:+-d "$DEVICE"} \
  --dart-define=FLAVOR=dev \
  --dart-define=API_BASE_URL="$API"
