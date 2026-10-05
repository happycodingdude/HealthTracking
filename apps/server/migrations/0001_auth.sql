-- VS-01: tài khoản và phiên đăng nhập (05 §6.7.3, §6.8.4).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- UA-20: số Việt Nam 10 chữ số, bắt đầu bằng 0; mỗi số một tài khoản.
  phone         varchar(10) NOT NULL UNIQUE CHECK (phone ~ '^0[0-9]{9}$'),
  -- TD-09: bcrypt cost 12 qua pgcrypto.
  password_hash text NOT NULL,
  -- UA-21: 1–30 ký tự, đã bỏ khoảng trắng đầu/cuối.
  display_name  varchar(30) NOT NULL CHECK (char_length(display_name) >= 1 AND display_name = btrim(display_name)),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- TD-10: refresh token ngẫu nhiên 32 byte, chỉ lưu SHA-256; xoay vòng theo chuỗi (family).
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  family_id   uuid NOT NULL,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  replaced_by uuid REFERENCES refresh_tokens(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id);
CREATE INDEX refresh_tokens_expires_idx ON refresh_tokens (expires_at);
