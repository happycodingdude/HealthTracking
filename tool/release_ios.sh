#!/usr/bin/env bash
# Phát hành app lên TestFlight nhóm nội bộ (06 VS00-T10, §6.11.2, IR-08).
# Chạy trên Mac của Bạn sau khi gắn tag mobile-vX.Y.Z.
#
# Biến môi trường bắt buộc:
#   API_BASE_URL     địa chỉ server production, bắt buộc https:// (05 §6.8.1)
#   ASC_KEY_ID       App Store Connect API key ID
#   ASC_ISSUER_ID    App Store Connect issuer ID
#   ASC_KEY_PATH     đường dẫn file AuthKey_<ASC_KEY_ID>.p8 (không nằm trong repo)
#   TEAM_ID          Apple Developer Team ID
# Tùy chọn: SENTRY_DSN, SKIP_INTEGRATION=1 (bỏ integration test simulator — chỉ dùng cho R0).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/flutter_sdk.sh"
: "${API_BASE_URL:?Thiếu API_BASE_URL}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}" "${TEAM_ID:?}"
case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL phải là https:// (05 §6.8.1)" >&2; exit 1 ;; esac

BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"
OUT="$ROOT/build/ios-release"
rm -rf "$OUT" && mkdir -p "$OUT"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

echo "==> 1. Kiểm tra như CI"
"$ROOT/tool/check.sh"

if [ "${SKIP_INTEGRATION:-0}" != 1 ] && [ -d "$ROOT/apps/mobile/integration_test" ]; then
  echo "==> 2. Integration test trên simulator (ED-10)"
  "$ROOT/tool/integration_test.sh"
fi

echo "==> 3. Build (flavor prod, build $BUILD_NUMBER)"
cd "$ROOT/apps/mobile"
flutter build ios --release --config-only --build-number="$BUILD_NUMBER" \
  --dart-define=FLAVOR=prod --dart-define=API_BASE_URL="$API_BASE_URL" --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$OUT/Runner.xcarchive" -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic "${AUTH[@]}" archive
xcodebuild -exportArchive -archivePath "$OUT/Runner.xcarchive" -exportPath "$OUT" \
  -exportOptionsPlist ios/ExportOptions.plist "${AUTH[@]}"
IPA="$(find "$OUT" -maxdepth 1 -name '*.ipa' | head -1)"

echo "==> 4. Quét .ipa (TAC-06, ED-17)"
"$ROOT/tool/scan_ipa.sh" "$IPA"

echo "==> 5. Tải lên TestFlight"
mkdir -p "$HOME/.appstoreconnect/private_keys"
cp "$ASC_KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "Đã tải lên build $BUILD_NUMBER. Thêm build vào nhóm TestFlight nội bộ trên App Store Connect."
