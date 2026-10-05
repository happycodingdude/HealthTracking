import 'local_date.dart';

/// Nguồn thời gian duy nhất cho mọi quy tắc phụ thuộc thời gian (IS-5).
///
/// `now()` trả giờ địa phương của thiết bị ("Ngày theo giờ trên iPhone",
/// 03 §6.1). Chỉ điểm khởi động app/server được dùng [SystemClock].
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Đồng hồ cố định cho test. Có thể đặt lại hoặc tua tới.
final class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;

  void advance(Duration by) => _now = _now.add(by);
}

extension ClockToday on Clock {
  /// Ngày hôm nay theo giờ của [Clock].
  LocalDate today() => LocalDate.fromDateTime(now());
}
