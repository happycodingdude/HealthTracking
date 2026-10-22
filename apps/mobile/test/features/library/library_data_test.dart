import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/library/application/library_providers.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';

import '../../support/fake_sync.dart';

Exercise _ex(MuscleRegion r, String kind, int order, {bool active = true}) =>
    Exercise(
      id: '${r.id}-$kind'.replaceAll('_', '-'),
      region: r,
      nameVi: 'Bài ${r.id} $kind',
      youtubeVideoId: 'abcdefghijk',
      videoChannel: 'Kênh',
      videoDurationS: 45,
      guideSteps: const ['Một', 'Hai', 'Ba'],
      guideSafety: const ['Một', 'Hai'],
      approvedAt: LocalDate(2026, 10, 11),
      sortOrder: order,
      active: active,
    );

SyncChange _change(Exercise e, int version) => SyncChange(
  entity: SyncEntities.exercise,
  key: e.id,
  deleted: false,
  serverVersion: version,
  data: const ExerciseCodec().encode(e),
);

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late ExerciseRepository repo;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    repo = ExerciseRepository(db);
    engine = SyncEngine(
      db: db,
      api: api,
      stores: {SyncEntities.exercise: ExerciseStore(repo)},
      clock: FixedClock(DateTime(2026, 10, 12, 18)),
      reporter: RecordingReporter(),
      scheduler: FakeScheduler(),
    );
  });
  tearDown(() async {
    engine.stop();
    await db.close();
  });

  final upperFree = _ex(MuscleRegion.chestUpper, 'free-weight', 2);
  final upperMachine = _ex(MuscleRegion.chestUpper, 'machine', 1);
  final mid = _ex(MuscleRegion.chestMid, 'machine', 3);
  final gone = _ex(MuscleRegion.chestLower, 'machine', 5, active: false);
  final back = _ex(MuscleRegion.lats, 'machine', 7);

  test('VS21-T07, VS33-T05: pull exercise vào Drift; thư viện của nhóm là '
      'danh sách phẳng theo thứ tự thư viện, chỉ bài đang có; tombstone bài '
      'bỏ → xóa dòng (F18-R42, F18-R43)', () async {
    api.pages[0] = PullResponse(
      changes: [
        _change(upperFree, 1),
        _change(mid, 2),
        _change(gone, 3),
        _change(upperMachine, 4),
        _change(back, 5),
        SyncChange(
          entity: SyncEntities.exercise,
          key: back.id,
          deleted: true,
          serverVersion: 6,
        ),
      ],
      nextCursor: 6,
      hasMore: false,
      remaining: 0,
      meta: SyncMeta(serverTime: DateTime.utc(2026, 10, 12)),
    );
    expect(await engine.syncNow(), SyncOutcome.synced);
    expect(await repo.get(upperFree.id), upperFree);
    expect(await repo.get(back.id), isNull, reason: 'tombstone bài bỏ');

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(libraryProvider(MuscleGroup.chest), (_, _) {});
    addTearDown(sub.close);
    final chest = await container.read(
      libraryProvider(MuscleGroup.chest).future,
    );
    expect(chest, [upperMachine, upperFree, mid]);
    final one = container.listen(exerciseProvider(gone.id), (_, _) {});
    addTearDown(one.close);
    expect(
      await container.read(exerciseProvider(gone.id).future),
      gone,
      reason: 'bài đã rời thư viện vẫn mở được (F19-E2)',
    );
  });

  test(
    'ED2-14: bộ entity đã biết chưa có exercise → cursor = 0, pull lại',
    () async {
      await db
          .update(db.syncState)
          .write(
            const SyncStateCompanion(
              cursor: Value(300),
              knownEntities: Value('account,profile'),
            ),
          );
      await engine.syncNow();
      expect(api.pulls.first, 0);
      final state = await db.select(db.syncState).getSingle();
      expect(state.knownEntities, 'exercise');
    },
  );
}
