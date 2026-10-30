#!/usr/bin/env bash
# Hàng rào đường dẫn Bản 4 (06 Bản 4 ED4-02, 05 Bản 4 AP-15): trên nhánh v4,
# diff so với main không được đụng domain, server, data (Drift, SyncEngine),
# contract. Chạy trong check.sh và CI; muốn vượt phải STOP và báo Bạn (IR4-03).
#   tool/check_protected_paths.sh [<base>]   mặc định base = main (hoặc origin/main)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PROTECTED=(
  packages/domain/
  apps/server/
  apps/mobile/lib/data/
  packages/api_contract/
)
# Chỉ áp dụng cho nhánh Bản 4; main và nhánh khác không bị chặn.
BRANCH="${GITHUB_HEAD_REF:-$(git branch --show-current 2>/dev/null || true)}"
case "$BRANCH" in
  v4|v4/*|v4-*) ;;
  *) echo "check_protected_paths: bỏ qua (nhánh '$BRANCH' không phải v4)"; exit 0 ;;
esac
BASE="${1:-}"
if [ -z "$BASE" ]; then
  if git rev-parse --verify -q main >/dev/null; then BASE=main
  elif git rev-parse --verify -q origin/main >/dev/null; then BASE=origin/main
  else echo "check_protected_paths: không tìm thấy main" >&2; exit 2; fi
fi
MERGE_BASE="$(git merge-base "$BASE" HEAD)"
# Diff từ điểm tách + thay đổi đang có trong cây làm việc.
CHANGED="$( { git diff --name-only "$MERGE_BASE" HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u)"
HITS=""
for p in "${PROTECTED[@]}"; do
  H="$(printf '%s\n' "$CHANGED" | grep -E "^$p" || true)"
  [ -n "$H" ] && HITS="$HITS$H"$'\n'
done
if [ -n "$HITS" ]; then
  echo "check_protected_paths: nhánh v4 đụng đường dẫn bảo vệ (AP-15, IR4-03):" >&2
  printf '%s' "$HITS" >&2
  exit 1
fi
echo "check_protected_paths: OK (không đụng domain / server / data / contract)"
