import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('F02-AC1: nam 30t 175cm 80kg vận động vừa → 2.210 kcal', () {
    final e = CalorieRules.estimate(
      heightCm: 175,
      weightKgX10: 800,
      age: 30,
      sex: Sex.male,
      activity: ActivityLevel.moderate,
    );
    expect(e.kcal, 2210);
    expect(e.maintenanceKcal, 2710);
    expect(e.note, isNull);
    expect(CalorieRules.belowMaintenance(e.maintenanceKcal, e.kcal), 500);
  });

  test('F02-AC2: nữ 55t 150cm 45kg ít vận động → 1.200 kcal kèm ghi chú '
      'F02-E2', () {
    final e = CalorieRules.estimate(
      heightCm: 150,
      weightKgX10: 450,
      age: 55,
      sex: Sex.female,
      activity: ActivityLevel.sedentary,
    );
    expect(e.kcal, 1200);
    expect(e.note, CalorieNote.maintenanceBelowSafetyFloor);
    expect(CalorieRules.belowMaintenance(e.maintenanceKcal, e.kcal), isNull);
  });

  test('F02-E1: mức duy trì − 500 dưới ngưỡng, mức duy trì trên ngưỡng → '
      'ngưỡng an toàn kèm ghi chú E1', () {
    // Nữ 40t 160cm 55kg ít vận động: BMR 1.189 × 1,2 = 1.426,8; − 500 = 926,8.
    final e = CalorieRules.estimate(
      heightCm: 160,
      weightKgX10: 550,
      age: 40,
      sex: Sex.female,
      activity: ActivityLevel.sedentary,
    );
    expect(e.kcal, 1200);
    expect(e.maintenanceKcal, 1430);
    expect(e.note, CalorieNote.raisedToSafetyFloor);
    expect(CalorieRules.belowMaintenance(e.maintenanceKcal, e.kcal), 230);
  });

  test('F02-R2: mức ước tính không bao giờ dưới ngưỡng an toàn', () {
    for (final sex in Sex.values) {
      for (final activity in ActivityLevel.values) {
        final e = CalorieRules.estimate(
          heightCm: 120,
          weightKgX10: 300,
          age: 80,
          sex: sex,
          activity: activity,
        );
        expect(e.kcal, greaterThanOrEqualTo(CalorieRules.safetyFloor(sex)));
      }
    }
  });

  test('5 hệ số vận động FA-04 và bước 5 làm tròn 10 kcal gần nhất', () {
    expect(ActivityLevel.values.map((a) => a.factorPerMille), [
      1200,
      1375,
      1550,
      1725,
      1900,
    ]);
    // Nam 25t 180cm 75,3kg vận động nhiều: BMR 1.758 × 1,725 = 3.032,55;
    // − 500 = 2.532,55 → 2.530.
    expect(
      CalorieRules.estimate(
        heightCm: 180,
        weightKgX10: 753,
        age: 25,
        sex: Sex.male,
        activity: ActivityLevel.active,
      ).kcal,
      2530,
    );
    // Nam 30t 175cm 81kg vận động vừa: 1.758,75 × 1,55 = 2.726,06; − 500 =
    // 2.226,06 → 2.230 (làm tròn lên khi ≥ 5).
    expect(
      CalorieRules.estimate(
        heightCm: 175,
        weightKgX10: 810,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
      ).kcal,
      2230,
    );
  });

  test('mức ước tính lớn nhất với hồ sơ hợp lệ không vượt autoMax', () {
    final e = CalorieRules.estimate(
      heightCm: ProfileRules.maxHeightCm,
      weightKgX10: WeightRules.maxKgX10,
      age: ProfileRules.minAge,
      sex: Sex.male,
      activity: ActivityLevel.veryActive,
    );
    expect(e.kcal, 6820);
    expect(e.kcal, lessThanOrEqualTo(CalorieRules.autoMax));
  });

  test('F02-AC3: Bạn tự đặt 1.300 kcal (nam) → dưới ngưỡng, vẫn hợp lệ, '
      'thực đơn dùng 1.500 kcal', () {
    expect(CalorieRules.isValidManual(1300), isTrue);
    expect(CalorieRules.isBelowSafetyFloor(1300, Sex.male), isTrue);
    expect(CalorieRules.menuKcal(1300, Sex.male), 1500);
    expect(CalorieRules.menuKcal(2210, Sex.male), 2210);
    expect(CalorieRules.isBelowSafetyFloor(1200, Sex.female), isFalse);
  });

  test('F02-V1: mức tự đặt là số nguyên 800–5.000', () {
    expect(CalorieRules.isValidManual(799), isFalse);
    expect(CalorieRules.isValidManual(800), isTrue);
    expect(CalorieRules.isValidManual(5000), isTrue);
    expect(CalorieRules.isValidManual(5001), isFalse);
    expect(CalorieRules.isValidManual(null), isFalse);
    expect(CalorieRules.parseKcal('1.300'), 1300);
    expect(CalorieRules.parseKcal(' 1900 '), 1900);
    expect(CalorieRules.parseKcal('1300,5'), isNull);
    expect(CalorieRules.parseKcal('13.00'), isNull);
    expect(CalorieRules.parseKcal(''), isNull);
  });

  test('S-52: "Thấp hơn mức duy trì khoảng 690 kcal" khi Bạn tự đặt 1.900', () {
    expect(CalorieRules.belowMaintenance(2590, 1900), 690);
    expect(CalorieRules.belowMaintenance(2590, 1955), 640);
    expect(CalorieRules.belowMaintenance(2590, 2600), isNull);
  });

  test('forProfile: dùng tuổi theo năm hiện tại; hồ sơ chưa đủ → null', () {
    const p = Profile(
      onboardingStep: 3,
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
    );
    expect(
      CalorieRules.forProfile(p, weightKgX10: 800, currentYear: 2026)!.kcal,
      2210,
    );
    // F01-E2: sang năm mới tuổi tăng 1 → năng lượng cơ bản giảm 5 kcal.
    expect(
      CalorieRules.forProfile(p, weightKgX10: 800, currentYear: 2027)!.kcal,
      2200,
    );
    expect(
      CalorieRules.forProfile(
        const Profile(onboardingStep: 2),
        weightKgX10: 800,
        currentYear: 2026,
      ),
      isNull,
    );
    expect(
      CalorieRules.forProfile(p, weightKgX10: null, currentYear: 2026),
      isNull,
    );
  });
}
