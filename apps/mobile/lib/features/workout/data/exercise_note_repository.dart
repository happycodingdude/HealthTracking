import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `exercise_note` (05 Bản 3 §6.6.4): mỗi bài tối
/// đa một ghi chú mỗi buổi (F26-R1); xóa là xóa dòng.
final class ExerciseNoteRepository {
  ExerciseNoteRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox). Ghi lại là ghi đè.
  Future<void> put(ExerciseNote n) => _db
      .into(_db.exerciseNotes)
      .insertOnConflictUpdate(
        ExerciseNotesCompanion.insert(
          date: n.date.toKey(),
          exerciseId: n.exerciseId,
          noteText: n.text,
        ),
      );

  Future<void> delete(LocalDate date, String exerciseId) =>
      (_db.delete(_db.exerciseNotes)..where(
            (n) =>
                n.date.equals(date.toKey()) & n.exerciseId.equals(exerciseId),
          ))
          .go();

  Future<ExerciseNote?> get(LocalDate date, String exerciseId) async {
    final row =
        await (_db.select(_db.exerciseNotes)..where(
              (n) =>
                  n.date.equals(date.toKey()) & n.exerciseId.equals(exerciseId),
            ))
            .getSingleOrNull();
    return row == null ? null : _note(row);
  }

  /// Mọi ghi chú, cũ → mới (ghi chú buổi trước, FA3-02).
  Stream<List<ExerciseNote>> watchAll() =>
      (_db.select(_db.exerciseNotes)..orderBy([
            (n) => OrderingTerm.asc(n.date),
            (n) => OrderingTerm.asc(n.exerciseId),
          ]))
          .watch()
          .map((rows) => [for (final r in rows) _note(r)]);

  static ExerciseNote _note(ExerciseNoteRow r) => ExerciseNote(
    date: LocalDate.parse(r.date),
    exerciseId: r.exerciseId,
    text: r.noteText,
  );
}
