import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';
import 'sync_entities.dart';

/// Giá trị enum trong API và PostgreSQL (snake_case, 05 §6.7.3).
abstract final class ProfileWire {
  static const sex = {Sex.male: 'male', Sex.female: 'female'};
  static const activityLevel = {
    ActivityLevel.sedentary: 'sedentary',
    ActivityLevel.light: 'light',
    ActivityLevel.moderate: 'moderate',
    ActivityLevel.active: 'active',
    ActivityLevel.veryActive: 'very_active',
  };
  static const calorieMode = {
    CalorieMode.auto: 'auto',
    CalorieMode.manual: 'manual',
  };
  static const pendingReason = {
    CaloriePendingReason.weight: 'weight',
    CaloriePendingReason.profile: 'profile',
  };

  static T? decode<T>(Map<T, String> wire, JsonReader r, String key) =>
      parse(wire, r.optString(key), key);

  /// Giá trị enum từ chuỗi [value] (null → null). Giá trị lạ → lỗi theo [key].
  static T? parse<T>(Map<T, String> wire, String? value, String key) {
    if (value == null) return null;
    for (final e in wire.entries) {
      if (e.value == value) return e.key;
    }
    throw ContractFormatException(key, 'giá trị lạ: $value');
  }
}

/// Entity `profile`, key `me` (06 §6.5.1). Mọi khóa luôn có mặt, trường chưa
/// có giá trị là null.
final class ProfileCodec implements EntityCodec<Profile> {
  const ProfileCodec();

  static const key = 'me';

  @override
  String get entity => SyncEntities.profile;

  @override
  Profile decode(Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    DateTime? instant(String k) =>
        r.has(k) ? r.decoded(k, InstantCodec.decode) : null;
    return Profile(
      onboardingStep: r.integer('onboardingStep'),
      heightCm: r.optInteger('heightCm'),
      birthYear: r.optInteger('birthYear'),
      sex: ProfileWire.decode(ProfileWire.sex, r, 'sex'),
      activityLevel: ProfileWire.decode(
        ProfileWire.activityLevel,
        r,
        'activityLevel',
      ),
      setupDate: r.has('setupDate')
          ? r.decoded('setupDate', DateCodec.decode)
          : null,
      disclaimerAcceptedAt: instant('disclaimerAcceptedAt'),
      onboardingCompletedAt: instant('onboardingCompletedAt'),
      calorieMode: ProfileWire.decode(
        ProfileWire.calorieMode,
        r,
        'calorieMode',
      ),
      calorieKcal: r.optInteger('calorieKcal'),
      caloriePendingKcal: r.optInteger('caloriePendingKcal'),
      caloriePendingReason: ProfileWire.decode(
        ProfileWire.pendingReason,
        r,
        'caloriePendingReason',
      ),
      remindersEnabled: r.optBoolean('remindersEnabled') ?? false,
      timezone: r.optString('timezone'),
    );
  }

  @override
  Map<String, Object?> encode(Profile p) => {
    'heightCm': p.heightCm,
    'birthYear': p.birthYear,
    'sex': ProfileWire.sex[p.sex],
    'activityLevel': ProfileWire.activityLevel[p.activityLevel],
    'setupDate': p.setupDate == null ? null : DateCodec.encode(p.setupDate!),
    'onboardingStep': p.onboardingStep,
    'disclaimerAcceptedAt': p.disclaimerAcceptedAt == null
        ? null
        : InstantCodec.encode(p.disclaimerAcceptedAt!.toUtc()),
    'onboardingCompletedAt': p.onboardingCompletedAt == null
        ? null
        : InstantCodec.encode(p.onboardingCompletedAt!.toUtc()),
    'calorieMode': ProfileWire.calorieMode[p.calorieMode],
    'calorieKcal': p.calorieKcal,
    'caloriePendingKcal': p.caloriePendingKcal,
    'caloriePendingReason': ProfileWire.pendingReason[p.caloriePendingReason],
    'remindersEnabled': p.remindersEnabled,
    'timezone': p.timezone,
  };
}

/// Entity `weight`, key `YYYY-MM-DD` (thứ 2 của tuần, FR-11).
final class WeightData {
  const WeightData({required this.weightKgX10});

  final int weightKgX10;

  @override
  bool operator ==(Object other) =>
      other is WeightData && other.weightKgX10 == weightKgX10;

  @override
  int get hashCode => weightKgX10.hashCode;
}

final class WeightCodec implements EntityCodec<WeightData> {
  const WeightCodec();

  @override
  String get entity => SyncEntities.weight;

  @override
  WeightData decode(Map<String, Object?> data) => WeightData(
    weightKgX10: JsonReader(data, path: 'data').integer('weightKgX10'),
  );

  @override
  Map<String, Object?> encode(WeightData value) => {
    'weightKgX10': value.weightKgX10,
  };
}
