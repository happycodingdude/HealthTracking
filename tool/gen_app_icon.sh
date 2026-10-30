#!/usr/bin/env bash
# Sinh icon app từ apps/mobile/design/app_icon.svg (05 Bản 4 TD4-09, §6.7):
# một PNG 1024 cho AppIcon (prod) và một cho AppIcon-Dev (dải "DEV" góc dưới),
# Xcode tự co các cỡ còn lại. Cần rsvg-convert (brew install librsvg).
#   tool/gen_app_icon.sh           ghi PNG
#   tool/gen_app_icon.sh --check   so sánh với file đang có; khác → exit 1
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/apps/mobile/design/app_icon.svg"
ASSETS="$ROOT/apps/mobile/ios/Runner/Assets.xcassets"
CHECK="${1:-}"
command -v rsvg-convert >/dev/null || { echo "gen_app_icon: cần rsvg-convert (brew install librsvg)" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Flavor dev: cùng SVG + dải "DEV" (ED-15), chèn trước </svg>.
sed 's#</svg>#  <rect x="0" y="824" width="1024" height="200" fill="\#FF6A1A"/>\n  <text x="512" y="968" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="700" font-size="150" fill="\#1A1A1A">DEV</text>\n</svg>#' "$SRC" > "$TMP/app_icon_dev.svg"

render() { # svg out
  rsvg-convert -w 1024 -h 1024 --background-color='#1A1A1A' "$1" > "$2"
}
write_contents() { # dir
  cat > "$1/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "tool/gen_app_icon.sh",
    "version" : 1
  }
}
JSON
}

STATUS=0
for set in AppIcon AppIcon-Dev; do
  DIR="$ASSETS/$set.appiconset"
  if [ "$set" = AppIcon ]; then render "$SRC" "$TMP/$set.png"; else render "$TMP/app_icon_dev.svg" "$TMP/$set.png"; fi
  if [ "$CHECK" = "--check" ]; then
    if ! cmp -s "$TMP/$set.png" "$DIR/icon-1024.png"; then
      echo "gen_app_icon: $set.appiconset/icon-1024.png không khớp app_icon.svg" >&2
      STATUS=1
    fi
  else
    mkdir -p "$DIR"
    # Chỉ giữ một cỡ 1024 (Xcode 14+ tự sinh các cỡ).
    find "$DIR" -name 'Icon-App-*.png' -delete
    cp "$TMP/$set.png" "$DIR/icon-1024.png"
    write_contents "$DIR"
    echo "gen_app_icon: đã ghi $set.appiconset/icon-1024.png"
  fi
done
[ "$CHECK" = "--check" ] && [ "$STATUS" = 0 ] && echo "gen_app_icon: OK (icon khớp app_icon.svg)"
exit "$STATUS"
