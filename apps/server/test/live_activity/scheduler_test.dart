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
    // 05 Bản 5 §6.6.3: hook sau push như server thật (server_app.dart).
    app.deps.sync.onPushed = scheduler.afterPush;
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

  test(
    '06 Bản 5 VS54-T02, F25-AC65: bài 1 bỏ qua hôm nay → start gửi "Kế '
    'tiếp" là bài 2 (danh sách bài của buổi, không gửi bài bỏ qua)',
    () async {
      await setUpSchedule();
      await putToken();
      final ids = [
        for (final r in await app.tdb.pool.execute(
          "SELECT id FROM exercises WHERE muscle_group = 'chest' AND active "
          'ORDER BY sort_order LIMIT 2',
        ))
          r[0]! as String,
      ];
      await app.tdb.pool.execute(
        Sql.named('''
        INSERT INTO session_exercises (user_id, date, exercise_id, role,
                                       position, skipped, client_updated_at,
                                       server_version)
        SELECT id, '2026-10-12', @first, 'original', 0, true, now(),
               nextval('sync_version_seq') FROM users'''),
        parameters: {'first': ids.first},
      );
      await runAt(DateTime.utc(2026, 10, 12, 11));
      final state =
          (apns.sent.single.payload['aps']! as Map)['content-state']! as Map;
      expect((state['next']! as Map)['name'], 'Bài ${ids[1]}');
      expect(state['allLogged'], isFalse);
    },
  );

  group('Bản 5 — tạm dừng (F31-R4, F31-R7, F25-R64, TD5-13)', () {
    const pauseId = '6f1d2c3b-0000-4000-8000-0000000000b1';
    SyncMutation pauseMutation(LocalDate from, LocalDate to, DateTime at) =>
        mutation(
          'schedule_pause',
          pauseId,
          SyncOp.upsert,
          at: at,
          data: const SchedulePauseCodec().encode(
            SchedulePause(id: pauseId, startDate: from, endDate: to),
          ),
        );

    test('F31-AC1: tạm dừng thứ 2 → 18:00 không gửi start; tuần sau ngoài '
        'khoảng gửi như thường', () async {
      await setUpSchedule();
      await putToken();
      await setNow(DateTime.utc(2026, 10, 12, 2));
      await push([
        pauseMutation(
          monday,
          LocalDate(2026, 10, 18),
          DateTime.utc(2026, 10, 12, 2),
        ),
      ]);
      await runAt(DateTime.utc(2026, 10, 12, 11));
      await runAt(DateTime.utc(2026, 10, 12, 11, 5));
      expect(apns.sent, isEmpty);
      expect(await sessions(), isEmpty);
      await runAt(DateTime.utc(2026, 10, 19, 11));
      expect(apns.events('start'), hasLength(1));
    });

    test('F31-R7, F25-R64: đặt tạm dừng hôm nay khi thẻ đang hiện → gửi end '
        'một lần', () async {
      await setUpSchedule();
      await putToken();
      await runAt(DateTime.utc(2026, 10, 12, 11));
      expect(apns.events('start'), hasLength(1));
      await setNow(DateTime.utc(2026, 10, 12, 11, 30));
      await putToken(update: updateToken, date: monday);
      await push([
        pauseMutation(
          monday,
          LocalDate(2026, 10, 14),
          DateTime.utc(2026, 10, 12, 11, 30),
        ),
      ]);
      await runAt(DateTime.utc(2026, 10, 12, 11, 31));
      final end = apns.events('end').single;
      expect(end.token, updateToken);
      await runAt(DateTime.utc(2026, 10, 12, 11, 32));
      await runAt(DateTime.utc(2026, 10, 12, 17));
      expect(apns.events('end'), hasLength(1));
      expect((await sessions()).single[2], isTrue);
    });
  });

  group('Bản 5 — thẻ hiện lại, nguồn bật, tắt 00:00 (TD5-13, F25-R61)', () {
    const pauseId = '6f1d2c3b-0000-4000-8000-0000000000b2';
    final mondayDay = generated.days.firstWhere((d) => d.date == monday);

    Future<List<List<Object?>>> rows() async => [
      for (final r in await app.tdb.pool.execute(
        'SELECT to_char(date, \'YYYY-MM-DD\'), end_sent_at IS NOT NULL, '
        'restarts, trigger, kind FROM live_activity_sessions ORDER BY date',
      ))
        r.toList(),
    ];

    PlanDay done(DateTime at) => mondayDay.withMark(
      DayMark.done,
      actual: mondayDay.muscles,
      markedAt: at,
    );

    test('TAC5-07, F25-AC62: "Đã tập" 18:30 → thẻ tắt; bỏ đánh dấu 19:00 → '
        'start mới, restarts = 1; 00:00 tắt; bỏ đánh dấu lúc 00:30 → không '
        'gửi', () async {
      await setUpSchedule();
      await putToken();
      await runAt(DateTime.utc(2026, 10, 12, 11));
      expect(apns.events('start'), hasLength(1));
      await setNow(DateTime.utc(2026, 10, 12, 11, 30));
      await putToken(update: updateToken, date: monday);
      await push([
        dayMutation(
          done(DateTime.utc(2026, 10, 12, 11, 30)),
          DateTime.utc(2026, 10, 12, 11, 30),
          ended: true,
        ),
      ]);
      expect(apns.events('start'), hasLength(1), reason: 'Đã tập không bật');
      expect(await rows(), [
        ['2026-10-12', true, 0, 'time', 'session'],
      ]);

      await setNow(DateTime.utc(2026, 10, 12, 12));
      await push([
        dayMutation(mondayDay.withMark(null), DateTime.utc(2026, 10, 12, 12)),
      ]);
      final restart = apns.events('start');
      expect(restart, hasLength(2));
      expect(restart.last.token, startToken);
      expect(
        ((restart.last.payload['aps']! as Map)['attributes']! as Map)['date'],
        '2026-10-12',
      );
      expect(await rows(), [
        ['2026-10-12', false, 1, 'time', 'session'],
      ]);
      // Job mỗi phút không bật thêm; 00:00 gửi end như mọi thẻ.
      await runAt(DateTime.utc(2026, 10, 12, 12, 1));
      expect(apns.events('start'), hasLength(2));
      await runAt(DateTime.utc(2026, 10, 12, 17));
      expect(apns.events('end'), hasLength(1));

      // 00:30 hôm sau: bỏ đánh dấu ngày 12/10 → day_locked, không gửi.
      await setNow(DateTime.utc(2026, 10, 12, 17, 30));
      final late = (await app.push(token, [
        dayMutation(
          done(DateTime.utc(2026, 10, 12, 11, 30)),
          DateTime.utc(2026, 10, 12, 17, 30),
        ),
      ], appVersion: AppVersion.v3)).results.single;
      expect(late.status, PushStatus.rejected);
      expect(late.code, ErrorCode.dayLocked);
      expect(apns.events('start'), hasLength(2));
    });

    test('Bỏ đánh dấu khi thẻ đang hiện → không gửi start thứ hai', () async {
      await setUpSchedule();
      await putToken();
      await runAt(DateTime.utc(2026, 10, 12, 11));
      await setNow(DateTime.utc(2026, 10, 12, 11, 30));
      // "Đã tập" không kèm liveActivityEnded (app chưa kịp tắt): dòng còn mở.
      await push([
        dayMutation(
          done(DateTime.utc(2026, 10, 12, 11, 30)),
          DateTime.utc(2026, 10, 12, 11, 30),
        ),
        dayMutation(
          mondayDay.withMark(null),
          DateTime.utc(2026, 10, 12, 11, 31),
        ),
      ]);
      expect(apns.events('start'), hasLength(1));
      expect((await rows()).single[2], 0);
    });

    test('F25-E65: "Không tập" 10:00 → 18:00 không thẻ; bỏ đánh dấu 19:00 → '
        'thẻ hiện (chưa có dòng → tạo, restarts = 0)', () async {
      await setUpSchedule();
      await putToken();
      await setNow(DateTime.utc(2026, 10, 12, 3));
      await push([
        dayMutation(
          mondayDay.withMark(
            DayMark.skipped,
            markedAt: DateTime.utc(2026, 10, 12, 3),
          ),
          DateTime.utc(2026, 10, 12, 3),
        ),
      ]);
      await runAt(DateTime.utc(2026, 10, 12, 11));
      expect(apns.sent, isEmpty);
      await setNow(DateTime.utc(2026, 10, 12, 12));
      await push([
        dayMutation(mondayDay.withMark(null), DateTime.utc(2026, 10, 12, 12)),
      ]);
      expect(apns.events('start'), hasLength(1));
      expect(await rows(), [
        ['2026-10-12', false, 0, 'time', 'session'],
      ]);
    });

    test(
      'Bỏ đánh dấu trước giờ tập → không bật; 18:00 job bật như thường',
      () async {
        await setUpSchedule();
        await putToken();
        await setNow(DateTime.utc(2026, 10, 12, 3));
        await push([
          dayMutation(
            mondayDay.withMark(
              DayMark.skipped,
              markedAt: DateTime.utc(2026, 10, 12, 3),
            ),
            DateTime.utc(2026, 10, 12, 3),
          ),
        ]);
        await setNow(DateTime.utc(2026, 10, 12, 4));
        await push([
          dayMutation(mondayDay.withMark(null), DateTime.utc(2026, 10, 12, 4)),
        ]);
        expect(apns.sent, isEmpty);
        await runAt(DateTime.utc(2026, 10, 12, 11));
        expect(apns.events('start'), hasLength(1));
      },
    );

    test('F31-E5, F31-R8: tạm dừng từ hôm qua, kết thúc sớm 19:00 ngày có '
        'buổi 18:00 → thẻ hiện ngay', () async {
      await setUpSchedule();
      await putToken();
      final pause = SchedulePause(
        id: pauseId,
        startDate: LocalDate(2026, 10, 11),
        endDate: LocalDate(2026, 10, 14),
      );
      await setNow(DateTime.utc(2026, 10, 10, 13));
      await push([
        mutation(
          'schedule_pause',
          pauseId,
          SyncOp.upsert,
          at: DateTime.utc(2026, 10, 10, 13),
          data: const SchedulePauseCodec().encode(pause),
        ),
      ]);
      await runAt(DateTime.utc(2026, 10, 12, 11));
      expect(apns.sent, isEmpty);
      await setNow(DateTime.utc(2026, 10, 12, 12));
      await push([
        mutation(
          'schedule_pause',
          pauseId,
          SyncOp.upsert,
          at: DateTime.utc(2026, 10, 12, 12),
          data: const SchedulePauseCodec().encode(
            PauseRules.endEarly(pause, monday)!,
          ),
        ),
      ]);
      expect(apns.events('start'), hasLength(1));
      expect(await rows(), [
        ['2026-10-12', false, 0, 'time', 'session'],
      ]);
    });

    test('F31-R7 → R8: đặt tạm dừng hôm nay khi thẻ đang hiện (tắt), kết '
        'thúc vào ngày A (xóa khoảng) → thẻ hiện lại, restarts = 1', () async {
      await setUpSchedule();
      await putToken();
      await runAt(DateTime.utc(2026, 10, 12, 11));
      await setNow(DateTime.utc(2026, 10, 12, 11, 30));
      await putToken(update: updateToken, date: monday);
      await push([
        mutation(
          'schedule_pause',
          pauseId,
          SyncOp.upsert,
          at: DateTime.utc(2026, 10, 12, 11, 30),
          data: const SchedulePauseCodec().encode(
            SchedulePause(
              id: pauseId,
              startDate: monday,
              endDate: LocalDate(2026, 10, 14),
            ),
          ),
        ),
      ]);
      await runAt(DateTime.utc(2026, 10, 12, 11, 31));
      expect(apns.events('end'), hasLength(1));
      await setNow(DateTime.utc(2026, 10, 12, 12));
      await push([
        mutation(
          'schedule_pause',
          pauseId,
          SyncOp.delete,
          at: DateTime.utc(2026, 10, 12, 12),
        ),
      ]);
      expect(apns.events('start'), hasLength(2));
      expect(await rows(), [
        ['2026-10-12', false, 1, 'time', 'session'],
      ]);
    });

    test('F25-AC64: tạm dừng → 18:00 không thẻ; bỏ đánh dấu trong khoảng → '
        'không thẻ', () async {
      await setUpSchedule();
      await putToken();
      await setNow(DateTime.utc(2026, 10, 12, 2));
      await push([
        mutation(
          'schedule_pause',
          pauseId,
          SyncOp.upsert,
          at: DateTime.utc(2026, 10, 12, 2),
          data: const SchedulePauseCodec().encode(
            SchedulePause(
              id: pauseId,
              startDate: monday,
              endDate: LocalDate(2026, 10, 14),
            ),
          ),
        ),
      ]);
      await runAt(DateTime.utc(2026, 10, 12, 11));
      await setNow(DateTime.utc(2026, 10, 12, 11, 30));
      await push([
        dayMutation(
          done(DateTime.utc(2026, 10, 12, 11, 30)),
          DateTime.utc(2026, 10, 12, 11, 30),
        ),
      ]);
      await setNow(DateTime.utc(2026, 10, 12, 12));
      await push([
        dayMutation(mondayDay.withMark(null), DateTime.utc(2026, 10, 12, 12)),
      ]);
      expect(apns.sent, isEmpty);
    });

    test(
      'TD5-13.2: đã có dòng thẻ theo vị trí hôm nay → 18:00 job không bật '
      'theo giờ; TD5-13.4: dòng thẻ ngày nghỉ (kind extra) tắt lúc 00:00',
      () async {
        await setUpSchedule();
        await putToken();
        await app.tdb.pool.execute(
          Sql.named('''
          INSERT INTO live_activity_sessions (user_id, date, started_at, trigger, kind)
          SELECT id, '2026-10-12', @at, 'location', 'session' FROM users;
          '''),
          parameters: {'at': DateTime.utc(2026, 10, 12, 10, 20)},
        );
        await runAt(DateTime.utc(2026, 10, 12, 11));
        expect(apns.events('start'), isEmpty);
        await app.tdb.pool.execute(
          Sql.named('''
          INSERT INTO live_activity_sessions (user_id, date, started_at, trigger, kind)
          SELECT id, '2026-10-13', @at, 'location', 'extra' FROM users;
          '''),
          parameters: {'at': DateTime.utc(2026, 10, 13, 9)},
        );
        await runAt(DateTime.utc(2026, 10, 13, 16, 59));
        // Thẻ 12/10 tắt lúc 00:00 (không có token cập nhật → no_update_token).
        expect((await rows()).first[1], isTrue);
        expect((await rows()).last[1], isFalse);
        await setNow(DateTime.utc(2026, 10, 13, 16, 59));
        await putToken(update: updateToken, date: LocalDate(2026, 10, 13));
        await runAt(DateTime.utc(2026, 10, 13, 17));
        expect(
          apns.events('end').single.token,
          updateToken,
          reason: 'thẻ extra 13/10 tắt 00:00',
        );
        expect(await rows(), [
          ['2026-10-12', true, 0, 'location', 'session'],
          ['2026-10-13', true, 0, 'location', 'extra'],
        ]);
      },
    );

    test('LiveActivityPlan.restart: ngoài cửa sổ, đã đánh dấu, thẻ đang mở, '
        'tạm dừng → null', () {
      final at = DateTime(2026, 10, 12, 19);
      LiveActivityAccount account({
        PlanDay? day,
        DateTime? now,
        List<OpenLiveActivity> open = const [],
        List<SchedulePause> pauses = const [],
      }) => LiveActivityAccount(
        userId: 'u',
        environment: ApnsEnvironment.sandbox,
        pushToStartToken: startToken,
        localNow: now ?? at,
        tomorrowStart: DateTime.utc(2026, 10, 12, 17),
        hasSchedule: true,
        today: day ?? mondayDay,
        open: open,
        pauses: pauses,
      );
      expect(LiveActivityPlan.restart(account()), mondayDay);
      expect(
        LiveActivityPlan.restart(account(now: DateTime(2026, 10, 12, 17, 59))),
        isNull,
      );
      expect(
        LiveActivityPlan.restart(
          account(
            day: mondayDay.withOpenedAt(DateTime(2026, 10, 12, 17, 20)),
            now: DateTime(2026, 10, 12, 17, 30),
          ),
        ),
        isNotNull,
        reason: 'FD5-01: cửa sổ mở từ lúc tới gym',
      );
      expect(
        LiveActivityPlan.restart(
          account(day: done(DateTime.utc(2026, 10, 12, 11))),
        ),
        isNull,
      );
      expect(
        LiveActivityPlan.restart(
          account(
            open: [(date: monday, endsAt: DateTime.utc(2026, 10, 12, 17))],
          ),
        ),
        isNull,
      );
      expect(
        LiveActivityPlan.restart(
          account(
            pauses: [
              SchedulePause(id: pauseId, startDate: monday, endDate: monday),
            ],
          ),
        ),
        isNull,
      );
    });
  });
}
