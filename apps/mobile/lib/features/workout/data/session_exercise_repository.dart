import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `session_exercise` (05 Bản 5 §6.5, TD5-03):
/// bài đổi / bỏ qua / thêm của từng buổi; tombstone = xóa dòng.
final class SessionExerciseRepository {
  SessionExerciseRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox). Ghi lại là ghi đè.
  Future<void> put(SessionExerciseRow r) => _db
      .into(_db.sessionExercises)
      .insertOnConflictUpdate(
        SessionExercisesCompanion.insert(
          date: r.date.toKey(),
          exerciseId: r.exerciseId,
          role: r.role.wire,
          replacesExerciseId: Value(r.replacesExerciseId),
          position: Value(r.position),
          skipped: Value(r.skipped),
        ),
      );

  Future<void> delete(LocalDate date, String exerciseId) =>
      (_db.delete(_db.sessionExercises)..where(
            (r) =>
                r.date.equals(date.toKey()) & r.exerciseId.equals(exerciseId),
          ))
          .go();

  /// Các dòng của buổi ngày [date].
  Future<List<SessionExerciseRow>> day(LocalDate date) async => [
    for (final r in await (_db.select(
      _db.sessionExercises,
    )..where((r) => r.date.equals(date.toKey()))).get())
      _row(r),
  ];

  Stream<List<SessionExerciseRow>> watchDay(LocalDate date) =>
      (_db.select(_db.sessionExercises)
            ..where((r) => r.date.equals(date.toKey()))
            ..orderBy([(r) => OrderingTerm.asc(r.position)]))
          .watch()
          .map((rows) => [for (final r in rows) _row(r)]);

  static SessionExerciseRow _row(SessionExerciseDbRow r) => SessionExerciseRow(
    date: LocalDate.parse(r.date),
    exerciseId: r.exerciseId,
    role: SessionExerciseRole.tryParse(r.role)!,
    replacesExerciseId: r.replacesExerciseId,
    position: r.position,
    skipped: r.skipped,
  );
}
