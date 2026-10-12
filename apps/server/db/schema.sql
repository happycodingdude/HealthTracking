-- Cấu trúc database server trong lúc dev (05 Bản 1 v1.1 §6.7.5, 06 Bản 2
-- IR2-13, ED2-18): nguồn duy nhất, sửa thẳng file này; tạo lại database dev
-- bằng tool/reset_dev_db.sh. Bản phát hành đầu tiên có dữ liệu thật đóng băng
-- file này thành migrations/0001_baseline.sql; từ đó mọi thay đổi là migration
-- đánh số, chỉ thêm.
--
-- Phần 1 — Bản 1 (trước đây là migration 0001 → 0005).
-- Phần 2 — Bản 2 (05 Bản 2 §6.7.3, đặt một lần ở VS-20, ED2-20).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- server_version lấy từ một sequence toàn cục, tăng mỗi lần ghi (05 §6.6.3).
-- Dòng dùng chung (thư viện, hình món ăn) cũng lấy từ đây (05 Bản 2 §6.6.1).
CREATE SEQUENCE sync_version_seq;

-- ============================================================================
-- Phần 1 — Bản 1
-- ============================================================================

-- VS-01: tài khoản và phiên đăng nhập (05 §6.7.3, §6.8.4).
-- Entity `account` = bảng users (chỉ display_name sửa được qua đồng bộ, VS-02).
CREATE TABLE users (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- UA-20: số Việt Nam 10 chữ số, bắt đầu bằng 0; mỗi số một tài khoản.
  phone             varchar(10) NOT NULL UNIQUE CHECK (phone ~ '^0[0-9]{9}$'),
  -- TD-09: bcrypt cost 12 qua pgcrypto.
  password_hash     text NOT NULL,
  -- UA-21: 1–30 ký tự, đã bỏ khoảng trắng đầu/cuối.
  display_name      varchar(30) NOT NULL CHECK (char_length(display_name) >= 1 AND display_name = btrim(display_name)),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  server_version    bigint      NOT NULL DEFAULT nextval('sync_version_seq'),
  client_updated_at timestamptz NOT NULL DEFAULT now(),
  deleted           boolean     NOT NULL DEFAULT false
);

-- TD-10: refresh token ngẫu nhiên 32 byte, chỉ lưu SHA-256; xoay vòng theo chuỗi (family).
-- Job dọn token hết hạn (VS02-T06) xóa cả token được trỏ tới qua replaced_by.
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  family_id   uuid NOT NULL,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  replaced_by uuid REFERENCES refresh_tokens(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id);
CREATE INDEX refresh_tokens_expires_idx ON refresh_tokens (expires_at);

