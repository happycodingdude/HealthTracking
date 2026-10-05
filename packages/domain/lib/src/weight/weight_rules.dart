import '../time/local_date.dart';

/// Quy tắc số cân (F01-V5, F07-V1, FR-11). App và server cùng dùng (AP-4).
abstract final class WeightRules {
  /// 30–250 kg, lưu dạng kg × 10 (05 §6.7.1).
  static const minKgX10 = 300;
  static const maxKgX10 = 2500;

  static final _pattern = RegExp(r'^(\d{1,3})(?:[.,](\d))?$');

  /// Đọc số cân Bạn gõ: nhận cả "," và ".", tối đa 1 chữ số thập phân
  /// (F01-AC3). "72,5" → 725. null nếu không đọc được.
  static int? parseKgX10(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final tenth = match.group(2) == null ? 0 : int.parse(match.group(2)!);
    return whole * 10 + tenth;
  }

  static bool isValidKgX10(int? kgX10) =>
      kgX10 != null && kgX10 >= minKgX10 && kgX10 <= maxKgX10;

  /// F01-V5 / F07-V1 với chuỗi Bạn gõ.
  static bool isValidInput(String input) => isValidKgX10(parseKgX10(input));

  /// Khóa của tuần chứa [date]: thứ 2 (FR-11, 06 §6.5.1).
  static LocalDate weekKey(LocalDate date) => date.weekStart;

  static bool isWeekKey(LocalDate date) => date.weekday == DateTime.monday;

  /// Tuần bắt đầu từ [weekStart] nằm sau tuần chứa [today] (F07-R2).
  static bool isFutureWeek(LocalDate weekStart, LocalDate today) =>
      weekStart.isAfter(today.weekStart);
}
