import 'dart:async';
import 'dart:math';

/// Hủy một lịch hẹn.
typedef CancelSchedule = void Function();

/// Hẹn giờ cho [SyncEngine]; test thay bằng bản giả để điều khiển thời gian.
abstract interface class SyncScheduler {
  CancelSchedule after(Duration delay, void Function() callback);
  CancelSchedule every(Duration interval, void Function() callback);
}

final class TimerSyncScheduler implements SyncScheduler {
  const TimerSyncScheduler();

  @override
  CancelSchedule after(Duration delay, void Function() callback) =>
      Timer(delay, callback).cancel;

  @override
  CancelSchedule every(Duration interval, void Function() callback) =>
      Timer.periodic(interval, (_) => callback()).cancel;
}

/// Chờ tăng dần khi lỗi mạng hoặc 5xx: 2 giây → gấp đôi → tối đa 5 phút
/// (05 §6.6.4).
final class Backoff {
  const Backoff({
    this.initial = const Duration(seconds: 2),
    this.cap = const Duration(minutes: 5),
  });

  final Duration initial;
  final Duration cap;

  /// Thời gian chờ sau lần lỗi thứ [failures] (bắt đầu từ 1).
  Duration delay(int failures) {
    final ms = initial.inMilliseconds * pow(2, max(0, failures - 1));
    return ms >= cap.inMilliseconds ? cap : Duration(milliseconds: ms.toInt());
  }
}
