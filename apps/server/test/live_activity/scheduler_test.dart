import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/src/alerts.dart';
import 'package:server/src/live_activity/scheduler.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// Cảnh báo ghi lại (Sentry giả).
final class _Alerts implements Alerts {
  final messages = <String>[];

  @override
  Future<void> warning(String message, Map<String, String> tags) async =>
      messages.add(message);
}

/// 06 Bản 3 VS40-T08 (server): TAC3-07 với APNs giả + đồng hồ giả + PostgreSQL;
/// TA3-01, F25-E6, timezone khác UTC, `no_update_token`.
/// Giờ Việt Nam (UTC+7): thứ 2 12/10 Ngực + Tay sau 18:00 = 11:00 UTC.
void main() {
  late TestApp app;
  late String token;
  late FakeApns apns;
  late _Alerts alerts;
  late LiveActivityScheduler scheduler;
  final t0 = DateTime.utc(2026, 10, 7, 5);
  final monday = LocalDate(2026, 10, 12);
  final startToken = randomApnsToken();
  final updateToken = randomApnsToken();

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

  Future<void> setNow(DateTime utc) async {
    app.clock.set(utc);
    token = TokenPair.fromJson(
      (await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': testPassword,
      })).json,
    ).accessToken;
  }

  SyncMutation dayMutation(PlanDay d, DateTime at, {bool? ended}) => mutation(
    'day',
    d.date.toKey(),
    SyncOp.upsert,
    at: at,
    data: {...const DayCodec().encode(d), 'liveActivityEnded': ?ended},
  );

  Future<void> push(List<SyncMutation> ms) async {
    final results = (await app.push(
      token,
      ms,
      appVersion: AppVersion.v3,
    )).results;
    expect([
      for (final r in results) r.status,
    ], everyElement(PushStatus.applied));
  }

  Future<void> setUpSchedule({String timezone = 'Asia/Ho_Chi_Minh'}) => push([
    mutation(
      'profile',
      'me',
      SyncOp.upsert,
      at: t0,
      data: const ProfileCodec().encode(
        Profile(
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
        ),
      ),
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
    for (final d in generated.days)
      mutation(
        'day',
        d.date.toKey(),
        SyncOp.ensure,
        at: t0,
        data: const DayCodec().encode(d),
      ),
  ]);

  Future<void> putToken({String? update, LocalDate? date}) async {
    final res = await app.send(
      'PUT',
      '/v1/me/live-activity-token',
      body: LiveActivityTokenRequest(
        pushToStartToken: startToken,
        activityPushToken: update,
        activityDate: date,
        environment: ApnsEnvironment.sandbox,
        appVersion: '3.0.0',
      ).toJson(),
      token: token,
    );
    expect(res.status, 204);
  }

  /// "Máy ép ngực" buổi trước 40 → 45 kg (07/10).
  Future<void> seedPrevious() => app.tdb.pool.execute(
    Sql.named('''
      INSERT INTO exercise_units (user_id, exercise_id, unit, changed_on,
                                  client_updated_at, server_version)
      SELECT id, 'chest-mid-machine-pec-deck', 'kg', '2026-10-05', now(),
             nextval('sync_version_seq') FROM users;
      '''),
  );

  Future<void> seedPreviousLog() => app.tdb.pool.execute(
    Sql.named('''
      INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10,
                             logged_at, server_version, client_updated_at)
      SELECT id, '2026-10-07', 'chest-mid-machine-pec-deck', 400, 450, now(),
             nextval('sync_version_seq'), now() FROM users'''),
  );

  Future<void> runAt(DateTime utc) async {
    app.clock.set(utc);
    await scheduler.run();
  }

  Future<List<List<Object?>>> sessions() async => [
    for (final r in await app.tdb.pool.execute(
      'SELECT to_char(date, \'YYYY-MM-DD\'), started_at IS NOT NULL, '
      'end_sent_at IS NOT NULL, last_error FROM live_activity_sessions',
    ))
      r.toList(),
  ];

  setUp(() async {
    app = await TestApp.create(now: t0);
    expect((await LibraryImporter(app.tdb.pool).run(library28())).ok, isTrue);
    token = (await app.register()).accessToken;
    apns = FakeApns();
    alerts = _Alerts();
    scheduler = LiveActivityScheduler(
      pool: app.tdb.pool,
      apns: apns,
      clock: app.clock,
      logger: app.log.logger,
      alerts: alerts,
    );
  });
  tearDown(() => app.dispose());

  test('TAC3-07, F25-AC1, F25-AC5: 17:59 không gửi; 18:00 gửi đúng một '
      'start (nhóm cơ, bài kế tiếp, buổi trước, stale-date 00:00); 18:01 không gửi lại; '
      '00:00 gửi end một lần tới token cập nhật', () async {
    await setUpSchedule();
    await seedPrevious();
    await seedPreviousLog();
    await putToken();

    await runAt(DateTime.utc(2026, 10, 12, 10, 59));
    expect(apns.sent, isEmpty);

    await runAt(DateTime.utc(2026, 10, 12, 11));
    final start = apns.sent.single;
    expect(start.token, startToken);
    expect(start.environment, ApnsEnvironment.sandbox);
    expect(start.payload, {
      'aps': {
        'timestamp':
            DateTime.utc(2026, 10, 12, 11).millisecondsSinceEpoch ~/ 1000,
        'event': 'start',
        'attributes-type': 'IronlySessionAttributes',
        'attributes': {'date': '2026-10-12', 'groups': 'Ngực + Tay sau'},
        'content-state': {
          'lastLogged': null,
          'next': {
            'name': 'Bài chest-mid-machine-pec-deck',
            'prev': '40 → 45 kg',
          },
          'allLogged': false,
          'absOnly': false,
        },
        'stale-date':
            DateTime.utc(2026, 10, 12, 17).millisecondsSinceEpoch ~/ 1000,
        'alert': {'title': 'Buổi tập hôm nay', 'body': 'Ngực + Tay sau'},
      },
    });
    expect(await sessions(), [
      ['2026-10-12', true, false, null],
    ]);

    await runAt(DateTime.utc(2026, 10, 12, 11, 1));
    expect(apns.sent, hasLength(1));

    // iOS khởi động app ở nền → app gửi token cập nhật (TA3-13).
    await setNow(DateTime.utc(2026, 10, 12, 11, 2));
    await putToken(update: updateToken, date: monday);
    await runAt(DateTime.utc(2026, 10, 12, 16, 59));
    expect(apns.events('end'), isEmpty);
    await runAt(DateTime.utc(2026, 10, 12, 17));
    final end = apns.events('end').single;
    expect(end.token, updateToken);
    expect((end.payload['aps']! as Map)['dismissal-date'], isA<int>());
    await runAt(DateTime.utc(2026, 10, 12, 17, 1));
    expect(apns.events('end'), hasLength(1));
    expect(await sessions(), [
      ['2026-10-12', true, true, null],
    ]);
    // Log không chứa nội dung push (TA3-06).
    expect(app.log.lines.join('\n'), isNot(contains('Ngực')));
  });

  test('TAC3-07: "Đã tập" kèm liveActivityEnded → không gửi end', () async {
    await setUpSchedule();
    await putToken();
    await runAt(DateTime.utc(2026, 10, 12, 11));
    await setNow(DateTime.utc(2026, 10, 12, 11, 30));
    await putToken(update: updateToken, date: monday);
    final day = generated.days.firstWhere((d) => d.date == monday);
    await push([
      dayMutation(
        day.withMark(
          DayMark.done,
          actual: day.muscles,
          markedAt: DateTime.utc(2026, 10, 12, 11, 30),
        ),
        DateTime.utc(2026, 10, 12, 11, 30),
        ended: true,
      ),
    ]);
    await runAt(DateTime.utc(2026, 10, 12, 17));
    expect(apns.events('end'), isEmpty);
    expect((await sessions()).single[2], isTrue);
  });

  test('TAC3-07, F25-AC4: ngày sửa riêng thành nghỉ, buổi tập thêm → không '
      'gửi', () async {
    await setUpSchedule();
    await putToken();
    await setNow(DateTime.utc(2026, 10, 12, 9));
    await push([
      dayMutation(
        PlanDay(date: monday, kind: DayKind.rest, source: DaySource.override),
        DateTime.utc(2026, 10, 12, 9),
      ),
    ]);
    await runAt(DateTime.utc(2026, 10, 12, 11));
    expect(apns.sent, isEmpty);
    // Thứ 3 13/10 nghỉ, có buổi tập thêm lúc 18:00.
    final tuesday = generated.days.firstWhere(
      (d) => d.date == LocalDate(2026, 10, 13),
    );
    await setNow(DateTime.utc(2026, 10, 13, 11));
    await push([
      dayMutation(
        tuesday.withExtra(const [
          MuscleGroup.abs,
        ], loggedAt: DateTime.utc(2026, 10, 13, 11)),
        DateTime.utc(2026, 10, 13, 11),
      ),
    ]);
    await runAt(DateTime.utc(2026, 10, 13, 11, 1));
    expect(apns.sent, isEmpty);
  });

  test('TA3-01: APNs lỗi → thử lại mỗi phút tới 18:10 rồi thôi, cảnh báo ở '
      'lần lỗi thứ 3; không ghi dòng', () async {
    await setUpSchedule();
    await putToken();
    apns.respond = (_) => const ApnsResult(ApnsOutcome.retry, status: 503);
    for (var m = 0; m <= 12; m++) {
      await runAt(DateTime.utc(2026, 10, 12, 11, m));
    }
    expect(apns.sent, hasLength(11));
    expect(alerts.messages, ['live_activity_start_failing']);
    expect(await sessions(), isEmpty);
  });

  test('TAC3-07: Apple trả 410 → token bị xóa, không gửi nữa', () async {
    await setUpSchedule();
    await putToken();
    apns.respond = (_) => const ApnsResult(
      ApnsOutcome.invalidToken,
      status: 410,
      reason: 'Unregistered',
    );
    await runAt(DateTime.utc(2026, 10, 12, 11));
    expect(
      await app.tdb.pool.execute('SELECT 1 FROM live_activity_tokens'),
      isEmpty,
    );
    await runAt(DateTime.utc(2026, 10, 12, 11, 1));
    expect(apns.sent, hasLength(1));
  });

  test('TA3-02: không có token cập nhật → không gửi end, ghi no_update_token '
      'một lần và cảnh báo', () async {
    await setUpSchedule();
    await putToken();
    await runAt(DateTime.utc(2026, 10, 12, 11));
    await runAt(DateTime.utc(2026, 10, 12, 17));
    await runAt(DateTime.utc(2026, 10, 12, 17, 1));
    expect(apns.events('end'), isEmpty);
    expect(await sessions(), [
      ['2026-10-12', true, true, 'no_update_token'],
    ]);
    expect(alerts.messages, ['live_activity_no_update_token']);
  });

  test('F25-E6: giờ tập 23:30 → bật 23:30, tắt 00:00', () async {
    await setUpSchedule();
    await putToken();
    await setNow(DateTime.utc(2026, 10, 12, 9));
    await push([
      dayMutation(
        PlanDay(
          date: monday,
          kind: DayKind.workout,
          time: LocalTime(23, 30),
          muscles: const [MuscleGroup.chest],
          source: DaySource.override,
        ),
        DateTime.utc(2026, 10, 12, 9),
      ),
    ]);
    await runAt(DateTime.utc(2026, 10, 12, 16, 29));
    expect(apns.sent, isEmpty);
    await runAt(DateTime.utc(2026, 10, 12, 16, 30));
    expect(apns.events('start'), hasLength(1));
    await setNow(DateTime.utc(2026, 10, 12, 16, 31));
    await putToken(update: updateToken, date: monday);
    await runAt(DateTime.utc(2026, 10, 12, 17));
    expect(apns.events('end'), hasLength(1));
  });

  test(
    'timezone khác UTC+7: Tokyo 18:00 = 09:00 UTC, stale-date 15:00 UTC',
    () async {
      await setUpSchedule(timezone: 'Asia/Tokyo');
      await putToken();
      await runAt(DateTime.utc(2026, 10, 12, 8, 59));
      expect(apns.sent, isEmpty);
      await runAt(DateTime.utc(2026, 10, 12, 9));
      final aps = apns.sent.single.payload['aps']! as Map;
      expect(
        aps['stale-date'],
        DateTime.utc(2026, 10, 12, 15).millisecondsSinceEpoch ~/ 1000,
      );
    },
  );

  test('IA3-09: job xử lý một tài khoản (đọc lịch, tính nội dung, gửi start, '
      'ghi phiên) dưới 50 ms', () async {
    await setUpSchedule();
    await seedPrevious();
    await seedPreviousLog();
    await putToken();
    await runAt(DateTime.utc(2026, 10, 12, 10, 59)); // làm nóng, chưa gửi
    final watch = Stopwatch()..start();
    await runAt(DateTime.utc(2026, 10, 12, 11));
    watch.stop();
    expect(apns.sent, hasLength(1));
    expect(watch.elapsedMilliseconds, lessThan(50));
  });

  test('Chưa có lịch tuần → không gửi', () async {
    await putToken();
    await runAt(DateTime.utc(2026, 10, 12, 11));
    expect(apns.sent, isEmpty);
  });
}
