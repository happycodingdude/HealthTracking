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
ENV_FILE="$ROOT/apps/server/.env"
if [ ! -f "$ENV_FILE" ]; then
  sed -e 's/^HOST=.*/HOST=0.0.0.0/' \
      -e "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')|" \
      "$ROOT/.env.example" > "$ENV_FILE"
  echo "Đã tạo apps/server/.env cho server dev."
fi

SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT

if [ "$SERVER" = 1 ]; then
  "$ROOT/tool/test_db.sh" ensure
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
