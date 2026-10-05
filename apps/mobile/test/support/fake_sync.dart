import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:mobile/core/error_reporting.dart';
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_scheduler.dart';

/// SyncApi giả: ghi lại lời gọi, trả kết quả lập trình được.
final class FakeSyncApi implements SyncApi {
  final pushes = <PushRequest>[];
  final pulls = <int>[];
  bool offline = false;
  ApiFailure? failure;

  /// Mặc định: mọi mutation đều `applied`.
  PushResult Function(SyncMutation m) onPush = (m) =>
      PushResult(mutationId: m.mutationId, status: PushStatus.applied);

  /// Chạy trong lúc request push đang "trên đường" (mô phỏng thao tác của Bạn).
  Future<void> Function()? duringPush;

  /// Các trang trả về theo cursor.
  final pages = <int, PullResponse>{};

  int get calls => pushes.length + pulls.length;

  @override
  Future<PushResponse> push(PushRequest request) async {
    _fail();
    pushes.add(request);
    final hook = duringPush;
    duringPush = null;
    if (hook != null) await hook();
    return PushResponse([for (final m in request.mutations) onPush(m)]);
  }

  @override
  Future<PullResponse> pull({
    required int cursor,
    int limit = PullResponse.maxLimit,
  }) async {
    _fail();
    pulls.add(cursor);
    return pages[cursor] ??
        PullResponse(
          changes: const [],
          nextCursor: cursor,
          hasMore: false,
          remaining: 0,
          meta: SyncMeta(serverTime: DateTime.utc(2026)),
        );
  }

  void _fail() {
    if (offline) throw const NetworkFailure();
    final f = failure;
    if (f != null) throw f;
  }
}

/// Lịch hẹn giả: test tự kích hoạt.
final class FakeScheduler implements SyncScheduler {
  final timers = <_FakeTimer>[];

  List<Duration> get pendingDelays => [
    for (final t in timers)
      if (!t.cancelled && !t.periodic) t.delay,
  ];

  @override
  CancelSchedule after(Duration delay, void Function() callback) {
    final t = _FakeTimer(delay, callback, periodic: false);
    timers.add(t);
    return () => t.cancelled = true;
  }

  @override
  CancelSchedule every(Duration interval, void Function() callback) {
    final t = _FakeTimer(interval, callback, periodic: true);
    timers.add(t);
    return () => t.cancelled = true;
  }

  /// Chạy các hẹn giờ một lần còn hiệu lực có thời gian chờ [delay] (hoặc tất cả).
  Future<void> fire({Duration? delay}) async {
    final due = [
      for (final t in timers)
        if (!t.cancelled && !t.periodic && (delay == null || t.delay == delay))
          t,
    ];
    for (final t in due) {
      t.cancelled = true;
      t.callback();
    }
    await pumpEventQueue();
  }

  Future<void> firePeriodic() async {
    for (final t in [
      for (final t in timers)
        if (!t.cancelled && t.periodic) t,
    ]) {
      t.callback();
    }
    await pumpEventQueue();
  }

  bool get hasActivePeriodic => timers.any((t) => t.periodic && !t.cancelled);
}

final class _FakeTimer {
  _FakeTimer(this.delay, this.callback, {required this.periodic});
  final Duration delay;
  final void Function() callback;
  final bool periodic;
  bool cancelled = false;
}

/// ErrorReporter ghi lại các lỗi được báo.
final class RecordingReporter implements ErrorReporter {
  final reasons = <String?>[];

  @override
  Future<void> report(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async => reasons.add(reason);
}

/// Chờ các microtask/timer 0 xử lý xong.
Future<void> pumpEventQueue({int times = 20}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
