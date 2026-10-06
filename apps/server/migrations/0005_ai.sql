-- VS-12: thực đơn AI và kiểm soát ngân sách (05 §6.7.3, §6.9, 06 §6.5.2).

CREATE TYPE menu_attempt_status AS ENUM ('generating', 'ready', 'failed');
CREATE TYPE ai_request_status AS ENUM ('reserved', 'succeeded', 'failed', 'expired');

-- Entity `menu` (chỉ pull, key = ngày Bạn bấm tạo, F08-E5). Chỉ server ghi.
-- F08-R5: chỉ giữ thực đơn hôm nay; ngày cũ thành tombstone khi có ngày mới.
CREATE TABLE menus (
  user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date                date NOT NULL,
  -- Thực đơn hợp lệ gần nhất của ngày (05 §6.9.4). Lỗi giữ payload cũ (TAC-13).
  payload             jsonb,
  -- Mức calo dùng cho thực đơn, đã áp ngưỡng an toàn (FR-05).
  target_kcal         integer CHECK (target_kcal BETWEEN 800 AND 5000),
  used_safety_floor   boolean NOT NULL DEFAULT false,
  -- Server tự cộng, không tin con số AI trả về.
  total_kcal          integer CHECK (total_kcal > 0),
  last_attempt_status menu_attempt_status,
  last_error_code     text,
  generated_at        timestamptz,
  -- Lần tạo đang chạy bắt đầu lúc nào (TA-13, job dọn sau 10 phút).
  attempt_started_at  timestamptz,
  server_version      bigint NOT NULL,
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted             boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, date),
  CHECK ((payload IS NULL) = (total_kcal IS NULL)),
  CHECK (deleted OR (target_kcal IS NOT NULL AND last_attempt_status IS NOT NULL)),
  CHECK (last_attempt_status IS DISTINCT FROM 'generating' OR attempt_started_at IS NOT NULL)
);

CREATE INDEX menus_sync_idx ON menus (user_id, server_version);

-- Entity `ai_daily_usage` (chỉ pull, key `YYYY-MM-DD:menu`). Chỉ tăng khi tạo
-- thành công (F08-R2, F08-R3).
CREATE TABLE ai_daily_usage (
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date           date NOT NULL,
  feature        text NOT NULL CHECK (feature = 'menu' OR feature LIKE 'exercise:%'),
  success_count  smallint NOT NULL DEFAULT 0 CHECK (success_count BETWEEN 0 AND 3),
  server_version bigint NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, date, feature)
);

CREATE INDEX ai_daily_usage_sync_idx ON ai_daily_usage (user_id, server_version);

-- Ngân sách dùng chung toàn app (TR-07), tháng theo giờ Việt Nam (TA-17).
CREATE TABLE ai_budget_months (
  month         char(7) PRIMARY KEY CHECK (month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  cap_vnd       integer NOT NULL DEFAULT 50000 CHECK (cap_vnd > 0),
  used_vnd      numeric(12, 2) NOT NULL DEFAULT 0 CHECK (used_vnd >= 0),
  reserved_vnd  numeric(12, 2) NOT NULL DEFAULT 0 CHECK (reserved_vnd >= 0),
  -- F11-R4: đã báo 80% (đúng một lần trong tháng).
  warned_80_at  timestamptz,
  -- F11-R5: tháng bị chặn, mọi gợi ý AI dừng đến ngày 1 tháng sau.
  blocked_at    timestamptz
  -- F11-AC1 (không vượt trần) được bảo đảm bằng đặt trước ước tính ≥ thực tế
  -- trong transaction khóa dòng tháng (05 §6.9.3). Không đặt CHECK tổng ở
  -- đây: quyết toán chi phí thực tế phải luôn ghi được.
);

-- Sổ cái chi phí: mỗi yêu cầu AI một dòng (05 §6.9.2).
CREATE TABLE ai_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Chống trừ tiền 2 lần khi app gửi lại.
  request_id    uuid NOT NULL,
  feature       text NOT NULL,
  local_date    date NOT NULL,
  month         char(7) NOT NULL REFERENCES ai_budget_months(month),
  provider      text NOT NULL,
  model         text NOT NULL,
  status        ai_request_status NOT NULL,
  reserved_vnd  numeric(12, 2) NOT NULL CHECK (reserved_vnd >= 0),
  actual_vnd    numeric(12, 2) CHECK (actual_vnd >= 0),
  input_tokens  integer,
  output_tokens integer,
  error_code    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  settled_at    timestamptz,
  UNIQUE (user_id, request_id),
  CHECK ((status = 'reserved') = (settled_at IS NULL))
);

CREATE INDEX ai_requests_reserved_idx ON ai_requests (created_at) WHERE status = 'reserved';
CREATE INDEX ai_requests_month_idx ON ai_requests (month, created_at DESC);
