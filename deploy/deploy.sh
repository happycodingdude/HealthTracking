#!/usr/bin/env bash
# Triển khai production trên server (05 §6.13.3, 06 OPS-1). Chạy trong thư mục
# chứa docker-compose.yml, Caddyfile, .env (danh sách biến: docs/runbook.md §9).
#   deploy.sh --init <image>   cài lần đầu: tạo cấu trúc database từ schema.sql rồi chạy
#   deploy.sh <image>          cập nhật api lên image mới; /healthz lỗi thì quay về image trước
#   deploy.sh --rollback       quay về image trước
# Image đang chạy ghi ở .api_image, image trước ở .api_image.prev.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
[ -f .env ] || { echo "Thiếu .env (docs/runbook.md §9)" >&2; exit 1; }
API_DOMAIN="$(sed -n 's/^API_DOMAIN=//p' .env | tr -d '"' | head -1)"
[ -n "$API_DOMAIN" ] || { echo "Thiếu API_DOMAIN trong .env" >&2; exit 1; }

compose() { API_IMAGE="$1" docker compose "${@:2}"; }

healthy() {
  # Trong mạng compose trước, rồi qua Caddy (chứng chỉ, chuyển hướng).
  local i
  for i in $(seq 1 30); do
    if compose "$1" exec -T api curl -fsS http://127.0.0.1:8080/healthz 2>/dev/null | grep -q '"ok"'; then
      break
    fi
    sleep 2
  done
  [ "$i" -lt 30 ] || return 1
  for i in $(seq 1 60); do
    if curl -fsS --max-time 5 "https://$API_DOMAIN/healthz" 2>/dev/null | grep -q '"ok"'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

init_db() {
  compose "$1" up -d --wait db
  local tables
  tables="$(compose "$1" exec -T db psql -U "$(sed -n 's/^POSTGRES_USER=//p' .env)" -d "$(sed -n 's/^POSTGRES_DB=//p' .env)" -tA \
    -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")"
  if [ "$tables" != "0" ]; then
    echo "Database đã có $tables bảng, không nạp schema.sql lại."
    return 0
  fi
  echo "==> Nạp cấu trúc database từ schema.sql trong image"
  compose "$1" run --rm --no-deps --entrypoint cat api /app/db/schema.sql \
    | compose "$1" exec -T db psql -U "$(sed -n 's/^POSTGRES_USER=//p' .env)" -d "$(sed -n 's/^POSTGRES_DB=//p' .env)" -v ON_ERROR_STOP=1 -q
}

case "${1:-}" in
  --init)
    IMAGE="${2:?Thiếu image}"
    init_db "$IMAGE"
    compose "$IMAGE" up -d
    healthy "$IMAGE" || { echo "api không trả lời /healthz; xem: docker compose logs api caddy" >&2; exit 1; }
    echo "$IMAGE" > .api_image
    echo "Đã cài: https://$API_DOMAIN/healthz trả lời ok."
    ;;
  --rollback)
    [ -f .api_image.prev ] || { echo "Không có image trước để quay về" >&2; exit 1; }
    PREV="$(cat .api_image.prev)"
    compose "$PREV" up -d api
    healthy "$PREV" || { echo "Quay về $PREV nhưng /healthz vẫn lỗi" >&2; exit 1; }
    cp .api_image .api_image.prev 2>/dev/null || true
    echo "$PREV" > .api_image
    echo "Đã quay về $PREV."
    ;;
  "")
    echo "usage: deploy.sh --init <image> | <image> | --rollback" >&2; exit 2
    ;;
  *)
    IMAGE="$1"
    CURRENT="$(cat .api_image 2>/dev/null || true)"
    compose "$IMAGE" up -d
    if healthy "$IMAGE"; then
      [ -n "$CURRENT" ] && echo "$CURRENT" > .api_image.prev
      echo "$IMAGE" > .api_image
      echo "Đã cập nhật lên $IMAGE."
    else
      echo "/healthz lỗi với $IMAGE" >&2
      if [ -n "$CURRENT" ]; then
        echo "==> Quay về $CURRENT" >&2
        compose "$CURRENT" up -d api
        healthy "$CURRENT" && echo "Đã quay về $CURRENT." >&2
      fi
      exit 1
    fi
    ;;
esac
