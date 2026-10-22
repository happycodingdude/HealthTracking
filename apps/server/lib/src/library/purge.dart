import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../jobs/job_scheduler.dart';
import '../sync/sync_service.dart';

/// `library purge` từ chối, database không đổi.
final class PurgeRefused implements Exception {
  PurgeRefused(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Một dòng của bảng xem trước: bản ghi chưa xóa của một bài bỏ.
typedef PurgeRow = ({String id, String nameVi, int liftLogs, int notes});

/// Kết quả `--dry-run` (05 Bản 3 §6.11.1) hoặc số đã xóa sau `--apply`.
final class PurgeReport {
  const PurgeReport({
    required this.rows,
    required this.exercisesLeft,
    required this.stepsUnits,
    required this.kgUnits,
  });

  /// Đủ 14 bài bỏ, theo thứ tự [LibraryPurge.removedIds].
  final List<PurgeRow> rows;

  /// Số bài bỏ còn trong thư viện (chưa tombstone).
  final int exercisesLeft;

  /// Đơn vị tạo (hoặc sẽ tạo) cho bài giữ đã ghi: bài máy Bản 2 → nấc máy,
  /// bài tạ Bản 2 → kg (TA3-04, D3-04).
  final int stepsUnits;
  final int kgUnits;

  int get liftLogs => rows.fold(0, (n, r) => n + r.liftLogs);
  int get notes => rows.fold(0, (n, r) => n + r.notes);

  /// Con số Bạn xem và `--confirm-count` phải khớp: bản ghi mức tạ + ghi chú.
  int get total => liftLogs + notes;

  bool get nothingToDo =>
      total == 0 && exercisesLeft == 0 && stepsUnits + kgUnits == 0;

  /// Bảng Markdown: tên bài · số mức tạ · số ghi chú · tổng (§6.11.1).
  String table() => [
    '| Bài bỏ | Mức tạ | Ghi chú | Tổng |',
    '|---|---:|---:|---:|',
    for (final r in rows)
      '| ${r.nameVi} | ${r.liftLogs} | ${r.notes} | ${r.liftLogs + r.notes} |',
    '| **Tổng** | **$liftLogs** | **$notes** | **$total** |',
  ].join('\n');
}

/// Xóa 14 bài bỏ khi lên Bản 3 (05 Bản 3 §6.11, TD3-08, TA3-04, TA3-07).
///
/// [dryRun] chỉ đếm. [apply] làm trong **một transaction**: tombstone
/// `lift_logs`, `exercise_notes` của 14 bài; 14 dòng `exercises`
/// `deleted = true, active = false`; tạo `exercise_units` cho mỗi
/// `(user_id, exercise_id)` còn bản ghi mức tạ mà chưa có đơn vị, theo
/// `exercises.equipment` Bản 2 (`machine` → `steps`, `free_weight` → `kg`);
/// `lift_logs` không đổi số. Mọi dòng đổi có `server_version` mới để máy xóa
/// theo qua pull. Không DELETE vật lý (job dọn sau 90 ngày, [Maintenance]).
final class LibraryPurge {
  LibraryPurge(this._db, this._clock);

  final SessionExecutor _db;
  final Clock _clock;

  /// 14 bài bỏ (03 Bản 3 §6.12), cố định trong code; test đối chiếu với
  /// [LibraryV3.removedV2Ids] và `data/v2__exercises.json` (ED3-04).
  static const removedIds = [
    'chest-upper-free-weight-incline-dumbbell-press',
    'chest-lower-machine-high-to-low-cable-crossover',
    'chest-lower-free-weight-decline-barbell-bench-press',
    'lats-free-weight-one-arm-dumbbell-row',
    'back-mid-free-weight-barbell-bent-over-row',
    'back-lower-machine-back-extension-machine',
    'back-lower-free-weight-romanian-deadlift',
    'delt-side-free-weight-dumbbell-lateral-raise',
    'delt-rear-free-weight-bent-over-dumbbell-rear-delt-raise',
    'biceps-free-weight-dumbbell-biceps-curl',
    'brachialis-forearm-machine-cable-rope-hammer-curl',
    'brachialis-forearm-free-weight-dumbbell-hammer-curl',
    'triceps-long-machine-overhead-cable-triceps-extension',
    'triceps-lateral-medial-free-weight-close-grip-bench-press',
  ];

  /// Bài còn lại có bản ghi mức tạ mà chưa có đơn vị: những dòng [apply] sẽ
  /// tạo `exercise_units`.
  static const _needsUnit = '''
    FROM (SELECT DISTINCT user_id, exercise_id FROM lift_logs WHERE NOT deleted) l
    JOIN exercises e ON e.id = l.exercise_id
    WHERE NOT e.deleted AND NOT (e.id = ANY(@removed::text[]))
      AND NOT EXISTS (SELECT 1 FROM exercise_units u
                      WHERE u.user_id = l.user_id AND u.exercise_id = l.exercise_id)''';

  Future<PurgeReport> dryRun() => _db.run(_preview);

  /// [confirmCount] phải bằng [PurgeReport.total] của lần xem trước, ngay
  /// lúc chạy; khác → [PurgeRefused]. Bài giữ đã ghi mà `equipment` không còn
  /// giá trị Bản 2 (`library import` Bản 3 đã chạy trước purge, §6.11.3) →
  /// [PurgeRefused]. Không có gì để làm → trả report rỗng, không đổi gì.
  Future<PurgeReport> apply({required int confirmCount}) => _db.runTx((
    tx,
  ) async {
    // Không pull nào thấy nửa chừng; push đang dở của các tài khoản liên
    // quan xong trước khi cấp version mới (ED-03).
    await SyncService.lockSharedRowsForWrite(tx);
    await tx.execute(
      Sql.named(
        'SELECT id FROM exercises WHERE id = ANY(@removed::text[]) FOR UPDATE',
      ),
      parameters: _removed,
    );
    final users = await tx.execute(
      Sql.named('''
        SELECT user_id FROM lift_logs
          WHERE exercise_id = ANY(@removed::text[]) AND NOT deleted
        UNION SELECT user_id FROM exercise_notes
          WHERE exercise_id = ANY(@removed::text[]) AND NOT deleted
        UNION SELECT l.user_id $_needsUnit
        ORDER BY 1'''),
      parameters: _removed,
    );
    for (final u in users) {
      await SyncService.lockUser(tx, u[0]! as String);
    }

    final preview = await _preview(tx);
    if (preview.nothingToDo && confirmCount == 0) return preview;
    if (confirmCount != preview.total) {
      throw PurgeRefused(
        'Từ chối: --confirm-count=$confirmCount khác tổng hiện tại '
        '${preview.total}. Chạy lại --dry-run, gửi bảng mới cho Bạn. '
        'Database không đổi.',
      );
    }
    final noEquipment = await tx.execute(
      Sql.named('''
        SELECT DISTINCT e.id $_needsUnit
          AND (e.equipment IS NULL OR e.equipment NOT IN ('machine', 'free_weight'))
        ORDER BY 1'''),
      parameters: _removed,
    );
    if (noEquipment.isNotEmpty) {
      throw PurgeRefused(
        'Từ chối: bài giữ đã ghi không còn loại bài Bản 2 (equipment), '
        'không gán được đơn vị — library import Bản 3 đã chạy trước purge? '
        'Database không đổi. Bài: '
        '${[for (final r in noEquipment) r[0]].join(', ')}',
      );
    }

    final logs = await tx.execute(
      Sql.named('''
        UPDATE lift_logs SET deleted = true, start_kg_x10 = NULL,
          end_kg_x10 = NULL, logged_at = NULL,
          server_version = nextval('sync_version_seq'),
          client_updated_at = now(), updated_at = now()
        WHERE exercise_id = ANY(@removed::text[]) AND NOT deleted'''),
      parameters: _removed,
    );
    final notes = await tx.execute(
      Sql.named('''
        UPDATE exercise_notes SET deleted = true, text = '',
          server_version = nextval('sync_version_seq'),
          client_updated_at = now(), updated_at = now()
        WHERE exercise_id = ANY(@removed::text[]) AND NOT deleted'''),
      parameters: _removed,
    );
    if (logs.affectedRows + notes.affectedRows != confirmCount) {
      throw PurgeRefused(
        'Từ chối: số bản ghi xóa được '
        '(${logs.affectedRows + notes.affectedRows}) khác $confirmCount. '
        'Database không đổi.',
      );
    }
    await tx.execute(
      Sql.named('''
        UPDATE exercises SET deleted = true, active = false,
          server_version = nextval('sync_version_seq'), updated_at = now()
        WHERE id = ANY(@removed::text[]) AND NOT deleted'''),
      parameters: _removed,
    );
    final today = LocalDate.fromDateTime(
      _clock.now().toUtc().add(JobScheduler.vietnamOffset),
    );
    await tx.execute(
      Sql.named('''
        INSERT INTO exercise_units (user_id, exercise_id, unit, changed_on,
                                    client_updated_at, server_version)
        SELECT l.user_id, l.exercise_id,
               CASE e.equipment WHEN 'machine' THEN 'steps' ELSE 'kg' END,
               @today::date, now(), nextval('sync_version_seq')
        $_needsUnit'''),
      parameters: {..._removed, 'today': today.toKey()},
    );
    // Đã giữ khóa từ lúc đếm: số đã làm đúng bằng bảng xem trước.
    return preview;
  });

  static final _removed = {'removed': removedIds};

  Future<PurgeReport> _preview(Session s) async {
    final rows = await s.execute(
      Sql.named('''
        SELECT e.id, e.name_vi,
          (SELECT count(*) FROM lift_logs l
            WHERE l.exercise_id = e.id AND NOT l.deleted)::int,
          (SELECT count(*) FROM exercise_notes n
            WHERE n.exercise_id = e.id AND NOT n.deleted)::int,
          NOT e.deleted
        FROM exercises e WHERE e.id = ANY(@removed::text[])'''),
      parameters: _removed,
    );
    final byId = {for (final r in rows) r[0]! as String: r};
    final units = await s.execute(
      Sql.named('''
        SELECT count(*) FILTER (WHERE e.equipment = 'machine')::int,
               count(*) FILTER (WHERE e.equipment IS DISTINCT FROM 'machine')::int
        $_needsUnit'''),
      parameters: _removed,
    );
    return PurgeReport(
      rows: [
        for (final id in removedIds)
          if (byId[id] case final r?)
            (
              id: id,
              nameVi: r[1]! as String,
              liftLogs: r[2]! as int,
              notes: r[3]! as int,
            )
          else
            (id: id, nameVi: id, liftLogs: 0, notes: 0),
      ],
      exercisesLeft: rows.where((r) => r[4]! as bool).length,
      stepsUnits: units.single[0]! as int,
      kgUnits: units.single[1]! as int,
    );
  }
}
