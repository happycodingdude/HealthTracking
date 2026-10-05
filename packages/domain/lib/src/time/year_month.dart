import 'local_date.dart';

/// Tháng dương lịch, khóa `YYYY-MM` (month_plans, tháng ngân sách FA-14).
final class YearMonth implements Comparable<YearMonth> {
  YearMonth(this.year, this.month) {
    if (month < 1 || month > 12) throw ArgumentError.value(month, 'month');
  }

  factory YearMonth.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Tháng không đúng định dạng YYYY-MM', value);
    }
    try {
      return YearMonth(int.parse(match.group(1)!), int.parse(match.group(2)!));
    } on ArgumentError {
      throw FormatException('Tháng không tồn tại', value);
    }
  }

  final int year;
  final int month;

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  int get lengthInDays => switch (month) {
    2 => isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  LocalDate get firstDay => LocalDate(year, month, 1);

  LocalDate get lastDay => LocalDate(year, month, lengthInDays);

  /// Mọi ngày trong tháng, theo thứ tự.
  List<LocalDate> get days => [
    for (var d = 1; d <= lengthInDays; d++) LocalDate(year, month, d),
  ];

  bool contains(LocalDate date) => date.year == year && date.month == month;

  YearMonth get next =>
      month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  YearMonth get previous =>
      month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1);

  String toKey() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(YearMonth other) => year != other.year
      ? year.compareTo(other.year)
      : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => toKey();
}
