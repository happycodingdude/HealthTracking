import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'lift_log_handler.dart';
import 'schedule_handlers.dart';
import 'shared_handlers.dart';
import 'sync_entity_handler.dart';
import 'sync_service.dart';

/// Thời điểm ISO 8601 UTC, độ chính xác mili giây (05 §6.8.1).
String _instant(String column) =>
    '''to_char($column AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')''';

ApiError _invalid(String field) =>
    ApiError(ErrorCode.validationFailed, field: field);

String _field(ContractFormatException e) => e.field.replaceFirst('data.', '');

RowState? _rowState(Result rows) => rows.isEmpty
    ? null
    : RowState(
        clientUpdatedAt: rows.first[0]! as DateTime,
        deleted: rows.first[1]! as bool,
      );

/// App < 5.0.0 không nhận 4 entity mới (TR5-07, TA2-01): dòng vẫn tính vào
/// cursor nhưng `entity` = [SyncService.skippedEntity].
String _forVersion(String sql, AppVersion? appVersion) =>
    appVersion != null && appVersion >= AppVersion.v5
    ? sql
    : '''
    SELECT '${SyncService.skippedEntity}'::text AS entity, c.key, c.deleted,
           c.server_version, NULL::jsonb AS data
    FROM ($sql) c''';

/// Giờ trên iPhone lúc ghi; chưa biết múi giờ thì dùng chính thời điểm gửi.
Future<DateTime> _localNow(Session s, String userId, DateTime at) async =>
    await deviceNow(s, userId, at) ?? at;

/// Các dòng `session_exercises` còn hiệu lực của ngày [date] (trừ [except]).
Future<List<SessionExerciseRow>> sessionRows(
  Session s,
  String userId,
  LocalDate date, {
  String? except,
}) async {
  final rows = await s.execute(
    Sql.named('''
      SELECT exercise_id, role, replaces_exercise_id, position, skipped
      FROM session_exercises
      WHERE user_id = @user AND date = @date::date AND NOT deleted
        AND (@except::text IS NULL OR exercise_id <> @except::text)'''),
    parameters: {'user': userId, 'date': date.toKey(), 'except': except},
  );
  return [
    for (final r in rows)
      SessionExerciseRow(
        date: date,
        exerciseId: r[0]! as String,
        role: SessionExerciseRole.tryParse(r[1]! as String)!,
        replacesExerciseId: r[2] as String?,
        position: r[3]! as int,
        skipped: r[4]! as bool,
      ),
  ];
}

/// Thư viện (kể cả bài đã rời; bài bỏ ở Bản 3 không có).
Future<List<Exercise>> _library(Session s) async {
  const handler = ExerciseHandler();
  final rows = await s.execute(
    Sql.named('SELECT * FROM (${handler.pullSql}) c WHERE NOT c.deleted'),
    parameters: {'cursor': 0},
  );
  return [
    for (final r in rows)
      const ExerciseCodec().decode(
        r.toColumnMap()['key']! as String,
        (r.toColumnMap()['data']! as Map).cast<String, Object?>(),
      ),
  ];
}

/// TD5-09 (05 Bản 5 §6.6.2): bài được ghi mức tạ / ghi chú / mức thoải mái
/// trong buổi [day] theo danh sách bài của buổi (bài thay / thêm / bỏ qua).
/// Ném [SyncRejection] `lift_exercise_not_in_session`.
Future<void> requireInSession(
  Session s,
  String userId,
  PlanDay day,
  Exercise exercise,
) async {
  final rows = day.isWorkout
      ? await sessionRows(s, userId, day.date)
      : const <SessionExerciseRow>[];
  if (!SessionExerciseRules.inSession(
    exercise: exercise,
    groups: day.sessionMuscles,
    rows: rows,
  )) {
    throw const SyncRejection('key', code: ErrorCode.liftExerciseNotInSession);
  }
}

