import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `exercise_feel` (05 Bản 5 §6.5, TD5-04): mức
/// thoải mái của set cuối theo bài + buổi; bỏ chọn = xóa dòng.
final class ExerciseFeelRepository {
  ExerciseFeelRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox). Ghi lại là ghi đè.
  Future<void> put(ExerciseFeel f) => _db
      .into(_db.exerciseFeels)
      .insertOnConflictUpdate(
        ExerciseFeelsCompanion.insert(
          date: f.date.toKey(),
          exerciseId: f.exerciseId,
          feel: f.feel.wire,
        ),
      );

  Future<void> delete(LocalDate date, String exerciseId) =>
      (_db.delete(_db.exerciseFeels)..where(
            (f) =>
                f.date.equals(date.toKey()) & f.exerciseId.equals(exerciseId),
          ))
          .go();

  /// Mọi mức thoải mái, cũ → mới (mức thoải mái buổi trước, FC5-07).
  Stream<List<ExerciseFeel>> watchAll() =>
      (_db.select(_db.exerciseFeels)..orderBy([
            (f) => OrderingTerm.asc(f.date),
            (f) => OrderingTerm.asc(f.exerciseId),
          ]))
          .watch()
          .map((rows) => [for (final r in rows) _feel(r)]);

  static ExerciseFeel _feel(ExerciseFeelDbRow r) => ExerciseFeel(
    date: LocalDate.parse(r.date),
    exerciseId: r.exerciseId,
    feel: Feel.tryParse(r.feel)!,
  );
}
