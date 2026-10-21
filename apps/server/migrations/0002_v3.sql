-- 0002_v3: toàn bộ cấu trúc Bản 3, chỉ thêm (05 Bản 3 §6.7.3, 06 Bản 3
-- ED3-01). `lift_logs` không đổi: nấc máy lưu × 10 cùng cột với kg (TA3-05).
--
-- Giá trị enum mới phải được commit trước khi dùng (PostgreSQL: "unsafe use
-- of new value"), nên file chia hai đoạn bằng dòng `-- migrate:commit`:
-- Migrator chạy mỗi đoạn trong một transaction riêng. Đoạn đầu chạy lại được
-- (IF NOT EXISTS) nếu tiến trình dừng giữa hai đoạn.

-- nhóm cơ Chân (BR3-10)
ALTER TYPE muscle_group ADD VALUE IF NOT EXISTS 'legs';

-- migrate:commit

-- 3 vùng chân (BR3-11, TD3-19)
INSERT INTO muscle_regions (id, muscle_group, view, sort_order) VALUES
  ('quads','legs','front',17), ('hamstrings','legs','back',18), ('calves','legs','back',19)
ON CONFLICT DO NOTHING;

-- thư viện (TD3-07): vị trí trong nhóm, tombstone bài bỏ; bỏ ràng buộc dụng cụ
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS sort_in_group smallint NOT NULL DEFAULT 0;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS deleted boolean NOT NULL DEFAULT false;
ALTER TABLE exercises ALTER COLUMN equipment DROP NOT NULL;
ALTER TABLE exercises DROP CONSTRAINT IF EXISTS exercises_equipment_check;   -- "bodyweight chỉ ở bụng"
-- Tên thật của ràng buộc trên trong 0001 do PostgreSQL tự đặt.
ALTER TABLE exercises DROP CONSTRAINT IF EXISTS exercises_check;

-- đơn vị theo bài, theo tài khoản (TD3-03)
CREATE TABLE exercise_units (
  user_id uuid NOT NULL REFERENCES users(id),
  exercise_id text NOT NULL REFERENCES exercises(id),
  unit text NOT NULL CHECK (unit IN ('kg','steps')),
  changed_on date NOT NULL,
  client_updated_at timestamptz NOT NULL,
  server_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, exercise_id)
);

-- ghi chú theo bài theo buổi (TD3-06)
CREATE TABLE exercise_notes (
  user_id uuid NOT NULL,
  date date NOT NULL,
  exercise_id text NOT NULL REFERENCES exercises(id),
  text varchar(200) NOT NULL,
  logged_at timestamptz NOT NULL,
  client_updated_at timestamptz NOT NULL,
  server_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, date, exercise_id),
  FOREIGN KEY (user_id, date) REFERENCES days(user_id, date)
);

-- thẻ màn hình khóa (TD3-11)
CREATE TABLE live_activity_tokens (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  push_to_start_token text NOT NULL,
  activity_push_token text NULL,
  activity_date date NULL,
  environment text NOT NULL CHECK (environment IN ('production','sandbox')),
  app_version text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE live_activity_sessions (
  user_id uuid NOT NULL REFERENCES users(id),
  date date NOT NULL,
  started_at timestamptz NOT NULL,
  end_sent_at timestamptz NULL,
  last_error text NULL,
  PRIMARY KEY (user_id, date)
);
CREATE INDEX ON exercise_units (server_version);
CREATE INDEX ON exercise_notes (server_version);
