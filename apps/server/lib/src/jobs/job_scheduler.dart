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
  final _daily = <String, Timer>{};
  final _running = <String, Future<void>>{};
  bool _stopped = false;

  void every(String name, Duration interval, Future<void> Function() job) {
    if (_stopped) throw StateError('JobScheduler đã dừng');
    _timers.add(Timer.periodic(interval, (_) => runNow(name, job)));
  }

  /// Chạy [job] mỗi ngày lúc [time] theo giờ có độ lệch [utcOffset] so với
  /// UTC (giờ Việt Nam: +7, không đổi giờ theo mùa). [now] cho test.
  void dailyAt(
    String name,
    ({int hour, int minute}) time,
    Future<void> Function() job, {
    Duration utcOffset = vietnamOffset,
    DateTime Function()? now,
  }) {
    if (_stopped) throw StateError('JobScheduler đã dừng');
    final clock = now ?? DateTime.now;
    void schedule() {
      if (_stopped) return;
      _daily[name] = Timer(untilNext(clock(), time, utcOffset), () {
        unawaited(runNow(name, job));
        schedule();
      });
    }

    schedule();
  }

  /// Giờ Việt Nam so với UTC (TA-17).
  static const vietnamOffset = Duration(hours: 7);

  /// Thời gian từ [now] tới lần [time] kế tiếp (sau [now]) theo giờ lệch
  /// [utcOffset].
  static Duration untilNext(
    DateTime now,
    ({int hour, int minute}) time,
    Duration utcOffset,
  ) {
    final local = now.toUtc().add(utcOffset);
    var target = DateTime.utc(
      local.year,
      local.month,
      local.day,
      time.hour,
      time.minute,
    );
    if (!target.isAfter(local)) target = target.add(const Duration(days: 1));
    return target.difference(local);
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
    for (final t in [..._timers, ..._daily.values]) {
      t.cancel();
    }
    _timers.clear();
    _daily.clear();
    await Future.wait(_running.values.toList());
  }
}
