#!/usr/bin/env bash
# Kiểm tra file .ipa trước khi phát hành:
#  - TAC-06: không chứa khóa API AI, khóa ký JWT hay bí mật server.
#  - ED-17: không có ngoại lệ mạng cục bộ của flavor dev.
# Dùng: tool/scan_ipa.sh <file.ipa>
set -euo pipefail
IPA="${1:?Thiếu đường dẫn .ipa}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP" ] || { echo "Không tìm thấy Payload/*.app trong $IPA" >&2; exit 1; }
FAIL=0

# Mẫu bí mật cố định + giá trị thật trong các file .env của server (nếu có trên máy).
PATTERNS=('sk-ant-' 'ANTHROPIC_API_KEY' 'JWT_SECRET' 'BEGIN PRIVATE KEY' 'DATABASE_URL')
for env in "$ROOT/apps/server/.env" "$ROOT/deploy/.env"; do
  [ -f "$env" ] || continue
  while IFS='=' read -r key value; do
    case "$key" in JWT_SECRET|ANTHROPIC_API_KEY|YOUTUBE_API_KEY|OPENAI_API_KEY) [ ${#value} -ge 16 ] && PATTERNS+=("$value") ;; esac
  done < <(grep -E '^(JWT_SECRET|ANTHROPIC_API_KEY|YOUTUBE_API_KEY|OPENAI_API_KEY)=' "$env" || true)
done
for p in "${PATTERNS[@]}"; do
  if grep -r -a -l -F -- "$p" "$WORK" >/dev/null 2>&1; then
    echo "TAC-06: tìm thấy bí mật trong .ipa (mẫu: ${p:0:12}…)" >&2
    FAIL=1
  fi
done

# ED-17: Info.plist của bản phát hành không được có ngoại lệ mạng cục bộ.
INFO="$APP/Info.plist"
for key in NSAllowsLocalNetworking NSLocalNetworkUsageDescription NSBonjourServices NSAllowsArbitraryLoads; do
  if plutil -convert xml1 -o - "$INFO" | grep -q "<key>$key</key>"; then
    echo "ED-17: Info.plist của bản phát hành có $key" >&2
    FAIL=1
  fi
done

# TAC3-11: không có file khóa .p8 trong .ipa (khóa YouTube dò bằng giá trị thật ở trên).
if find "$WORK" -name '*.p8' | grep -q .; then
  echo "TAC3-11: .ipa có file .p8" >&2
  FAIL=1
fi

# 06 Bản 3 VS39-T01, TAC3-11: có extension widget; extension không có
# entitlement mạng.
APPEX="$APP/PlugIns/IronlyWidgets.appex"
if [ ! -d "$APPEX" ]; then
  echo "VS39-T01: thiếu PlugIns/IronlyWidgets.appex" >&2
  FAIL=1
else
  NETWORK_ENTITLEMENTS="$(codesign -d --entitlements :- "$APPEX" 2>/dev/null \
    | plutil -convert xml1 -o - - 2>/dev/null | grep -oE '<key>[^<]*network[^<]*</key>' || true)"
  if [ -n "$NETWORK_ENTITLEMENTS" ]; then
    echo "TAC3-11: extension có entitlement mạng: $NETWORK_ENTITLEMENTS" >&2
    FAIL=1
  fi
fi

[ "$FAIL" = 0 ] && echo "scan_ipa: OK ($(basename "$IPA"))"
exit "$FAIL"
