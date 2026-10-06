import '../calorie/calorie.dart';
import '../time/local_date.dart';

/// Giới tính (F-01). Cần cho công thức calo và ngưỡng an toàn.
enum Sex { male, female }

/// 5 mức vận động (F-01, FA-04). Hệ số tính bằng phần nghìn để app và server
/// ra cùng một con số (không dùng số thực).
enum ActivityLevel {
  sedentary(1200),
  light(1375),
  moderate(1550),
  active(1725),
  veryActive(1900);

  const ActivityLevel(this.factorPerMille);

  /// Hệ số vận động × 1000 (1,55 → 1550).
  final int factorPerMille;
}

/// Lý do của đề xuất calo đang chờ (F02-R9): chọn câu đầu của S-53.
enum CaloriePendingReason { weight, profile }

/// Hồ sơ của Bạn (entity `profile`, key `me`, 06 §6.5.1). Các trường của bước
/// chưa làm tới là null (thiết lập lần đầu, OB-3).
final class Profile {
  const Profile({
    required this.onboardingStep,
    this.heightCm,
    this.birthYear,
    this.sex,
    this.activityLevel,
    this.setupDate,
    this.disclaimerAcceptedAt,
    this.onboardingCompletedAt,
    this.calorieMode,
    this.calorieKcal,
    this.caloriePendingKcal,
    this.caloriePendingReason,
    this.remindersEnabled = false,
    this.timezone,
  });

  /// Bước thiết lập đang dở, 1–5 (OB-3, OB-6).
  final int onboardingStep;
  final int? heightCm;
  final int? birthYear;
  final Sex? sex;
  final ActivityLevel? activityLevel;

  /// Ngày hoàn tất thiết lập (F06-R5, F07-R2).
  final LocalDate? setupDate;

  /// Thời điểm bấm "Tôi đã hiểu" (F10-AC1).
  final DateTime? disclaimerAcceptedAt;
  final DateTime? onboardingCompletedAt;
  final CalorieMode? calorieMode;

  /// Mức calo của Bạn (con số hiển thị).
  final int? calorieKcal;
  final int? caloriePendingKcal;
  final CaloriePendingReason? caloriePendingReason;
  final bool remindersEnabled;

  /// Múi giờ IANA của iPhone.
  final String? timezone;

  bool get isOnboardingCompleted => onboardingCompletedAt != null;

  /// Đã có đủ thông tin cơ thể (bước 2) để ước tính calo.
  bool get hasBody =>
      heightCm != null &&
      birthYear != null &&
      sex != null &&
      activityLevel != null;

  Profile copyWith({
    int? onboardingStep,
    int? heightCm,
    int? birthYear,
    Sex? sex,
    ActivityLevel? activityLevel,
    LocalDate? setupDate,
    DateTime? disclaimerAcceptedAt,
    DateTime? onboardingCompletedAt,
    CalorieMode? calorieMode,
    int? calorieKcal,
    bool? remindersEnabled,
    String? timezone,
  }) => Profile(
    onboardingStep: onboardingStep ?? this.onboardingStep,
    heightCm: heightCm ?? this.heightCm,
    birthYear: birthYear ?? this.birthYear,
    sex: sex ?? this.sex,
    activityLevel: activityLevel ?? this.activityLevel,
    setupDate: setupDate ?? this.setupDate,
    disclaimerAcceptedAt: disclaimerAcceptedAt ?? this.disclaimerAcceptedAt,
    onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
    calorieMode: calorieMode ?? this.calorieMode,
    calorieKcal: calorieKcal ?? this.calorieKcal,
    caloriePendingKcal: caloriePendingKcal,
    caloriePendingReason: caloriePendingReason,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    timezone: timezone ?? this.timezone,
  );

  /// Bản sao với đề xuất mức calo đang chờ (F02-R9, F02-E3); null = không
  /// có đề xuất.
  Profile withPending(int? kcal, CaloriePendingReason? reason) => Profile(
    onboardingStep: onboardingStep,
    heightCm: heightCm,
    birthYear: birthYear,
    sex: sex,
    activityLevel: activityLevel,
    setupDate: setupDate,
    disclaimerAcceptedAt: disclaimerAcceptedAt,
    onboardingCompletedAt: onboardingCompletedAt,
    calorieMode: calorieMode,
    calorieKcal: calorieKcal,
    caloriePendingKcal: kcal,
    caloriePendingReason: kcal == null ? null : reason,
    remindersEnabled: remindersEnabled,
    timezone: timezone,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.onboardingStep == onboardingStep &&
      other.heightCm == heightCm &&
      other.birthYear == birthYear &&
      other.sex == sex &&
      other.activityLevel == activityLevel &&
      other.setupDate == setupDate &&
      other.disclaimerAcceptedAt == disclaimerAcceptedAt &&
      other.onboardingCompletedAt == onboardingCompletedAt &&
      other.calorieMode == calorieMode &&
      other.calorieKcal == calorieKcal &&
      other.caloriePendingKcal == caloriePendingKcal &&
      other.caloriePendingReason == caloriePendingReason &&
      other.remindersEnabled == remindersEnabled &&
      other.timezone == timezone;

  @override
  int get hashCode => Object.hash(
    onboardingStep,
    heightCm,
    birthYear,
    sex,
    activityLevel,
    setupDate,
    disclaimerAcceptedAt,
    onboardingCompletedAt,
    calorieMode,
    calorieKcal,
    caloriePendingKcal,
    caloriePendingReason,
    remindersEnabled,
    timezone,
  );
}