/// Entity `session_exercise` (key `{date}:{exerciseId}`) = bảng
/// `session_exercises` (05 Bản 5 §6.6.2, TD5-03): bài đổi / bỏ qua / thêm của
/// buổi hôm nay. Kiểm tra theo thứ tự: (1) buổi theo lịch tồn tại, không
/// phải buổi tập thêm → `lift_no_session`; (2) [DayLock] → `day_locked`; (3)
/// buổi chưa "Đã tập" lúc xử lý (theo thứ tự mutation) → `session_done`;
/// (4) bài và vai trò ([SessionExerciseRules.check]) → `validation_failed`.
/// `delete` = tombstone (hủy đổi, xóa bài thêm, hủy bỏ qua).
final class SessionExerciseHandler implements SyncEntityHandler, VersionedPull {
  const SessionExerciseHandler();

  static const _codec = SessionExerciseCodec();

  @override
  String get entity => SyncEntities.sessionExercise;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (SessionExerciseRow.parseKey(m.key) == null) return _invalid('key');
    if (m.op == SyncOp.delete) return null;
    final data = m.data;
    if (data == null) return _invalid('data');
    try {
      final row = _codec.decode(m.key, data);
      final field = row.invalidField;
      if (field != null) return _invalid(field);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    } on FormatException {
      return _invalid('data');
    }
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final (date, exerciseId) = SessionExerciseRow.parseKey(key)!;
    return _rowState(
      await s.execute(
        Sql.named('''
          SELECT client_updated_at, deleted FROM session_exercises
          WHERE user_id = @user AND date = @date::date AND exercise_id = @exercise
          FOR UPDATE'''),
        parameters: {
          'user': userId,
          'date': date.toKey(),
          'exercise': exerciseId,
        },
      ),
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
    final (date, exerciseId) = SessionExerciseRow.parseKey(m.key)!;
    final day = await sessionDay(s, userId, date);
    if (day == null || !day.isWorkout) {
      throw const SyncRejection('key', code: ErrorCode.liftNoSession);
    }
    final now = await _localNow(s, userId, m.clientUpdatedAt);
    if (!DayLock.isOpen(date, now)) {
      throw const SyncRejection('key', code: ErrorCode.dayLocked);
    }
    if (day.mark == DayMark.done) {
      throw const SyncRejection('key', code: ErrorCode.sessionDone);
    }
    final parameters = {
      'user': userId,
      'date': date.toKey(),
      'exercise': exerciseId,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      await s.execute(
        Sql.named('''
          UPDATE session_exercises
          SET deleted = true, server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user AND date = @date::date
            AND exercise_id = @exercise'''),
        parameters: parameters,
      );
      return;
    }
    final row = _codec.decode(m.key, m.data!);
    final library = await _library(s);
    final field = SessionExerciseRules.check(
      row: row,
      groups: day.muscles.toSet(),
      exercise: library.where((e) => e.id == exerciseId).firstOrNull,
      library: library,
      others: await sessionRows(s, userId, date, except: exerciseId),
    );
    if (field != null) throw SyncRejection(field);
    await s.execute(
      Sql.named('''
        INSERT INTO session_exercises (user_id, date, exercise_id, role,
                                       replaces_exercise_id, position, skipped,
                                       client_updated_at, server_version)
        VALUES (@user, @date::date, @exercise, @role, @replaces, @position,
                @skipped, @clientUpdatedAt, @version)
        ON CONFLICT (user_id, date, exercise_id) DO UPDATE SET
          role = EXCLUDED.role,
          replaces_exercise_id = EXCLUDED.replaces_exercise_id,
          position = EXCLUDED.position,
          skipped = EXCLUDED.skipped,
          client_updated_at = EXCLUDED.client_updated_at,
          server_version = EXCLUDED.server_version,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        ...parameters,
        'role': row.role.wire,
        'replaces': row.replacesExerciseId,
        'position': row.position,
        'skipped': row.skipped,
      },
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE c.key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String pullSqlFor(AppVersion? appVersion) => _forVersion(pullSql, appVersion);

  @override
  String get pullSql => '''
    SELECT 'session_exercise'::text AS entity,
           to_char(date, 'YYYY-MM-DD') || ':' || exercise_id AS key,
           deleted, server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'date', to_char(date, 'YYYY-MM-DD'),
                  'exerciseId', exercise_id,
                  'role', role,
                  'replacesExerciseId', replaces_exercise_id,
                  'position', position,
                  'skipped', skipped) END AS data
    FROM session_exercises
    WHERE user_id = @user AND server_version > @cursor''';
}

/// Entity `exercise_feel` (key `{date}:{exerciseId}`) = bảng `exercise_feels`
/// (05 Bản 5 §6.6.2, TD5-04): mức thoải mái của set cuối, độc lập mức tạ và
/// ghi chú (F33-R3). Kiểm tra: buổi; [DayLock] → `day_locked`; cửa sổ ghi tạ
/// ([LiftWindow], gồm mở sớm khi tới gym) → `lift_window_closed`; bài (kể cả
/// bài bụng — không xét `logsWeight`) và bài thuộc buổi theo TD5-09. Bỏ chọn
/// = `delete` (tombstone).
final class ExerciseFeelHandler implements SyncEntityHandler, VersionedPull {
  const ExerciseFeelHandler();

  static const _codec = ExerciseFeelCodec();

  @override
  String get entity => SyncEntities.exerciseFeel;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (ExerciseFeel.parseKey(m.key) == null) return _invalid('key');
    if (m.op == SyncOp.delete) return null;
    final data = m.data;
    if (data == null) return _invalid('data');
    try {
      _codec.decode(m.key, data);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    } on FormatException {
      return _invalid('data');
    }
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final (date, exerciseId) = ExerciseFeel.parseKey(key)!;
    return _rowState(
      await s.execute(
        Sql.named('''
          SELECT client_updated_at, deleted FROM exercise_feels
          WHERE user_id = @user AND date = @date::date AND exercise_id = @exercise
          FOR UPDATE'''),
        parameters: {
          'user': userId,
          'date': date.toKey(),
          'exercise': exerciseId,
        },
      ),
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
    final (date, exerciseId) = ExerciseFeel.parseKey(m.key)!;
    final day = await sessionDay(s, userId, date);
    if (!LiftLogRules.isSession(day)) {
      throw const SyncRejection('key', code: ErrorCode.liftNoSession);
    }
    final now = await _localNow(s, userId, m.clientUpdatedAt);
    if (!DayLock.isOpen(date, now)) {
      throw const SyncRejection('key', code: ErrorCode.dayLocked);
    }
    if (!LiftWindow.of(day, now).isOpen) {
      throw const SyncRejection('key', code: ErrorCode.liftWindowClosed);
    }
    final existing = await read(s, userId, m.key);
    final exists = existing != null && !existing.deleted;
    final exercise = await libraryExercise(s, exerciseId);
    if (exercise == null || (!exists && !exercise.active)) {
      throw const SyncRejection(
        'key',
        code: ErrorCode.liftNotAllowedForExercise,
      );
    }
    // Bỏ chọn (tombstone) không xét bài thuộc buổi (như `lift_log`, TD5-10).
    if (m.op != SyncOp.delete) {
      await requireInSession(s, userId, day!, exercise);
    }
    final parameters = {
      'user': userId,
      'date': date.toKey(),
      'exercise': exerciseId,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      await s.execute(
        Sql.named('''
          UPDATE exercise_feels
          SET deleted = true, server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user AND date = @date::date
            AND exercise_id = @exercise'''),
        parameters: parameters,
      );
      return;
    }
    final feel = _codec.decode(m.key, m.data!).feel;
    await s.execute(
      Sql.named('''
        INSERT INTO exercise_feels (user_id, date, exercise_id, feel,
                                    client_updated_at, server_version)
        VALUES (@user, @date::date, @exercise, @feel, @clientUpdatedAt,
                @version)
        ON CONFLICT (user_id, date, exercise_id) DO UPDATE SET
          feel = EXCLUDED.feel,
          client_updated_at = EXCLUDED.client_updated_at,
          server_version = EXCLUDED.server_version,
          updated_at = now(),
          deleted = false'''),
      parameters: {...parameters, 'feel': feel.wire},
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE c.key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String pullSqlFor(AppVersion? appVersion) => _forVersion(pullSql, appVersion);

  @override
  String get pullSql => '''
    SELECT 'exercise_feel'::text AS entity,
           to_char(date, 'YYYY-MM-DD') || ':' || exercise_id AS key,
           deleted, server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'date', to_char(date, 'YYYY-MM-DD'),
                  'exerciseId', exercise_id,
                  'feel', feel) END AS data
    FROM exercise_feels
    WHERE user_id = @user AND server_version > @cursor''';
}

/// Entity `schedule_pause` (key `id`) = bảng `schedule_pauses` (05 Bản 5
/// §6.6.2, TD5-05): khoảng tạm dừng lịch tập. Kiểm tra theo [PauseRules] với
/// "hôm nay" theo giờ iPhone lúc ghi: ngày bắt đầu không ở quá khứ, B ≥ A,
/// sửa B không về quá khứ, `endedOn` ∈ [A − 1, B]; một khoảng hiệu lực tại một
/// thời điểm → `pause_overlap`. `delete` chỉ với khoảng chưa bắt đầu (xóa
/// khoảng đặt trước / kết thúc vào ngày A, F31-R8): ngày đã qua của khoảng
/// không bị đổi. Thẻ: tắt khi khoảng phủ hôm nay (job, VS-56), hiện lại khi
/// khoảng thôi phủ hôm nay ([PushSignal.pauseEndedToday], VS-57).
final class SchedulePauseHandler implements SyncEntityHandler, VersionedPull {
  const SchedulePauseHandler();

  static const _codec = SchedulePauseCodec();

  static const _fields = {
    PauseError.startInPast: 'startDate',
    PauseError.endBeforeStart: 'endDate',
    PauseError.endInPast: 'endDate',
    PauseError.endedOnOutOfRange: 'endedOn',
  };

  @override
  String get entity => SyncEntities.schedulePause;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (!SchedulePauseCodec.validKey(m.key)) return _invalid('key');
    if (m.op == SyncOp.delete) return null;
    final data = m.data;
    if (data == null) return _invalid('data');
    try {
      final p = _codec.decode(m.key, data);
      final field = p.invalidField;
      if (field != null) return _invalid(field);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    } on FormatException {
      return _invalid('data');
    }
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async =>
      _rowState(
        await s.execute(
          Sql.named('''
            SELECT client_updated_at, deleted FROM schedule_pauses
            WHERE user_id = @user AND id = @id::uuid FOR UPDATE'''),
          parameters: {'user': userId, 'id': key},
        ),
      );

  /// Các khoảng còn hiệu lực về dữ liệu (chưa tombstone) của [userId].
  static Future<List<SchedulePause>> pauses(Session s, String userId) async {
    const handler = SchedulePauseHandler();
    final rows = await s.execute(
      Sql.named('SELECT * FROM (${handler.pullSql}) c WHERE NOT c.deleted'),
      parameters: {'user': userId, 'cursor': 0},
    );
    return [
      for (final r in rows)
        _codec.decode(
          r.toColumnMap()['key']! as String,
          (r.toColumnMap()['data']! as Map).cast<String, Object?>(),
        ),
    ];
  }

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int serverVersion,
  ) async {
    final userId = ctx.userId;
    final today = LocalDate.fromDateTime(
      await _localNow(s, userId, m.clientUpdatedAt),
    );
    final all = await pauses(s, userId);
    final before = all.where((p) => p.id == m.key).firstOrNull;
    final parameters = {
      'user': userId,
      'id': m.key,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      if (before != null && before.startDate.isBefore(today)) {
        throw const SyncRejection('key');
      }
      await s.execute(
        Sql.named('''
          UPDATE schedule_pauses
          SET deleted = true, server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user AND id = @id::uuid'''),
        parameters: parameters,
      );
      // Xóa khoảng đang phủ hôm nay (kết thúc vào ngày A, F31-R8).
      if (before != null && before.covers(today)) {
        ctx.signals.add(PushSignal.pauseEndedToday);
      }
      return;
    }
    final after = _codec.decode(m.key, m.data!);
    final error = PauseRules.check(
      before: before,
      after: after,
      others: all.where((p) => p.id != m.key),
      today: today,
    );
    if (error == PauseError.overlap) {
      throw const SyncRejection('startDate', code: ErrorCode.pauseOverlap);
    }
    if (error != null) throw SyncRejection(_fields[error]!);
    await s.execute(
      Sql.named('''
        INSERT INTO schedule_pauses (id, user_id, start_date, end_date, ended_on,
                                     client_updated_at, server_version)
        VALUES (@id::uuid, @user, @start::date, @end::date, @endedOn::date,
                @clientUpdatedAt, @version)
        ON CONFLICT (user_id, id) DO UPDATE SET
          start_date = EXCLUDED.start_date,
          end_date = EXCLUDED.end_date,
          ended_on = EXCLUDED.ended_on,
          client_updated_at = EXCLUDED.client_updated_at,
          server_version = EXCLUDED.server_version,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        ...parameters,
        'start': after.startDate.toKey(),
        'end': after.endDate.toKey(),
        'endedOn': after.endedOn?.toKey(),
      },
    );
    // 05 Bản 5 §6.6.3, TD5-13.3: khoảng thôi phủ hôm nay (kết thúc sớm) → sau
    // commit, thẻ hiện lại nếu còn trong cửa sổ (F31-R8, F25-R64).
    if (before != null && before.covers(today) && !after.covers(today)) {
      ctx.signals.add(PushSignal.pauseEndedToday);
    }
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE c.key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String pullSqlFor(AppVersion? appVersion) => _forVersion(pullSql, appVersion);

  @override
  String get pullSql => '''
    SELECT 'schedule_pause'::text AS entity, id::text AS key, deleted,
           server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'id', id::text,
                  'startDate', to_char(start_date, 'YYYY-MM-DD'),
                  'endDate', to_char(end_date, 'YYYY-MM-DD'),
                  'endedOn', to_char(ended_on, 'YYYY-MM-DD')) END AS data
    FROM schedule_pauses
    WHERE user_id = @user AND server_version > @cursor''';
}

