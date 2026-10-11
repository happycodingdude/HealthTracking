import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('profile khứ hồi đủ trường, đúng tên camelCase của 06 §6.5.1', () {
    final p = Profile(
      onboardingStep: 5,
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.veryActive,
      setupDate: LocalDate(2026, 10, 7),
      disclaimerAcceptedAt: DateTime.utc(2026, 10, 7, 11, 40),
      onboardingCompletedAt: DateTime.utc(2026, 10, 7, 11, 45),
      calorieMode: CalorieMode.manual,
      calorieKcal: 1900,
      caloriePendingKcal: 2090,
      caloriePendingReason: CaloriePendingReason.weight,
      remindersEnabled: true,
      timezone: 'Asia/Ho_Chi_Minh',
    );
    final json = const ProfileCodec().encode(p);
    expect(json.keys.toSet(), {
      'heightCm',
      'birthYear',
      'sex',
      'activityLevel',
      'setupDate',
      'scheduleStartedOn',
      'onboardingStep',
      'disclaimerAcceptedAt',
      'onboardingCompletedAt',
      'calorieMode',
      'calorieKcal',
      'caloriePendingKcal',
      'caloriePendingReason',
      'remindersEnabled',
      'timezone',
    });
    expect(json['activityLevel'], 'very_active');
    expect(json['setupDate'], '2026-10-07');
    expect(json['disclaimerAcceptedAt'], '2026-10-07T11:40:00.000Z');
    expect(const ProfileCodec().decode(json), p);
  });

  test('profile thiết lập dở: trường chưa có là null', () {
    const p = Profile(onboardingStep: 1);
    final json = const ProfileCodec().encode(p);
    expect(json['heightCm'], isNull);
    expect(json['remindersEnabled'], isFalse);
    expect(const ProfileCodec().decode(json), p);
  });

  test('profile: enum lạ hoặc thời điểm không có múi giờ bị từ chối', () {
    final json = const ProfileCodec().encode(const Profile(onboardingStep: 1));
    expect(
      () => const ProfileCodec().decode({...json, 'sex': 'other'}),
      throwsA(
        isA<ContractFormatException>().having((e) => e.field, 'field', 'sex'),
      ),
    );
    expect(
      () => const ProfileCodec().decode({
        ...json,
        'disclaimerAcceptedAt': '2026-10-07T11:40:00',
      }),
      throwsA(
        isA<ContractFormatException>().having(
          (e) => e.field,
          'field',
          'data.disclaimerAcceptedAt',
        ),
      ),
    );
  });

  test('weight khứ hồi; codec có trong registry', () {
    const w = WeightData(weightKgX10: 725);
    expect(const WeightCodec().encode(w), {'weightKgX10': 725});
    expect(const WeightCodec().decode({'weightKgX10': 725}), w);
    expect(
      SyncEntities.codecs.keys,
      containsAll(['account', 'profile', 'weight']),
    );
  });

  group('Bản 2: scheduleStartedOn (06 Bản 2 §6.5.1)', () {
    final base = Profile(
      onboardingStep: 5,
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
      setupDate: LocalDate(2026, 10, 7),
      scheduleStartedOn: LocalDate(2026, 10, 14),
      disclaimerAcceptedAt: DateTime.utc(2026, 10, 7, 11, 40),
      onboardingCompletedAt: DateTime.utc(2026, 10, 7, 11, 45),
      calorieMode: CalorieMode.auto,
      calorieKcal: 2210,
    );

    test(
      'khứ hồi; mốc lịch = scheduleStartedOn khi có, setupDate khi không',
      () {
        final json = const ProfileCodec().encode(base);
        expect(json['scheduleStartedOn'], '2026-10-14');
        final back = const ProfileCodec().decode(json);
        expect(back, base);
        expect(back.scheduleStart, LocalDate(2026, 10, 14));
      },
    );

    test('TA2-01: dữ liệu của app Bản 1 (không có trường) đọc được, '
        'scheduleStartedOn = null', () {
      final json = const ProfileCodec().encode(base)
        ..remove('scheduleStartedOn');
      final p = const ProfileCodec().decode(json);
      expect(p.scheduleStartedOn, isNull);
      expect(p.scheduleStart, LocalDate(2026, 10, 7));
    });
  });
}
