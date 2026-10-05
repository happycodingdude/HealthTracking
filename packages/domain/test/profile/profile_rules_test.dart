import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  List<ProfileField> validate({
    String height = '175',
    int? birthYear = 1996,
    Sex? sex = Sex.male,
    ActivityLevel? activity = ActivityLevel.moderate,
    String weight = '80',
  }) => ProfileRules.validate(
    height: height,
    birthYear: birthYear,
    sex: sex,
    activityLevel: activity,
    weight: weight,
    currentYear: 2026,
  );

  test('hồ sơ đủ và đúng → không có lỗi', () {
    expect(validate(), isEmpty);
  });

  test(
    'F01-AC1: thiếu thông tin bắt buộc → báo đúng ô, theo thứ tự màn hình',
    () {
      expect(
        validate(
          height: '',
          birthYear: null,
          sex: null,
          activity: null,
          weight: '',
        ),
        ProfileField.values,
      );
      expect(validate(sex: null), [ProfileField.sex]);
      expect(validate(activity: null), [ProfileField.activityLevel]);
    },
  );

  test('F01-AC2: chiều cao 119 hoặc 231 → lỗi F01-V1; 120 và 230 hợp lệ', () {
    expect(validate(height: '119'), [ProfileField.height]);
    expect(validate(height: '231'), [ProfileField.height]);
    expect(validate(height: '120'), isEmpty);
    expect(validate(height: '230'), isEmpty);
    expect(validate(height: '175,5'), [ProfileField.height]);
    expect(ProfileRules.parseHeight(' 175 '), 175);
  });

  test('F01-V2, F01-R2: tuổi = năm hiện tại − năm sinh, từ 18 đến 80', () {
    expect(ProfileRules.age(1996, 2026), 30);
    expect(validate(birthYear: 2008), isEmpty);
    expect(validate(birthYear: 2009), [ProfileField.birthYear]);
    expect(validate(birthYear: 1946), isEmpty);
    expect(validate(birthYear: 1945), [ProfileField.birthYear]);
    expect(ProfileRules.firstBirthYear(2026), 1946);
    expect(ProfileRules.lastBirthYear(2026), 2008);
  });

  test('F01-AC3: cân "72,5" hoặc "72.5" → 72,5 kg', () {
    expect(WeightRules.parseKgX10('72,5'), 725);
    expect(WeightRules.parseKgX10('72.5'), 725);
    expect(WeightRules.parseKgX10('72'), 720);
    expect(validate(weight: '72,5'), isEmpty);
    expect(validate(weight: '72.5'), isEmpty);
  });

  test('F01-V5: 30–250 kg, tối đa 1 chữ số thập phân', () {
    expect(validate(weight: '29,9'), [ProfileField.weight]);
    expect(validate(weight: '30'), isEmpty);
    expect(validate(weight: '250'), isEmpty);
    expect(validate(weight: '250,1'), [ProfileField.weight]);
    expect(validate(weight: '72,55'), [ProfileField.weight]);
    expect(validate(weight: '72,'), [ProfileField.weight]);
    expect(validate(weight: 'abc'), [ProfileField.weight]);
  });

  group('server: hồ sơ gửi lên (06 VS03-T05)', () {
    final at = DateTime.utc(2026, 10, 7, 5);
    final accepted = DateTime.utc(2026, 10, 7, 4);
    const body = Profile(
      onboardingStep: 3,
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
    );
    final step3 = Profile(
      onboardingStep: 3,
      heightCm: body.heightCm,
      birthYear: body.birthYear,
      sex: body.sex,
      activityLevel: body.activityLevel,
      disclaimerAcceptedAt: accepted,
    );

    String? check(Profile p) => ProfileRules.invalidStoredField(p, at);

    test('các bước thiết lập dở hợp lệ', () {
      expect(check(const Profile(onboardingStep: 1)), isNull);
      expect(
        check(Profile(onboardingStep: 2, disclaimerAcceptedAt: accepted)),
        isNull,
      );
      expect(check(step3), isNull);
      expect(
        check(
          step3.copyWith(
            onboardingStep: 4,
            calorieMode: CalorieMode.auto,
            calorieKcal: 2210,
          ),
        ),
        isNull,
      );
    });

    test('F10-AC1: qua bước 1 mà chưa bấm "Tôi đã hiểu" → từ chối', () {
      expect(check(const Profile(onboardingStep: 2)), 'disclaimerAcceptedAt');
    });

    test('qua bước 2 mà thiếu thông tin cơ thể → từ chối', () {
      expect(
        check(
          Profile(
            onboardingStep: 3,
            disclaimerAcceptedAt: accepted,
            heightCm: 175,
          ),
        ),
        'birthYear',
      );
    });

    test('giá trị ngoài khoảng bị từ chối', () {
      expect(check(step3.copyWith(heightCm: 231)), 'heightCm');
      expect(check(step3.copyWith(birthYear: 2010)), 'birthYear');
      expect(check(step3.copyWith(onboardingStep: 6)), 'onboardingStep');
      expect(
        check(
          step3.copyWith(
            onboardingStep: 4,
            calorieMode: CalorieMode.manual,
            calorieKcal: 799,
          ),
        ),
        'calorieKcal',
      );
      expect(
        check(
          step3.copyWith(
            onboardingStep: 4,
            calorieMode: CalorieMode.manual,
            calorieKcal: 5001,
          ),
        ),
        'calorieKcal',
      );
      expect(
        check(
          step3.copyWith(
            onboardingStep: 4,
            calorieMode: CalorieMode.auto,
            calorieKcal: 1490,
          ),
        ),
        'calorieKcal',
        reason: 'Tự động không bao giờ dưới ngưỡng an toàn (F02-R2)',
      );
    });

    test('qua 80 tuổi vẫn hợp lệ (F01-V2 chỉ áp dụng khi nhập)', () {
      expect(check(step3.copyWith(birthYear: 1940)), isNull);
    });

    test('mức tự đặt dưới ngưỡng an toàn vẫn được lưu (F02-R5)', () {
      expect(
        check(
          step3.copyWith(
            onboardingStep: 4,
            calorieMode: CalorieMode.manual,
            calorieKcal: 1300,
          ),
        ),
        isNull,
      );
    });

    test('đề xuất đang chờ phải đủ số và lý do, chỉ ở chế độ Bạn tự đặt', () {
      final manual = step3.copyWith(
        onboardingStep: 4,
        calorieMode: CalorieMode.manual,
        calorieKcal: 1900,
      );
      Profile withPending(
        CalorieMode mode,
        int? kcal,
        CaloriePendingReason? r,
      ) => Profile(
        onboardingStep: manual.onboardingStep,
        heightCm: manual.heightCm,
        birthYear: manual.birthYear,
        sex: manual.sex,
        activityLevel: manual.activityLevel,
        disclaimerAcceptedAt: manual.disclaimerAcceptedAt,
        calorieMode: mode,
        calorieKcal: mode == CalorieMode.auto ? 2210 : manual.calorieKcal,
        caloriePendingKcal: kcal,
        caloriePendingReason: r,
      );
      expect(
        check(
          withPending(CalorieMode.manual, 2090, CaloriePendingReason.weight),
        ),
        isNull,
      );
      expect(
        check(withPending(CalorieMode.manual, 2090, null)),
        'caloriePendingKcal',
      );
      expect(
        check(withPending(CalorieMode.auto, 2090, CaloriePendingReason.weight)),
        'caloriePendingKcal',
      );
    });

    test('hoàn tất thiết lập cần bước 5 và ngày thiết lập', () {
      final done = step3.copyWith(
        onboardingStep: 5,
        calorieMode: CalorieMode.auto,
        calorieKcal: 2210,
        onboardingCompletedAt: at,
      );
      expect(check(done), 'onboardingCompletedAt');
      expect(check(done.copyWith(setupDate: LocalDate(2026, 10, 7))), isNull);
    });
  });
}
