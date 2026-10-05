-- VS-02: lớp đồng bộ (05 §6.6, §6.7.1).

-- server_version lấy từ một sequence toàn cục, tăng mỗi lần ghi (05 §6.6.3).
CREATE SEQUENCE sync_version_seq;

-- Entity `account` = bảng users (chỉ display_name sửa được qua đồng bộ).
ALTER TABLE users
  ADD COLUMN server_version    bigint      NOT NULL DEFAULT nextval('sync_version_seq'),
  ADD COLUMN client_updated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN deleted           boolean     NOT NULL DEFAULT false;

-- Idempotency (TAC-03): mutation đã xử lý trả lại kết quả cũ. Dọn sau 30 ngày.
CREATE TABLE processed_mutations (
  mutation_id uuid PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  result      jsonb NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX processed_mutations_created_idx ON processed_mutations (created_at);

-- Job dọn refresh token hết hạn (VS02-T06) xóa cả token được trỏ tới qua replaced_by.
ALTER TABLE refresh_tokens
  DROP CONSTRAINT refresh_tokens_replaced_by_fkey,
  ADD CONSTRAINT refresh_tokens_replaced_by_fkey
    FOREIGN KEY (replaced_by) REFERENCES refresh_tokens(id) ON DELETE SET NULL;
