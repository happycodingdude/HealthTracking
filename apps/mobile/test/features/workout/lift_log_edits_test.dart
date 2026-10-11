import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/data/sync/sync_status.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/fake_sync.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 2 VS26-T06, VS26-T07, VS26-T08 (app).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeSyncApi api;
  late SyncEngine engine;
  late LiftLogRepository logs;
  late SaveLiftLog save;
  late DeleteLiftLog delete;
  late List<Exercise> library;

  // Thứ 2 12/10: Ngực + Tay sau 18:00 (templateAc2).
  final monday = LocalDate(2026, 10, 12);
  late String chest;
  late String triceps;
  late String shoulders;
  late String abs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 19));
    api = FakeSyncApi();
    logs = LiftLogRepository(db);
    final schedule = ScheduleRepository(db);
    final exercises = ExerciseRepository(db);
    final outbox = OutboxWriter(db, clock);
    save = SaveLiftLog(
      db: db,
      logs: logs,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
    );
    delete = DeleteLiftLog(
      db: db,
      logs: logs,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
    );
    engine = SyncEngine(
      db: db,
      api: api,
      stores: {SyncEntities.liftLog: LiftLogStore(logs)},
      clock: clock,
      reporter: RecordingReporter(),
      scheduler: FakeScheduler(),
    );
    await seedSetUp(db);
    library = await seedLibrary(db);
    chest = exerciseOf(library, MuscleRegion.chestUpper).id;
    triceps = exerciseOf(library, MuscleRegion.tricepsLong).id;
    shoulders = exerciseOf(library, MuscleRegion.deltSide).id;
    abs = exerciseOf(library, MuscleRegion.absLower).id;
  });
  tearDown(() async {
    engine.stop();
    await db.close();
  });

  Future<List<SyncMutation>> outbox() async => [
    for (final r in await db.select(db.outbox).get()) r.toMutation(),
  ];

  Future<LiftException> liftError(Future<Object?> f) async {
    try {
      await f;
    } on LiftException catch (e) {
      return e;
    }
    fail('không ném LiftException');
  }

  test('TAC-01 mở rộng, F21-R10: không có mạng → bản ghi trên máy và giao '
      'diện cập nhật ngay, không gọi mạng; "Chưa đồng bộ" tính cả mức tạ '
      '(F09-R21)', () async {
    api.offline = true;
    final day = logs.watchDay(monday);
    final saved = await save(monday, chest, start: '72,5', end: '75.5');
    expect(saved.startKgX10, 725);
    expect(saved.endKgX10, 755);
    expect(await day.first, [saved]);
    expect(api.calls, 0);
    final m = (await outbox()).single;
    expect(
      (m.entity, m.key, m.op),
      ('lift_log', '2026-10-12:$chest', SyncOp.upsert),
    );
    expect(m.data, {
      'date': '2026-10-12',
      'exerciseId': chest,
      'startKgX10': 725,
      'endKgX10': 755,
    });
    expect((await watchSyncStatus(db).first).pending, 1);
  });

  test('F21-AC3: ghi lại cùng bài trong buổi → ghi đè; outbox gộp thành một '
      'mutation, xóa sau đó → một mutation delete', () async {
    await save(monday, chest, start: '50', end: '60');
    await save(monday, chest, start: '55', end: '65');
    expect(await logs.get(monday, chest), isA<LiftLog>());
    expect((await logs.get(monday, chest))!.endKgX10, 650);
    var ms = await outbox();
    expect(ms.single.data?['endKgX10'], 650);
    await delete(monday, chest);
    expect(await logs.get(monday, chest), isNull);
    ms = await outbox();
    expect((ms.single.op, ms.single.data), (SyncOp.delete, null));
  });

  test('F21-V1 → V4: ô sai → LiftInputException, không lưu gì', () async {
    for (final (start, end, startError, endError) in [
      ('', '60', LiftInputError.missing, null),
      ('0', '300,5', LiftInputError.outOfRange, LiftInputError.outOfRange),
      ('72,3', 'abc', LiftInputError.notStep, LiftInputError.notNumber),
    ]) {
      await expectLater(
        save(monday, chest, start: start, end: end),
        throwsA(
          isA<LiftInputException>()
              .having((e) => e.input.startError, 'start', startError)
              .having((e) => e.input.endError, 'end', endError),
        ),
      );
    }
    expect(await outbox(), isEmpty);
    expect(await logs.watchDay(monday).first, isEmpty);
  });

  test('FA2-17, F21-E4: thời điểm bấm Lưu quyết định — 23:59 lưu được, '
      '00:00 → windowClosed; xóa ngoài cửa sổ cũng bị từ chối', () async {
    clock.set(DateTime(2026, 10, 12, 23, 59));
    await save(monday, chest, start: '50', end: '60');
    clock.set(DateTime(2026, 10, 13));
    expect(
      (await liftError(save(monday, triceps, start: '20', end: '25'))).error,
      LiftError.windowClosed,
    );
    expect(
      (await liftError(delete(monday, chest))).error,
      LiftError.windowClosed,
    );
    expect(await logs.get(monday, chest), isNotNull);
    expect((await outbox()).single.op, SyncOp.upsert);
  });

  test('F21-AC1: 17:59 chưa ghi được, 18:00 được', () async {
    clock.set(DateTime(2026, 10, 12, 17, 59));
    expect(
      (await liftError(save(monday, chest, start: '50', end: '60'))).error,
      LiftError.windowClosed,
    );
    clock.set(DateTime(2026, 10, 12, 18));
    await save(monday, chest, start: '50', end: '60');
  });

  test('F21-AC13, F21-AC14: bài vai trong buổi ngực, bài bụng, ngày nghỉ → '
      'từ chối', () async {
    expect(
      (await liftError(save(monday, shoulders, start: '10', end: '12'))).error,
      LiftError.exerciseNotInSession,
    );
    expect(
      (await liftError(save(monday, abs, start: '10', end: '12'))).error,
      LiftError.notAllowedForExercise,
    );
    clock.set(DateTime(2026, 10, 13, 19));
    expect(
      (await liftError(
        save(LocalDate(2026, 10, 13), chest, start: '10', end: '12'),
      )).error,
      LiftError.noSession,
    );
    expect(await outbox(), isEmpty);
  });

  test('F21-E7: bài đã rời thư viện — tạo mới bị chặn, bản ghi đã có vẫn '
      'sửa, xóa được', () async {
    await save(monday, chest, start: '50', end: '60');
    final repo = ExerciseRepository(db);
    for (final id in [chest, triceps]) {
      await repo.put((await repo.get(id))!.copyWith(active: false));
    }
    expect(
      (await liftError(save(monday, triceps, start: '20', end: '25'))).error,
      LiftError.notAllowedForExercise,
    );
    await save(monday, chest, start: '50', end: '62,5');
    await delete(monday, chest);
    expect(await logs.get(monday, chest), isNull);
  });

  test('F05-R28: "Không tập" đếm số bài đã có mức tạ của buổi; mức tạ giữ '
      'nguyên sau khi lưu (FD2-02)', () async {
    final skipped = MarkSessionSkipped(
      db: db,
      schedule: ScheduleRepository(db),
      liftLogs: logs,
      outbox: OutboxWriter(db, clock),
      clock: clock,
    );
    expect(await skipped.liftLogCount(monday), 0);
    await save(monday, chest, start: '50', end: '60');
    await save(monday, triceps, start: '20', end: '25');
    expect(await skipped.liftLogCount(monday), 2);
    await skipped(monday);
    expect(await logs.watchDay(monday).first, hasLength(2));
  });

  test('pull: bản ghi và tombstone của lift_log ghi vào bảng trên máy; push '
      'bị từ chối → hoàn về bản server (TA-12)', () async {
    final log = LiftLog(
      date: monday,
      exerciseId: chest,
      startKgX10: 500,
      endKgX10: 600,
    );
    api.pages[0] = PullResponse(
      changes: [
        SyncChange(
          entity: 'lift_log',
          key: log.key,
          deleted: false,
          serverVersion: 5,
          data: const LiftLogCodec().encode(log),
        ),
      ],
      nextCursor: 5,
      hasMore: false,
      remaining: 0,
      meta: SyncMeta(serverTime: DateTime.utc(2026, 10, 12, 12)),
    );
    await engine.syncNow();
    expect(await logs.get(monday, chest), log);

    await save(monday, chest, start: '50', end: '65');
    api.onPush = (m) => PushResult(
      mutationId: m.mutationId,
      status: PushStatus.rejected,
      code: ErrorCode.liftWindowClosed,
      field: 'key',
      current: SyncChange(
        entity: 'lift_log',
        key: log.key,
        deleted: false,
        serverVersion: 5,
        data: const LiftLogCodec().encode(log),
      ),
    );
    await engine.syncNow();
    expect(await logs.get(monday, chest), log);
    expect(await outbox(), isEmpty);

    api.pages[5] = PullResponse(
      changes: [
        SyncChange(
          entity: 'lift_log',
          key: log.key,
          deleted: true,
          serverVersion: 9,
        ),
      ],
      nextCursor: 9,
      hasMore: false,
      remaining: 0,
      meta: SyncMeta(serverTime: DateTime.utc(2026, 10, 12, 12)),
    );
    api.onPush = (m) =>
        PushResult(mutationId: m.mutationId, status: PushStatus.applied);
    await engine.syncNow();
    expect(await logs.get(monday, chest), isNull);
  });
}
