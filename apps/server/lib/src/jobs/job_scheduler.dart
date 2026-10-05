import 'dart:async';

import '../logging/logger.dart';

/// Khung job định kỳ chạy trong tiến trình server (05 §6.11, một instance).
///
/// - Không chạy chồng: nếu lần trước chưa xong thì bỏ qua lần này.
/// - Lỗi được ghi log, không làm dừng server.
/// - [stop] hủy hẹn giờ và chờ các job đang chạy xong (tắt an toàn).
final class JobScheduler {
  JobScheduler(this._logger);

  final Logger _logger;
  final _timers = <Timer>[];
  final _running = <String, Future<void>>{};
  bool _stopped = false;

  void every(String name, Duration interval, Future<void> Function() job) {
    if (_stopped) throw StateError('JobScheduler đã dừng');
    _timers.add(Timer.periodic(interval, (_) => runNow(name, job)));
  }

  /// Chạy [job] ngay (dùng cho timer và test). Trả về khi job xong.
  Future<void> runNow(String name, Future<void> Function() job) {
    final current = _running[name];
    if (current != null || _stopped) return current ?? Future.value();
    final stopwatch = Stopwatch()..start();
    final future = Future.sync(job)
        .then(
          (_) => _logger.info('job_done', {
            'job': name,
            'durationMs': stopwatch.elapsedMilliseconds,
          }),
          onError: (Object e, StackTrace s) => _logger.error(
            'job_failed',
            error: e,
            stack: s,
            fields: {'job': name},
          ),
        )
        .whenComplete(() {
          _running.remove(name);
        });
    _running[name] = future;
    return future;
  }

  Future<void> stop() async {
    _stopped = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    await Future.wait(_running.values.toList());
  }
}
