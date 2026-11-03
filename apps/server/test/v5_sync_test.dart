import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// 06 Bản 5 VS52-T04, T08 (server): khung 4 entity mới với kiểm tra đủ theo
/// 05 Bản 5 §6.6.2, `day.openedAt`, `DayCloser`, pull theo phiên bản app
/// (TR5-07). Giờ Việt Nam = UTC+7; lịch `clockV5`: thứ 4 04/11 Lưng 18:00
/// (= 11:00 UTC).
void main() {
  late TestApp app;
  late String token;
  final t0 = DateTime.utc(2026, 11, 2, 5); // 12:00 thứ 2 02/11 giờ VN.

  setUp(() async {
    app = await TestApp.create(now: t0);
    token = (await app.register()).accessToken;
  });
  tearDown(() => app.dispose());

  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest],
    ),
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });
  final generated = MonthGenerator.first(template, DateTime(2026, 11, 2, 12));
  final wed = LocalDate(2026, 11, 4);
  final tue = LocalDate(2026, 11, 3);
  PlanDay day(LocalDate d) => generated.days.firstWhere((x) => x.date == d);

  /// Giờ VN [h]:[m] ngày [d] → UTC.
  DateTime vn(int d, int h, [int m = 0]) => DateTime.utc(2026, 11, d, h - 7, m);

  Future<String> login(String phone) async {
    final res = await app.post('/v1/auth/login', {
      'phone': phone,
      'password': testPassword,
    });
    return TokenPair.fromJson(res.json).accessToken;
  }

  Future<void> setNow(DateTime atUtc) async {
    app.clock.set(atUtc);
    token = await login('0912345678');
  }

  Future<List<PushResult>> push(List<SyncMutation> ms, {String? as}) async =>
      (await app.push(as ?? token, ms, appVersion: AppVersion.v5)).results;

  Future<PushResult> pushAt(DateTime atUtc, SyncMutation m) async {
    await setNow(atUtc);
    return (await push([m])).single;
  }

  SyncMutation dayMutation(
    PlanDay d, {
    SyncOp op = SyncOp.ensure,
    DateTime? at,
  }) => mutation(
    'day',
    d.date.toKey(),
    op,
    at: at ?? t0,
    data: const DayCodec().encode(d),
  );

  Future<void> insertExercise(String id, String region) async {
    final r = MuscleRegion.tryParse(region)!;
    await app.tdb.pool.execute(
      Sql.named('''
        INSERT INTO exercises (id, muscle_group, muscle_region, equipment, logs_weight, name_vi,
                               youtube_video_id, video_channel, video_duration_s, guide_steps,
                               guide_safety, approved_at, sort_order, active, library_version,
                               server_version)
        VALUES (@id, @group::muscle_group, @region, 'machine', @logs, @id, 'TrTSvn5-MTk',
                'Renaissance Periodization', 48, ARRAY['a','b','c'], ARRAY['x','y'],
                '2026-10-11', 1, true, 1, nextval('sync_version_seq'))'''),
      parameters: {
        'id': id,
        'group': r.group.name,
        'region': region,
        'logs': r.group != MuscleGroup.abs,
      },
    );
  }

  Future<void> setUpSchedule({String? as}) async {
    final profile = Profile(
      onboardingStep: 5,
      disclaimerAcceptedAt: DateTime.utc(2026, 11, 2, 4),
      heightCm: 175,
      birthYear: 1996,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
      calorieMode: CalorieMode.auto,
      calorieKcal: 2210,
      setupDate: LocalDate(2026, 11, 2),
      onboardingCompletedAt: DateTime.utc(2026, 11, 2, 5),
      timezone: ClockV5.timezone,
    );
    final results = await push([
      mutation(
        'profile',
        'me',
        SyncOp.upsert,
        at: t0,
        data: const ProfileCodec().encode(profile),
      ),
      mutation(
        'weekly_template',
        'me',
        SyncOp.upsert,
        at: t0,
        data: const WeeklyTemplateCodec().encode(template),
      ),
      mutation(
        'month_plan',
        MonthPlanCodec.keyOf(generated.plan.month),
        SyncOp.ensure,
        at: t0,
        data: const MonthPlanCodec().encode(generated.plan),
      ),
      for (final d in generated.days) dayMutation(d),
    ], as: as);
    expect(results.every((r) => r.status == PushStatus.applied), isTrue);
    await insertExercise('back-lat', 'lats');
    await insertExercise('back-row', 'lats');
    await insertExercise('chest-press', 'chest_mid');
    await insertExercise('abs-plank', 'abs_lower');
  }

  SyncMutation sessionRow(
    SessionExerciseRow row,
    DateTime atUtc, {
    SyncOp op = SyncOp.upsert,
  }) => mutation(
    SyncEntities.sessionExercise,
    row.key,
    op,
    at: atUtc,
    data: op == SyncOp.delete ? null : const SessionExerciseCodec().encode(row),
  );

  SessionExerciseRow replace(String id, String of) => SessionExerciseRow(
    date: wed,
    exerciseId: id,
    role: SessionExerciseRole.replacement,
    replacesExerciseId: of,
  );

  SessionExerciseRow extra(String id, {LocalDate? date}) => SessionExerciseRow(
    date: date ?? wed,
    exerciseId: id,
    role: SessionExerciseRole.extra,
    position: 1,
  );

  SyncMutation feel(String id, Feel f, DateTime atUtc, {LocalDate? date}) {
    final value = ExerciseFeel(date: date ?? wed, exerciseId: id, feel: f);
    return mutation(
      SyncEntities.exerciseFeel,
      value.key,
      SyncOp.upsert,
      at: atUtc,
      data: const ExerciseFeelCodec().encode(value),
    );
  }

  PlanDay marked(PlanDay d, DayMark mark, DateTime at) => d.withMark(
    mark,
    actual: mark == DayMark.done ? d.muscles : null,
    markedAt: at,
  );

  group('session_exercise (05 Bản 5 §6.6.2)', () {
    setUp(setUpSchedule);

    test('đổi bài hôm nay → applied; app 5.0.0 nhận, app 4.x bỏ qua mà cursor '
        'vẫn tiến (TR5-07)', () async {
      final r = await pushAt(
        vn(4, 18, 30),
        sessionRow(replace('chest-press', 'back-lat'), vn(4, 18, 30)),
      );
      expect(r.status, PushStatus.applied);
      final v5 = await app.pull(token, appVersion: AppVersion.v5);
      expect(
        v5.changes
            .where((c) => c.entity == SyncEntities.sessionExercise)
            .single
            .data,
        const SessionExerciseCodec().encode(replace('chest-press', 'back-lat')),
      );
      final v4 = await app.pull(token, appVersion: const AppVersion(4, 0, 0));
      expect(
        v4.changes.where((c) => c.entity == SyncEntities.sessionExercise),
        isEmpty,
      );
      expect(v4.nextCursor, v5.nextCursor);
    });

    test('ngày nghỉ → lift_no_session; hôm qua → day_locked; buổi "Đã tập" → '
        'session_done; cùng batch bỏ đánh dấu trước thì được', () async {
      final rest = await pushAt(
        vn(3, 18, 30),
        sessionRow(extra('abs-plank', date: tue), vn(3, 18, 30)),
      );
      expect(rest.code, ErrorCode.liftNoSession);
      final late = await pushAt(
        vn(5, 0, 1),
        sessionRow(extra('abs-plank'), vn(5, 0, 1)),
      );
      expect(
        (late.status, late.code),
        (PushStatus.rejected, ErrorCode.dayLocked),
      );

      final at = vn(4, 18, 30);
      await setNow(at);
      expect(
        (await push([
          dayMutation(
            marked(day(wed), DayMark.done, at),
            op: SyncOp.upsert,
            at: at,
          ),
        ])).single.status,
        PushStatus.applied,
      );
      final done = (await push([sessionRow(extra('abs-plank'), at)])).single;
      expect(
        (done.status, done.code),
        (PushStatus.rejected, ErrorCode.sessionDone),
      );
      final batch = await push([
        dayMutation(
          day(wed),
          op: SyncOp.upsert,
          at: at.add(const Duration(minutes: 1)),
        ),
        sessionRow(extra('abs-plank'), at.add(const Duration(minutes: 1))),
      ]);
      expect(batch.map((x) => x.status), [
        PushStatus.applied,
        PushStatus.applied,
      ]);
    });

    test(
      'bài trùng / vai trò sai → validation_failed (C5-03, FC5-04)',
      () async {
        final at = vn(4, 18, 30);
        await setNow(at);
        final results = await push([
          sessionRow(replace('chest-press', 'back-lat'), at),
          sessionRow(extra('back-row'), at),
          sessionRow(extra('back-lat'), at),
          sessionRow(
            SessionExerciseRow(
              date: wed,
              exerciseId: 'back-lat',
              role: SessionExerciseRole.original,
              skipped: true,
            ),
            at,
          ),
          sessionRow(extra('abs-plank'), at),
        ]);
        expect(results.map((r) => (r.status, r.field)), [
          (PushStatus.applied, null),
          (PushStatus.rejected, 'exerciseId'),
          (PushStatus.rejected, 'exerciseId'),
          (PushStatus.rejected, 'skipped'),
          (PushStatus.applied, null),
        ]);
        // Hủy đổi = tombstone.
        final cancel = (await push([
          sessionRow(
            replace('chest-press', 'back-lat'),
            at.add(const Duration(minutes: 1)),
            op: SyncOp.delete,
          ),
        ])).single;
        expect(cancel.status, PushStatus.applied);
      },
    );
  });

  group('exercise_feel (05 Bản 5 §6.6.2, F33)', () {
    setUp(setUpSchedule);

    test('trước giờ tập → lift_window_closed; tới gym 17:20 (openedAt) → '
        'được từ 17:20; hôm sau → day_locked', () async {
      final early = await pushAt(
        vn(4, 17, 25),
        feel('back-lat', Feel.easy, vn(4, 17, 25)),
      );
      expect(early.code, ErrorCode.liftWindowClosed);
      final opened = day(wed).withOpenedAt(vn(4, 17, 20));
      expect(
        (await pushAt(
          vn(4, 17, 20),
          dayMutation(opened, op: SyncOp.upsert, at: vn(4, 17, 20)),
        )).status,
        PushStatus.applied,
      );
      final ok = await pushAt(
        vn(4, 17, 26),
        feel('back-lat', Feel.easy, vn(4, 17, 26)),
      );
      expect(ok.status, PushStatus.applied);
      final late = await pushAt(
        vn(5, 0, 1),
        feel('back-lat', Feel.hard, vn(5, 0, 1)),
      );
      expect(late.code, ErrorCode.dayLocked);
    });

    test('TD5-09: bài thêm (kể cả bụng) được; bài gốc bị thay, bài ngoài buổi '
        '→ lift_exercise_not_in_session', () async {
      final at = vn(4, 18, 30);
      await setNow(at);
      final results = await push([
        sessionRow(replace('chest-press', 'back-lat'), at),
        sessionRow(extra('abs-plank'), at),
        feel('abs-plank', Feel.hard, at),
        feel('chest-press', Feel.medium, at),
        feel('back-lat', Feel.medium, at),
        feel('back-row', Feel.medium, at),
      ]);
      expect(results.map((r) => r.code), [
        null,
        null,
        null,
        null,
        ErrorCode.liftExerciseNotInSession,
        null,
      ]);
    });
  });

  group('schedule_pause (05 Bản 5 §6.6.2, F31)', () {
    setUp(setUpSchedule);
    const a = '0b6f1c9e-3d4a-4f6b-9a1e-2c3d4e5f6a7b';
    const b = '1c7f2d0f-4e5b-4a7c-8b2f-3d4e5f6a7b8c';
    SyncMutation pause(
      String id,
      int start,
      int end,
      DateTime at, {
      int? ended,
    }) => mutation(
      SyncEntities.schedulePause,
      id,
      SyncOp.upsert,
      at: at,
      data: const SchedulePauseCodec().encode(
        SchedulePause(
          id: id,
          startDate: LocalDate(2026, 11, start),
          endDate: LocalDate(2026, 11, end),
          endedOn: ended == null ? null : LocalDate(2026, 11, ended),
        ),
      ),
    );

    test('đặt T4 → CN; khoảng thứ hai → pause_overlap; bắt đầu ngày đã qua → '
        'startDate; kết thúc sớm (endedOn hôm qua) → applied; xóa khoảng đã '
        'bắt đầu → rejected', () async {
      final at = vn(3, 21);
      expect((await pushAt(at, pause(a, 4, 8, at))).status, PushStatus.applied);
      final second = await pushAt(at, pause(b, 10, 12, at));
      expect(
        (second.status, second.code),
        (PushStatus.rejected, ErrorCode.pauseOverlap),
      );
      final past = await pushAt(at, pause(b, 2, 12, at));
      expect(past.field, 'startDate');
      final sat = vn(7, 9);
      expect(
        (await pushAt(sat, pause(a, 4, 8, sat, ended: 6))).status,
        PushStatus.applied,
      );
      final del = await pushAt(
        sat.add(const Duration(minutes: 1)),
        mutation(
          SyncEntities.schedulePause,
          a,
          SyncOp.delete,
          at: sat.add(const Duration(minutes: 1)),
        ),
      );
      expect(del.status, PushStatus.rejected);
      // Khoảng cũ đã kết thúc → đặt khoảng mới được.
      expect(
        (await pushAt(sat, pause(b, 10, 12, sat))).status,
        PushStatus.applied,
      );
    });
  });

  group('gym_location (05 Bản 5 §6.6.2, TAC5-10)', () {
    test('lưu → pull trả tọa độ 6 chữ số; lat sai → lat; không ghi tọa độ vào '
        'log; tài khoản khác không thấy', () async {
      final g = GymLocation(lat: 10.7701234, lng: 106.6904567, savedAt: t0);
      final r = (await push([
        mutation(
          SyncEntities.gymLocation,
          'me',
          SyncOp.upsert,
          at: t0,
          data: const GymLocationCodec().encode(g),
        ),
      ])).single;
      expect(r.status, PushStatus.applied);
      final change = (await app.pull(
        token,
        appVersion: AppVersion.v5,
      )).changes.where((c) => c.entity == SyncEntities.gymLocation).single;
      final back = const GymLocationCodec().decode('me', change.data!);
      expect((back.lat, back.lng, back.enabled), (10.770123, 106.690457, true));
      final bad = (await push([
        mutation(
          SyncEntities.gymLocation,
          'me',
          SyncOp.upsert,
          at: t0,
          data: {...const GymLocationCodec().encode(g), 'lat': 91},
        ),
      ])).single;
      expect((bad.status, bad.field), (PushStatus.rejected, 'lat'));
      expect(app.log.lines.join('\n'), isNot(contains('10.77')));
      expect(app.log.lines.join('\n'), isNot(contains('106.69')));
      final other = (await app.register(phone: '0912345679')).accessToken;
      final otherPull = await app.pull(other, appVersion: AppVersion.v5);
      expect(
        otherPull.changes.where((c) => c.entity == SyncEntities.gymLocation),
        isEmpty,
      );
    });
  });

  group('day.openedAt (TD5-07)', () {
    setUp(setUpSchedule);

    test('TAC5-04: "Đã tập" 17:20 với openedAt 17:20 → applied; mốc sớm hơn '
        'thắng; openedAt sau giờ tập → openedAt', () async {
      final at = vn(4, 17, 20);
      final opened = day(wed).withOpenedAt(at);
      expect(
        (await pushAt(
          at,
          dayMutation(
            marked(opened, DayMark.done, at),
            op: SyncOp.upsert,
            at: at,
          ),
        )).status,
        PushStatus.applied,
      );
      final later = day(wed).withOpenedAt(vn(4, 17, 40));
      final r = await pushAt(
        vn(4, 17, 41),
        dayMutation(
          marked(later, DayMark.done, at),
          op: SyncOp.upsert,
          at: vn(4, 17, 41),
        ),
      );
      expect(r.status, PushStatus.applied);
      final pulled = (await app.pull(
        token,
        appVersion: AppVersion.v5,
      )).changes.lastWhere((c) => c.key == wed.toKey());
      expect(const DayCodec().decode(pulled.key, pulled.data!).openedAt, at);
      final fri = LocalDate(2026, 11, 6);
      final bad = await pushAt(
        vn(6, 17, 42),
        dayMutation(
          day(fri).withOpenedAt(vn(6, 18, 30)),
          op: SyncOp.upsert,
          at: vn(6, 17, 42),
        ),
      );
      expect((bad.status, bad.field), (PushStatus.rejected, 'openedAt'));
    });
  });

  group('DayCloser (TD5-12, TD5-17, F05-AC63)', () {
    setUp(setUpSchedule);

    Future<String?> markOf(LocalDate d) async =>
        (await app.tdb.pool.execute(
              Sql.named('SELECT mark::text FROM days WHERE date = @d::date'),
              parameters: {'d': d.toKey()},
            )).single[0]
            as String?;

    test('00:05 thứ 5: buổi thứ 4 chưa đánh dấu → skipped_auto; pull không gửi '
        'giá trị này; hôm nay không đụng; buổi "Đã tập" lúc 23:59 tới muộn vẫn '
        'đè được', () async {
      final closer = DayCloser(app.tdb.pool, app.clock);
      app.clock.set(vn(4, 23, 50));
      expect(await closer.run(), 1, reason: 'thứ 2 02/11 chưa đánh dấu');
      expect(await markOf(wed), isNull);
      app.clock.set(vn(5, 0, 5));
      expect(await closer.run(), 1);
      expect(await markOf(wed), 'skipped_auto');
      expect(await closer.run(), 0, reason: 'chạy lại không đổi gì');
      await setNow(vn(5, 0, 5));
      final pulled = (await app.pull(
        token,
        appVersion: AppVersion.v5,
      )).changes.lastWhere((c) => c.key == wed.toKey());
      expect(pulled.data!['mark'], isNull);
      // Mutation "Đã tập" lúc 23:59 thứ 4 tới sau khi đã đóng.
      final at = vn(4, 23, 59);
      await setNow(vn(5, 0, 6));
      final r = (await push([
        dayMutation(
          marked(day(wed), DayMark.done, at),
          op: SyncOp.upsert,
          at: at,
        ),
      ])).single;
      expect(r.status, PushStatus.applied);
      expect(await markOf(wed), 'done');
    });

    test('F31-R3: ngày trong khoảng tạm dừng không bị đóng', () async {
      final at = vn(3, 21);
      await setNow(at);
      expect(
        (await push([
          mutation(
            SyncEntities.schedulePause,
            '0b6f1c9e-3d4a-4f6b-9a1e-2c3d4e5f6a7b',
            SyncOp.upsert,
            at: at,
            data: const SchedulePauseCodec().encode(
              SchedulePause(
                id: '0b6f1c9e-3d4a-4f6b-9a1e-2c3d4e5f6a7b',
                startDate: wed,
                endDate: LocalDate(2026, 11, 8),
              ),
            ),
          ),
        ])).single.status,
        PushStatus.applied,
      );
      app.clock.set(vn(5, 0, 5));
      await DayCloser(app.tdb.pool, app.clock).run();
      expect(await markOf(wed), isNull);
      expect(await markOf(LocalDate(2026, 11, 2)), 'skipped_auto');
    });
  });
}
