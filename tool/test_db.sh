#!/usr/bin/env bash
# Bật PostgreSQL dev/test (deploy/docker-compose.dev.yml).
#   tool/test_db.sh ensure   bật nếu chưa chạy, chờ sẵn sàng
#   tool/test_db.sh stop     tắt
#   tool/test_db.sh reset    xóa sạch dữ liệu dev
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tool/dev_env.sh"
COMPOSE=(docker compose -f "$ROOT/deploy/docker-compose.dev.yml")

[ -n "${CI:-}" ] || dev_env_require POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB

case "${1:-ensure}" in
  ensure)
    if [ -n "${CI:-}" ]; then exit 0; fi  # CI tự bật PostgreSQL riêng (ci.yml)
    "${COMPOSE[@]}" up -d --wait db >/dev/null
    ;;
  stop)
    "${COMPOSE[@]}" down
    ;;
  reset)
    "${COMPOSE[@]}" down -v
    "${COMPOSE[@]}" up -d --wait db
    ;;
  *)
    echo "usage: $0 ensure|stop|reset" >&2
    exit 2
    ;;
esac
