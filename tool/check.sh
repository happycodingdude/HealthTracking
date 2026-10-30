#!/usr/bin/env bash
# Chạy toàn bộ kiểm tra như CI ở local: format → analyze → lint → test (06 §6.11).
# Golden test chỉ so sánh trên Linux (ED-09); trên macOS bị bỏ qua.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
cd "$ROOT"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
has_tests() { [ -n "$(find "$1/test" -name '*_test.dart' 2>/dev/null | head -1)" ]; }

# PostgreSQL cho test server và test E2E đồng bộ của app (sync_e2e). CI đặt sẵn
# TEST_DATABASE_URL; trên Mac dựng từ .env ở gốc repo.
if [ -z "${TEST_DATABASE_URL:-}" ]; then
  dev_env_require POSTGRES_USER POSTGRES_PASSWORD
  TEST_DATABASE_URL="$(dev_db_url postgres)"
  export TEST_DATABASE_URL
fi

step "file cấm và chuỗi giống khóa trong git"
"$ROOT/tool/scan_repo.sh"

step "câu chữ Swift của widget (06 Bản 3 VS39-T07)"
"$ROOT/tool/scan_strings.sh"

step "schema.sql khớp tổng các migration (06 Bản 3 ED3-01)"
"$ROOT/tool/gen_schema.sh" --check

step "hàng rào đường dẫn Bản 4 (06 Bản 4 ED4-02)"
"$ROOT/tool/check_protected_paths.sh"

step "token sinh khớp tokens.json (05 Bản 4 TD4-02)"
dart run tool/gen_tokens.dart --check

if command -v rsvg-convert >/dev/null; then
  step "icon app khớp app_icon.svg (05 Bản 4 TD4-09)"
  "$ROOT/tool/gen_app_icon.sh" --check
fi

step "pub get"
flutter pub get >/dev/null

step "format"
dart format --output=none --set-exit-if-changed packages apps/server apps/mobile/lib apps/mobile/test apps/mobile/tool apps/mobile/integration_test tool

step "analyze"
dart analyze --fatal-infos

step "lint (06 §6.4.4)"
dart run tool/lint.dart

for pkg in packages/domain packages/api_contract; do
  if has_tests "$pkg"; then
    step "test $pkg"
    (cd "$pkg" && dart test -r failures-only)
  fi
done

if has_tests apps/server; then
  step "test apps/server (PostgreSQL)"
  "$ROOT/tool/test_db.sh" ensure
  (cd apps/server && dart test -r failures-only --concurrency=1)
fi

if has_tests apps/mobile; then
  step "test apps/mobile (unit, widget, câu chữ, sync_e2e$([ "$(uname -s)" = "Linux" ] && echo ', golden'))"
  "$ROOT/tool/test_db.sh" ensure
  if [ "$(uname -s)" = "Linux" ]; then
    (cd apps/mobile && flutter test -r failures-only)
  else
    (cd apps/mobile && flutter test -r failures-only --exclude-tags golden)
  fi
fi

# Test Swift của widget (06 Bản 3 ED3-14) trên Mac; CI chạy ở job Mac riêng.
if [ "$(uname -s)" = "Darwin" ] && [ -z "${CI:-}" ] && command -v xcodebuild >/dev/null; then
  step "test Swift của widget (IronlyWidgetsTests, simulator)"
  # Ảnh chụp widget so theo bản iOS: ưu tiên simulator iPhone đang bật, rồi
  # iPhone của bản iOS mới nhất.
  SIM="${ITEST_DEVICE:-$(xcrun simctl list -j devices available | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [(rt, d) for rt, ds in devices.items() if "iOS" in rt for d in ds if d["name"].startswith("iPhone")]
booted = [d for _, d in phones if d["state"] == "Booted"]
latest = sorted(phones, key=lambda p: [int(x) for x in p[0].rsplit("iOS-", 1)[-1].split("-")])
print((booted or [latest[-1][1]])[0]["udid"])')}"
  LOG="$(mktemp)"
  if ! xcodebuild test -quiet -project apps/mobile/ios/Runner.xcodeproj -scheme IronlyWidgets \
    -destination "platform=iOS Simulator,id=$SIM" >"$LOG" 2>&1; then
    tail -40 "$LOG"
    exit 1
  fi
  echo "IronlyWidgetsTests: OK"
fi

printf '\n\033[1;32mcheck.sh: tất cả đều xanh\033[0m\n'
