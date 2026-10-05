import 'package:domain/domain.dart';

/// Ngày `YYYY-MM-DD` (05 §6.8.1).
abstract final class DateCodec {
  static String encode(LocalDate date) => date.toKey();
  static LocalDate decode(String value) => LocalDate.parse(value);
}

/// Giờ `HH:mm` (05 §6.8.1).
abstract final class TimeCodec {
  static String encode(LocalTime time) => time.toKey();
  static LocalTime decode(String value) => LocalTime.parse(value);
}

/// Thời điểm ISO 8601 có múi giờ (05 §6.8.1), độ chính xác mili giây.
///
/// - Giờ UTC → `2026-10-07T11:42:10.000Z`.
/// - Giờ địa phương → `2026-10-07T18:42:10.000+07:00`.
///
/// Chuỗi không có múi giờ bị từ chối để tránh hiểu sai giờ địa phương.
abstract final class InstantCodec {
  static final _zoned = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:?\d{2})$',
  );

  static String encode(DateTime value) {
    final date =
        '${_pad(value.year, 4)}-${_pad(value.month)}-${_pad(value.day)}'
        'T${_pad(value.hour)}:${_pad(value.minute)}:${_pad(value.second)}'
        '.${_pad(value.millisecond, 3)}';
    if (value.isUtc) return '${date}Z';
    final offset = value.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return '$date$sign${_pad(minutes ~/ 60)}:${_pad(minutes % 60)}';
  }

  /// Trả [DateTime] ở UTC. Ném [FormatException] nếu sai hoặc thiếu múi giờ.
  static DateTime decode(String value) {
    if (!_zoned.hasMatch(value)) {
      throw FormatException('Thời điểm phải là ISO 8601 có múi giờ', value);
    }
    return DateTime.parse(value).toUtc();
  }

  static DateTime? tryDecode(String value) {
    try {
      return decode(value);
    } on FormatException {
      return null;
    }
  }

  static String _pad(int v, [int width = 2]) =>
      v.toString().padLeft(width, '0');
}
