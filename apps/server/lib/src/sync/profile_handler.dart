import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'sync_entity_handler.dart';

/// Entity `profile` (key `me`) = bảng `profiles` (06 VS03-T05).
///
/// Bản 2 (05 Bản 2 TA2-11, §6.6.5): `setup_date` và `schedule_started_on` ghi
/// một lần — đã có thì giữ, bỏ qua giá trị mới (kể cả null từ app Bản 1 không
/// biết `scheduleStartedOn`).
final class ProfileHandler implements SyncEntityHandler {
  const ProfileHandler();

  static const _codec = ProfileCodec();

  @override
  String get entity => SyncEntities.profile;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (m.key != ProfileCodec.key) {
      return const ApiError(ErrorCode.validationFailed, field: 'key');
    }
    final data = m.data;
    if (data == null) {
      return const ApiError(ErrorCode.validationFailed, field: 'data');
    }
    final Profile profile;
    try {
      profile = _codec.decode(data);
    } on ContractFormatException catch (e) {
      return ApiError(
        ErrorCode.validationFailed,
        field: e.field.replaceFirst('data.', ''),
      );
    }
    final field = ProfileRules.invalidStoredField(profile, m.clientUpdatedAt);
    return field == null
        ? null
        : ApiError(ErrorCode.validationFailed, field: field);
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM profiles WHERE user_id = @user FOR UPDATE',
      ),
      parameters: {'user': userId},
    );
    if (rows.isEmpty) return null;
    return RowState(
      clientUpdatedAt: rows.first[0]! as DateTime,
      deleted: rows.first[1]! as bool,
    );
  }

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int serverVersion,
  ) async {
    final userId = ctx.userId;
    final p = _codec.decode(m.data!);
    await s.execute(
      Sql.named('''
        INSERT INTO profiles (
          user_id, height_cm, birth_year, sex, activity_level, setup_date,
          schedule_started_on, onboarding_step, disclaimer_accepted_at, onboarding_completed_at,
          calorie_mode, calorie_kcal, calorie_pending_kcal, calorie_pending_reason,
          reminders_enabled, timezone, server_version, client_updated_at)
        VALUES (
          @user, @height, @birthYear, @sex::sex, @activity::activity_level, @setupDate::date,
          @scheduleStartedOn::date, @step, @disclaimerAt, @completedAt,
          @mode::calorie_mode, @kcal, @pendingKcal, @pendingReason::calorie_pending_reason,
          @reminders, @timezone, @version, @clientUpdatedAt)
        ON CONFLICT (user_id) DO UPDATE SET
          height_cm = EXCLUDED.height_cm,
          birth_year = EXCLUDED.birth_year,
          sex = EXCLUDED.sex,
          activity_level = EXCLUDED.activity_level,
          setup_date = COALESCE(profiles.setup_date, EXCLUDED.setup_date),
          schedule_started_on = COALESCE(profiles.schedule_started_on, EXCLUDED.schedule_started_on),
          onboarding_step = EXCLUDED.onboarding_step,
          disclaimer_accepted_at = EXCLUDED.disclaimer_accepted_at,
          onboarding_completed_at = EXCLUDED.onboarding_completed_at,
          calorie_mode = EXCLUDED.calorie_mode,
          calorie_kcal = EXCLUDED.calorie_kcal,
          calorie_pending_kcal = EXCLUDED.calorie_pending_kcal,
          calorie_pending_reason = EXCLUDED.calorie_pending_reason,
          reminders_enabled = EXCLUDED.reminders_enabled,
          timezone = EXCLUDED.timezone,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        'user': userId,
        'height': p.heightCm,
        'birthYear': p.birthYear,
        'sex': ProfileWire.sex[p.sex],
        'activity': ProfileWire.activityLevel[p.activityLevel],
        'setupDate': p.setupDate?.toKey(),
        'scheduleStartedOn': p.scheduleStartedOn?.toKey(),
        'step': p.onboardingStep,
        'disclaimerAt': p.disclaimerAcceptedAt,
        'completedAt': p.onboardingCompletedAt,
        'mode': ProfileWire.calorieMode[p.calorieMode],
        'kcal': p.calorieKcal,
        'pendingKcal': p.caloriePendingKcal,
        'pendingReason': ProfileWire.pendingReason[p.caloriePendingReason],
        'reminders': p.remindersEnabled,
        'timezone': p.timezone,
        'version': serverVersion,
        'clientUpdatedAt': m.clientUpdatedAt,
      },
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c'),
      parameters: {'user': userId, 'cursor': 0},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  /// Thời điểm ISO 8601 UTC, độ chính xác mili giây (05 §6.8.1).
  static String _instant(String column) =>
      '''to_char($column AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')''';

  @override
  String get pullSql =>
      '''
    SELECT 'profile'::text AS entity, 'me'::text AS key, deleted, server_version,
           jsonb_build_object(
             'heightCm', height_cm,
             'birthYear', birth_year,
             'sex', sex::text,
             'activityLevel', activity_level::text,
             'setupDate', to_char(setup_date, 'YYYY-MM-DD'),
             'scheduleStartedOn', to_char(schedule_started_on, 'YYYY-MM-DD'),
             'onboardingStep', onboarding_step,
             'disclaimerAcceptedAt', ${_instant('disclaimer_accepted_at')},
             'onboardingCompletedAt', ${_instant('onboarding_completed_at')},
             'calorieMode', calorie_mode::text,
             'calorieKcal', calorie_kcal,
             'caloriePendingKcal', calorie_pending_kcal,
             'caloriePendingReason', calorie_pending_reason::text,
             'remindersEnabled', reminders_enabled,
             'timezone', timezone) AS data
    FROM profiles
    WHERE user_id = @user AND server_version > @cursor''';
}
