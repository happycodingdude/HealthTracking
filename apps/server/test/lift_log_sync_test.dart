import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// 06 Bản 2 VS26-T08 (server): TAC2-05, F21-E7, truy cập chéo, xung đột.
/// Giờ Việt Nam = UTC+7. Thứ 2 12/10 Ngực + Tay sau 18:00 = 11:00 UTC.
void main() {
  late TestApp app;
  late String token;
  final t0 = DateTime.utc(2026, 10, 7, 5);

  setUp(() async {
    app = await TestApp.create();
    app.clock.set(t0);
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
  final monday = LocalDate(2026, 10, 12);

  Future<String> login(String phone) async {
    final res = await app.post('/v1/auth/login', {
      'phone': phone,
      'password': 'matkhau123',
    });
    return TokenPair.fromJson(res.json).accessToken;
  }

  /// Đặt giờ server và đăng nhập lại (access token sống 15 phút).
  Future<void> setNow(DateTime atUtc) async {
    app.clock.set(atUtc);
    token = await login('0912345678');
  }

  Future<List<PushResult>> push(List<SyncMutation> ms, {String? as}) async =>
      (await app.push(as ?? token, ms, appVersion: AppVersion.v2)).results;

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

  Future<void> setUpSchedule({String? as}) async {
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
      timezone: 'Asia/Ho_Chi_Minh',
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
  }

  Future<void> insertExercise(
    String id,
    String region, {
    bool active = true,
  }) async {
    final r = MuscleRegion.tryParse(region)!;
    await app.tdb.pool.execute(
      Sql.named('''
        INSERT INTO exercises (id, muscle_group, muscle_region, equipment, logs_weight, name_vi,
                               youtube_video_id, video_channel, video_duration_s, guide_steps,
                               guide_safety, approved_at, sort_order, active, library_version,
                               server_version)
        VALUES (@id, @group::muscle_group, @region, 'machine', @logs, @id, 'TrTSvn5-MTk',
                'Renaissance Periodization', 48, ARRAY['a','b','c'], ARRAY['x','y'],
                '2026-10-11', 1, @active, 1, nextval('sync_version_seq'))'''),
      parameters: {
        'id': id,
        'group': r.group.name,
        'region': region,
        'logs': r.group != MuscleGroup.abs,
        'active': active,
      },
    );
  }

  SyncMutation lift(
    LocalDate date,
    String exerciseId,
    DateTime atUtc, {
    int start = 120,
    int end = 140,
    SyncOp op = SyncOp.upsert,
  }) {
    final log = LiftLog(
      date: date,
      exerciseId: exerciseId,
      startKgX10: start,
      endKgX10: end,
    );
    return mutation(
      'lift_log',
      log.key,
      op,
      at: atUtc,
      data: op == SyncOp.delete ? null : const LiftLogCodec().encode(log),
    );
  }

  Future<PushResult> liftAt(
    LocalDate date,
    String exerciseId,
    DateTime atUtc, {
    int start = 120,
    int end = 140,
    SyncOp op = SyncOp.upsert,
  }) async {
    await setNow(atUtc);
    return (await push([
      lift(date, exerciseId, atUtc, start: start, end: end, op: op),
    ])).single;
  }

  Future<List<SyncChange>> serverLogs({String? as}) async => [
    for (final c in (await app.pull(as ?? token)).changes)
      if (c.entity == 'lift_log') c,
  ];

  group('TAC2-05: kiểm tra 6 bước (05 Bản 2 §6.6.2)', () {
    setUp(() async {
      await setUpSchedule();
      await insertExercise('chest-upper-machine', 'chest_upper');
      await insertExercise('delt-side-machine', 'delt_side');
      await insertExercise('abs-lower-crunch', 'abs_lower');
    });

    test('trong cửa sổ, đúng bài → applied, pull trả bản ghi', () async {
      // 19:00 12/10 giờ Việt Nam.
      final r = await liftAt(
        monday,
        'chest-upper-machine',
        DateTime.utc(2026, 10, 12, 12),
      );
      expect(r.status, PushStatus.applied);
      final logs = await serverLogs();
      expect(logs.single.key, '2026-10-12:chest-upper-machine');
      expect(
        const LiftLogCodec().decode(logs.single.key, logs.single.data!),
        LiftLog(
          date: monday,
          exerciseId: 'chest-upper-machine',
          startKgX10: 120,
          endKgX10: 140,
        ),
      );
      final row = await app.tdb.pool.execute(
        "SELECT logged_at FROM lift_logs WHERE date = '2026-10-12'",
      );
      expect(row.single[0], DateTime.utc(2026, 10, 12, 12));
    });

    test('F21-AC1: 17:59 → lift_window_closed; 18:00 → applied', () async {
      final early = await liftAt(
        monday,
        'chest-upper-machine',
        DateTime.utc(2026, 10, 12, 10, 59),
      );
      expect(
        (early.status, early.code),
        (PushStatus.rejected, ErrorCode.liftWindowClosed),
      );
      final onTime = await liftAt(
        monday,
        'chest-upper-machine',
        DateTime.utc(2026, 10, 12, 11),
      );
      expect(onTime.status, PushStatus.applied);
    });

    test('F21-AC9: 23:59 → applied; 00:01 ngày sau → lift_window_closed, '
        'server giữ nguyên bản cũ', () async {
      expect(
        (await liftAt(
          monday,
          'chest-upper-machine',
          DateTime.utc(2026, 10, 12, 16, 59),
        )).status,
        PushStatus.applied,
      );
      final late = await liftAt(
        monday,
        'chest-upper-machine',
        DateTime.utc(2026, 10, 12, 17, 1),
        end: 150,
      );
      expect(
        (late.status, late.code),
        (PushStatus.rejected, ErrorCode.liftWindowClosed),
      );
      expect(late.current?.data?['endKgX10'], 140);
    });

    test(
      'F21-AC13: bài vai trong buổi ngực → lift_exercise_not_in_session',
      () async {
        final r = await liftAt(
          monday,
          'delt-side-machine',
          DateTime.utc(2026, 10, 12, 12),
        );
        expect(
          (r.status, r.code),
          (PushStatus.rejected, ErrorCode.liftExerciseNotInSession),
        );
      },
    );

    test('F21-AC14: bài bụng, bài không có trong thư viện → '
        'lift_not_allowed_for_exercise', () async {
      for (final id in ['abs-lower-crunch', 'missing-exercise']) {
        final r = await liftAt(monday, id, DateTime.utc(2026, 10, 12, 12));
        expect(
          (r.status, r.code),
          (PushStatus.rejected, ErrorCode.liftNotAllowedForExercise),
          reason: id,
        );
      }
    });

    test('ngày nghỉ, ngày không có trong lịch → lift_no_session', () async {
      // Thứ 3 13/10 nghỉ; 30/09 chưa có dòng ngày.
      for (final (date, at) in [
        (LocalDate(2026, 10, 13), DateTime.utc(2026, 10, 13, 12)),
        (LocalDate(2026, 9, 30), DateTime.utc(2026, 10, 7, 6)),
      ]) {
        final r = await liftAt(date, 'chest-upper-machine', at);
        expect(
          (r.status, r.code),
          (PushStatus.rejected, ErrorCode.liftNoSession),
          reason: '$date',
        );
      }
    });

    test(
      'F21-AC7: 0; 300,5; 72,3 → validation_failed; 0,5 và 300 → applied',
      () async {
        final at = DateTime.utc(2026, 10, 12, 12);
        for (final (start, end, field) in [
          (0, 140, 'startKgX10'),
          (120, 3005, 'endKgX10'),
          (723, 140, 'startKgX10'),
        ]) {
          final r = await liftAt(
            monday,
            'chest-upper-machine',
            at,
            start: start,
            end: end,
          );
          expect(
            (r.status, r.code, r.field),
            (PushStatus.rejected, ErrorCode.validationFailed, field),
          );
        }
        expect(
          (await liftAt(
            monday,
            'chest-upper-machine',
            at,
            start: 5,
            end: 3000,
          )).status,
          PushStatus.applied,
        );
      },
    );

    test('mức tạ độc lập với trạng thái buổi (AP-9): buổi "Không tập" vẫn '
        'ghi được trong cửa sổ', () async {
      final day = generated.days.firstWhere((d) => d.date == monday);
      final at = DateTime.utc(2026, 10, 12, 12);
      await setNow(at);
      expect(
        (await push([
          dayMutation(
            day.withMark(DayMark.skipped, markedAt: at),
            op: SyncOp.upsert,
            at: at,
          ),
        ])).single.status,
        PushStatus.applied,
      );
      expect(
        (await liftAt(
          monday,
          'chest-upper-machine',
          at.add(const Duration(minutes: 1)),
        )).status,
        PushStatus.applied,
      );
    });
  });

  group('buổi tập thêm (05 Bản 2 §6.4.3)', () {
    setUp(() async {
      await setUpSchedule();
      await insertExercise('delt-side-machine', 'delt_side');
    });

    Future<void> extra(LocalDate date, DateTime atUtc) async {
      final day = generated.days.firstWhere((d) => d.date == date);
      await setNow(atUtc);
      expect(
        (await push([
          dayMutation(
            day.withExtra(const [MuscleGroup.shoulders], loggedAt: atUtc),
            op: SyncOp.upsert,
            at: atUtc,
          ),
        ])).single.status,
        PushStatus.applied,
      );
    }

    test('lưu hôm nay → mở từ lúc lưu đến 00:00', () async {
      final sat = LocalDate(2026, 10, 10);
      // Lưu 20:00 10/10 giờ Việt Nam.
      await extra(sat, DateTime.utc(2026, 10, 10, 13));
      expect(
        (await liftAt(
          sat,
          'delt-side-machine',
          DateTime.utc(2026, 10, 10, 13, 30),
        )).status,
        PushStatus.applied,
      );
      expect(
        (await liftAt(
          sat,
          'delt-side-machine',
          DateTime.utc(2026, 10, 10, 17, 1),
        )).code,
        ErrorCode.liftWindowClosed,
      );
    });

    test('F21-AC10: buổi tập thêm cho hôm qua → lift_window_closed', () async {
      // Lưu 09:00 10/10 giờ Việt Nam cho thứ 6 09/10.
      final fri = LocalDate(2026, 10, 9);
      await extra(fri, DateTime.utc(2026, 10, 10, 2));
      final r = await liftAt(
        fri,
        'delt-side-machine',
        DateTime.utc(2026, 10, 10, 2, 30),
      );
      expect(
        (r.status, r.code),
        (PushStatus.rejected, ErrorCode.liftWindowClosed),
      );
    });
  });

  group('F21-E7: bài đã rời thư viện', () {
    setUp(() async {
      await setUpSchedule();
      await insertExercise('chest-upper-machine', 'chest_upper');
      await insertExercise('chest-mid-machine', 'chest_mid', active: false);
    });

    test('tạo mới → lift_not_allowed_for_exercise; bản ghi đã có vẫn sửa, '
        'xóa được', () async {
      final at = DateTime.utc(2026, 10, 12, 12);
      expect(
        (await liftAt(monday, 'chest-mid-machine', at)).code,
        ErrorCode.liftNotAllowedForExercise,
      );
      expect(
        (await liftAt(monday, 'chest-upper-machine', at)).status,
        PushStatus.applied,
      );
      await app.tdb.pool.execute(
        "UPDATE exercises SET active = false WHERE id = 'chest-upper-machine'",
      );
      expect(
        (await liftAt(
          monday,
          'chest-upper-machine',
          at.add(const Duration(minutes: 5)),
          end: 150,
        )).status,
        PushStatus.applied,
      );
      expect(
        (await liftAt(
          monday,
          'chest-upper-machine',
          at.add(const Duration(minutes: 10)),
          op: SyncOp.delete,
        )).status,
        PushStatus.applied,
      );
      final logs = await serverLogs();
      expect(logs.single.deleted, isTrue);
      expect(logs.single.data, isNull);
    });
  });

  group('xóa, xung đột, truy cập chéo', () {
    setUp(() async {
      await setUpSchedule();
      await insertExercise('chest-upper-machine', 'chest_upper');
    });

    test('delete → tombstone; ghi lại sau khi xóa → có lại', () async {
      final at = DateTime.utc(2026, 10, 12, 12);
      await liftAt(monday, 'chest-upper-machine', at);
      expect(
        (await liftAt(
          monday,
          'chest-upper-machine',
          at.add(const Duration(minutes: 1)),
          op: SyncOp.delete,
        )).status,
        PushStatus.applied,
      );
      expect((await serverLogs()).single.deleted, isTrue);
      expect(
        (await liftAt(
          monday,
          'chest-upper-machine',
          at.add(const Duration(minutes: 2)),
          end: 160,
        )).status,
        PushStatus.applied,
      );
      final log = (await serverLogs()).single;
      expect((log.deleted, log.data?['endKgX10']), (false, 160));
    });

    test('hai máy cùng (date, exerciseId): bản có clientUpdatedAt mới hơn '
        'thắng, bản cũ đến sau → ignored_stale', () async {
      final at = DateTime.utc(2026, 10, 12, 12);
      await setNow(at.add(const Duration(minutes: 5)));
      final results = await push([
        lift(
          monday,
          'chest-upper-machine',
          at.add(const Duration(minutes: 3)),
          end: 160,
        ),
        lift(monday, 'chest-upper-machine', at, end: 150),
      ]);
      expect(
        [for (final r in results) r.status],
        [PushStatus.applied, PushStatus.ignoredStale],
      );
      expect((await serverLogs()).single.data?['endKgX10'], 160);
    });

    test(
      'TAC-07: B không đọc, không ghi, không xóa được mức tạ của A',
      () async {
        final at = DateTime.utc(2026, 10, 12, 12);
        await liftAt(monday, 'chest-upper-machine', at);
        await app.register(phone: '0922222222', name: 'Bình');
        final b = await login('0922222222');
        expect(await serverLogs(as: b), isEmpty);
        // B chưa có buổi ngày đó.
        expect(
          (await push([
            lift(monday, 'chest-upper-machine', at, end: 200),
          ], as: b)).single.code,
          ErrorCode.liftNoSession,
        );
        await push([
          lift(monday, 'chest-upper-machine', at, op: SyncOp.delete),
        ], as: b);
        final a = await serverLogs();
        expect((a.single.deleted, a.single.data?['endKgX10']), (false, 140));
        final rows = await app.tdb.pool.execute(
          'SELECT count(DISTINCT user_id) FROM lift_logs',
        );
        expect(rows.single[0], 1);
      },
    );
  });
}