-- VS-02: idempotency (TAC-03): mutation đã xử lý trả lại kết quả cũ. Dọn sau 30 ngày.
CREATE TABLE processed_mutations (
  mutation_id uuid PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  result      jsonb NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX processed_mutations_created_idx ON processed_mutations (created_at);

-- VS-03: hồ sơ, mức calo và cân nặng (05 §6.7.3, 06 §6.5.2).
CREATE TYPE sex AS ENUM ('male', 'female');
CREATE TYPE activity_level AS ENUM ('sedentary', 'light', 'moderate', 'active', 'very_active');
CREATE TYPE calorie_mode AS ENUM ('auto', 'manual');
CREATE TYPE calorie_pending_reason AS ENUM ('weight', 'profile');

-- Entity `profile` (key `me`), 1 dòng/người dùng. Trường của bước chưa làm tới là NULL.
CREATE TABLE profiles (
  user_id                 uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  -- F01-V1.
  height_cm               smallint CHECK (height_cm BETWEEN 120 AND 230),
  -- F01-V2 kiểm tra lúc nhập (theo năm hiện tại); ở đây chỉ chặn giá trị vô lý.
  birth_year              smallint CHECK (birth_year BETWEEN 1900 AND 2100),
  sex                     sex,
  activity_level          activity_level,
  -- Ghi một lần (05 Bản 2 TA2-11): server bỏ qua mọi lần ghi đè sau đó.
  setup_date              date,
  -- Bản 2 (05 Bản 2 §6.6.5): ngày lưu lịch tuần lần đầu của tài khoản đã
  -- "Để sau" lịch tuần. Tài khoản Bản 1 để trống, mốc tiến độ dùng setup_date.
  schedule_started_on     date,
  -- OB-3, OB-6: bước đang dở.
  onboarding_step         smallint NOT NULL CHECK (onboarding_step BETWEEN 1 AND 5),
  disclaimer_accepted_at  timestamptz,
  onboarding_completed_at timestamptz,
  calorie_mode            calorie_mode,
  calorie_kcal            integer CHECK (calorie_kcal BETWEEN 800 AND 7000),
  calorie_pending_kcal    integer CHECK (calorie_pending_kcal BETWEEN 1200 AND 7000),
  calorie_pending_reason  calorie_pending_reason,
  reminders_enabled       boolean NOT NULL DEFAULT false,
  timezone                text CHECK (char_length(timezone) BETWEEN 1 AND 64),
  server_version          bigint NOT NULL,
  client_updated_at       timestamptz NOT NULL,
  updated_at              timestamptz NOT NULL DEFAULT now(),
  deleted                 boolean NOT NULL DEFAULT false,
  -- F10-AC1: qua bước 1 phải đã bấm "Tôi đã hiểu".
  CHECK (onboarding_step = 1 OR disclaimer_accepted_at IS NOT NULL),
  -- Qua bước 2 phải đủ thông tin cơ thể.
  CHECK (onboarding_step <= 2 OR (height_cm IS NOT NULL AND birth_year IS NOT NULL AND sex IS NOT NULL AND activity_level IS NOT NULL)),
  -- Qua bước 3 phải có mức calo.
  CHECK (onboarding_step <= 3 OR (calorie_mode IS NOT NULL AND calorie_kcal IS NOT NULL)),
  -- F02-V1: mức Bạn tự đặt 800–5.000 kcal.
  CHECK (calorie_mode IS DISTINCT FROM 'manual' OR calorie_kcal BETWEEN 800 AND 5000),
  -- F02-R9: đề xuất đang chờ chỉ có ở chế độ Bạn tự đặt, đủ cả số và lý do.
  CHECK ((calorie_pending_kcal IS NULL) = (calorie_pending_reason IS NULL)),
  CHECK (calorie_pending_kcal IS NULL OR calorie_mode = 'manual'),
  CHECK (onboarding_completed_at IS NULL OR (onboarding_step = 5 AND setup_date IS NOT NULL)),
  -- "Chưa có lịch" chỉ có sau khi đã hoàn tất thiết lập (03 Bản 2 §6.1, TD2-09).
  CHECK (schedule_started_on IS NULL OR onboarding_completed_at IS NOT NULL)
);

-- Entity `weight` (key = thứ 2 của tuần), tối đa 1 số cân mỗi tuần (FR-11).
CREATE TABLE weights (
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  week_start        date NOT NULL CHECK (EXTRACT(ISODOW FROM week_start) = 1),
  -- F07-V1: 30–250 kg, lưu kg × 10. NULL khi đã xóa (tombstone).
  weight_kg_x10     smallint CHECK (weight_kg_x10 BETWEEN 300 AND 2500),
  server_version    bigint NOT NULL,
  client_updated_at timestamptz NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted           boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, week_start),
  CHECK (deleted OR weight_kg_x10 IS NOT NULL)
);

CREATE INDEX weights_sync_idx ON weights (user_id, server_version);

-- VS-04: lịch tuần, lịch tháng, ngày trong lịch (05 §6.7.3, 06 §6.5.2).
CREATE TYPE muscle_group AS ENUM ('chest', 'triceps', 'shoulders', 'abs', 'back', 'biceps');
CREATE TYPE day_kind AS ENUM ('workout', 'rest');
CREATE TYPE day_source AS ENUM ('template', 'override');
CREATE TYPE day_mark AS ENUM ('done', 'skipped');

-- Entity `weekly_template` (key `me`), 1 dòng/người dùng. `days` theo JSON
-- chuẩn hóa: khóa "1" → "6", không có chủ nhật (F03-R1). Bản 2: không có dòng
-- nào = "Chưa có lịch" (TD2-09).
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
-- Bản 2 không đổi cấu trúc, chỉ đổi cách ghi (05 Bản 2 §6.7.4): "Đã tập" và
-- buổi tập thêm là bất biến (AP-8), kiểm ở packages/domain.
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

