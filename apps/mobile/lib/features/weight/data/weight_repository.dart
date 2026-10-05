import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Một số cân: tuần (thứ 2) và cân nặng × 10.
typedef WeightEntry = ({LocalDate week, int kgX10});

/// Bản sao trên máy của entity `weight` (một số cân mỗi tuần, FR-11).
final class WeightRepository {
  WeightRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox).
  Future<void> put(LocalDate week, int kgX10) => _db
      .into(_db.weights)
      .insertOnConflictUpdate(
        WeightsCompanion.insert(weekStart: week.toKey(), weightKgX10: kgX10),
      );

  Future<void> delete(LocalDate week) => (_db.delete(
    _db.weights,
  )..where((w) => w.weekStart.equals(week.toKey()))).go();

  Future<List<WeightEntry>> all() async => [
    for (final r in await (_db.select(
      _db.weights,
    )..orderBy([(w) => OrderingTerm.asc(w.weekStart)])).get())
      _entry(r),
  ];

  /// Số cân mới nhất = tuần gần đây nhất có ghi (F07-R4).
  Stream<WeightEntry?> watchLatest() =>
      _latest.watchSingleOrNull().map((r) => r == null ? null : _entry(r));

  Future<WeightEntry?> latest() async {
    final r = await _latest.getSingleOrNull();
    return r == null ? null : _entry(r);
  }

  SimpleSelectStatement<$WeightsTable, WeightRow> get _latest =>
      _db.select(_db.weights)
        ..orderBy([(w) => OrderingTerm.desc(w.weekStart)])
        ..limit(1);

  static WeightEntry _entry(WeightRow r) =>
      (week: LocalDate.parse(r.weekStart), kgX10: r.weightKgX10);
}
