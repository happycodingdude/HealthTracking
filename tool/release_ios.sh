#!/usr/bin/env bash
# Phát hành app lên TestFlight nhóm nội bộ (06 VS00-T10, §6.11.2, IR-08).
# Chạy trên Mac của Bạn: tool/release_ios.sh
#
# Biến môi trường, đọc từ .env ở gốc repo (tool/dev_env.sh; danh sách: docs/runbook.md §8):
#   API_BASE_URL     địa chỉ server production, bắt buộc https:// (05 §6.8.1)
#   ASC_KEY_ID       App Store Connect API key ID (dùng để kiểm tra và tải lên)
#   ASC_ISSUER_ID    App Store Connect issuer ID
#   ASC_KEY_PATH     đường dẫn file AuthKey_<ASC_KEY_ID>.p8, nằm ngoài repo; đọc tại chỗ, không chép
#   TEAM_ID          Apple Developer Team ID
# Tùy chọn: SENTRY_DSN, ITEST_DEVICE (id simulator cho integration test),
#   SKIP_INTEGRATION=1 (bỏ integration test simulator — chỉ dùng cho R0).
# Xcode phải đăng nhập Apple ID chủ team (Xcode → Settings → Accounts) để ký bản phát hành.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
source "$ROOT/tool/dev_env.sh"
dev_env_require API_BASE_URL ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH TEAM_ID
case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL phải là https:// (05 §6.8.1)" >&2; exit 1 ;; esac
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[ -f "$ASC_KEY_PATH" ] || { echo "Không thấy file khóa ASC_KEY_PATH" >&2; exit 1; }
case "$(cd "$(dirname "$ASC_KEY_PATH")" && pwd -P)/" in
  "$(cd "$ROOT" && pwd -P)"/*) echo "File khóa .p8 phải nằm ngoài repo" >&2; exit 1 ;;
esac
# Build phải khớp đúng commit hiện tại (số build = số commit).
if [ -n "$(git -C "$ROOT" status --porcelain -- apps packages data pubspec.yaml pubspec.lock)" ]; then
  echo "Code app còn thay đổi chưa commit" >&2; exit 1
fi
if ! defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null | grep -q 'identifier'; then
  echo "Xcode chưa đăng nhập Apple ID: Xcode → Settings → Accounts → +" >&2; exit 1
fi

BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"
OUT="$ROOT/build/ios-release"
rm -rf "$OUT" && mkdir -p "$OUT"
ALTOOL_AUTH=(--api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH")

echo "==> 1. Kiểm tra như CI"
"$ROOT/tool/check.sh"

if [ "${SKIP_INTEGRATION:-0}" != 1 ] && [ -d "$ROOT/apps/mobile/integration_test" ]; then
  echo "==> 2. Integration test trên simulator (ED-10)"
  "$ROOT/tool/integration_test.sh" ${ITEST_DEVICE:+-d "$ITEST_DEVICE"}
fi

echo "==> 3. Build (flavor prod, build $BUILD_NUMBER)"
cd "$ROOT/apps/mobile"
flutter build ios --release --config-only --build-number="$BUILD_NUMBER" \
  --dart-define=FLAVOR=prod --dart-define=API_BASE_URL="$API_BASE_URL" --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"
# Archive không ký; bước export ký bằng chứng chỉ phân phối do Apple giữ (cloud-managed),
# qua tài khoản Account Holder đăng nhập trong Xcode. Ký lúc archive (tự động) đòi hồ sơ
# development, mà hồ sơ đó cần ít nhất một iPhone đã đăng ký với team.
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$OUT/Runner.xcarchive" -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGNING_ALLOWED=NO archive
cp ios/ExportOptions.plist "$OUT/ExportOptions.plist"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$OUT/ExportOptions.plist"
xcodebuild -exportArchive -archivePath "$OUT/Runner.xcarchive" -exportPath "$OUT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates
IPA="$(find "$OUT" -maxdepth 1 -name '*.ipa' | head -1)"

echo "==> 4. Quét .ipa (TAC-06, ED-17)"
"$ROOT/tool/scan_ipa.sh" "$IPA"

echo "==> 5. Tải lên TestFlight"
xcrun altool --validate-app "$IPA" "${ALTOOL_AUTH[@]}"
xcrun altool --upload-package "$IPA" "${ALTOOL_AUTH[@]}"
echo "Đã tải lên build $BUILD_NUMBER. Apple xử lý xong (khoảng 5–30 phút) thì build hiện ở nhóm TestFlight nội bộ."
