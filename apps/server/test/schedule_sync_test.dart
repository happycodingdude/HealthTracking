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
}