/// Entity `gym_location` (key `me`) = bảng `gym_locations` (05 Bản 5 §6.6.2,
/// TD5-06): một dòng / tài khoản; `lat` ∈ [−90, 90], `lng` ∈ [−180, 180].
/// Server không ghi body vào log, không dùng tọa độ làm gì ngoài trả về app
/// (TA5-03, AP-18, TAC5-10). Xóa = tombstone.
final class GymLocationHandler implements SyncEntityHandler, VersionedPull {
  const GymLocationHandler();

  static const _codec = GymLocationCodec();

  @override
  String get entity => SyncEntities.gymLocation;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (m.key != GymLocation.key) return _invalid('key');
    if (m.op == SyncOp.delete) return null;
    final data = m.data;
    if (data == null) return _invalid('data');
    try {
      final g = _codec.decode(m.key, data);
      final field = g.invalidField;
      if (field != null) return _invalid(field);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    } on FormatException {
      return _invalid('data');
    }
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async =>
      _rowState(
        await s.execute(
          Sql.named('''
            SELECT client_updated_at, deleted FROM gym_locations
            WHERE user_id = @user FOR UPDATE'''),
          parameters: {'user': userId},
        ),
      );

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int serverVersion,
  ) async {
    final parameters = {
      'user': ctx.userId,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      await s.execute(
        Sql.named('''
          UPDATE gym_locations
          SET deleted = true, server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user'''),
        parameters: parameters,
      );
      return;
    }
    final g = _codec.decode(m.key, m.data!);
    await s.execute(
      Sql.named('''
        INSERT INTO gym_locations (user_id, lat, lng, saved_at, enabled,
                                   client_updated_at, server_version)
        VALUES (@user, round(@lat::numeric, 6), round(@lng::numeric, 6),
                @savedAt, @enabled, @clientUpdatedAt, @version)
        ON CONFLICT (user_id) DO UPDATE SET
          lat = EXCLUDED.lat,
          lng = EXCLUDED.lng,
          saved_at = EXCLUDED.saved_at,
          enabled = EXCLUDED.enabled,
          client_updated_at = EXCLUDED.client_updated_at,
          server_version = EXCLUDED.server_version,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        ...parameters,
        'lat': g.lat.toString(),
        'lng': g.lng.toString(),
        'savedAt': g.savedAt,
        'enabled': g.enabled,
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

  @override
  String pullSqlFor(AppVersion? appVersion) => _forVersion(pullSql, appVersion);

  @override
  String get pullSql =>
      '''
    SELECT 'gym_location'::text AS entity, 'me'::text AS key, deleted,
           server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'lat', lat::float8,
                  'lng', lng::float8,
                  'savedAt', ${_instant('saved_at')},
                  'enabled', enabled) END AS data
    FROM gym_locations
    WHERE user_id = @user AND server_version > @cursor''';
}
