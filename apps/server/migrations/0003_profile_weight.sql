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
  setup_date              date,
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
  CHECK (onboarding_completed_at IS NULL OR (onboarding_step = 5 AND setup_date IS NOT NULL))
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
