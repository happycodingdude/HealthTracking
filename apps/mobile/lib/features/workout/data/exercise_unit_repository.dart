import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `exercise_unit` (05 Bản 3 §6.6.2): đơn vị
/// mức tạ của từng bài, chưa có dòng = bài chưa từng ghi (F19-R42).
final class ExerciseUnitRepository {
  ExerciseUnitRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox).
  Future<void> put(ExerciseUnit u) => _db
      .into(_db.exerciseUnits)
      .insertOnConflictUpdate(
        ExerciseUnitsCompanion.insert(
          exerciseId: u.exerciseId,
          unit: u.unit.wire,
          changedOn: u.changedOn.toKey(),
        ),
      );

  Future<void> delete(String exerciseId) => (_db.delete(
    _db.exerciseUnits,
  )..where((u) => u.exerciseId.equals(exerciseId))).go();

  Future<ExerciseUnit?> get(String exerciseId) async {
    final row = await (_db.select(
      _db.exerciseUnits,
    )..where((u) => u.exerciseId.equals(exerciseId))).getSingleOrNull();
    return row == null ? null : _unit(row);
  }

  Stream<ExerciseUnit?> watch(String exerciseId) =>
      (_db.select(_db.exerciseUnits)
            ..where((u) => u.exerciseId.equals(exerciseId)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _unit(r));

  /// Đơn vị của mọi bài đã từng ghi, theo `exerciseId`.
  Stream<Map<String, ExerciseUnit>> watchAll() => _db
      .select(_db.exerciseUnits)
      .watch()
      .map((rows) => {for (final r in rows) r.exerciseId: _unit(r)});

  static ExerciseUnit _unit(ExerciseUnitRow r) => ExerciseUnit(
    exerciseId: r.exerciseId,
    unit: LiftUnit.tryParse(r.unit) ?? LiftUnit.kg,
    changedOn: DateCodec.decode(r.changedOn),
  );
}
