import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'schedule_handlers.dart';
import 'shared_handlers.dart';
import 'sync_entity_handler.dart';

/// Entity `lift_log` (key `{date}:{exerciseId}`) = bảng `lift_logs` (06 Bản 2
/// VS26-T05). Kiểm tra theo thứ tự 05 Bản 2 §6.6.2 bằng `domain`: buổi, cửa
/// sổ ghi tạ, bài, nhóm cơ của buổi, con số; xung đột thì bản có
/// `clientUpdatedAt` mới hơn thắng (SyncService). `delete` là tombstone.
final class LiftLogHandler implements SyncEntityHandler {
  const LiftLogHandler();

  static const _codec = LiftLogCodec();
  static const _dayCodec = DayCodec();
  static const _exerciseCodec = ExerciseCodec();
  static const _days = DayHandler();
  static const _exercises = ExerciseHandler();

  @override
  String get entity => SyncEntities.liftLog;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (LiftLog.parseKey(m.key) == null) {
      return const ApiError(ErrorCode.validationFailed, field: 'key');
    }
    if (m.op == SyncOp.delete) return null;
    final data = m.data;
    if (data == null) {
      return const ApiError(ErrorCode.validationFailed, field: 'data');
    }
    try {
      _codec.decode(m.key, data);
    } on ContractFormatException catch (e) {
      return ApiError(
        ErrorCode.validationFailed,
        field: e.field.replaceFirst('data.', ''),
      );
    } on FormatException {
      return const ApiError(ErrorCode.validationFailed, field: 'data');
    }
    // Bước 5 (con số) kiểm ở [apply], sau các bước cần đọc database.
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final (date, exerciseId) = LiftLog.parseKey(key)!;
    final rows = await s.execute(
      Sql.named('''
        SELECT client_updated_at, deleted FROM lift_logs
        WHERE user_id = @user AND date = @date::date AND exercise_id = @exercise
        FOR UPDATE'''),
      parameters: {
        'user': userId,
        'date': date.toKey(),
        'exercise': exerciseId,
      },
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
    final (date, exerciseId) = LiftLog.parseKey(m.key)!;
    final existing = await read(s, userId, m.key);
    final error = LiftLogRules.check(
      day: await _day(s, userId, date),
      exercise: await _exercise(s, exerciseId),
      now: await deviceNow(s, userId, m.clientUpdatedAt) ?? m.clientUpdatedAt,
      exists: existing != null && !existing.deleted,
    );
    if (error != null) {
      throw SyncRejection('key', code: _codes[error]!);
    }
    final parameters = {
      'user': userId,
      'date': date.toKey(),
      'exercise': exerciseId,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      // SyncService chỉ gọi khi dòng đang có (chưa xóa).
      await s.execute(
        Sql.named('''
          UPDATE lift_logs
          SET deleted = true, start_kg_x10 = NULL, end_kg_x10 = NULL,
              logged_at = NULL, server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user AND date = @date::date
            AND exercise_id = @exercise'''),
        parameters: parameters,
      );
      return;
    }
    // Bước 5: F21-V2, F21-V3.
    final log = _codec.decode(m.key, m.data!);
    final invalid = log.invalidField;
    if (invalid != null) throw SyncRejection(invalid);
    await s.execute(
      Sql.named('''
        INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10,
                               logged_at, server_version, client_updated_at)
        VALUES (@user, @date::date, @exercise, @start, @end, @clientUpdatedAt,
                @version, @clientUpdatedAt)
        ON CONFLICT (user_id, date, exercise_id) DO UPDATE SET
          start_kg_x10 = EXCLUDED.start_kg_x10,
          end_kg_x10 = EXCLUDED.end_kg_x10,
          logged_at = EXCLUDED.logged_at,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false'''),
      parameters: {...parameters, 'start': log.startKgX10, 'end': log.endKgX10},
    );
  }

  static const _codes = {
    LiftError.noSession: ErrorCode.liftNoSession,
    LiftError.windowClosed: ErrorCode.liftWindowClosed,
    LiftError.notAllowedForExercise: ErrorCode.liftNotAllowedForExercise,
    LiftError.exerciseNotInSession: ErrorCode.liftExerciseNotInSession,
  };

  /// Dòng `days` của [date]; thời điểm lưu buổi tập thêm quy về giờ trên
  /// iPhone như `clientUpdatedAt` (05 Bản 2 §6.4.3).
  Future<PlanDay?> _day(Session s, String userId, LocalDate date) async {
    final change = await _days.read(s, userId, date.toKey());
    if (change == null || change.deleted) return null;
    final day = _dayCodec.decode(change.key, change.data!);
    final loggedAt = day.extraLoggedAt;
    if (loggedAt == null) return day;
    return day.withExtra(
      day.extraMuscles,
      loggedAt: await deviceNow(s, userId, loggedAt) ?? loggedAt,
    );
  }

  Future<Exercise?> _exercise(Session s, String id) async {
    final change = await _exercises.read(s, '', id);
    return change == null
        ? null
        : _exerciseCodec.decode(change.key, change.data!);
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
  String get pullSql => '''
    SELECT 'lift_log'::text AS entity,
           to_char(date, 'YYYY-MM-DD') || ':' || exercise_id AS key,
           deleted, server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'date', to_char(date, 'YYYY-MM-DD'),
                  'exerciseId', exercise_id,
                  'startKgX10', start_kg_x10,
                  'endKgX10', end_kg_x10) END AS data
    FROM lift_logs
    WHERE user_id = @user AND server_version > @cursor''';
}
