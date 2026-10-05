import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/data/sync/sync_scheduler.dart';
import 'package:mobile/features/me/data/account_repository.dart';

import '../../support/fake_sync.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeSyncApi api;
  late FakeScheduler scheduler;
  late RecordingReporter reporter;
  late AccountRepository accounts;
  late OutboxWriter outbox;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 7, 18, 42));
    api = FakeSyncApi();
    scheduler = FakeScheduler();
    reporter = RecordingReporter();
    accounts = AccountRepository(db);
    outbox = OutboxWriter(db, clock);
    engine = SyncEngine(
      db: db,
      api: api,
      stores: {SyncEntities.account: AccountStore(accounts)},
      clock: clock,
      reporter: reporter,
      scheduler: scheduler,
    );
  });
  tearDown(() async {
    engine.stop();
    await db.close();
  });

  /// Ghi tên như use case: bản ghi + outbox trong một transaction.
  Future<void> rename(String name) => db.transaction(() async {
    await accounts.put(name);
    await outbox.enqueue('account', 'me', SyncOp.upsert, {'displayName': name});
  });

  Future<int> pending() async => (await db.select(db.outbox).get()).length;

  Future<void> startIdle() async {
    engine.start();
    await pumpEventQueue();
    api.pushes.clear();
    api.pulls.clear();
  }

  test(
    'TAC-01: ghi khi không có mạng → bản trên máy cập nhật ngay, chưa có lời gọi mạng nào',
    () async {
      await startIdle();
      api.offline = true;
      await rename('Minh mới');
      expect(await accounts.watchDisplayName().first, 'Minh mới');
      expect(api.calls, 0, reason: 'ghi không chờ mạng');
      expect(await pending(), 1);
    },
  );

  test(
    '05 §6.6.4: đẩy sau 1 giây không có thao tác mới; nhiều lần sửa → một lần gửi',
    () async {
      await startIdle();
      await rename('A');
      await pumpEventQueue();
      await rename('B');
      await pumpEventQueue();
      expect(scheduler.pendingDelays, [
        const Duration(seconds: 1),
      ], reason: 'hẹn 1 giây, lần trước bị hủy');
      expect(api.pushes, isEmpty);
      await scheduler.fire(delay: const Duration(seconds: 1));
      expect(api.pushes, hasLength(1));
      expect(api.pushes.single.mutations.single.data, {'displayName': 'B'});
      expect(await pending(), 0);
      final state = await db.select(db.syncState).getSingle();
      expect(state.lastSyncedAt, clock.now(), reason: '"Đã đồng bộ lúc …"');
    },
  );

  test(
    'mở app: start() đồng bộ ngay (push rồi pull); pull định kỳ 60 giây',
    () async {
      await rename('A');
      engine.start();
      await pumpEventQueue();
      expect(api.pushes, hasLength(1));
      expect(api.pulls, [0]);
      expect(
        scheduler.timers.where((t) => t.periodic).single.delay,
        const Duration(seconds: 60),
      );
      await scheduler.firePeriodic();
      expect(api.pulls, hasLength(2));
    },
  );

  test(
    '05 §6.6.4: lỗi mạng → thử lại chờ tăng dần 2 giây → 5 phút; thành công thì về 0',
    () async {
      api.offline = true;
      engine.start();
      await pumpEventQueue();
      final delays = <Duration>[];
      for (var i = 0; i < 10; i++) {
        delays.add(scheduler.pendingDelays.single);
        await scheduler.fire();
      }
      expect(delays.map((d) => d.inSeconds), [
        2,
        4,
        8,
        16,
        32,
        64,
        128,
        256,
        300,
        300,
      ]);
      api.offline = false;
      await scheduler.fire();
      expect(engine.failures, 0);
      expect(scheduler.pendingDelays, isEmpty);
    },
  );

  test(
    'có mạng trở lại → đồng bộ ngay, không chờ hết thời gian thử lại',
    () async {
      await rename('A');
      api.offline = true;
      engine.start();
      await pumpEventQueue();
      expect(await pending(), 1);
      api.offline = false;
      engine.onConnectivityRestored();
      await pumpEventQueue();
      expect(await pending(), 0);
    },
  );

  test('lỗi khi gửi → giữ trong outbox, tăng số lần thử', () async {
    await rename('A');
    api.offline = true;
    engine.start();
    await pumpEventQueue();
    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempts, 1);
    expect(row.lastError, contains('NetworkFailure'));
  });

  test(
    'TA-12: ignored_stale/rejected → lấy bản server thay bản trên máy và báo lỗi',
    () async {
      await startIdle();
      api.onPush = (m) => PushResult(
        mutationId: m.mutationId,
        status: PushStatus.ignoredStale,
        current: const SyncChange(
          entity: 'account',
          key: 'me',
          deleted: false,
          serverVersion: 9,
          data: {'displayName': 'Bản server'},
        ),
      );
      await rename('Bản máy');
      await engine.syncNow();
      expect(await accounts.watchDisplayName().first, 'Bản server');
      expect(await pending(), 0);
      expect(reporter.reasons, ['sync_ignored_stale']);
    },
  );

  test(
    'kết quả của lần gửi cũ không xóa, không ghi đè thay đổi mới hơn sửa trong lúc đang gửi',
    () async {
      await startIdle();
      await rename('Lần 1');
      api.onPush = (m) => PushResult(
        mutationId: m.mutationId,
        status: PushStatus.rejected,
        code: ErrorCode.validationFailed,
        current: const SyncChange(
          entity: 'account',
          key: 'me',
          deleted: false,
          serverVersion: 9,
          data: {'displayName': 'Server'},
        ),
      );
      api.duringPush = () async {
        await rename(
          'Lần 2',
        ); // được gộp vào dòng đang gửi, nhận mutationId mới
        api.onPush = (m) =>
            PushResult(mutationId: m.mutationId, status: PushStatus.applied);
      };
      await engine.syncNow();
      expect(
        await accounts.watchDisplayName().first,
        'Lần 2',
        reason: 'không bị bản server ghi đè',
      );
      expect(
        api.pushes,
        hasLength(2),
        reason: 'thay đổi mới được gửi ngay sau đó',
      );
      expect(api.pushes.last.mutations.single.data, {'displayName': 'Lần 2'});
      expect(await pending(), 0);
    },
  );

  test(
    'pull: áp dụng thay đổi nhiều trang, cập nhật cursor, bỏ qua bản ghi đang chờ gửi',
    () async {
      api.pages[0] = PullResponse(
        changes: const [
          SyncChange(
            entity: 'account',
            key: 'me',
            deleted: false,
            serverVersion: 5,
            data: {'displayName': 'Từ server'},
          ),
        ],
        nextCursor: 5,
        hasMore: true,
        remaining: 1,
        meta: SyncMeta(serverTime: DateTime.utc(2026)),
      );
      api.pages[5] = PullResponse(
        changes: const [
          SyncChange(
            entity: 'ghost',
            key: 'x',
            deleted: false,
            serverVersion: 6,
          ),
        ],
        nextCursor: 6,
        hasMore: false,
        remaining: 0,
        meta: SyncMeta(serverTime: DateTime.utc(2026)),
      );
      await engine.syncNow();
      expect(api.pulls, [0, 5]);
      expect(await accounts.watchDisplayName().first, 'Từ server');
      expect((await db.select(db.syncState).getSingle()).cursor, 6);

      // Có thay đổi trên máy chưa gửi được → pull không ghi đè.
      api.failure = null;
      api.pages[6] = PullResponse(
        changes: const [
          SyncChange(
            entity: 'account',
            key: 'me',
            deleted: false,
            serverVersion: 7,
            data: {'displayName': 'Cũ'},
          ),
        ],
        nextCursor: 7,
        hasMore: false,
        remaining: 0,
        meta: SyncMeta(serverTime: DateTime.utc(2026)),
      );
      api.onPush = (m) => throw const NetworkFailure();
      await rename('Trên máy');
      await engine.syncNow();
      expect(await accounts.watchDisplayName().first, 'Trên máy');
    },
  );

  test('phiên hết hạn (401) → dừng đồng bộ', () async {
    api.failure = const ServerFailure(ApiError(ErrorCode.unauthorized), 401);
    engine.start();
    await pumpEventQueue();
    expect(engine.isStarted, isFalse);
    expect(scheduler.hasActivePeriodic, isFalse);
  });

  test('gọi syncNow khi đang chạy → chạy thêm đúng một lần', () async {
    final first = engine.syncNow();
    final second = engine.syncNow();
    final third = engine.syncNow();
    await Future.wait([first, second, third]);
    expect(api.pulls, hasLength(2));
  });

  test(
    'chạy nền: stop() hủy mọi hẹn giờ, ghi mới không kích hoạt gửi',
    () async {
      await startIdle();
      engine.stop();
      await rename('A');
      await pumpEventQueue();
      expect(scheduler.pendingDelays, isEmpty);
      expect(api.calls, 0);
    },
  );

  test('Backoff: 2 s, gấp đôi, tối đa 5 phút', () {
    const b = Backoff();
    expect(b.delay(1), const Duration(seconds: 2));
    expect(b.delay(2), const Duration(seconds: 4));
    expect(b.delay(9), const Duration(minutes: 5));
    expect(b.delay(50), const Duration(minutes: 5));
  });
}
