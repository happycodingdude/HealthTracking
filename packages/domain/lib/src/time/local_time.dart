/// Giờ trong ngày, "trôi nổi" theo giờ thiết bị (05 §6.7.1). Định dạng `HH:mm`.
final class LocalTime implements Comparable<LocalTime> {
  LocalTime(this.hour, this.minute) {
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
    if (minute < 0 || minute > 59) throw ArgumentError.value(minute, 'minute');
  }

  factory LocalTime.fromDateTime(DateTime dateTime) =>
      LocalTime(dateTime.hour, dateTime.minute);

  /// Đọc chuỗi `HH:mm` (24 giờ). Ném [FormatException] nếu sai.
  factory LocalTime.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Giờ không đúng định dạng HH:mm', value);
    }
    try {
      return LocalTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
    } on ArgumentError {
      throw FormatException('Giờ không tồn tại', value);
    }
  }

  static LocalTime? tryParse(String value) {
    try {
      return LocalTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  static final _pattern = RegExp(r'^(\d{2}):(\d{2})$');

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  String toKey() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  bool isBefore(LocalTime other) => compareTo(other) < 0;
  bool isAfter(LocalTime other) => compareTo(other) > 0;

  @override
  int compareTo(LocalTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toKey();
}
