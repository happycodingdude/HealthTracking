import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;
  late String token;
  // 03:00 UTC thứ 4 07/10/2026 = 10:00 giờ Việt Nam.
  final t0 = DateTime.utc(2026, 10, 7, 3);
  final today = LocalDate(2026, 10, 7);
  const uuid = Uuid();

  /// Hồ sơ đã thiết lập xong: nam 1996 (30 tuổi), Tự động 2.210 kcal.
  Profile completed({int kcal = 2210, CalorieMode mode = CalorieMode.auto}) =>
      Profile(
        onboardingStep: 5,
        disclaimerAcceptedAt: t0.subtract(const Duration(hours: 1)),
        heightCm: 175,
        birthYear: 1996,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        calorieMode: mode,
        calorieKcal: kcal,
        setupDate: today,
        onboardingCompletedAt: t0.subtract(const Duration(minutes: 30)),
        timezone: 'Asia/Ho_Chi_Minh',
      );

  Future<String> user(String phone) async {
    final t = (await app.register(phone: phone)).accessToken;
    final r = (await app.push(t, [
      mutation(
        'profile',
        'me',
        SyncOp.upsert,
        at: t0.subtract(const Duration(minutes: 1)),
        data: const ProfileCodec().encode(completed()),
      ),
    ])).results.single;
    expect(r.status, PushStatus.applied);
    return t;
  }

  setUp(() async {
    app = await TestApp.create(now: t0);
    token = await user('0912345678');
  });

  /// Đặt giờ server; đăng nhập lại vì access token chỉ sống 15 phút.
  Future<void> at(DateTime t) async {
    app.clock.set(t);
    final res = await app.post('/v1/auth/login', {
      'phone': '0912345678',
      'password': '***REMOVED***',
    });
    token = TokenPair.fromJson(res.json).accessToken;
  }

  tearDown(() => app.dispose());

  Future<TestResponse> generate({
    String? as,
    LocalDate? date,
    int targetKcal = 2210,
    String? requestId,
  }) => app.post('/v1/ai/menus', {
    'localDate': (date ?? today).toKey(),
    'requestId': requestId ?? uuid.v4(),
    'targetKcal': targetKcal,
  }, token: as ?? token);

  Future<GenerateMenuResponse> ok({
    String? as,
    LocalDate? date,
    int targetKcal = 2210,
  }) async {
    final r = await generate(as: as, date: date, targetKcal: targetKcal);
    expect(r.status, 200, reason: '${r.json}');
    return GenerateMenuResponse.fromJson(r.json);
  }

  Future<MenuStatusResponse> status([LocalDate? date, String? as]) async =>
      MenuStatusResponse.fromJson(
        (await app.get(
          '/v1/ai/menus/${(date ?? today).toKey()}',
          token: as ?? token,
        )).json,
      );

  Future<({int used, int reserved, bool blocked})> budget([
    String month = '2026-10',
  ]) async {
    final rows = await app.tdb.pool.execute(
      Sql.named('''
        SELECT round(used_vnd * 100)::bigint, round(reserved_vnd * 100)::bigint,
               blocked_at IS NOT NULL
        FROM ai_budget_months WHERE month = @m'''),
      parameters: {'m': month},
    );
    if (rows.isEmpty) return (used: 0, reserved: 0, blocked: false);
    final r = rows.single;
    return (used: r[0]! as int, reserved: r[1]! as int, blocked: r[2]! as bool);
  }

  /// Đặt sẵn chi phí đã dùng của tháng (đồng).
  Future<void> spent(num vnd, [String month = '2026-10']) =>
      app.tdb.pool.execute(
        Sql.named('''
          INSERT INTO ai_budget_months (month, used_vnd) VALUES (@m, @v::numeric)
          ON CONFLICT (month) DO UPDATE SET used_vnd = EXCLUDED.used_vnd'''),
        parameters: {'m': month, 'v': '$vnd'},
      );

  int estimateCenti({int kcal = 2210, List<String> previous = const []}) =>
      const CostEstimator(AiConfig()).estimateCenti(
        PromptBuilder.menu(
          sex: Sex.male,
          age: 30,
          targetKcal: kcal,
          maxTokens: 2500,
          previousDishes: previous,
        ),
      );

  final actualCenti = const CostEstimator(AiConfig()).actualCenti(900, 1200);

  test('05 §6.9.3: ước tính khoảng 450đ/lần, luôn ≥ chi phí thực tế', () {
    final e = estimateCenti();
    expect(e, inInclusiveRange(30000, 60000));
    expect(actualCenti, lessThan(e));
    // Token ra tối đa (2.500) vẫn không vượt ước tính.
    expect(
      const CostEstimator(AiConfig()).actualCenti(3000, 2500),
      lessThanOrEqualTo(e),
    );
  });

  test('F08-AC1: chưa bấm thì không có thực đơn, không gọi AI', () async {
    final pull = await app.pull(token);
    expect(pull.changes.where((c) => c.entity == 'menu'), isEmpty);
    expect((await status()).menu, isNull);
    expect((await status()).remaining, 3);
    expect(app.ai.requests, isEmpty);
  });

  test('F08-AC4: mức 2.210 → thực đơn hợp lệ, tổng 1.989–2.431; còn 2 lượt; '
      'chi phí thực tế vào ngân sách; pull có menu, ai_daily_usage, '
      'meta.aiBudget', () async {
    final r = await ok();
    final menu = r.menu.payload!;
    expect(MenuValidator.validate(menu, 2210), isNull);
    expect(r.menu.totalKcal, inInclusiveRange(1989, 2431));
    expect(
      (r.menu.targetKcal, r.menu.usedSafetyFloor, r.menu.lastAttemptStatus),
      (2210, false, MenuAttemptStatus.ready),
    );
    expect((r.remaining, r.budgetWarning80), (2, false));
    expect(await budget(), (used: actualCenti, reserved: 0, blocked: false));

    final pull = await app.pull(token);
    final m = pull.changes.singleWhere((c) => c.entity == 'menu');
    expect(m.key, '2026-10-07');
    expect(const MenuCodec().decode(m.data!), r.menu);
    final u = pull.changes.singleWhere((c) => c.entity == 'ai_daily_usage');
    expect(
      (u.key, const AiDailyUsageCodec().decode(u.data!)),
      ('2026-10-07:menu', 1),
    );
    expect(
      pull.meta.budget,
      (AiBudgetMeta(
        month: YearMonth(2026, 10),
        usedVnd: actualCenti / 100,
        capVnd: 50000,
        blocked: false,
      )),
    );
  });

  test('F08-AC3, F08-R11: xem lại không tốn lượt, không gọi AI', () async {
    final r = await ok();
    final calls = app.ai.requests.length;
    final s = await status();
    expect((s.menu, s.remaining), (r.menu, 2));
    expect(app.ai.requests.length, calls);
    expect((await budget()).used, actualCenti);
  });

  test('F08-AC2, F08-R2: sau 3 lần thành công → menu_quota_exhausted, thực '
      'đơn hiện tại vẫn xem được', () async {
    for (var i = 0; i < 3; i++) {
      expect((await ok()).remaining, 2 - i);
    }
    final r = await generate();
    expect((r.status, r.errorCode), (429, 'menu_quota_exhausted'));
    expect((await status()).menu?.payload, isNotNull);
    expect(app.ai.requests.length, 3, reason: 'không gọi AI lần thứ 4');
  });

  test('F08-R4, TR-12: gợi ý lại gửi kèm tên các món trước; prompt chỉ có giới '
      'tính, tuổi, mức calo', () async {
    final first = await ok();
    await ok();
    final [a, b] = app.ai.requests;
    expect(a.user, contains('Nam'));
    expect(a.user, contains('Tuổi: 30'));
    expect(a.user, contains('2210 kcal'));
    for (final secret in ['Minh', '0912345678', '175', 'kg', '1996']) {
      expect(a.user, isNot(contains(secret)));
      expect(a.system, isNot(contains(secret)));
    }
    expect(b.avoidDishes, first.menu.payload!.dishNames);
    for (final name in first.menu.payload!.dishNames) {
      expect(b.user, contains(name));
    }
  });

  group('F08-E4, F08-R3, TAC-13: lỗi không trừ lượt, giữ thực đơn cũ', () {
    for (final (mode, code, billed) in [
      (FakeAiMode.wrongKcal, 'ai_invalid_output', true),
      (FakeAiMode.missingMeal, 'ai_invalid_output', true),
      (FakeAiMode.invalidJson, 'ai_invalid_output', true),
      (FakeAiMode.overloaded, 'ai_provider_error', false),
      (FakeAiMode.timeout, 'ai_provider_error', true),
    ]) {
      test(
        '${mode.name} → $code; F11-E1: ${billed ? 'vẫn tính chi phí' : 'không tính'}',
        () async {
          final before = await ok();
          app.ai.mode = mode;
          final r = await generate();
          expect((r.status, r.errorCode), (502, code));
          final s = await status();
          expect(s.remaining, 2, reason: 'F08-R3');
          expect(s.menu!.payload, before.menu.payload, reason: 'TAC-13');
          expect(s.menu!.lastAttemptStatus, MenuAttemptStatus.failed);
          expect(s.menu!.lastErrorCode, ErrorCode.fromWire(code));
          final b = await budget();
          expect(b.reserved, 0);
          expect(
            b.used,
            actualCenti +
                (!billed
                    ? 0
                    : mode == FakeAiMode.timeout
                    ? estimateCenti(previous: before.menu.payload!.dishNames)
                    : actualCenti),
          );
        },
      );
    }
  });

  test(
    'F08-AC5, TAC-08: nam đặt 1.300 → server dùng 1.500, có ghi chú F08-R9',
    () async {
      final r = await ok(targetKcal: 1300);
      expect((r.menu.targetKcal, r.menu.usedSafetyFloor), (1500, true));
      expect(r.menu.totalKcal, inInclusiveRange(1350, 1650));
      expect(app.ai.requests.single.user, contains('1500 kcal'));
    },
  );

  test('gửi trùng requestId → trả kết quả cũ, không tạo, không tính tiền lần '
      'nữa', () async {
    final id = uuid.v4();
    final a = await generate(requestId: id);
    final b = await generate(requestId: id);
    expect((a.status, b.status), (200, 200));
    expect(
      GenerateMenuResponse.fromJson(b.json).menu,
      GenerateMenuResponse.fromJson(a.json).menu,
    );
    expect(app.ai.requests, hasLength(1));
    expect((await budget()).used, actualCenti);
    expect((await status()).remaining, 2);
  });

  test('TA-13: đang tạo thì yêu cầu thứ hai → generation_in_progress; trạng '
      'thái "generating" đi qua pull, thực đơn cũ giữ nguyên', () async {
    final first = await ok();
    final gate = app.ai.gate = Completer<void>();
    final pending = generate();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final second = await generate();
    expect((second.status, second.errorCode), (409, 'generation_in_progress'));
    final s = await status();
    expect(s.menu!.lastAttemptStatus, MenuAttemptStatus.generating);
    expect(s.menu!.payload, first.menu.payload);
    gate.complete();
    expect((await pending).status, 200);
  });

  test('F08-E5: bấm 23:59, xong 00:01 → thực đơn thuộc ngày bấm', () async {
    await at(DateTime.utc(2026, 10, 7, 16, 59)); // 23:59 giờ Việt Nam
    final gate = app.ai.gate = Completer<void>();
    final pending = generate(date: today);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    app.clock.set(DateTime.utc(2026, 10, 7, 17, 1)); // 00:01 ngày 08/10
    gate.complete();
    final r = GenerateMenuResponse.fromJson((await pending).json);
    expect(r.date, today);
    expect((await status(today)).menu?.payload, isNotNull);
    expect((await status(LocalDate(2026, 10, 8))).menu, isNull);
  });

  test(
    'ngày bấm lệch quá 1 ngày so với ngày trên iPhone → validation_failed',
    () async {
      final r = await generate(date: LocalDate(2026, 10, 9));
      expect((r.status, r.errorField), (422, 'localDate'));
      expect((await generate(date: LocalDate(2026, 10, 6))).status, 200);
    },
  );

  test(
    'F08-R5: tạo thực đơn ngày mới → thực đơn ngày cũ bị xóa ở máy khác',
    () async {
      await ok();
      final cursor = (await app.pull(token)).nextCursor;
      await at(DateTime.utc(2026, 10, 8, 3));
      await ok(date: LocalDate(2026, 10, 8));
      final changes = (await app.pull(
        token,
        cursor: cursor,
      )).changes.where((c) => c.entity == 'menu').toList();
      expect(
        {for (final c in changes) c.key: c.deleted},
        {'2026-10-07': true, '2026-10-08': false},
      );
      expect((await status(today)).menu, isNull);
      expect((await status(LocalDate(2026, 10, 8))).remaining, 2);
    },
  );

  test('chưa thiết lập xong → profile_incomplete, không gọi AI', () async {
    final t = (await app.register(phone: '0987654321')).accessToken;
    final r = await generate(as: t);
    expect((r.status, r.errorCode), (409, 'profile_incomplete'));
    expect(app.ai.requests, isEmpty);
  });

  group('F-11: kiểm soát ngân sách', () {
    test(
      'F11-R3, F11-R5, F11-AC3: còn ít hơn ước tính → budget_exhausted, '
      'tháng bị chặn; vẫn đồng bộ ghi chép, vẫn xem thực đơn đã tạo',
      () async {
        await ok();
        final used = (await budget()).used;
        await spent((50000 * 100 - estimateCenti() + 1 - 0) / 100);
        final r = await generate();
        expect((r.status, r.errorCode), (429, 'budget_exhausted'));
        expect((await budget()).blocked, isTrue);
        expect(app.ai.requests, hasLength(1));
        // F11-R5: đã chặn thì kể cả khi còn tiền cũng dừng đến tháng sau.
        await spent(used / 100);
        expect((await generate()).errorCode, 'budget_exhausted');
        expect((await app.pull(token)).meta.budget!.blocked, isTrue);
        // F11-AC3: ghi chép vẫn chạy, thực đơn đã tạo vẫn xem được.
        final w = (await app.push(token, [
          mutation(
            'weight',
            '2026-10-05',
            SyncOp.upsert,
            at: t0,
            data: {'weightKgX10': 790},
          ),
        ])).results.single;
        expect(w.status, PushStatus.applied);
        expect((await status()).menu?.payload, isNotNull);
      },
    );

    test('F11-E2, F11-AC4: sang tháng mới (giờ Việt Nam) → tạo được lại, mức '
        'đã dùng về 0', () async {
      await spent(49990);
      expect((await generate()).errorCode, 'budget_exhausted');
      // 17:00 UTC 31/10 = 00:00 01/11 giờ Việt Nam.
      await at(DateTime.utc(2026, 10, 31, 17));
      final r = await ok(date: LocalDate(2026, 11, 1));
      expect(r.menu.payload, isNotNull);
      expect(await budget('2026-11'), (
        used: actualCenti,
        reserved: 0,
        blocked: false,
      ));
      expect((await app.pull(token)).meta.budget!.month, YearMonth(2026, 11));
    });

    test('TAC-05, F11-AC1: 10 yêu cầu đồng thời khi chỉ đủ cho 3 → không bao '
        'giờ vượt trần', () async {
      final tokens = [
        for (var i = 0; i < 10; i++)
          await user('09100000${i.toString().padLeft(2, '0')}'),
      ];
      final e = estimateCenti();
      await spent((50000 * 100 - 3 * e - 50) / 100);
      final gate = app.ai.gate = Completer<void>();
      final pending = [for (final t in tokens) generate(as: t)];
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final mid = await budget();
      expect(mid.used + mid.reserved, lessThanOrEqualTo(50000 * 100));
      expect(mid.reserved, 3 * e);
      gate.complete();
      final results = await Future.wait(pending);
      final codes = [for (final r in results) r.status];
      expect(codes.where((c) => c == 200), hasLength(3));
      expect(
        results.where((r) => r.errorCode == 'budget_exhausted'),
        hasLength(7),
      );
      final end = await budget();
      expect(end.used, lessThanOrEqualTo(50000 * 100));
      expect(end.reserved, 0);
    });

    test(
      'TAC-12: server dừng giữa chừng → job dọn sau 10 phút tính trọn số '
      'đặt trước, thực đơn "failed"; kết quả về muộn không tính lần nữa',
      () async {
        final gate = app.ai.gate = Completer<void>();
        final pending = generate();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final e = estimateCenti();
        expect(await budget(), (used: 0, reserved: e, blocked: false));

        final cleanup = AiCleanup(app.tdb.pool, app.clock);
        expect(await cleanup.run(), (requests: 0, menus: 0));
        app.clock.set(t0.add(const Duration(minutes: 11)));
        expect(await cleanup.run(), (requests: 1, menus: 1));
        expect(await budget(), (used: e, reserved: 0, blocked: false));
        final s = await status();
        expect(
          (s.menu!.lastAttemptStatus, s.menu!.lastErrorCode, s.remaining),
          (MenuAttemptStatus.failed, ErrorCode.aiProviderError, 3),
        );

        gate.complete();
        final r = await pending;
        expect((r.status, r.errorCode), (502, 'ai_provider_error'));
        expect(await budget(), (used: e, reserved: 0, blocked: false));
        // Hết yêu cầu treo: tạo lại được.
        expect((await generate()).status, 200);
      },
    );
  });

  group('F11-R4, F11-AC2: báo 80% đúng một lần trong tháng', () {
    test('lần tạo làm chi phí đạt 80% → budgetWarning80 = true; các lần sau '
        '→ false', () async {
      await spent((40000 * 100 - actualCenti) / 100);
      expect((await ok()).budgetWarning80, isTrue);
      expect((await ok()).budgetWarning80, isFalse);
      final b = await user('0987654321');
      expect((await ok(as: b)).budgetWarning80, isFalse);
    });

    test(
      '2 máy cùng tạo khi sắp chạm 80% → chỉ một kết quả có cờ báo',
      () async {
        final other = await user('0987654321');
        await spent((40000 * 100 - actualCenti) / 100);
        final gate = app.ai.gate = Completer<void>();
        final a = generate();
        final b = generate(as: other);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        gate.complete();
        final results = [
          for (final r in await Future.wait([a, b]))
            GenerateMenuResponse.fromJson(r.json),
        ];
        expect(results.where((r) => r.budgetWarning80), hasLength(1));
      },
    );

    test('lần tạo lỗi không mang cờ; lần thành công kế tiếp mới báo', () async {
      await spent((40000 * 100 - 1) / 100);
      app.ai.mode = FakeAiMode.wrongKcal;
      expect((await generate()).errorCode, 'ai_invalid_output');
      app.ai.mode = FakeAiMode.valid;
      expect((await ok()).budgetWarning80, isTrue);
    });
  });

  group('TAC-07: truy cập chéo tài khoản', () {
    test('B không xem, không pull được thực đơn và lượt của A; app không ghi '
        'được entity chỉ pull', () async {
      await ok();
      final b = await user('0987654321');
      expect((await status(today, b)).menu, isNull);
      expect((await status(today, b)).remaining, 3);
      final pull = await app.pull(b);
      expect(
        pull.changes.where(
          (c) => c.entity == 'menu' || c.entity == 'ai_daily_usage',
        ),
        isEmpty,
      );
      final push = (await app.push(b, [
        mutation(
          'menu',
          '2026-10-07',
          SyncOp.upsert,
          at: t0,
          data: {'targetKcal': 2210},
        ),
      ])).results.single;
      expect((push.status, push.field), (PushStatus.rejected, 'op'));
    });
  });
}
