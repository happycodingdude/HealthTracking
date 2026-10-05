import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/data/sync/sync_status.dart';
import 'package:mobile/features/me/data/account_repository.dart';

import '../../support/fake_sync.dart';

void main() {
  test(
    'VS02-T09: SyncStatus = số mutation chờ + lần đồng bộ gần nhất, cập nhật ngay',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FixedClock(DateTime(2026, 10, 7, 18, 42));
      final statuses = <SyncStatus>[];
      final sub = watchSyncStatus(db).listen(statuses.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect((statuses.last.pending, statuses.last.lastSyncedAt), (0, null));

      await OutboxWriter(
        db,
        clock,
      ).enqueue('account', 'me', SyncOp.upsert, {'displayName': 'A'});
      await pumpEventQueue();
      expect(statuses.last.hasPending, isTrue, reason: 'F09-E1: Chưa đồng bộ');

      final engine = SyncEngine(
        db: db,
        api: FakeSyncApi(),
        stores: {'account': AccountStore(AccountRepository(db))},
        clock: clock,
        reporter: RecordingReporter(),
        scheduler: FakeScheduler(),
      );
      await engine.syncNow();
      await pumpEventQueue();
      expect(statuses.last.hasPending, isFalse);
      expect(statuses.last.lastSyncedAt, clock.now());
    },
  );
}
