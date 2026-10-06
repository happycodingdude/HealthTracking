import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // F02-AC1: nam, 1996, 175 cm, vận động vừa; 80 kg → 2.210 kcal.
  final base = Profile(
    onboardingStep: 5,
    disclaimerAcceptedAt: DateTime.utc(2026, 10, 7),
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    calorieMode: CalorieMode.auto,
    calorieKcal: 2210,
  );

  int estimate(Profile p, int kgX10, {int year = 2026}) =>
      CalorieRules.forProfile(p, weightKgX10: kgX10, currentYear: year)!.kcal;

  test('F02-AC4, F02-R8: Tự động, ghi cân mới 72,5 kg → cập nhật ngay từ '
      '2.210 thành 2.090 kcal', () {
    final after = estimate(base, 725);
    expect(after, 2090);
    final r = CalorieRecalc.apply(
      profile: base,
      before: 2210,
      after: after,
      reason: CaloriePendingReason.weight,
    );
    expect(r.profile!.calorieKcal, 2090);
    expect(r.profile!.calorieMode, CalorieMode.auto);
    expect(r.outcome, isA<CalorieAutoUpdated>());
    final o = r.outcome as CalorieAutoUpdated;
    expect((o.from, o.to), (2210, 2090));
  });

  test('F02-R10: chênh dưới 10 kcal → không thông báo, không đề xuất', () {
    // 80,0 → 80,1 kg: 2.210 → 2.210 (cùng mức sau làm tròn).
    final same = CalorieRecalc.apply(
      profile: base,
      before: 2210,
      after: estimate(base, 801),
      reason: CaloriePendingReason.weight,
    );
    expect(same.profile, isNull);
    expect(same.outcome, isA<CalorieUnchanged>());

    final manual = base.copyWith(
      calorieMode: CalorieMode.manual,
      calorieKcal: 1900,
    );
    final small = CalorieRecalc.apply(
      profile: manual,
      before: 2210,
      after: 2215,
      reason: CaloriePendingReason.weight,
    );
    expect(small.profile, isNull);
    expect(small.outcome, isA<CalorieUnchanged>());

    final autoSmall = CalorieRecalc.apply(
      profile: base,
      before: 2210,
      after: 2205,
      reason: CaloriePendingReason.weight,
    );
    expect(autoSmall.profile!.calorieKcal, 2205, reason: 'vẫn bằng ước tính');
    expect(autoSmall.outcome, isA<CalorieUnchanged>());
  });

  test('F02-AC5, F02-R9: Bạn tự đặt 1.900, ghi cân mới → đề xuất 2.090; Giữ '
      'nguyên → con số không đổi; Đồng ý → về Tự động', () {
    final manual = base.copyWith(
      calorieMode: CalorieMode.manual,
      calorieKcal: 1900,
    );
    final r = CalorieRecalc.apply(
      profile: manual,
      before: 2210,
      after: 2090,
      reason: CaloriePendingReason.weight,
    );
    final proposed = r.outcome as CalorieProposed;
    expect((proposed.kcal, proposed.current), (2090, 1900));
    final pending = r.profile!;
    expect(pending.calorieKcal, 1900);
    expect(
      (pending.caloriePendingKcal, pending.caloriePendingReason),
      (2090, CaloriePendingReason.weight),
    );
    expect(
      ProfileRules.invalidStoredField(pending, DateTime.utc(2026)),
      isNull,
    );

    final kept = CalorieRecalc.keepManual(pending);
    expect((kept.calorieMode, kept.calorieKcal), (CalorieMode.manual, 1900));
    expect(kept.caloriePendingKcal, isNull);

    final accepted = CalorieRecalc.useEstimate(pending, 2090);
    expect(
      (accepted.calorieMode, accepted.calorieKcal),
      (CalorieMode.auto, 2090),
    );
    expect(accepted.caloriePendingReason, isNull);
  });

  test('F01-AC5, F01-R5: đổi mức vận động → đề xuất lý do "hồ sơ"; F02-E3: đề '
      'xuất mới thay đề xuất cũ', () {
    final manual = base
        .copyWith(calorieMode: CalorieMode.manual, calorieKcal: 1900)
        .withPending(2090, CaloriePendingReason.weight);
    final active = manual.copyWith(activityLevel: ActivityLevel.active);
    final r = CalorieRecalc.apply(
      profile: active,
      before: estimate(manual, 725),
      after: estimate(active, 725),
      reason: CaloriePendingReason.profile,
    );
    expect(r.profile!.caloriePendingReason, CaloriePendingReason.profile);
    expect(r.profile!.caloriePendingKcal, estimate(active, 725));
  });

  test('F01-E2: sang năm mới (31/12 → 01/01), tuổi tăng 1 → tính lại', () {
    final before = estimate(base, 800, year: 2026);
    final after = estimate(base, 800, year: 2027);
    expect(after, before - 10, reason: '5 kcal × 1,55 ≈ 8 → làm tròn 10');
    final r = CalorieRecalc.apply(
      profile: base,
      before: before,
      after: after,
      reason: CaloriePendingReason.profile,
    );
    expect(r.outcome, isA<CalorieAutoUpdated>());
  });

  test('"Đặt mức khác" bỏ đề xuất đang chờ (F02-R4)', () {
    final pending = base
        .copyWith(calorieMode: CalorieMode.manual, calorieKcal: 1900)
        .withPending(2090, CaloriePendingReason.weight);
    final set = CalorieRecalc.setManual(pending, 1800);
    expect((set.calorieMode, set.calorieKcal), (CalorieMode.manual, 1800));
    expect(set.caloriePendingKcal, isNull);
  });
}
