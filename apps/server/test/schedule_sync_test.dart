import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;
  late String token;
  final t0 = DateTime.utc(2026, 10, 7, 5);

  setUp(() async {
    app = await TestApp.create();
    token = (await app.register()).accessToken;
  });
  tearDown(() => app.dispose());

  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
  });
  final generated = MonthGenerator.first(template, DateTime(2026, 10, 7, 12));

  SyncMutation templateUpsert(WeeklyTemplate t, {DateTime? at}) => mutation(
    'weekly_template',
    'me',
    SyncOp.upsert,
    at: at ?? t0,
    data: const WeeklyTemplateCodec().encode(t),
  );

  SyncMutation planEnsure(MonthPlan p, {DateTime? at}) => mutation(
    'month_plan',
    MonthPlanCodec.keyOf(p.month),
    SyncOp.ensure,
    at: at ?? t0,
    data: const MonthPlanCodec().encode(p),
  );

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

  Future<List<PushResult>> push(
    List<SyncMutation> ms, {
    String? as,
    AppVersion? appVersion,
  }) async => (await app.push(as ?? token, ms, appVersion: appVersion)).results;

  test(
    'lưu lịch tuần lần đầu: template + month_plan + các ngày, khứ hồi qua pull',
    () async {
      final results = await push([
        templateUpsert(template),
        planEnsure(generated.plan),
        for (final d in generated.days) dayMutation(d),
      ]);
      expect(results.every((r) => r.status == PushStatus.applied), isTrue);

      final pulled = (await app.pull(token)).changes;
      final t = pulled.singleWhere((c) => c.entity == 'weekly_template');
      expect(const WeeklyTemplateCodec().decode(t.data!), template);
      final p = pulled.singleWhere((c) => c.entity == 'month_plan');
      expect(const MonthPlanCodec().decode(p.key, p.data!), generated.plan);
      final days = [
        for (final c in pulled.where((c) => c.entity == 'day'))
          const DayCodec().decode(c.key, c.data!),
      ];
      expect(days, generated.days);
    },
  );

  group('kiểm tra lại bằng domain (VS04-T06)', () {
    test('F03-V1: lịch tuần không có ngày tập → rejected', () async {
      final r = (await push([templateUpsert(WeeklyTemplate({}))])).single;
      expect((r.status, r.field), (PushStatus.rejected, 'days'));
    });

    test('F03-V3: thứ có tập thiếu nhóm cơ → rejected', () async {
      final bad = WeeklyTemplate({
        2: TemplateDay(enabled: true, time: LocalTime(7, 0)),
      });
      expect((await push([templateUpsert(bad)])).single.field, 'days');
    });

    test('contentHash không khớp hoặc có chủ nhật → rejected', () async {
      final data = const WeeklyTemplateCodec().encode(template)
        ..['contentHash'] = 'a' * 64;
      final r = (await push([
        mutation('weekly_template', 'me', SyncOp.upsert, at: t0, data: data),
      ])).single;
      expect(r.field, 'contentHash');
      final sunday = {
        'days': {
          ...template.toJson(),
          '7': {'enabled': false},
        },
        'contentHash': template.contentHash,
      };
      expect(
        (await push([
          mutation(
            'weekly_template',
            'me',
            SyncOp.upsert,
            at: t0,
            data: sunday,
          ),
        ])).single.field,
        'days',
      );
    });

    test(
      'ngày: chủ nhật, ngày tập thiếu giờ, chưa có month_plan → rejected',
      () async {
        final sunday = PlanDay(
          date: LocalDate(2026, 10, 11),
          kind: DayKind.rest,
        );
        expect((await push([dayMutation(sunday)])).single.field, 'key');
        final noTime = mutation(
          'day',
          '2026-10-12',
          SyncOp.ensure,
          at: t0,
          data: {
            'kind': 'workout',
            'muscles': ['abs'],
            'source': 'template',
          },
        );
        expect((await push([noTime])).single.field, 'time');
        final r = (await push([dayMutation(generated.days.first)])).single;
        expect((r.status, r.field), (PushStatus.rejected, 'key'));
      },
    );
  });

  test('VS04-T12: ensure sau upsert không ghi đè; hai máy cùng ensure một '
      'ngày → một bản ghi', () async {
    await push([templateUpsert(template), planEnsure(generated.plan)]);
    final day = generated.days.first;
    final changed = PlanDay(
      date: day.date,
      kind: DayKind.workout,
      time: LocalTime(19, 0),
      muscles: const [MuscleGroup.abs],
      source: DaySource.override,
    );
    expect(
      (await push([dayMutation(changed, op: SyncOp.upsert)])).single.status,
      PushStatus.applied,
    );
    // Máy khác vẫn còn bản cũ, tạo lại bằng ensure (ví dụ chia tháng mới).
    final again = (await push([
      dayMutation(day, at: t0.add(const Duration(hours: 1))),
    ])).single;
    expect(again.status, PushStatus.ignoredStale);
    expect(
      const DayCodec().decode(day.date.toKey(), again.current!.data!),
      changed,
    );
    expect(
      (await push([planEnsure(generated.plan)])).single.status,
      PushStatus.ignoredStale,
    );

    final rows = await app.tdb.pool.execute(
      "SELECT count(*) FROM days WHERE date = '2026-10-07'",
    );
    expect(rows.single[0], 1);
  });

  test('TAC-07: B không đọc, không ghi được lịch của A', () async {
    await push([
      templateUpsert(template),
      planEnsure(generated.plan),
      for (final d in generated.days) dayMutation(d),
    ]);
    final b = (await app.register(
      phone: '0922222222',
      name: 'Bình',
    )).accessToken;
    expect(
      [for (final c in (await app.pull(b)).changes) c.entity],
      ['account'],
    );
    // B chưa có month_plan nên không tạo được ngày, dù A đã có tháng đó.
    expect(
      (await push([dayMutation(generated.days[1])], as: b)).single.field,
      'key',
    );
    await push([planEnsure(generated.plan)], as: b);
    expect(
      (await push([dayMutation(generated.days[1])], as: b)).single.status,
      PushStatus.applied,
    );
    final count = await app.tdb.pool.execute(
      'SELECT count(DISTINCT user_id) FROM days',
    );
    expect(count.single[0], 2);
  });

  group('đánh dấu buổi tập (VS06-T03)', () {
    // Giờ Việt Nam = UTC+7. Buổi thứ 4 07/10 Lưng 18:00 = 11:00 UTC.
    final wed = generated.days.firstWhere(
      (d) => d.date == LocalDate(2026, 10, 7),
    );

    Future<void> setUpSchedule({String? timezone = 'Asia/Ho_Chi_Minh'}) async {
      final profile = Profile(
        onboardingStep: 5,
        disclaimerAcceptedAt: DateTime.utc(2026, 10, 7, 4),
        heightCm: 175,
        birthYear: 1996,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        calorieMode: CalorieMode.auto,
        calorieKcal: 2210,
        setupDate: LocalDate(2026, 10, 7),
        onboardingCompletedAt: DateTime.utc(2026, 10, 7, 5),
        timezone: timezone,
      );
      final results = await push([
        mutation(
          'profile',
          'me',
          SyncOp.upsert,
          at: t0,
          data: const ProfileCodec().encode(profile),
        ),
        templateUpsert(template),
        planEnsure(generated.plan),
        for (final d in generated.days) dayMutation(d),
      ]);
      expect(results.every((r) => r.status == PushStatus.applied), isTrue);
    }

    PlanDay marked(DayMark mark, DateTime at) => wed.withMark(
      mark,
      actual: mark == DayMark.done ? const [MuscleGroup.back] : null,
      markedAt: at,
    );

    /// Đặt giờ server và đăng nhập lại (access token sống 15 phút).
    Future<void> setNow(DateTime atUtc) async {
      app.clock.set(atUtc);
      final res = await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': '***REMOVED***',
      });
      token = TokenPair.fromJson(res.json).accessToken;
    }

    Future<PushResult> markAt(
      DayMark mark,
      DateTime atUtc, {
      AppVersion? appVersion,
    }) async {
      await setNow(atUtc);
      return (await push([
        dayMutation(marked(mark, atUtc), op: SyncOp.upsert, at: atUtc),
      ], appVersion: appVersion)).single;
    }

    /// Ghi nguyên bản [day] lúc [atUtc] (giờ iPhone = UTC+7).
    Future<PushResult> writeAt(
      PlanDay day,
      DateTime atUtc, {
      AppVersion? appVersion,
    }) async {
      await setNow(atUtc);
      return (await push([
        dayMutation(day, op: SyncOp.upsert, at: atUtc),
      ], appVersion: appVersion)).single;
    }

    Future<PlanDay> serverDay(LocalDate date) async {
      final c = (await app.pull(
        token,
      )).changes.lastWhere((c) => c.key == date.toKey());
      return const DayCodec().decode(c.key, c.data!);
    }

    test('TAC2-03: buổi "Đã tập" → đổi sang Không tập, đổi nhóm cơ thực tế, '
        'bỏ đánh dấu, cho nghỉ — app Bản 1 hay Bản 2 → rejected '
        'session_locked, server giữ nguyên', () async {
      await setUpSchedule();
      // 19:00 07/10 giờ Việt Nam = 12:00 UTC.
      expect(
        (await markAt(
          DayMark.done,
          DateTime.utc(2026, 10, 7, 12),
          appVersion: AppVersion.v2,
        )).status,
        PushStatus.applied,
      );
      final done = await serverDay(wed.date);
      final attempts = [
        marked(DayMark.skipped, DateTime.utc(2026, 10, 7, 12, 30)),
        done.withMark(
          DayMark.done,
          actual: const [MuscleGroup.shoulders],
          markedAt: done.markedAt,
        ),
        wed,
        PlanDay(date: wed.date, kind: DayKind.rest, source: DaySource.override),
      ];
      for (final version in [null, AppVersion.v2]) {
        for (final (i, a) in attempts.indexed) {
          final r = await writeAt(
            a,
            DateTime.utc(2026, 10, 7, 12, 30 + i),
            appVersion: version,
          );
          expect(
            (r.status, r.code),
            (PushStatus.rejected, ErrorCode.sessionLocked),
            reason: '$version #$i',
          );
          expect(
            const DayCodec().decode(wed.date.toKey(), r.current!.data!).mark,
            DayMark.done,
          );
        }
      }
      expect((await serverDay(wed.date)).actualMuscles, [MuscleGroup.back]);
    });

    test('app Bản 1 (không có header) ghi "Đã tập" với nhóm cơ thực tế tự '
        'chọn → applied, rồi khóa như mọi buổi; app Bản 2 phải ghi đúng nhóm '
        'cơ của lịch (TD2-08)', () async {
      await setUpSchedule();
      final at = DateTime.utc(2026, 10, 7, 12);
      final v1 = wed.withMark(
        DayMark.done,
        actual: const [MuscleGroup.shoulders],
        markedAt: at,
      );
      expect(
        (await writeAt(v1, at, appVersion: AppVersion.v2)).field,
        'actualMuscles',
      );
      expect((await writeAt(v1, at)).status, PushStatus.applied);
      final undo = await writeAt(wed, DateTime.utc(2026, 10, 8, 3));
      expect(undo.code, ErrorCode.sessionLocked);
      expect((await serverDay(wed.date)).actualMuscles, [
        MuscleGroup.shoulders,
      ]);
    });

    test('F05-R25: Không tập → Đã tập trong 7 ngày (app Bản 2) → applied rồi '
        'khóa', () async {
      await setUpSchedule();
      expect(
        (await markAt(
          DayMark.skipped,
          DateTime.utc(2026, 10, 7, 12),
          appVersion: AppVersion.v2,
        )).status,
        PushStatus.applied,
      );
      // 10:00 13/10 giờ Việt Nam.
      expect(
        (await markAt(
          DayMark.done,
          DateTime.utc(2026, 10, 13, 3),
          appVersion: AppVersion.v2,
        )).status,
        PushStatus.applied,
      );
      final back = await markAt(
        DayMark.skipped,
        DateTime.utc(2026, 10, 13, 4),
        appVersion: AppVersion.v2,
      );
      expect(back.code, ErrorCode.sessionLocked);
    });

    test('F05-AC1: 17:59 giờ iPhone → rejected, kèm bản trên server; 18:00 '
        '→ applied', () async {
      await setUpSchedule();
      final early = await markAt(
        DayMark.done,
        DateTime.utc(2026, 10, 7, 10, 59),
      );
      expect((early.status, early.field), (PushStatus.rejected, 'mark'));
      expect(
        const DayCodec().decode(wed.date.toKey(), early.current!.data!).mark,
        isNull,
      );
      final ok = await markAt(DayMark.done, DateTime.utc(2026, 10, 7, 11));
      expect(ok.status, PushStatus.applied);
      final pulled = (await app.pull(
        token,
      )).changes.lastWhere((c) => c.key == wed.date.toKey());
      final day = const DayCodec().decode(pulled.key, pulled.data!);
      expect(day.mark, DayMark.done);
      expect(day.actualMuscles, [MuscleGroup.back]);
    });

    test('F05-AC4: sửa được đến hết 14/10, 00:00 15/10 giờ iPhone → '
        'rejected', () async {
      await setUpSchedule();
      // 23:59 14/10 giờ Việt Nam = 16:59 UTC.
      expect(
        (await markAt(
          DayMark.skipped,
          DateTime.utc(2026, 10, 14, 16, 59),
        )).status,
        PushStatus.applied,
      );
      final late = await markAt(DayMark.done, DateTime.utc(2026, 10, 14, 17));
      expect((late.status, late.field), (PushStatus.rejected, 'mark'));
    });

    test('đánh dấu ngày nghỉ, "Đã tập" thiếu nhóm cơ → rejected', () async {
      await setUpSchedule();
      final at = DateTime.utc(2026, 10, 8, 12);
      await setNow(at);
      final rest = generated.days.firstWhere((d) => !d.isWorkout);
      final restMarked = mutation(
        'day',
        rest.date.toKey(),
        SyncOp.upsert,
        at: at,
        data: {
          ...const DayCodec().encode(rest),
          'mark': 'skipped',
          'markedAt': '2026-10-08T12:00:00.000Z',
        },
      );
      expect((await push([restMarked])).single.field, 'mark');
      final noMuscles = mutation(
        'day',
        wed.date.toKey(),
        SyncOp.upsert,
        at: at,
        data: {
          ...const DayCodec().encode(wed),
          'mark': 'done',
          'markedAt': '2026-10-08T12:00:00.000Z',
        },
      );
      expect((await push([noMuscles])).single.field, 'actualMuscles');
    });

    test('hồ sơ chưa có múi giờ → không áp quy tắc thời gian', () async {
      await setUpSchedule(timezone: null);
      expect(
        (await markAt(DayMark.done, DateTime.utc(2026, 10, 7, 10))).status,
        PushStatus.applied,
      );
    });

    test('TAC-07: B không đánh dấu được ngày của A', () async {
      await setUpSchedule();
      final at = DateTime.utc(2026, 10, 7, 12);
      await setNow(at);
      final b = (await app.register(
        phone: '0933333333',
        name: 'Bình',
      )).accessToken;
      final r = (await push([
        dayMutation(marked(DayMark.done, at), op: SyncOp.upsert, at: at),
      ], as: b)).single;
      expect((r.status, r.field), (PushStatus.rejected, 'key'));
      final rows = await app.tdb.pool.execute(
        "SELECT mark FROM days WHERE date = '2026-10-07'",
      );
      expect(rows.single[0], isNull);
    });

    // Buổi tập thêm (VS07-T02). Thứ 7 10/10 nghỉ; 20:00 giờ Việt Nam = 13:00
    // UTC.
    final sat = generated.days.firstWhere(
      (d) => d.date == LocalDate(2026, 10, 10),
    );

    Future<PushResult> extraAt(
      PlanDay day,
      List<MuscleGroup>? muscles,
      DateTime atUtc,
    ) async {
      await setNow(atUtc);
      return (await push([
        dayMutation(
          day.withExtra(muscles, loggedAt: muscles == null ? null : atUtc),
          op: SyncOp.upsert,
          at: atUtc,
        ),
      ])).single;
    }

    test('F05-AC6: buổi tập thêm cho ngày mai, cho ngày đã có buổi theo lịch '
        '→ rejected; thứ 7 ghi cho hôm nay → applied', () async {
      await setUpSchedule();
      const abs = [MuscleGroup.abs];
      final tomorrow = await extraAt(sat, abs, DateTime.utc(2026, 10, 9, 13));
      expect(
        (tomorrow.status, tomorrow.field),
        (PushStatus.rejected, 'extraMuscles'),
      );
      final workout = await extraAt(wed, abs, DateTime.utc(2026, 10, 10, 13));
      expect(
        (workout.status, workout.field),
        (PushStatus.rejected, 'extraMuscles'),
      );
      final ok = await extraAt(sat, abs, DateTime.utc(2026, 10, 10, 13));
      expect(ok.status, PushStatus.applied);
      final rows = await app.tdb.pool.execute(
        "SELECT extra_muscles::text[] FROM days WHERE date = '2026-10-10'",
      );
      expect(rows.single[0], ['abs']);
    });

    // Sửa riêng, chia lại (VS09-T04). 14/10 10:00 giờ Việt Nam = 03:00 UTC.
    Future<PushResult> overrideAt(PlanDay after, DateTime atUtc) async {
      await setNow(atUtc);
      return (await push([
        dayMutation(after, op: SyncOp.upsert, at: atUtc),
      ])).single;
    }

    PlanDay restOverride(LocalDate date) =>
        PlanDay(date: date, kind: DayKind.rest, source: DaySource.override);

    test('F03-AC9: sửa riêng ngày đã qua → rejected; F03-R9: hôm nay sau '
        'giờ tập → rejected; ngày tới trong tháng → applied', () async {
      await setUpSchedule();
      final at = DateTime.utc(2026, 10, 14, 3);
      final past = await overrideAt(restOverride(LocalDate(2026, 10, 7)), at);
      expect((past.status, past.field), (PushStatus.rejected, 'key'));
      final ok = await overrideAt(restOverride(LocalDate(2026, 10, 21)), at);
      expect(ok.status, PushStatus.applied);
      // 18:30 giờ Việt Nam ngày 14/10: buổi thứ 4 đã đến giờ.
      final started = await overrideAt(
        restOverride(LocalDate(2026, 10, 14)),
        DateTime.utc(2026, 10, 14, 11, 30),
      );
      expect((started.status, started.field), (PushStatus.rejected, 'key'));
      final rows = await app.tdb.pool.execute(
        "SELECT to_char(date, 'DD'), kind::text, source::text FROM days "
        "WHERE date IN ('2026-10-07', '2026-10-14', '2026-10-21') ORDER BY date",
      );
      expect(rows.map((r) => r.toList()), [
        ['07', 'workout', 'template'],
        ['14', 'workout', 'template'],
        ['21', 'rest', 'override'],
      ]);
    });

    test('F03-R8: chia lại → month_plan upsert (templateHash, redistributedAt) '
        'và các ngày từ hôm nay → applied', () async {
      await setUpSchedule();
      final at = DateTime.utc(2026, 10, 14, 3);
      await setNow(at);
      final shoulders = WeeklyTemplate({
        ...template.days,
        3: TemplateDay(
          enabled: true,
          time: LocalTime(18, 0),
          muscles: const [MuscleGroup.shoulders],
        ),
      });
      final r = Redistributor.apply(
        days: generated.days,
        template: shoulders,
        now: DateTime(2026, 10, 14, 10),
      );
      final plan = MonthPlan(
        month: generated.plan.month,
        startDate: generated.plan.startDate,
        templateHash: shoulders.contentHash,
        generatedAt: generated.plan.generatedAt,
        redistributedAt: at,
      );
      final results = await push([
        templateUpsert(shoulders, at: at),
        mutation(
          'month_plan',
          '2026-10',
          SyncOp.upsert,
          at: at,
          data: const MonthPlanCodec().encode(plan),
        ),
        for (final d in r.changed) dayMutation(d, op: SyncOp.upsert, at: at),
      ]);
      expect(results.map((x) => x.status).toSet(), {PushStatus.applied});
      final rows = await app.tdb.pool.execute(
        "SELECT count(*) FROM days WHERE muscles = '{shoulders}' "
        'AND extract(isodow FROM date) = 3',
      );
      expect(rows.single[0], 3, reason: '14/10, 21/10, 28/10');
    });

    test('TAC2-04: buổi tập thêm đã lưu → xóa hoặc đổi nhóm cơ, kể cả trong '
        'ngày → rejected extra_session_locked, server giữ nguyên', () async {
      await setUpSchedule();
      final added = sat.withExtra(const [
        MuscleGroup.abs,
      ], loggedAt: DateTime.utc(2026, 10, 10, 13));
      expect(
        (await extraAt(sat, const [
          MuscleGroup.abs,
        ], DateTime.utc(2026, 10, 10, 13))).status,
        PushStatus.applied,
      );
      final changed = await extraAt(added, const [
        MuscleGroup.back,
      ], DateTime.utc(2026, 10, 10, 13, 30));
      expect(
        (changed.status, changed.code),
        (PushStatus.rejected, ErrorCode.extraSessionLocked),
      );
      final deleted = await extraAt(
        added,
        null,
        DateTime.utc(2026, 10, 10, 13, 31),
      );
      expect(deleted.code, ErrorCode.extraSessionLocked);
      final rows = await app.tdb.pool.execute(
        'SELECT extra_muscles::text[] FROM days '
        "WHERE date = '2026-10-10'",
      );
      expect(rows.single[0], ['abs']);
    });
  });
}
