import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/src/alerts.dart';
import 'package:server/src/live_activity/scheduler.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

final class _Alerts implements Alerts {
  @override
  Future<void> warning(String message, Map<String, String> tags) async {}
}

/// 06 Bản 5 VS59-T05 (server): `POST /v1/me/gym-arrival` (TD5-14, §6.9.4)
/// với APNs giả + đồng hồ giả + PostgreSQL — TAC5-06 đủ nhánh, rate limit,
/// ngày lệch, mở buổi sớm (TAC5-04), thẻ ngày nghỉ tắt khi lưu Buổi tập thêm
/// (TD5-13.5), log không tọa độ (TAC5-10), cross-account.
/// Giờ Việt Nam (UTC+7): thứ 4 14/10 Lưng 18:00 = 11:00 UTC; tới gym 17:20 =
/// 10:20 UTC.
void main() {
  late TestApp app;
  late String token;
  late FakeApns apns;
  late LiveActivityScheduler scheduler;
  final t0 = DateTime.utc(2026, 10, 7, 5);
  final wednesday = LocalDate(2026, 10, 14);
  final saturday = LocalDate(2026, 10, 17);
  final startToken = randomApnsToken();

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
  final wedDay = generated.days.firstWhere((d) => d.date == wednesday);
  final satDay = generated.days.firstWhere((d) => d.date == saturday);

  Future<String> login(DateTime utc, {String phone = '0912345678'}) async {
    app.clock.set(utc);
    return TokenPair.fromJson(
      (await app.post('/v1/auth/login', {
        'phone': phone,
        'password': testPassword,
      })).json,
    ).accessToken;
  }

  Future<void> setNow(DateTime utc) async => token = await login(utc);

  Future<void> push(List<SyncMutation> ms, {String? as}) async {
    final results = (await app.push(
      as ?? token,
      ms,
      appVersion: AppVersion.v5,
    )).results;
    expect([
      for (final r in results) r.status,
    ], everyElement(PushStatus.applied));
  }

  Future<void> setUpSchedule() => push([
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
          timezone: 'Asia/Ho_Chi_Minh',
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

  Future<void> putToken() async {
    final res = await app.send(
      'PUT',
      '/v1/me/live-activity-token',
      body: LiveActivityTokenRequest(
        pushToStartToken: startToken,
        environment: ApnsEnvironment.sandbox,
        appVersion: '5.0.0',
      ).toJson(),
      token: token,
    );
    expect(res.status, 204);
  }

  Future<int> arrive(LocalDate date, String time, {String? as}) async =>
      (await app.post('/v1/me/gym-arrival', {
        'date': date.toKey(),
        'localTime': time,
        'appVersion': '5.0.0',
      }, token: as ?? token)).status;

  Future<List<List<Object?>>> rows() async => [
    for (final r in await app.tdb.pool.execute(
      'SELECT to_char(date, \'YYYY-MM-DD\'), end_sent_at IS NOT NULL, '
      'trigger, kind FROM live_activity_sessions ORDER BY date',
    ))
      r.toList(),
  ];

  Future<DateTime?> openedAt(LocalDate date) async {
    final r = await app.tdb.pool.execute(
      'SELECT opened_at FROM days WHERE date = \'${date.toKey()}\'',
    );
    return r.single[0] as DateTime?;
  }

  Future<void> runAt(DateTime utc) async {
    app.clock.set(utc);
    await scheduler.run();
  }

  setUp(() async {
    app = await TestApp.create(now: t0);
    expect((await LibraryImporter(app.tdb.pool).run(library28())).ok, isTrue);
    token = (await app.register()).accessToken;
    apns = FakeApns();
    scheduler = LiveActivityScheduler(
      pool: app.tdb.pool,
      apns: apns,
      clock: app.clock,
      logger: app.log.logger,
      alerts: _Alerts(),
    );
    // Như server thật (server_app.dart).
    app.deps.sync.onPushed = scheduler.afterPush;
    app.deps.gymArrival.starter = scheduler.startOnArrival;
    await setUpSchedule();
  });
  tearDown(() => app.dispose());

  test('TAC5-06, F25-AC61: ngày Lưng 18:00, tới gym 17:20 → start buổi tập, '
      'opened_at = 17:20, trigger = location; 18:00 scheduler không gửi lại; '
      'lần hai 17:30 → 204 không gửi', () async {
    await putToken();
    await setNow(DateTime.utc(2026, 10, 14, 10, 20));
    expect(await arrive(wednesday, '17:20'), 204);
    final start = apns.events('start').single;
    final aps = start.payload['aps']! as Map;
    expect(aps['attributes'], {'date': '2026-10-14', 'groups': 'Lưng'});
    expect((aps['content-state']! as Map)['inviteExtra'], isNull);
    expect(await openedAt(wednesday), DateTime.utc(2026, 10, 14, 10, 20));
    expect(await rows(), [
      ['2026-10-14', false, 'location', 'session'],
    ]);

    await runAt(DateTime.utc(2026, 10, 14, 11));
    expect(apns.events('start'), hasLength(1));

    await setNow(DateTime.utc(2026, 10, 14, 10, 30));
    expect(await arrive(wednesday, '17:30'), 204);
    expect(apns.events('start'), hasLength(1));
    // Mốc sớm hơn giữ nguyên (TA5-02).
    expect(await openedAt(wednesday), DateTime.utc(2026, 10, 14, 10, 20));

    // App pull về `openedAt` (đổi server_version).
    final pulled = (await app.pull(
      token,
      appVersion: AppVersion.v5,
    )).changes.where((c) => c.entity == 'day' && c.key == '2026-10-14');
    expect(pulled.single.data!['openedAt'], '2026-10-14T10:20:00.000Z');
    // Log: không giờ chính xác, không tọa độ (TAC5-10, §6.14).
    final log = app.log.lines.where((l) => l.contains('gym_arrival')).join();
    expect(log, contains('"result":"session"'));
    expect(log, isNot(contains('17:20')));
    expect(log, isNot(contains('lat')));
  });

  test('TAC5-04 (opened_at): "Đã tập" lúc 17:20 với opened_at = 17:20 → '
      'applied; ngày khác không có opened_at → lift_window_closed', () async {
    await setNow(DateTime.utc(2026, 10, 14, 10, 20));
    expect(await arrive(wednesday, '17:20'), 204);
    // Không token thẻ: vẫn mở buổi sớm, không bật thẻ.
    expect(apns.sent, isEmpty);
    final at = DateTime.utc(2026, 10, 14, 10, 25);
    await setNow(at);
    final done = wedDay.withMark(
      DayMark.done,
      actual: wedDay.muscles,
      markedAt: at,
    );
    await push([
      mutation(
        'day',
        '2026-10-14',
        SyncOp.upsert,
        at: at,
        data: const DayCodec().encode(done),
      ),
    ]);

    final monday = generated.days.firstWhere(
      (d) => d.date == LocalDate(2026, 10, 19),
    );
    final early = DateTime.utc(2026, 10, 19, 10, 25);
    await setNow(early);
    final r = (await app.push(token, [
      mutation(
        'day',
        '2026-10-19',
        SyncOp.upsert,
        at: early,
        data: const DayCodec().encode(
          monday.withMark(
            DayMark.done,
            actual: monday.muscles,
            markedAt: early,
          ),
        ),
      ),
    ], appVersion: AppVersion.v5)).results.single;
    expect(r.code, ErrorCode.liftWindowClosed);
  });

  test(
    'TAC5-06, F25-AC63: thứ 7 nghỉ → start thẻ ngày nghỉ (kind extra); '
    'lưu Buổi tập thêm → dòng extra end_sent_at, 00:00 không gửi end',
    () async {
      await putToken();
      await setNow(DateTime.utc(2026, 10, 17, 10));
      expect(await arrive(saturday, '17:00'), 204);
      final aps = apns.events('start').single.payload['aps']! as Map;
      expect(aps['attributes'], {
        'date': '2026-10-17',
        'groups': 'Nghỉ',
        'kind': 'extra',
      });
      expect(aps['content-state'], {
        'lastLogged': null,
        'next': null,
        'allLogged': false,
        'absOnly': false,
        'inviteExtra': true,
      });
      expect((aps['alert']! as Map)['body'], 'Nghỉ');
      expect(await openedAt(saturday), isNull);
      expect(await rows(), [
        ['2026-10-17', false, 'location', 'extra'],
      ]);

      final at = DateTime.utc(2026, 10, 17, 10, 5);
      await setNow(at);
      await push([
        mutation(
          'day',
          '2026-10-17',
          SyncOp.upsert,
          at: at,
          data: {
            ...const DayCodec().encode(
              satDay.withExtra(const [MuscleGroup.shoulders], loggedAt: at),
            ),
            'liveActivityEnded': true,
          },
        ),
      ]);
      expect(await rows(), [
        ['2026-10-17', true, 'location', 'extra'],
      ]);
      await runAt(DateTime.utc(2026, 10, 17, 17));
      expect(apns.events('end'), isEmpty);

      // Đã có Buổi tập thêm: tới gym lần nữa (ngày khác dòng) không bật.
      await setNow(DateTime.utc(2026, 10, 17, 11));
      expect(await arrive(saturday, '18:00'), 204);
      expect(apns.events('start'), hasLength(1));
    },
  );

  test(
    'Thẻ ngày nghỉ không lưu Buổi tập thêm → 00:00 gửi end (F25-E64)',
    () async {
      await putToken();
      await setNow(DateTime.utc(2026, 10, 17, 10));
      await arrive(saturday, '17:00');
      await runAt(DateTime.utc(2026, 10, 17, 17));
      expect(await rows(), [
        ['2026-10-17', true, 'location', 'extra'],
      ]);
    },
  );

  test('TAC5-06: Chủ nhật, tạm dừng, đã "Đã tập", ngày lệch → không gửi; tạm '
      'dừng vẫn mở buổi sớm', () async {
    await putToken();
    // Chủ nhật 18/10.
    await setNow(DateTime.utc(2026, 10, 18, 10));
    expect(await arrive(LocalDate(2026, 10, 18), '17:00'), 204);
    // Ngày lệch (app gửi hôm qua).
    await setNow(DateTime.utc(2026, 10, 14, 10, 20));
    expect(await arrive(LocalDate(2026, 10, 13), '17:20'), 204);
    expect(apns.sent, isEmpty);
    expect(await openedAt(wednesday), isNull);

    // Tạm dừng 14/10 → 16/10.
    await push([
      mutation(
        'schedule_pause',
        '6f1d2c3b-0000-4000-8000-0000000000c1',
        SyncOp.upsert,
        at: DateTime.utc(2026, 10, 14, 10, 20),
        data: const SchedulePauseCodec().encode(
          SchedulePause(
            id: '6f1d2c3b-0000-4000-8000-0000000000c1',
            startDate: wednesday,
            endDate: LocalDate(2026, 10, 16),
          ),
        ),
      ),
    ]);
    expect(await arrive(wednesday, '17:20'), 204);
    expect(apns.sent, isEmpty);
    expect(await openedAt(wednesday), DateTime.utc(2026, 10, 14, 10, 20));
    expect(await rows(), isEmpty);
  });

  test('TAC5-06: đã "Đã tập" → không gửi; không đăng nhập → 401', () async {
    await putToken();
    final at = DateTime.utc(2026, 10, 14, 11, 30);
    await setNow(at);
    await push([
      mutation(
        'day',
        '2026-10-14',
        SyncOp.upsert,
        at: at,
        data: const DayCodec().encode(
          wedDay.withMark(DayMark.done, actual: wedDay.muscles, markedAt: at),
        ),
      ),
    ]);
    expect(await arrive(wednesday, '18:30'), 204);
    expect(apns.sent, isEmpty);
    final res = await app.post('/v1/me/gym-arrival', {
      'date': '2026-10-14',
      'localTime': '18:30',
    });
    expect(res.status, 401);
  });

  test('APNs lỗi → xóa dòng location, 18:00 thẻ theo giờ vẫn bật', () async {
    await putToken();
    apns.respond = (_) => const ApnsResult(ApnsOutcome.retry, status: 503);
    await setNow(DateTime.utc(2026, 10, 14, 10, 20));
    await arrive(wednesday, '17:20');
    expect(await rows(), isEmpty);
    apns.respond = (_) => ApnsResult.ok;
    await runAt(DateTime.utc(2026, 10, 14, 11));
    expect(await rows(), [
      ['2026-10-14', false, 'time', 'session'],
    ]);
  });

  test('Rate limit 10 / ngày / tài khoản: lần 11 không xử lý', () async {
    await setNow(DateTime.utc(2026, 10, 17, 10));
    for (var i = 0; i < 10; i++) {
      expect(await arrive(saturday, '17:00'), 204);
    }
    await putToken();
    expect(await arrive(saturday, '17:00'), 204);
    expect(apns.sent, isEmpty);
    expect(
      app.log.lines.where((l) => l.contains('"rate_limited"')),
      hasLength(1),
    );
  });

  test('Cross-account: gym-arrival của tài khoản khác không đụng ngày, thẻ '
      'của tài khoản này', () async {
    await putToken();
    await app.register(phone: '0987654321', name: 'Lan');
    final other = await login(
      DateTime.utc(2026, 10, 14, 10, 20),
      phone: '0987654321',
    );
    expect(await arrive(wednesday, '17:20', as: other), 204);
    expect(apns.sent, isEmpty);
    expect(await openedAt(wednesday), isNull);
    expect(await rows(), isEmpty);
  });
}
