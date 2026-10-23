#!/usr/bin/env bash
# Gắn quyền (entitlements) vào bản archive không ký trước bước export ký phân
# phối (06 Bản 3 VS42-T07, TD3-22). Archive chạy với CODE_SIGNING_ALLOWED=NO
# (team chưa đăng ký iPhone nên không có hồ sơ development, runbook §4), nên
# không có chữ ký mang quyền; export ký lại từ quyền của chữ ký cũ, thiếu thì
# app mất App Group, aps-environment → widget, thẻ màn hình khóa không chạy.
# Script ký tạm (ad-hoc) app và extension kèm quyền của cấu hình Release đã thay
# giá trị biến, rồi export ký lại bằng chứng chỉ phân phối.
# Dùng: tool/archive_entitlements.sh <Runner.xcarchive>   (chạy trong apps/mobile)
set -euo pipefail
ARCHIVE="${1:?Thiếu đường dẫn .xcarchive}"
APP="$ARCHIVE/Products/Applications/Runner.app"
[ -d "$APP" ] || { echo "Không thấy $APP" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SETTINGS="$(xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -showBuildSettings 2>/dev/null)"
APS="$(sed -n 's/^ *IRONLY_APS_ENVIRONMENT = //p' <<<"$SETTINGS" | head -1)"
GROUP="$(sed -n 's/^ *IRONLY_APP_GROUP = //p' <<<"$SETTINGS" | head -1)"
[ -n "$APS" ] && [ -n "$GROUP" ] || { echo "Không đọc được IRONLY_APS_ENVIRONMENT / IRONLY_APP_GROUP" >&2; exit 1; }
resolve() {
  sed -e "s/\$(IRONLY_APS_ENVIRONMENT)/$APS/" -e "s/\$(IRONLY_APP_GROUP)/$GROUP/" "$1" >"$2"
}
resolve ios/Runner/Runner.entitlements "$WORK/runner.entitlements"
resolve ios/IronlyWidgets/IronlyWidgets.entitlements "$WORK/widgets.entitlements"

# Ký từ trong ra ngoài: framework, extension, rồi app.
find "$APP/Frameworks" -maxdepth 1 \( -name '*.framework' -o -name '*.dylib' \) \
  -exec codesign --force --sign - {} \; 2>/dev/null
codesign --force --sign - --entitlements "$WORK/widgets.entitlements" "$APP/PlugIns/IronlyWidgets.appex" 2>/dev/null
codesign --force --sign - --entitlements "$WORK/runner.entitlements" "$APP" 2>/dev/null
echo "Đã gắn quyền: aps-environment=$APS, App Group=$GROUP"
