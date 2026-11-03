import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `schedule_pause` (05 Bản 5 §6.5, TD5-05):
/// khoảng tạm dừng lịch tập; tombstone = xóa dòng.
final class SchedulePauseRepository {
  SchedulePauseRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox). Ghi lại là ghi đè.
  Future<void> put(SchedulePause p) => _db
      .into(_db.schedulePauses)
      .insertOnConflictUpdate(
        SchedulePausesCompanion.insert(
          id: p.id,
          startDate: p.startDate.toKey(),
          endDate: p.endDate.toKey(),
          endedOn: Value(p.endedOn?.toKey()),
        ),
      );

  Future<void> delete(String id) =>
      (_db.delete(_db.schedulePauses)..where((p) => p.id.equals(id))).go();

  Future<List<SchedulePause>> all() async => [
    for (final r in await _db.select(_db.schedulePauses).get()) _pause(r),
  ];

  Stream<List<SchedulePause>> watchAll() =>
      (_db.select(_db.schedulePauses)
            ..orderBy([(p) => OrderingTerm.asc(p.startDate)]))
          .watch()
          .map((rows) => [for (final r in rows) _pause(r)]);

  static SchedulePause _pause(SchedulePauseDbRow r) => SchedulePause(
    id: r.id,
    startDate: LocalDate.parse(r.startDate),
    endDate: LocalDate.parse(r.endDate),
    endedOn: r.endedOn == null ? null : LocalDate.parse(r.endedOn!),
  );
}
