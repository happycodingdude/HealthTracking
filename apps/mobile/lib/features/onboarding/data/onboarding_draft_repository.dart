import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Thông tin đang nhập ở S-03, giữ nguyên chuỗi Bạn gõ (04 §6.13.5).
final class ProfileDraft {
  const ProfileDraft({
    this.height = '',
    this.birthYear,
    this.sex,
    this.activityLevel,
    this.weight = '',
  });

  final String height;
  final int? birthYear;
  final Sex? sex;
  final ActivityLevel? activityLevel;
  final String weight;
}

/// Nháp của bước 2 (OB-3): lưu mỗi lần Bạn đổi một ô, chỉ nằm trên máy.
final class OnboardingDraftRepository {
  OnboardingDraftRepository(this._db);

  final AppDatabase _db;

  Future<ProfileDraft?> get() async {
    final r = await _db.select(_db.onboardingDraft).getSingleOrNull();
    if (r == null) return null;
    return ProfileDraft(
      height: r.height,
      birthYear: r.birthYear,
      sex: ProfileWire.parse(ProfileWire.sex, r.sex, 'sex'),
      activityLevel: ProfileWire.parse(
        ProfileWire.activityLevel,
        r.activityLevel,
        'activityLevel',
      ),
      weight: r.weight,
    );
  }

  Future<void> save(ProfileDraft d) => _db
      .into(_db.onboardingDraft)
      .insertOnConflictUpdate(
        OnboardingDraftCompanion.insert(
          id: const Value(1),
          height: Value(d.height),
          birthYear: Value(d.birthYear),
          sex: Value(ProfileWire.sex[d.sex]),
          activityLevel: Value(ProfileWire.activityLevel[d.activityLevel]),
          weight: Value(d.weight),
        ),
      );

  Future<void> clear() => _db.delete(_db.onboardingDraft).go();
}
