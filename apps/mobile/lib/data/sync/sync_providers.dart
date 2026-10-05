import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/me/data/account_repository.dart';
import '../../features/me/data/profile_repository.dart';
import '../../features/schedule/data/schedule_repository.dart';
import '../../features/weight/data/weight_repository.dart';
import 'local_stores.dart';
import 'outbox_writer.dart';
import 'sync_api.dart';
import 'sync_engine.dart';
import 'sync_scheduler.dart';
import 'sync_status.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(databaseProvider)),
);

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(ref.watch(databaseProvider)),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(databaseProvider)),
);

final outboxWriterProvider = Provider<OutboxWriter>(
  (ref) => OutboxWriter(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Hẹn giờ của SyncEngine (test thay bằng bản giả).
final syncSchedulerProvider = Provider<SyncScheduler>(
  (ref) => const TimerSyncScheduler(),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    api: HttpSyncApi(ref.watch(apiClientProvider)),
    stores: {
      SyncEntities.account: AccountStore(ref.watch(accountRepositoryProvider)),
      SyncEntities.profile: ProfileStore(ref.watch(profileRepositoryProvider)),
      SyncEntities.weight: WeightStore(ref.watch(weightRepositoryProvider)),
      SyncEntities.weeklyTemplate: WeeklyTemplateStore(
        ref.watch(scheduleRepositoryProvider),
      ),
      SyncEntities.monthPlan: MonthPlanStore(
        ref.watch(scheduleRepositoryProvider),
      ),
      SyncEntities.day: DayStore(ref.watch(scheduleRepositoryProvider)),
    },
    clock: ref.watch(clockProvider),
    reporter: ref.watch(errorReporterProvider),
    scheduler: ref.watch(syncSchedulerProvider),
  );
  ref.onDispose(engine.stop);
  return engine;
});

/// Số thay đổi chờ gửi và thời điểm đồng bộ gần nhất (VS02-T09).
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => watchSyncStatus(ref.watch(databaseProvider)),
);
