import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `gym_location` (05 Bản 5 §6.5, TD5-06) và
/// bảng chỉ trên máy `gym_arrivals` (ngày đã báo "tới phòng gym").
final class GymLocationRepository {
  GymLocationRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản trên máy (không qua outbox). Ghi lại là ghi đè.
  Future<void> put(GymLocation g) => _db
      .into(_db.gymLocations)
      .insertOnConflictUpdate(
        GymLocationsCompanion.insert(
          key: GymLocation.key,
          lat: g.lat,
          lng: g.lng,
          savedAt: g.savedAt,
          enabled: Value(g.enabled),
        ),
      );

  Future<void> delete() => _db.delete(_db.gymLocations).go();

  Future<GymLocation?> get() async {
    final row = await _db.select(_db.gymLocations).getSingleOrNull();
    return row == null ? null : _location(row);
  }

  Stream<GymLocation?> watch() => _db
      .select(_db.gymLocations)
      .watchSingleOrNull()
      .map((r) => r == null ? null : _location(r));

  /// Ngày [date] đã báo server "tới phòng gym" chưa (chỉ trên máy).
  Future<bool> arrived(LocalDate date) async =>
      await (_db.select(
        _db.gymArrivals,
      )..where((a) => a.date.equals(date.toKey()))).getSingleOrNull() !=
      null;

  Future<void> markArrived(LocalDate date) => _db
      .into(_db.gymArrivals)
      .insertOnConflictUpdate(GymArrivalsCompanion.insert(date: date.toKey()));

  static GymLocation _location(GymLocationDbRow r) => GymLocation(
    lat: r.lat,
    lng: r.lng,
    savedAt: r.savedAt,
    enabled: r.enabled,
  );
}
