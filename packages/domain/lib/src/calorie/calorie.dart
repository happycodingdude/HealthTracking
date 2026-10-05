import 'dart:math' as math;

import '../profile/profile.dart';
import '../profile/profile_rules.dart';

/// Chế độ mức calo (F-02): Tự động hoặc Bạn tự đặt.
enum CalorieMode { auto, manual }

/// Ghi chú khi mức ước tính được nâng lên ngưỡng an toàn.
enum CalorieNote {
  /// F02-E1: mức duy trì − 500 thấp hơn ngưỡng an toàn.
  raisedToSafetyFloor,

  /// F02-E2: bản thân mức duy trì đã thấp hơn ngưỡng an toàn.
  maintenanceBelowSafetyFloor,
}

/// Kết quả ước tính mức calo (F02-R1).
final class CalorieEstimate {
  const CalorieEstimate({
    required this.kcal,
    required this.maintenanceKcal,
    this.note,
  });

  /// Mức ước tính, đã làm tròn 10 kcal, không dưới ngưỡng an toàn (F02-R2).
  final int kcal;

  /// Mức duy trì làm tròn 10 kcal (dùng cho dòng giải thích ở S-04/S-52).
  final int maintenanceKcal;
  final CalorieNote? note;

  @override
  String toString() =>
      'CalorieEstimate($kcal kcal, duy trì $maintenanceKcal, $note)';
}

/// Công thức và quy tắc calo (F-02, FA-04). App và server cùng dùng (AP-4).
///
/// Mọi phép tính dùng số nguyên (năng lượng cơ bản × 100, hệ số × 1000) để app
/// và server luôn ra cùng một con số.
abstract final class CalorieRules {
  /// Bước 3: mức giảm mỡ = mức duy trì − 500.
  static const deficitKcal = 500;

  /// F02-V1: mức Bạn tự đặt.
  static const manualMin = 800;
  static const manualMax = 5000;

  /// Mức ước tính lớn nhất có thể với hồ sơ hợp lệ là 6.820 kcal (nam, 230 cm,
  /// 250 kg, 18 tuổi, vận động rất nhiều). Server dùng mốc này để kiểm tra mức
  /// ở chế độ Tự động.
  static const autoMax = 7000;

  /// Ngưỡng an toàn (FR-05): 1.200 kcal (nữ), 1.500 kcal (nam).
  static int safetyFloor(Sex sex) => switch (sex) {
    Sex.male => 1500,
    Sex.female => 1200,
  };

  /// F02-R1: ước tính theo 5 bước (Mifflin-St Jeor). [age] = năm hiện tại −
  /// năm sinh (F01-R2); [weightKgX10] là số cân mới nhất (F07-R4).
  static CalorieEstimate estimate({
    required int heightCm,
    required int weightKgX10,
    required int age,
    required Sex sex,
    required ActivityLevel activity,
  }) {
    // Bước 1, đơn vị 1/100 kcal: 10 × kg + 6,25 × cm − 5 × tuổi ± hằng số.
    final bmr100 =
        weightKgX10 * 100 +
        625 * heightCm -
        500 * age +
        (sex == Sex.male ? 500 : -16100);
    // Bước 2, đơn vị 1/100.000 kcal.
    final maintenance = bmr100 * activity.factorPerMille;
    // Bước 3.
    final deficit = maintenance - deficitKcal * _unit;
    // Bước 4.
    final floor = safetyFloor(sex) * _unit;
    final note = maintenance < floor
        ? CalorieNote.maintenanceBelowSafetyFloor
        : deficit < floor
        ? CalorieNote.raisedToSafetyFloor
        : null;
    // Bước 5.
    return CalorieEstimate(
      kcal: _round10(math.max(deficit, floor)),
      maintenanceKcal: _round10(maintenance),
      note: note,
    );
  }

  /// Ước tính từ hồ sơ và số cân mới nhất. null khi hồ sơ chưa đủ thông tin
  /// cơ thể (bước 2 chưa xong).
  static CalorieEstimate? forProfile(
    Profile p, {
    required int? weightKgX10,
    required int currentYear,
  }) {
    if (!p.hasBody || weightKgX10 == null) return null;
    return estimate(
      heightCm: p.heightCm!,
      weightKgX10: weightKgX10,
      age: ProfileRules.age(p.birthYear!, currentYear),
      sex: p.sex!,
      activity: p.activityLevel!,
    );
  }

  static const _unit = 100000;

  /// Làm tròn đến 10 kcal gần nhất (nửa lên) từ đơn vị 1/100.000 kcal. Giá trị
  /// luôn dương với hồ sơ hợp lệ (năng lượng cơ bản nhỏ nhất ≈ 489 kcal).
  static int _round10(int value) {
    const ten = 10 * _unit;
    return (math.max(0, value) + ten ~/ 2) ~/ ten * 10;
  }

  /// F02-R6: mức calo dùng cho thực đơn.
  static int menuKcal(int userKcal, Sex sex) =>
      math.max(userKcal, safetyFloor(sex));

  /// F02-R5: mức Bạn tự đặt thấp hơn ngưỡng an toàn.
  static bool isBelowSafetyFloor(int kcal, Sex sex) => kcal < safetyFloor(sex);

  /// F02-V1.
  static bool isValidManual(int? kcal) =>
      kcal != null && kcal >= manualMin && kcal <= manualMax;

  static final _kcal = RegExp(r'^\d{1,3}(\.?\d{3})*$|^\d+$');

  /// Đọc mức calo Bạn gõ, nhận dấu chấm phân cách hàng nghìn ("1.300").
  static int? parseKcal(String input) {
    final s = input.trim();
    if (!_kcal.hasMatch(s)) return null;
    return int.tryParse(s.replaceAll('.', ''));
  }

  /// "Thấp hơn mức duy trì khoảng {N} kcal" (S-04, S-52): N làm tròn 10 kcal.
  /// null khi mức calo không thấp hơn mức duy trì.
  static int? belowMaintenance(int maintenanceKcal, int kcal) {
    final gap = (maintenanceKcal - kcal + 5) ~/ 10 * 10;
    return gap > 0 ? gap : null;
  }
}