-- Entity `ai_daily_usage` (chỉ pull, key `YYYY-MM-DD:<feature>`). Chỉ tăng khi
-- tạo thành công (F08-R2, F08-R3). Bản 2: thêm lượt hình món ăn (F12-R4); bỏ
-- lượt gợi ý bài tập của kế hoạch cũ (F-14 bị bỏ, TD2-13).
CREATE TABLE ai_daily_usage (
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date           date NOT NULL,
  feature        text NOT NULL CHECK (feature IN ('menu', 'dish_image')),
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

-- Sổ cái chi phí: mỗi yêu cầu AI một dòng (05 §6.9.2). Bản 2 (05 Bản 2
-- §6.7.3): thêm loại hình món ăn và soạn hướng dẫn, nhà cung cấp OpenAI và
-- ghi tay (`admin ai-cost add`), `name_key` chống tạo trùng hình (§6.9.2).
CREATE TABLE ai_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Chống trừ tiền 2 lần khi app gửi lại.
  request_id    uuid NOT NULL,
  feature       text NOT NULL CHECK (feature IN ('menu', 'dish_image', 'exercise_guide')),
  local_date    date NOT NULL,
  month         char(7) NOT NULL REFERENCES ai_budget_months(month),
  provider      text NOT NULL CHECK (provider IN ('anthropic', 'openai', 'manual', 'fake')),
  model         text NOT NULL,
  status        ai_request_status NOT NULL,
  reserved_vnd  numeric(12, 2) NOT NULL CHECK (reserved_vnd >= 0),
  actual_vnd    numeric(12, 2) CHECK (actual_vnd >= 0),
  input_tokens  integer,
  output_tokens integer,
  error_code    text,
  name_key      text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  settled_at    timestamptz,
  UNIQUE (user_id, request_id),
  CHECK ((status = 'reserved') = (settled_at IS NULL))
);

CREATE INDEX ai_requests_reserved_idx ON ai_requests (created_at) WHERE status = 'reserved';
CREATE INDEX ai_requests_month_idx ON ai_requests (month, created_at DESC);
CREATE INDEX ai_requests_name_key_idx ON ai_requests (name_key) WHERE status = 'reserved';

-- ============================================================================
-- Phần 2 — Bản 2 (05 Bản 2 §6.7.3)
-- ============================================================================

