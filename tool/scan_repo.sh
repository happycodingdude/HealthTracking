#!/usr/bin/env bash
# Kiểm tra mọi file git đang theo dõi (không chỉ phần đang stage):
#  - không có file env, file mẫu (.example, .sample, .template), khóa và hồ sơ ký iOS,
#    config dev/prod, khóa giải mã sao lưu, tài liệu dự án;
#  - không có chuỗi giống khóa thật.
# Tên biến môi trường và cấu hình ký app cần có ghi trong docs/runbook.md.
# Dùng: tool/scan_repo.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAIL=0

FORBIDDEN_FILES='(^|/)\.env($|\.)|\.(example|sample|template)$|\.(p8|p12|mobileprovision|agekey)$|(^|/)\.sentryclirc$|(^|/)age-key|(^|/)dart[-_]define[^/]*\.json$|(^|/)config\.(dev|prod)\.|(^|/)Signing\.xcconfig$|^docs/|(^|/)CLAUDE\.md$'
if hits="$(git ls-files | grep -E "$FORBIDDEN_FILES")"; then
  echo "scan_repo: file không được có trong git:" >&2
  printf '  %s\n' $hits >&2
  FAIL=1
fi

# Khóa API (Anthropic và dạng sk-, Google), khóa riêng PEM. Chỉ in tên file, không in giá trị.
KEY_PATTERN='(^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
if hits="$(git grep -lIE -e "$KEY_PATTERN" -- . ':!*.lock')"; then
  echo "scan_repo: có chuỗi giống khóa trong:" >&2
  printf '  %s\n' $hits >&2
  FAIL=1
fi

[ "$FAIL" = 0 ] && echo "scan_repo: OK ($(git ls-files | wc -l | tr -d ' ') file)"
exit "$FAIL"
