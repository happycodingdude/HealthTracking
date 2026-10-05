import 'package:domain/domain.dart';

import '../app/strings_vi.dart';

/// Định dạng kiểu Việt Nam (UR-10): `72,5 kg` · `2.210 kcal` · `07/10` ·
/// `18:00` · `50.000đ`.
abstract final class Fmt {
  /// Số nguyên có dấu chấm ngăn cách hàng nghìn: 2210 → `2.210`.
  static String integer(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }

  /// Cân nặng lưu dạng ×10 (05 §6.7.1): 725 → `72,5 kg`, 800 → `80 kg`.
  static String kg(int weightKgX10) => '${kgNumber(weightKgX10)} kg';

  /// Phần số của cân nặng, dấu phẩy thập phân: 725 → `72,5`.
  static String kgNumber(int weightKgX10) {
    final whole = integer(weightKgX10 ~/ 10);
    final tenth = weightKgX10.abs() % 10;
    return tenth == 0 ? whole : '$whole,$tenth';
  }

  /// 2210 → `2.210 kcal`.
  static String kcal(int value) => '${integer(value)} kcal';

  /// 50000 → `50.000đ`.
  static String vnd(int value) => '${integer(value)}${S.currencySuffix}';

  /// `07/10`.
  static String dayMonth(LocalDate date) =>
      '${_two(date.day)}/${_two(date.month)}';

  /// `18:00`.
  static String time(LocalTime time) => time.toKey();

  /// `18:42` từ một thời điểm, theo giờ của thiết bị.
  static String clock(DateTime instant) {
    final local = instant.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  /// `Thứ 4` / `Chủ nhật`.
  static String weekday(LocalDate date) => S.weekdays[date.weekday - 1];

  /// `Thứ 4, 07/10` (04 §6.7).
  static String weekdayDate(LocalDate date) =>
      '${weekday(date)}, ${dayMonth(date)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
