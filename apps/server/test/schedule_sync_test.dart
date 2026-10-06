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

  Future<List<PushResult>> push(List<SyncMutation> ms, {String? as}) async =>
      (await app.push(as ?? token, ms)).results;

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
        'password': 'matkhau123',
      });
      token = TokenPair.fromJson(res.json).accessToken;
    }

    Future<PushResult> markAt(DayMark mark, DateTime atUtc) async {
      await setNow(atUtc);
      return (await push([
        dayMutation(marked(mark, atUtc), op: SyncOp.upsert, at: atUtc),
      ])).single;
    }

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
  });
}