-- (a) Hình món ăn (F-12). Dòng dùng chung, không có user_id (AP-7); không bao
-- giờ xóa (FA2-16). File nằm ở volume `images`: `dish/{id}.jpg` (TD2-10).
CREATE TABLE dish_images (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Tên món chuẩn hóa: NFC, chữ thường, cắt và gộp khoảng trắng (FA2-07, ED2-06).
  name_key       text NOT NULL UNIQUE CHECK (char_length(name_key) >= 1 AND name_key = btrim(name_key)),
  display_name   text NOT NULL,
  file_path      text NOT NULL,
  width          integer NOT NULL CHECK (width > 0),
  height         integer NOT NULL CHECK (height > 0),
  bytes          integer NOT NULL CHECK (bytes > 0),
  provider       text NOT NULL,
  model          text NOT NULL,
  quality        text NOT NULL,
  -- Tài khoản bấm tạo, chỉ để truy vết (05 Bản 2 §6.7.3).
  created_by     uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  server_version bigint NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX dish_images_sync_idx ON dish_images (server_version);

-- (b) Thư viện bài tập và mức tạ (F-18 → F-21).
CREATE TYPE body_view AS ENUM ('front', 'back');
CREATE TYPE equipment AS ENUM ('machine', 'free_weight', 'bodyweight');

-- 16 vùng cơ, nạp sẵn (05 Bản 2 §6.10.4). Bảng tra thay vì enum để thêm vùng
-- sau này không phải sửa kiểu dữ liệu (§6.7.1).
CREATE TABLE muscle_regions (
  id           text PRIMARY KEY CHECK (id ~ '^[a-z_]+$'),
  muscle_group muscle_group NOT NULL,
  view         body_view NOT NULL,
  sort_order   smallint NOT NULL UNIQUE,
  -- Cho khóa ngoại (vùng, nhóm) của exercises: vùng phải đúng nhóm cơ.
  UNIQUE (id, muscle_group)
);

INSERT INTO muscle_regions (id, muscle_group, view, sort_order) VALUES
  ('chest_upper',            'chest',     'front',  1),
  ('chest_mid',              'chest',     'front',  2),
  ('chest_lower',            'chest',     'front',  3),
  ('lats',                   'back',      'back',   4),
  ('back_mid',               'back',      'back',   5),
  ('back_lower',             'back',      'back',   6),
  ('delt_front',             'shoulders', 'front',  7),
  ('delt_side',              'shoulders', 'front',  8),
  ('delt_rear',              'shoulders', 'back',   9),
  ('biceps',                 'biceps',    'front', 10),
  ('brachialis_forearm',     'biceps',    'front', 11),
  ('triceps_long',           'triceps',   'back',  12),
  ('triceps_lateral_medial', 'triceps',   'back',  13),
  ('abs_lower',              'abs',       'front', 14),
  ('abs_mid',                'abs',       'front', 15),
  ('obliques',               'abs',       'front', 16);

-- Entity `exercise` (chỉ pull, key = id). Dòng dùng chung, chỉ server ghi
-- (AP-7), nạp từ data/exercises.json bằng `admin library import` (TD2-05).
-- Bài rời thư viện giữ dòng với active = false, không bao giờ xóa (TA2-10).
CREATE TABLE exercises (
  -- Slug ổn định; thay video không đổi id (FA2-14).
  id                       text PRIMARY KEY CHECK (id ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  muscle_group             muscle_group NOT NULL,
  muscle_region            text NOT NULL,
  equipment                equipment NOT NULL,
  -- FR2-12: bài bụng không ghi mức tạ.
  logs_weight              boolean NOT NULL,
  name_vi                  text NOT NULL CHECK (char_length(name_vi) >= 1 AND name_vi = btrim(name_vi)),
  name_en                  text,
  youtube_video_id         varchar(11) NOT NULL CHECK (youtube_video_id ~ '^[A-Za-z0-9_-]{11}$'),
  -- LIB-AC1.
  video_channel            text NOT NULL CHECK (char_length(video_channel) >= 1),
  -- LIB-AC2: ≤ 60 giây. NULL khi chưa đo (chỉ trong lúc dev; cổng phát hành
  -- `library import --check-only` bắt buộc có, IR2-06).
  video_duration_s         smallint CHECK (video_duration_s BETWEEN 1 AND 60),
  -- Job kiểm tra video hằng ngày cập nhật (05 Bản 2 §6.10.3).
  video_available          boolean NOT NULL DEFAULT true,
  video_checked_at         timestamptz,
  video_unavailable_reason text CHECK (video_unavailable_reason IN ('removed', 'private', 'not_embeddable', 'too_long')),
  -- LIB-R4: "Cách tập" 3–6 bước, "Lưu ý an toàn" 2–4 ý.
  guide_steps              text[] NOT NULL CHECK (cardinality(guide_steps) BETWEEN 3 AND 6),
  guide_safety             text[] NOT NULL CHECK (cardinality(guide_safety) BETWEEN 2 AND 4),
  -- LIB-AC1: ngày Bạn duyệt.
  approved_at              date NOT NULL,
  -- F18-R9, tính khi nạp.
  sort_order               smallint NOT NULL,
  active                   boolean NOT NULL DEFAULT true,
  library_version          integer NOT NULL CHECK (library_version >= 1),
  server_version           bigint NOT NULL,
  updated_at               timestamptz NOT NULL DEFAULT now(),
  -- Vùng thuộc đúng nhóm cơ của bài.
  FOREIGN KEY (muscle_region, muscle_group) REFERENCES muscle_regions (id, muscle_group),
  -- Không dụng cụ chỉ ở bụng (BR2-22, F18-R1).
  CHECK (equipment <> 'bodyweight' OR muscle_group = 'abs'),
  CHECK (logs_weight = (muscle_group <> 'abs')),
  CHECK (video_available = (video_unavailable_reason IS NULL))
);

-- LIB-R1: tên tiếng Việt không trùng trong các bài đang có trong thư viện.
CREATE UNIQUE INDEX exercises_name_vi_active_idx ON exercises (name_vi) WHERE active;
CREATE INDEX exercises_sync_idx ON exercises (server_version);

-- Entity `lift_log` (key `YYYY-MM-DD:exerciseId`, TD2-06): mỗi bài tối đa 1
-- bản ghi mỗi buổi (FA2-01); "buổi" là dòng `days` của ngày đó. Mức tạ lưu
-- kg × 10, 0,5–300 kg theo bước 0,5 (FA2-03). Xóa là tombstone. Độc lập với
-- trạng thái buổi (AP-9). Nhóm cơ của buổi, bài bụng, cửa sổ ghi tạ do
-- packages/domain kiểm ở cả hai phía (05 Bản 2 §6.6.2).
CREATE TABLE lift_logs (
  user_id           uuid NOT NULL,
  date              date NOT NULL,
  exercise_id       text NOT NULL REFERENCES exercises(id),
  -- NULL khi đã xóa (tombstone).
  start_kg_x10      smallint CHECK (start_kg_x10 BETWEEN 5 AND 3000 AND start_kg_x10 % 5 = 0),
  end_kg_x10        smallint CHECK (end_kg_x10 BETWEEN 5 AND 3000 AND end_kg_x10 % 5 = 0),
  -- Lần lưu gần nhất.
  logged_at         timestamptz,
  server_version    bigint NOT NULL,
  client_updated_at timestamptz NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted           boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, date, exercise_id),
  FOREIGN KEY (user_id, date) REFERENCES days (user_id, date) ON DELETE CASCADE,
  CHECK (deleted OR (start_kg_x10 IS NOT NULL AND end_kg_x10 IS NOT NULL AND logged_at IS NOT NULL))
);

CREATE INDEX lift_logs_sync_idx ON lift_logs (user_id, server_version);
