#!/usr/bin/env bash
# Chạy toàn bộ kiểm tra như CI ở local: format → analyze → lint → test (06 §6.11).
# Golden test chỉ so sánh trên Linux (ED-09); trên macOS bị bỏ qua.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
has_tests() { [ -n "$(find "$1/test" -name '*_test.dart' 2>/dev/null | head -1)" ]; }

# PostgreSQL cho test server và test E2E đồng bộ của app (sync_e2e).
export TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgres://health:***REMOVED***@localhost:55432/postgres}"

step "pub get"
flutter pub get >/dev/null

step "format"
dart format --output=none --set-exit-if-changed packages apps/server apps/mobile/lib apps/mobile/test tool

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

printf '\n\033[1;32mcheck.sh: tất cả đều xanh\033[0m\n'
