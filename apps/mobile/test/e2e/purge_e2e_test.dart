@Tags(['e2e'])
library;

import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:postgres/postgres.dart' show Sql;
import 'package:server/server.dart' show LibraryImporter, LibraryPurge;
import 'package:server/testing.dart' show insertV2Library, library28;

import 'sync_e2e_harness.dart';

/// 06 Bản 3 VS34-T04, VS34-T06 (phần app): máy đang có mức tạ của bài bỏ;
/// server chạy `library purge` rồi nạp thư viện Bản 3 (05 Bản 3 §6.11.3) →
/// máy xóa theo qua pull.
void main() {
  late E2eServer server;
  final devices = <E2eDevice>[];

  setUpAll(() => HttpOverrides.global = null);
  setUp(() async {
    server = await E2eServer.start();
    // Thư viện Bản 2 như production trước khi phát hành Bản 3.
    await insertV2Library(server.tdb.pool);
  });
  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    await server.stop();
  });

  // T2 Ngực 06:00; ghi tạ lúc 08:00 thứ 2 14/09.
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(6, 0),
      muscles: const [MuscleGroup.chest],
    ),
  });
  final monday = LocalDate(2026, 9, 14);
  const pecDeck = 'chest-mid-machine-pec-deck'; // giữ, máy
  const removed = [
    'chest-upper-free-weight-incline-dumbbell-press',
    'chest-lower-machine-high-to-low-cable-crossover',
  ];

  test('F20-E41, FA3-15, F22-AC43, FR3-13: sau purge + import, máy không còn '
      '14 bài bỏ và bản ghi của chúng; buổi cũ còn, "Không tập" đếm theo bản '
      'ghi còn lại; bài máy đã ghi có đơn vị nấc với đúng số cũ', () async {
    final a = E2eDevice(server);
    devices.add(a);
    await a.register();
    a.clock.set(DateTime(2026, 9, 14, 5));
    await a.onboarding.acceptDisclaimer();
    expect(
      await a.onboarding.saveProfile(
        const ProfileDraft(
          height: '175',
          birthYear: 1996,
          sex: Sex.male,
          activityLevel: ActivityLevel.moderate,
          weight: '80',
        ),
      ),
      isEmpty,
    );
    expect(await a.onboarding.saveCalorie(), isTrue);
    expect(await a.onboarding.saveSchedule(template), isEmpty);
    await a.onboarding.complete(
      remindersEnabled: false,
      timezone: 'Asia/Ho_Chi_Minh',
    );
    expect(await a.sync(), SyncOutcome.synced);
    expect(await a.exercises.watchAll().first, hasLength(29));

    // Mức tạ ghi từ app 2.x trước khi phát hành Bản 3 (bài máy: số thanh).
    for (final id in [pecDeck, ...removed]) {
      await server.tdb.pool.execute(
        Sql.named('''
          INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10,
                                 end_kg_x10, logged_at, server_version,
                                 client_updated_at)
          SELECT id, '2026-09-14', @e, 70, 80, now(),
                 nextval('sync_version_seq'), now()
          FROM users WHERE phone = '0912345678' '''),
        parameters: {'e': id},
      );
    }
    expect(await a.sync(), SyncOutcome.synced);
    expect(await a.liftLogs.watchAll().first, hasLength(3));
    Future<List<ProgressItem>> progress() async => ProgressList.of(
      await a.liftLogs.watchAll().first,
      await a.exercises.watchAll().first,
    );
    expect(await progress(), hasLength(3));
    expect(await a.markSkipped.liftLogCount(monday), 3);

    // Bạn "Đồng ý" bảng 2 bản ghi → purge → nạp thư viện Bản 3.
    final purge = LibraryPurge(server.tdb.pool, const SystemClock());
    expect((await purge.dryRun()).total, 2);
    await purge.apply(confirmCount: 2);
    expect((await LibraryImporter(server.tdb.pool).run(library28())).ok, true);

    expect(await a.sync(), SyncOutcome.synced);
    expect(a.reporter.reasons, isEmpty);
    final ids = {for (final e in await a.exercises.watchAll().first) e.id};
    expect(ids, hasLength(28));
    expect(ids.intersection(LibraryV3.removedV2Ids), isEmpty);
    final logs = await a.liftLogs.watchAll().first;
    expect(
      [for (final l in logs) (l.exerciseId, l.startKgX10, l.endKgX10)],
      [(pecDeck, 70, 80)],
    );
    expect([for (final p in await progress()) p.exercise.id], [pecDeck]);
    for (final id in removed) {
      expect(await a.exercises.get(id), isNull, reason: 'F22-AC43: $id');
    }
    final day = await a.schedule.day(monday);
    expect(day!.isWorkout, isTrue, reason: 'buổi cũ còn');
    expect(await a.markSkipped.liftLogCount(monday), 1, reason: 'FA3-15');
    expect((await a.units.get(pecDeck))?.unit, LiftUnit.steps);
  });
}
