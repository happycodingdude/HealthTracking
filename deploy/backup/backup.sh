#!/bin/sh
# Sao lưu database (05 §6.13.4): pg_dump -Fc | age (khóa công khai) | rclone rcat.
# Giữ 7 bản ngày, 4 bản tuần (chủ nhật), 6 bản tháng (ngày 1). Xong thì gọi heartbeat.
#   backup.sh loop   chờ tới BACKUP_AT (giờ TZ) mỗi ngày rồi sao lưu (mặc định của container)
#   backup.sh now    sao lưu ngay (thử tay: docker compose run --rm backup now)
# Biến: DATABASE_URL, AGE_PUBLIC_KEY, BACKUP_REMOTE (đường dẫn rclone, ví dụ gdrive:ironly-backup;
# trống → không sao lưu, chỉ ghi log), BACKUP_HEARTBEAT_URL (tùy chọn), RCLONE_CONFIG_* (cấu hình remote).
set -eu

log() { printf '{"ts":"%s","event":"%s"%s}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${2:-}"; }

prune() { # prune <thư mục> <số bản giữ>
  rclone lsf "$BACKUP_REMOTE/$1" 2>/dev/null | sort | head -n -"$2" | while read -r f; do
    [ -n "$f" ] && rclone deletefile "$BACKUP_REMOTE/$1/$f" && log backup_pruned ",\"file\":\"$1/$f\""
  done
}

run_backup() {
  if [ -z "${BACKUP_REMOTE:-}" ]; then
    log backup_disabled ',"reason":"BACKUP_REMOTE trống"'
    return 0
  fi
  : "${AGE_PUBLIC_KEY:?Thiếu AGE_PUBLIC_KEY}" "${DATABASE_URL:?Thiếu DATABASE_URL}"
  name="ironly-$(date +%Y%m%d-%H%M%S).dump.age"
  if pg_dump --format=custom "$DATABASE_URL" | age -r "$AGE_PUBLIC_KEY" | rclone rcat "$BACKUP_REMOTE/daily/$name"; then
    log backup_done ",\"file\":\"daily/$name\""
  else
    log backup_failed
    return 1
  fi
  [ "$(date +%u)" = 7 ] && rclone copyto "$BACKUP_REMOTE/daily/$name" "$BACKUP_REMOTE/weekly/$name"
  [ "$(date +%d)" = 01 ] && rclone copyto "$BACKUP_REMOTE/daily/$name" "$BACKUP_REMOTE/monthly/$name"
  prune daily 7
  prune weekly 4
  prune monthly 6
  if [ -n "${BACKUP_HEARTBEAT_URL:-}" ]; then
    curl -fsS --max-time 10 "$BACKUP_HEARTBEAT_URL" >/dev/null && log heartbeat_sent || log heartbeat_failed
  fi
}

case "${1:-loop}" in
  now) run_backup ;;
  loop)
    log backup_scheduler_started ",\"at\":\"$BACKUP_AT\",\"tz\":\"$TZ\""
    while :; do
      now=$(date +%s)
      next=$(date -d "$(date +%Y-%m-%d) $BACKUP_AT" +%s)
      [ "$next" -le "$now" ] && next=$((next + 86400))
      sleep $((next - now))
      run_backup || true
    done
    ;;
  *) echo "usage: backup.sh loop|now" >&2; exit 2 ;;
esac
