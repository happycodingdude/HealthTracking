import '../calorie/calorie.dart';
import '../weight/weight_rules.dart';
import 'profile.dart';

/// Ô nhập của hồ sơ (S-03), theo thứ tự trên màn hình.
enum ProfileField { height, birthYear, sex, activityLevel, weight }

/// Quy tắc hồ sơ (F-01). App và server cùng dùng (AP-4).
abstract final class ProfileRules {
  /// F01-V1.
  static const minHeightCm = 120;
  static const maxHeightCm = 230;

  /// F01-V2.
  static const minAge = 18;
  static const maxAge = 80;

  /// Số bước của thiết lập lần đầu (OB-1).
  static const onboardingSteps = 5;

  static final _height = RegExp(r'^\d{1,3}$');

  /// F01-R2: tuổi = năm hiện tại − năm sinh.
  static int age(int birthYear, int currentYear) => currentYear - birthYear;

  /// Chiều cao là số nguyên (F01-V1). null nếu không đọc được.
  static int? parseHeight(String input) {
    final s = input.trim();
    return _height.hasMatch(s) ? int.parse(s) : null;
  }

  static bool isValidHeight(int? cm) =>
      cm != null && cm >= minHeightCm && cm <= maxHeightCm;

  /// F01-V2: tuổi tính ra từ 18 đến 80.
  static bool isValidBirthYear(int? birthYear, int currentYear) {
    if (birthYear == null) return false;
    final a = age(birthYear, currentYear);
    return a >= minAge && a <= maxAge;
  }

  /// Năm đầu và năm cuối của bánh xe năm sinh (S-03): tuổi 80 → 18.
  static int firstBirthYear(int currentYear) => currentYear - maxAge;
  static int lastBirthYear(int currentYear) => currentYear - minAge;

  /// S-03: các ô sai, theo thứ tự trên màn hình. Rỗng = hợp lệ (F01-AC1).
  static List<ProfileField> validate({
    required String height,
    required int? birthYear,
    required Sex? sex,
    required ActivityLevel? activityLevel,
    required String? weight,
    required int currentYear,
  }) => [
    if (!isValidHeight(parseHeight(height))) ProfileField.height,
    if (!isValidBirthYear(birthYear, currentYear)) ProfileField.birthYear,
    if (sex == null) ProfileField.sex,
    if (activityLevel == null) ProfileField.activityLevel,
    // Sửa hồ sơ (S-51) không có ô cân nặng (F01-R4): [weight] null.
    if (weight != null && !WeightRules.isValidInput(weight))
      ProfileField.weight,
  ];

  /// Kiểm tra hồ sơ được gửi lên server (06 VS03-T05). Trả tên trường sai
  /// (theo hợp đồng `profile`), null = hợp lệ.
  ///
  /// [at] là `clientUpdatedAt` của mutation. Năm sinh chỉ bị chặn khi chưa đủ
  /// 18 tuổi: F01-V2 là quy tắc lúc nhập, Bạn vẫn dùng app khi qua 80 tuổi.
  /// Cho phép lệch 1 năm vì [at] là giờ UTC còn tuổi tính theo giờ iPhone.
  static String? invalidStoredField(Profile p, DateTime at) {
    if (p.onboardingStep < 1 || p.onboardingStep > onboardingSteps) {
      return 'onboardingStep';
    }
    if (p.heightCm != null && !isValidHeight(p.heightCm)) return 'heightCm';
    final birthYear = p.birthYear;
    if (birthYear != null &&
        (birthYear < 1900 || age(birthYear, at.toUtc().year + 1) < minAge)) {
      return 'birthYear';
    }
    if (p.onboardingStep >= 2 && p.disclaimerAcceptedAt == null) {
      return 'disclaimerAcceptedAt';
    }
    if (p.onboardingStep >= 3 && !p.hasBody) {
      return p.heightCm == null
          ? 'heightCm'
          : p.birthYear == null
          ? 'birthYear'
          : p.sex == null
          ? 'sex'
          : 'activityLevel';
    }
    if (p.onboardingStep >= 4 &&
        (p.calorieMode == null || p.calorieKcal == null)) {
      return 'calorieKcal';
    }
    final kcal = p.calorieKcal;
    if (kcal != null) {
      final sex = p.sex;
      final ok = switch (p.calorieMode) {
        CalorieMode.manual => CalorieRules.isValidManual(kcal),
        CalorieMode.auto =>
          sex != null &&
              kcal >= CalorieRules.safetyFloor(sex) &&
              kcal <= CalorieRules.autoMax,
        null => false,
      };
      if (!ok) return 'calorieKcal';
    }
    // Đề xuất đang chờ (F02-R9) chỉ có ở chế độ Bạn tự đặt, đủ cả số và lý do.
    final pending = p.caloriePendingKcal;
    if ((pending == null) != (p.caloriePendingReason == null)) {
      return 'caloriePendingKcal';
    }
    if (pending != null &&
        (p.calorieMode != CalorieMode.manual ||
            p.sex == null ||
            pending < CalorieRules.safetyFloor(p.sex!) ||
            pending > CalorieRules.autoMax)) {
      return 'caloriePendingKcal';
    }
    if (p.onboardingCompletedAt != null &&
        (p.onboardingStep != onboardingSteps || p.setupDate == null)) {
      return 'onboardingCompletedAt';
    }
    final tz = p.timezone;
    if (tz != null && (tz.isEmpty || tz.length > 64)) return 'timezone';
    return null;
  }
}
