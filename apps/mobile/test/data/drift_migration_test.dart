import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/me/data/gym_location_repository.dart';
import 'package:mobile/features/schedule/data/schedule_pause_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/workout/data/exercise_feel_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/data/session_exercise_repository.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;
import '../generated_migrations/schema_v2.dart' as v2;
import '../support/fake_sync.dart';

/// 06 Bản 3 VS32-T05, VS32-T10, TAC3-02: database Bản 2 (schema 1) có dữ liệu
/// và outbox còn 2 mutation → app 3.0.0 mở lên schema 2, giữ nguyên dữ liệu
/// và outbox; lần đồng bộ đầu tiên gửi đủ 2 mutation rồi pull lại từ 0 (bộ
/// entity đã biết thêm `exercise_unit`, `exercise_note`, TD3-09).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema 1 → 2 đúng cấu trúc khai báo', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('TAC3-02: dữ liệu Bản 2 và outbox còn nguyên; đồng bộ gửi đủ '
      'mutation, cursor về 0 một lần', () async {
    const v2Entities =
        'account,ai_daily_usage,day,dish_image,exercise,lift_log,menu,'
        'month_plan,profile,weekly_template,weight';
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.customStatement(
      "INSERT INTO sync_state (id, cursor, known_entities) VALUES (1, 812, '$v2Entities')",
    );
    for (final (i, r) in MuscleRegion.values.take(16).indexed) {
      await old.customStatement(
        'INSERT INTO muscle_regions (id, muscle_group, view, sort_order) '
        "VALUES ('${r.id}', '${r.group.name}', '${r.view.name}', ${i + 1})",
      );
    }
    await old.customStatement('''
      INSERT INTO exercises (id, muscle_group, muscle_region, equipment, logs_weight,
        name_vi, youtube_video_id, video_channel, video_available, guide_steps,
        guide_safety, approved_at, sort_order, active)
      VALUES ('chest-mid-machine-pec-deck', 'chest', 'chest_mid', 'machine', 1,
        'Ép ngực với máy', 'abcdefghijk', 'Kênh', 1, '["a","b","c"]', '["a","b"]',
        '2026-10-11', 3, 1)''');
    await old.customStatement(
      'INSERT INTO lift_logs (date, exercise_id, start_kg_x10, end_kg_x10) '
      "VALUES ('2026-11-02', 'chest-mid-machine-pec-deck', 40, 50)",
    );
    for (final (id, key) in [
      ('11111111-1111-4111-8111-111111111111', '2026-11-12'),
      ('22222222-2222-4222-8222-222222222222', '2026-11-12:x'),
    ]) {
      await old.customStatement(
        'INSERT INTO outbox (mutation_id, entity, key, op, payload, client_updated_at) '
        "VALUES ('$id', '${key.contains(':') ? 'lift_log' : 'day'}', '$key', "
        "'upsert', '{}', '2026-11-12T18:40:00.000')",
      );
    }
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    expect(
      [for (final r in await db.select(db.outbox).get()) r.mutationId],
      [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      ],
    );
    expect(await db.select(db.muscleRegions).get(), hasLength(19));
    final kept = await ExerciseRepository(db).get('chest-mid-machine-pec-deck');
    expect(
      (kept!.nameVi, kept.sortInGroup, kept.sortOrder),
      ('Ép ngực với máy', 0, 3),
    );
    expect(
      await LiftLogRepository(
        db,
      ).get(LocalDate(2026, 11, 2), 'chest-mid-machine-pec-deck'),
      isNotNull,
    );
    expect(await db.select(db.exerciseUnits).get(), isEmpty);
    expect(await db.select(db.exerciseNotes).get(), isEmpty);

    final api = FakeSyncApi();
    final engine = SyncEngine(
      db: db,
      api: api,
      stores: {
        SyncEntities.exercise: ExerciseStore(ExerciseRepository(db)),
        SyncEntities.liftLog: LiftLogStore(LiftLogRepository(db)),
        SyncEntities.exerciseUnit: ExerciseUnitStore(
          ExerciseUnitRepository(db),
        ),
        SyncEntities.exerciseNote: ExerciseNoteStore(
          ExerciseNoteRepository(db),
        ),
      },
      clock: FixedClock(DateTime(2026, 11, 12, 18, 45)),
      reporter: RecordingReporter(),
      scheduler: FakeScheduler(),
    );
    addTearDown(engine.stop);
    expect(await engine.syncNow(), SyncOutcome.synced);
    expect(api.pushes.single.mutations.map((m) => m.mutationId), [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ]);
    expect(api.pulls, [0], reason: 'cursor 812 → 0 một lần');
    expect(await db.select(db.outbox).get(), isEmpty);
    final state = await db.select(db.syncState).getSingle();
    expect(state.knownEntities, contains('exercise_note'));
    expect(state.knownEntities, contains('exercise_unit'));

    // Lần sau không đặt lại cursor nữa.
    api.pages[0] = PullResponse(
      changes: const [],
      nextCursor: 900,
      hasMore: false,
      remaining: 0,
      meta: SyncMeta(serverTime: DateTime.utc(2026, 11, 12)),
    );
    await engine.syncNow();
    await engine.syncNow();
    expect(api.pulls, [0, 0, 900]);
  });

  test('schema 2 → 3 đúng cấu trúc khai báo (05 Bản 5 §6.5)', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('TAC5-02 (phần schema), TA5-10: database Bản 4 (schema 2) có dữ liệu '
      'và outbox 2 mutation → schema 3 giữ nguyên; đồng bộ gửi đủ, cursor về 0 '
      'một lần vì thêm 4 entity', () async {
    const v4Entities =
        'account,ai_daily_usage,day,dish_image,exercise,exercise_note,'
        'exercise_unit,lift_log,menu,month_plan,profile,weekly_template,weight';
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old.customStatement(
      "INSERT INTO sync_state (id, cursor, known_entities) VALUES (1, 4321, '$v4Entities')",
    );
    await old.customStatement('''
      INSERT INTO days (date, kind, time, muscles, source, mark, marked_at)
      VALUES ('2026-11-03', 'workout', '18:00', '["back"]', 'template',
        'skipped', '2026-11-03T19:00:00.000')''');
    for (final (id, key) in [
      ('33333333-3333-4333-8333-333333333333', '2026-11-04'),
      ('44444444-4444-4444-8444-444444444444', '2026-11-04:x'),
    ]) {
      await old.customStatement(
        'INSERT INTO outbox (mutation_id, entity, key, op, payload, client_updated_at) '
        "VALUES ('$id', '${key.contains(':') ? 'lift_log' : 'day'}', '$key', "
        "'upsert', '{}', '2026-11-04T18:40:00.000')",
      );
    }
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final day = await ScheduleRepository(db).day(LocalDate(2026, 11, 3));
    expect((day!.mark, day.openedAt), (DayMark.skipped, null));
    expect(await db.select(db.outbox).get(), hasLength(2));
    expect(await db.select(db.sessionExercises).get(), isEmpty);
    expect(await db.select(db.gymArrivals).get(), isEmpty);

    final api = FakeSyncApi();
    final engine = SyncEngine(
      db: db,
      api: api,
      stores: {
        SyncEntities.sessionExercise: SessionExerciseStore(
          SessionExerciseRepository(db),
        ),
        SyncEntities.exerciseFeel: ExerciseFeelStore(
          ExerciseFeelRepository(db),
        ),
        SyncEntities.schedulePause: SchedulePauseStore(
          SchedulePauseRepository(db),
        ),
        SyncEntities.gymLocation: GymLocationStore(GymLocationRepository(db)),
      },
      clock: FixedClock(DateTime(2026, 11, 4, 18, 45)),
      reporter: RecordingReporter(),
      scheduler: FakeScheduler(),
    );
    addTearDown(engine.stop);
    expect(await engine.syncNow(), SyncOutcome.synced);
    expect(api.pushes.single.mutations.map((m) => m.mutationId), [
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
    ]);
    expect(api.pulls, [0], reason: 'cursor 4321 → 0 một lần');
    final state = await db.select(db.syncState).getSingle();
    for (final e in [
      'session_exercise',
      'exercise_feel',
      'schedule_pause',
      'gym_location',
    ]) {
      expect(state.knownEntities, contains(e));
    }
  });

  test(
    '05 Bản 5 §6.12 quay lui: schema 3 → app 4.0.0 hạ user_version về 2 '
    '(bảng, cột Bản 5 còn nguyên) → cài lại 5.0.0 mở được, dữ liệu còn',
    () async {
      final schema = await verifier.schemaAt(2);
      final first = AppDatabase(schema.newConnection());
      await first.customStatement('''
      INSERT INTO days (date, kind, time, muscles, source, opened_at)
      VALUES ('2026-11-04', 'workout', '18:00', '["back"]', 'template',
        '2026-11-04T17:20:00.000')''');
      // App 4.0.0 (schemaVersion 2) mở database schema 3: Drift chỉ ghi lại
      // user_version = 2, không xóa bảng / cột.
      await first.customStatement('PRAGMA user_version = 2');
      await first.close();

      final again = AppDatabase(schema.newConnection());
      addTearDown(again.close);
      final day = await ScheduleRepository(again).day(LocalDate(2026, 11, 4));
      expect(day!.openedAt, isNotNull);
      expect(await again.select(again.gymArrivals).get(), isEmpty);
      final version = await again
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 3);
    },
  );
}
