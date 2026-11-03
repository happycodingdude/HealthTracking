-- 0003_v5: toàn bộ cấu trúc Bản 5, chỉ thêm (05 Bản 5 §6.7, 06 Bản 5 ED5-01).
-- `lift_logs`, `exercise_notes`, `exercise_units` không đổi.
--
-- `DayCloser` ghi "Không tập (tự động)" lúc 00:00 (TD5-12): giá trị
-- `skipped_auto` chưa có trong `day_mark` (Bản 2 chỉ suy ra, không lưu) nên
-- thêm ở đoạn đầu; giá trị enum mới phải commit trước khi dùng nên tách đoạn
-- bằng `-- migrate:commit` (xem 0002_v3.sql). Đoạn đầu chạy lại được.
ALTER TYPE day_mark ADD VALUE IF NOT EXISTS 'skipped_auto';

-- migrate:commit

-- bài trong buổi (chỉ ghi khi đổi / bỏ qua / thêm — TD5-03, AP-20)
CREATE TABLE session_exercises (
  user_id uuid NOT NULL,
  date date NOT NULL,
  exercise_id text NOT NULL REFERENCES exercises(id),
  role text NOT NULL CHECK (role IN ('original','replacement','extra')),
  replaces_exercise_id text NULL REFERENCES exercises(id),
  position smallint NOT NULL DEFAULT 0,
  skipped boolean NOT NULL DEFAULT false,
  client_updated_at timestamptz NOT NULL,
  server_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, date, exercise_id),
  FOREIGN KEY (user_id, date) REFERENCES days(user_id, date),
  CHECK ((role = 'replacement') = (replaces_exercise_id IS NOT NULL))
);

-- mức thoải mái set cuối (TD5-04)
CREATE TABLE exercise_feels (
  user_id uuid NOT NULL,
  date date NOT NULL,
  exercise_id text NOT NULL REFERENCES exercises(id),
  feel text NOT NULL CHECK (feel IN ('easy','medium','hard')),
  client_updated_at timestamptz NOT NULL,
  server_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, date, exercise_id),
  FOREIGN KEY (user_id, date) REFERENCES days(user_id, date)
);

-- tạm dừng lịch tập (TD5-05)
CREATE TABLE schedule_pauses (
  id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES users(id),
  start_date date NOT NULL,
  end_date date NOT NULL,
  ended_on date NULL,
  client_updated_at timestamptz NOT NULL,
  server_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, id),
  CHECK (end_date >= start_date)
);

-- vị trí phòng gym, một dòng / tài khoản (TD5-06)
CREATE TABLE gym_locations (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  lat numeric(9,6) NOT NULL,
  lng numeric(9,6) NOT NULL,
  saved_at timestamptz NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  client_updated_at timestamptz NOT NULL,
  server_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);

-- cửa sổ mở sớm khi tới gym (TD5-07)
ALTER TABLE days ADD COLUMN IF NOT EXISTS opened_at timestamptz NULL;

-- thẻ: nguồn bật, loại thẻ, số lần bật lại (TD5-13, TD5-14)
ALTER TABLE live_activity_sessions ADD COLUMN IF NOT EXISTS trigger text NOT NULL DEFAULT 'time'
  CHECK (trigger IN ('time','location'));
ALTER TABLE live_activity_sessions ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'session'
  CHECK (kind IN ('session','extra'));
ALTER TABLE live_activity_sessions ADD COLUMN IF NOT EXISTS restarts smallint NOT NULL DEFAULT 0;

CREATE INDEX ON session_exercises (server_version);
CREATE INDEX ON exercise_feels (server_version);
CREATE INDEX ON schedule_pauses (server_version);
CREATE INDEX ON gym_locations (server_version);
CREATE INDEX ON schedule_pauses (user_id, start_date, end_date) WHERE NOT deleted;
