# Nạp biến môi trường dev từ file .env ở gốc repo. File này không có trong git;
# danh sách biến cần có ghi trong docs/runbook.md. Biến đã có sẵn trong môi
# trường (ví dụ trên CI) được giữ nguyên. Các script trong tool/ source file này
# sau khi đặt ROOT.
if [ -f "$ROOT/.env" ]; then
  while IFS='=' read -r key value || [ -n "$key" ]; do
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    value="${value%$'\r'}"
    value="${value#\"}"; value="${value%\"}"
    [ -n "${!key:-}" ] || export "$key=$value"
  done <"$ROOT/.env"
fi

# dev_env_require TÊN...: dừng script nếu thiếu biến.
dev_env_require() {
  local name
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      echo "Thiếu $name: ghi vào file .env ở gốc repo (danh sách biến: docs/runbook.md)." >&2
      exit 1
    fi
  done
}

# dev_db_url DATABASE: URL tới database dev (deploy/docker-compose.dev.yml, cổng
# 55432). Gọi dev_env_require POSTGRES_USER POSTGRES_PASSWORD trước.
dev_db_url() {
  printf 'postgres://%s:%s@localhost:55432/%s' "$POSTGRES_USER" "$POSTGRES_PASSWORD" "$1"
}
