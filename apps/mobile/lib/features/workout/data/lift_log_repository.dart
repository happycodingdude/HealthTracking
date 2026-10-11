import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `lift_log` (06 Bản 2 VS26-T06): mỗi bài tối
/// đa một bản ghi mỗi buổi (FA2-01).
final class LiftLogRepository {
  LiftLogRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox). Ghi lại là ghi đè (F21-AC3).
  Future<void> put(LiftLog l) => _db
      .into(_db.liftLogs)
      .insertOnConflictUpdate(
        LiftLogsCompanion.insert(
          date: l.date.toKey(),
          exerciseId: l.exerciseId,
          startKgX10: l.startKgX10,
          endKgX10: l.endKgX10,
        ),
      );

  Future<void> delete(LocalDate date, String exerciseId) =>
      (_db.delete(_db.liftLogs)..where(
            (l) =>
                l.date.equals(date.toKey()) & l.exerciseId.equals(exerciseId),
          ))
          .go();

  Future<LiftLog?> get(LocalDate date, String exerciseId) async {
    final row =
        await (_db.select(_db.liftLogs)..where(
              (l) =>
                  l.date.equals(date.toKey()) & l.exerciseId.equals(exerciseId),
            ))
            .getSingleOrNull();
    return row == null ? null : _log(row);
  }

  /// Bản ghi của buổi ngày [date].
  Stream<List<LiftLog>> watchDay(LocalDate date) =>
      (_db.select(_db.liftLogs)..where((l) => l.date.equals(date.toKey())))
          .watch()
          .map((rows) => [for (final r in rows) _log(r)]);

  /// Số bài đã có mức tạ trong buổi ngày [date] (F05-R28).
  Future<int> countDay(LocalDate date) async {
    final count = _db.liftLogs.exerciseId.count();
    final row =
        await (_db.selectOnly(_db.liftLogs)
              ..addColumns([count])
              ..where(_db.liftLogs.date.equals(date.toKey())))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Mọi bản ghi, cũ → mới (biểu đồ, Tiến bộ, buổi trước).
  Stream<List<LiftLog>> watchAll() =>
      (_db.select(_db.liftLogs)..orderBy([
            (l) => OrderingTerm.asc(l.date),
            (l) => OrderingTerm.asc(l.exerciseId),
          ]))
          .watch()
          .map((rows) => [for (final r in rows) _log(r)]);

  static LiftLog _log(LiftLogRow r) => LiftLog(
    date: LocalDate.parse(r.date),
    exerciseId: r.exerciseId,
    startKgX10: r.startKgX10,
    endKgX10: r.endKgX10,
  );
}
