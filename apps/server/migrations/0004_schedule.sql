-- VS-04: lịch tuần, lịch tháng, ngày trong lịch (05 §6.7.3, 06 §6.5.2).

CREATE TYPE muscle_group AS ENUM ('chest', 'triceps', 'shoulders', 'abs', 'back', 'biceps');
CREATE TYPE day_kind AS ENUM ('workout', 'rest');
CREATE TYPE day_source AS ENUM ('template', 'override');
CREATE TYPE day_mark AS ENUM ('done', 'skipped');

-- Entity `weekly_template` (key `me`), 1 dòng/người dùng. `days` theo JSON
-- chuẩn hóa: khóa "1" → "6", không có chủ nhật (F03-R1).
CREATE TABLE weekly_templates (
  user_id           uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  days              jsonb NOT NULL CHECK (
                      jsonb_typeof(days) = 'object'
                      AND NOT days ?| ARRAY['0', '7']
                    ),
  content_hash      text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
  server_version    bigint NOT NULL,
  client_updated_at timestamptz NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted           boolean NOT NULL DEFAULT false
);

-- Entity `month_plan` (key `YYYY-MM`).
CREATE TABLE month_plans (
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month             char(7) NOT NULL CHECK (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  start_date        date NOT NULL,
  template_hash     text NOT NULL CHECK (template_hash ~ '^[0-9a-f]{64}$'),
  generated_at      timestamptz NOT NULL,
  redistributed_at  timestamptz,
  server_version    bigint NOT NULL,
  client_updated_at timestamptz NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted           boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, month),
  CHECK (to_char(start_date, 'YYYY-MM') = month)
);

-- Entity `day` (key `YYYY-MM-DD`), 1 dòng cho mỗi ngày thứ 2 → thứ 7 trong lịch tháng.
CREATE TABLE days (
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date              date NOT NULL CHECK (EXTRACT(ISODOW FROM date) <> 7),
  kind              day_kind NOT NULL,
  time              time,
  muscles           muscle_group[],
  source            day_source NOT NULL DEFAULT 'template',
  mark              day_mark,
  actual_muscles    muscle_group[],
  marked_at         timestamptz,
  extra_muscles     muscle_group[],
  extra_logged_at   timestamptz,
  server_version    bigint NOT NULL,
  client_updated_at timestamptz NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted           boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, date),
  -- Ngày tập ⇔ có giờ và ≥ 1 nhóm cơ; ngày nghỉ không có giờ, nhóm cơ.
  CHECK (kind = 'rest' OR (time IS NOT NULL AND coalesce(cardinality(muscles), 0) >= 1)),
  CHECK (kind = 'workout' OR (time IS NULL AND muscles IS NULL)),
  -- Buổi tập thêm chỉ ở ngày nghỉ; đánh dấu chỉ ở ngày tập.
  CHECK (extra_muscles IS NULL OR (kind = 'rest' AND coalesce(cardinality(extra_muscles), 0) >= 1)),
  CHECK (mark IS NULL OR kind = 'workout'),
  CHECK (actual_muscles IS NULL OR mark = 'done')
);

CREATE INDEX month_plans_sync_idx ON month_plans (user_id, server_version);
CREATE INDEX days_sync_idx ON days (user_id, server_version);
