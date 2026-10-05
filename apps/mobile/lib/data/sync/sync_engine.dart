import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../core/error_reporting.dart';
import '../api/api_client.dart';
import '../db/app_database.dart';
import 'local_stores.dart';
import 'outbox_writer.dart';
import 'sync_api.dart';
import 'sync_scheduler.dart';

/// Kết quả một lần đồng bộ.
enum SyncOutcome { synced, failed, sessionExpired }

/// Đồng bộ outbox ↔ server (05 §6.6, TD-05).
///
/// Khi nào đồng bộ (05 §6.6.4):
/// - Ghi bất kỳ: sau [debounce] (1 giây) không có thay đổi mới → push rồi pull.
/// - Mở app / quay lại foreground: [start] → push rồi pull.
/// - Có mạng trở lại: [syncNow].
/// - Đang mở app: pull mỗi [pollInterval] (60 giây).
/// - Lỗi mạng hoặc 5xx: thử lại với thời gian chờ tăng dần ([Backoff]).
/// Không đồng bộ khi app chạy nền: gọi [stop].
final class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required SyncApi api,
    required Map<String, LocalEntityStore> stores,
    required Clock clock,
    required ErrorReporter reporter,
    SyncScheduler scheduler = const TimerSyncScheduler(),
    Backoff backoff = const Backoff(),
    this.debounce = const Duration(seconds: 1),
    this.pollInterval = const Duration(seconds: 60),
    this.pushBatchSize = 100,
  }) : _db = db,
       _api = api,
       _stores = stores,
       _clock = clock,
       _reporter = reporter,
       _scheduler = scheduler,
       _backoff = backoff;

  final AppDatabase _db;
  final SyncApi _api;
  final Map<String, LocalEntityStore> _stores;
  final Clock _clock;
  final ErrorReporter _reporter;
  final SyncScheduler _scheduler;
  final Backoff _backoff;
  final Duration debounce;
  final Duration pollInterval;
  final int pushBatchSize;

  StreamSubscription<int>? _outboxSub;
  CancelSchedule? _debounceTimer;
  CancelSchedule? _pollTimer;
  CancelSchedule? _retryTimer;
  Future<SyncOutcome>? _running;
  bool _rerun = false;
  bool _started = false;

  /// Số lần lỗi liên tiếp (0 = bình thường).
  int failures = 0;

  bool get isStarted => _started;

  /// Bắt đầu khi app ở foreground: đồng bộ ngay, theo dõi outbox, pull định kỳ.
  void start() {
    if (_started) return;
    _started = true;
    _outboxSub = _pendingCount().listen((count) {
      // Đang chờ thử lại sau lỗi thì không gửi thêm theo từng lần ghi.
      if (count > 0 && failures == 0) _scheduleDebounced();
    });
    _pollTimer = _scheduler.every(pollInterval, () => unawaited(syncNow()));
    unawaited(syncNow());
  }

  /// App chạy nền hoặc phiên kết thúc: dừng mọi hẹn giờ.
  void stop() {
    _started = false;
    unawaited(_outboxSub?.cancel());
    _outboxSub = null;
    for (final cancel in [_debounceTimer, _pollTimer, _retryTimer]) {
      cancel?.call();
    }
    _debounceTimer = _pollTimer = _retryTimer = null;
  }

  /// Có mạng trở lại.
  void onConnectivityRestored() {
    if (!_started) return;
    failures = 0;
    _retryTimer?.call();
    _retryTimer = null;
    unawaited(syncNow());
  }

  /// Push toàn bộ outbox rồi pull đến hết. Chỉ một lần chạy tại một thời điểm;
  /// gọi trong lúc đang chạy thì chạy thêm một lần sau đó.
  Future<SyncOutcome> syncNow() {
    final running = _running;
    if (running != null) {
      _rerun = true;
      return running;
    }
    final run = _runLoop().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<SyncOutcome> _runLoop() async {
    SyncOutcome outcome;
    do {
      _rerun = false;
      outcome = await _runOnce();
    } while (_rerun && outcome == SyncOutcome.synced);
    return outcome;
  }

  Future<SyncOutcome> _runOnce() async {
    try {
      await _pushAll();
      await _pullAll();
      await (_db.update(_db.syncState)..where((s) => s.id.equals(1))).write(
        SyncStateCompanion(lastSyncedAt: Value(_clock.now())),
      );
      failures = 0;
      return SyncOutcome.synced;
    } on ServerFailure catch (e) {
      if (e.error.code == ErrorCode.unauthorized) {
        // Phiên hết hạn: TokenManager đã báo; dừng đến khi đăng nhập lại.
        stop();
        return SyncOutcome.sessionExpired;
      }
      if (e.status < 500) {
        unawaited(
          _reporter.report(e, StackTrace.current, reason: 'sync_client_error'),
        );
      }
      _scheduleRetry();
      return SyncOutcome.failed;
    } on ApiFailure {
      _scheduleRetry();
      return SyncOutcome.failed;
    }
  }

  Future<void> _pushAll() async {
    while (true) {
      final batch =
          await (_db.select(_db.outbox)
                ..orderBy([(o) => OrderingTerm.asc(o.id)])
                ..limit(pushBatchSize))
              .get();
      if (batch.isEmpty) return;
      final PushResponse response;
      try {
        response = await _api.push(
          PushRequest([for (final row in batch) row.toMutation()]),
        );
      } on ApiFailure catch (e) {
        await _markAttempt(batch, e);
        rethrow;
      }
      await _applyPushResults(response);
    }
  }

  Future<void> _markAttempt(List<OutboxRow> batch, ApiFailure error) =>
      _db.batch((b) {
        for (final row in batch) {
          b.update(
            _db.outbox,
            OutboxCompanion(
              attempts: Value(row.attempts + 1),
              lastError: Value(error.toString()),
            ),
            where: (o) => o.id.equals(row.id),
          );
        }
      });

  Future<void> _applyPushResults(
    PushResponse response,
  ) => _db.transaction(() async {
    for (final r in response.results) {
      final row = await (_db.select(
        _db.outbox,
      )..where((o) => o.mutationId.equals(r.mutationId))).getSingleOrNull();
      if (row == null) continue;
      await (_db.delete(_db.outbox)..where((o) => o.id.equals(row.id))).go();
      if (r.status == PushStatus.applied) continue;
      // TA-12: lấy bản ghi trên server thay cho bản trên máy, báo lỗi để sửa app.
      unawaited(
        _reporter.report(
          StateError(
            'sync ${r.status.wire} ${row.entity} ${r.code?.wire ?? ''} ${r.field ?? ''}',
          ),
          null,
          reason: 'sync_${r.status.wire}',
        ),
      );
      if (!await _hasPending(row.entity, row.entityKey)) {
        await _stores[row.entity]?.apply(row.entityKey, r.current);
      }
    }
  });

  Future<void> _pullAll() async {
    while (true) {
      final cursor = (await _db.select(_db.syncState).getSingle()).cursor;
      final page = await _api.pull(cursor: cursor);
      await _db.transaction(() async {
        for (final change in page.changes) {
          // Thay đổi trên máy chưa gửi được ưu tiên; server sẽ quyết khi push.
          if (await _hasPending(change.entity, change.key)) continue;
          await _stores[change.entity]?.apply(change.key, change);
        }
        await (_db.update(_db.syncState)..where((s) => s.id.equals(1))).write(
          SyncStateCompanion(cursor: Value(page.nextCursor)),
        );
      });
      if (!page.hasMore) return;
    }
  }

  Future<bool> _hasPending(String entity, String key) async =>
      await (_db.select(_db.outbox)
            ..where((o) => o.entity.equals(entity) & o.entityKey.equals(key))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Stream<int> _pendingCount() {
    final count = _db.outbox.id.count();
    return (_db.selectOnly(
      _db.outbox,
    )..addColumns([count])).map((r) => r.read(count) ?? 0).watchSingle();
  }

  void _scheduleDebounced() {
    _debounceTimer?.call();
    _debounceTimer = _scheduler.after(debounce, () {
      _debounceTimer = null;
      unawaited(syncNow());
    });
  }

  void _scheduleRetry() {
    failures++;
    _retryTimer?.call();
    if (!_started) return;
    _retryTimer = _scheduler.after(_backoff.delay(failures), () {
      _retryTimer = null;
      unawaited(syncNow());
    });
  }
}
