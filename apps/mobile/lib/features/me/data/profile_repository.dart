import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `profile` (key `me`, VS-03).
final class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$ProfilesTable, ProfileRow> get _me =>
      _db.select(_db.profiles)..where((p) => p.key.equals(ProfileCodec.key));

  /// Hồ sơ; cập nhật ngay sau mỗi lần ghi (P6). null khi chưa có.
  Stream<Profile?> watch() => _me.watchSingleOrNull().map(
    (row) => row == null ? null : _toProfile(row),
  );

  Future<Profile?> get() async {
    final row = await _me.getSingleOrNull();
    return row == null ? null : _toProfile(row);
  }

  /// Ghi bản trên máy (không qua outbox). Dùng trong use case và khi áp dụng
  /// dữ liệu từ server.
  Future<void> put(Profile p) => _db
      .into(_db.profiles)
      .insertOnConflictUpdate(
        ProfilesCompanion.insert(
          key: ProfileCodec.key,
          onboardingStep: p.onboardingStep,
          heightCm: Value(p.heightCm),
          birthYear: Value(p.birthYear),
          sex: Value(ProfileWire.sex[p.sex]),
          activityLevel: Value(ProfileWire.activityLevel[p.activityLevel]),
          setupDate: Value(p.setupDate?.toKey()),
          scheduleStartedOn: Value(p.scheduleStartedOn?.toKey()),
          disclaimerAcceptedAt: Value(p.disclaimerAcceptedAt),
          onboardingCompletedAt: Value(p.onboardingCompletedAt),
          calorieMode: Value(ProfileWire.calorieMode[p.calorieMode]),
          calorieKcal: Value(p.calorieKcal),
          caloriePendingKcal: Value(p.caloriePendingKcal),
          caloriePendingReason: Value(
            ProfileWire.pendingReason[p.caloriePendingReason],
          ),
          remindersEnabled: Value(p.remindersEnabled),
          timezone: Value(p.timezone),
        ),
      );

  Future<void> delete() => (_db.delete(
    _db.profiles,
  )..where((p) => p.key.equals(ProfileCodec.key))).go();

  static Profile _toProfile(ProfileRow r) => Profile(
    onboardingStep: r.onboardingStep,
    heightCm: r.heightCm,
    birthYear: r.birthYear,
    sex: ProfileWire.parse(ProfileWire.sex, r.sex, 'sex'),
    activityLevel: ProfileWire.parse(
      ProfileWire.activityLevel,
      r.activityLevel,
      'activityLevel',
    ),
    setupDate: r.setupDate == null ? null : LocalDate.parse(r.setupDate!),
    scheduleStartedOn: r.scheduleStartedOn == null
        ? null
        : LocalDate.parse(r.scheduleStartedOn!),
    disclaimerAcceptedAt: r.disclaimerAcceptedAt,
    onboardingCompletedAt: r.onboardingCompletedAt,
    calorieMode: ProfileWire.parse(
      ProfileWire.calorieMode,
      r.calorieMode,
      'calorieMode',
    ),
    calorieKcal: r.calorieKcal,
    caloriePendingKcal: r.caloriePendingKcal,
    caloriePendingReason: ProfileWire.parse(
      ProfileWire.pendingReason,
      r.caloriePendingReason,
      'caloriePendingReason',
    ),
    remindersEnabled: r.remindersEnabled,
    timezone: r.timezone,
  );
}
