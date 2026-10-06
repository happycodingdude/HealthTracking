import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';

import '../../support/fake_sync.dart';
import '../../support/menu_fixture.dart';

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late MenuRepository repo;
  late SyncEngine engine;
  final today = LocalDate(2026, 10, 7);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    repo = MenuRepository(db);
    engine = SyncEngine(
      db: db,
      api: api,
      stores: {
        SyncEntities.menu: MenuStore(repo),
        SyncEntities.aiDailyUsage: AiDailyUsageStore(repo),
      },
      clock: FixedClock(DateTime(2026, 10, 7, 18, 42)),
      reporter: RecordingReporter(),
      scheduler: FakeScheduler(),
    );
  });
  tearDown(() async {
    engine.stop();
    await db.close();
  });

  PullResponse page(List<SyncChange> changes, {AiBudgetMeta? budget}) =>
      PullResponse(
        changes: changes,
        nextCursor: 10,
        hasMore: false,
        remaining: 0,
        meta: SyncMeta(
          serverTime: DateTime.utc(2026, 10, 7),
          aiBudget: budget?.toJson(),
        ),
      );

  test('F09-AC1 (phần thực đơn): pull nhận thực đơn, lượt hôm nay và ngân '
      'sách AI của tháng (ED-04)', () async {
    final menu = readyMenu();
    final budget = AiBudgetMeta(
      month: YearMonth(2026, 10),
      usedVnd: 12500,
      capVnd: 50000,
      blocked: false,
    );
    api.pages[0] = page([
      SyncChange(
        entity: 'menu',
        key: '2026-10-07',
        deleted: false,
        serverVersion: 9,
        data: const MenuCodec().encode(menu),
      ),
      const SyncChange(
        entity: 'ai_daily_usage',
        key: '2026-10-07:menu',
        deleted: false,
        serverVersion: 10,
        data: {'successCount': 2},
      ),
    ], budget: budget);
    await engine.syncNow();
    expect(await repo.get(today), menu);
    expect(await repo.watchUsage(today).first, 2);
    expect(await repo.watchBudget().first, budget);
  });

  test('F08-R5: tombstone thực đơn ngày cũ → xóa trên máy', () async {
    await repo.put(today, readyMenu());
    api.pages[0] = page([
      const SyncChange(
        entity: 'menu',
        key: '2026-10-07',
        deleted: true,
        serverVersion: 11,
      ),
    ]);
    await engine.syncNow();
    expect(await repo.get(today), isNull);
  });
}
