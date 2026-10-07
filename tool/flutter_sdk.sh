# Chọn Flutter đúng phiên bản của dự án (environment.flutter trong
# apps/mobile/pubspec.yaml). Các script trong tool/ source file này sau khi đặt ROOT.
#
# Trên Mac: nếu gốc repo có symlink .flutter-sdk (không đưa lên git) trỏ tới SDK
# đúng phiên bản thì dùng SDK đó, không phải đổi bản Flutter dùng chung của máy:
#   ln -s ~/Desktop/Software/flutter-3.47.6 .flutter-sdk
# CI cài đúng phiên bản qua subosito/flutter-action (flutter-version-file).
if [ -x "$ROOT/.flutter-sdk/bin/flutter" ]; then
  export PATH="$ROOT/.flutter-sdk/bin:$PATH"
fi
