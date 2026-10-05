import 'local_time.dart';
import 'year_month.dart';

/// Ngày lịch không gắn múi giờ (`date` ở PostgreSQL, `YYYY-MM-DD` trong API).
final class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month');
    }
    if (day < 1 || day > YearMonth(year, month).lengthInDays) {
      throw ArgumentError.value(day, 'day');
    }
  }

  /// Lấy phần ngày của [dateTime] theo chính múi giờ của nó.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  /// Đọc chuỗi `YYYY-MM-DD`. Ném [FormatException] nếu sai định dạng.
  factory LocalDate.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Ngày không đúng định dạng YYYY-MM-DD', value);
    }
    try {
      return LocalDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      throw FormatException('Ngày không tồn tại', value);
    }
  }

  static LocalDate? tryParse(String value) {
    try {
      return LocalDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// 1 = thứ 2 … 7 = chủ nhật (giống [DateTime.weekday]).
  int get weekday => _utc.weekday;

  bool get isSunday => weekday == DateTime.sunday;

  YearMonth get yearMonth => YearMonth(year, month);

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Số ngày từ ngày này đến [other] (âm nếu [other] ở trước).
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  /// Thứ 2 của tuần chứa ngày này. Tuần: thứ 2 → chủ nhật (FR-08).
  LocalDate get weekStart => addDays(1 - weekday);

  /// Thời điểm theo giờ địa phương của thiết bị.
  DateTime atTime(LocalTime time) =>
      DateTime(year, month, day, time.hour, time.minute);

  /// 00:00 giờ địa phương của ngày này.
  DateTime get startOfDay => DateTime(year, month, day);

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  /// Khóa `YYYY-MM-DD` dùng cho API và đồng bộ.
  String toKey() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toKey();
}

String _two(int v) => v.toString().padLeft(2, '0');
