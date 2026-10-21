import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'sync_entity_handler.dart';

/// Entity `exercise_unit` (key `exerciseId`) = bảng `exercise_units` (05 Bản 3
/// §6.6.2, TD3-03): đơn vị mức tạ Bạn chọn cho từng bài. Không có cửa sổ, đổi
/// được bất cứ lúc nào (FA3-04); đổi đơn vị là `upsert`, không có tombstone.
/// Xung đột: `clientUpdatedAt` mới hơn thắng (SyncService).
final class ExerciseUnitHandler implements SyncEntityHandler {
  const ExerciseUnitHandler();

  static const _codec = ExerciseUnitCodec();

  @override
  String get entity => SyncEntities.exerciseUnit;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
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
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('''
        SELECT client_updated_at, deleted FROM exercise_units
        WHERE user_id = @user AND exercise_id = @exercise
        FOR UPDATE'''),
      parameters: {'user': userId, 'exercise': key},
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
    final unit = _codec.decode(m.key, m.data!);
    await s.execute(
      Sql.named('''
        INSERT INTO exercise_units (user_id, exercise_id, unit, changed_on,
                                    client_updated_at, server_version)
        VALUES (@user, @exercise, @unit, @changedOn::date, @clientUpdatedAt,
                @version)
        ON CONFLICT (user_id, exercise_id) DO UPDATE SET
          unit = EXCLUDED.unit,
          changed_on = EXCLUDED.changed_on,
          client_updated_at = EXCLUDED.client_updated_at,
          server_version = EXCLUDED.server_version,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        'user': ctx.userId,
        'exercise': unit.exerciseId,
        'unit': unit.unit.wire,
        'changedOn': DateCodec.encode(unit.changedOn),
        'clientUpdatedAt': m.clientUpdatedAt,
        'version': serverVersion,
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
  String get pullSql => '''
    SELECT 'exercise_unit'::text AS entity, exercise_id AS key, deleted,
           server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'exerciseId', exercise_id,
                  'unit', unit,
                  'changedOn', to_char(changed_on, 'YYYY-MM-DD')) END AS data
    FROM exercise_units
    WHERE user_id = @user AND server_version > @cursor''';
}

/// Entity `exercise_note` (key `{date}:{exerciseId}`) = bảng `exercise_notes`
/// (05 Bản 3 §6.6.4, TD3-06): ghi chú bài theo buổi, độc lập với mức tạ
/// (FD3-01 = A). Ghi chú trống là `delete` (tombstone, nội dung bị xóa). Nội
/// dung không ghi vào log (TA3-08).
final class ExerciseNoteHandler implements SyncEntityHandler {
  const ExerciseNoteHandler();

  static const _codec = ExerciseNoteCodec();

  @override
  String get entity => SyncEntities.exerciseNote;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (ExerciseNote.parseKey(m.key) == null) {
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
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final (date, exerciseId) = ExerciseNote.parseKey(key)!;
    final rows = await s.execute(
      Sql.named('''
        SELECT client_updated_at, deleted FROM exercise_notes
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
    final (date, exerciseId) = ExerciseNote.parseKey(m.key)!;
    final parameters = {
      'user': ctx.userId,
      'date': date.toKey(),
      'exercise': exerciseId,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      // SyncService chỉ gọi khi dòng đang có (chưa xóa).
      await s.execute(
        Sql.named('''
          UPDATE exercise_notes
          SET deleted = true, text = '', server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user AND date = @date::date
            AND exercise_id = @exercise'''),
        parameters: parameters,
      );
      return;
    }
    final note = _codec.decode(m.key, m.data!);
    await s.execute(
      Sql.named('''
        INSERT INTO exercise_notes (user_id, date, exercise_id, text, logged_at,
                                    server_version, client_updated_at)
        VALUES (@user, @date::date, @exercise, @text, @clientUpdatedAt,
                @version, @clientUpdatedAt)
        ON CONFLICT (user_id, date, exercise_id) DO UPDATE SET
          text = EXCLUDED.text,
          logged_at = EXCLUDED.logged_at,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false'''),
      parameters: {...parameters, 'text': note.text},
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
  String get pullSql => '''
    SELECT 'exercise_note'::text AS entity,
           to_char(date, 'YYYY-MM-DD') || ':' || exercise_id AS key,
           deleted, server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object(
                  'date', to_char(date, 'YYYY-MM-DD'),
                  'exerciseId', exercise_id,
                  'text', text) END AS data
    FROM exercise_notes
    WHERE user_id = @user AND server_version > @cursor''';
}
