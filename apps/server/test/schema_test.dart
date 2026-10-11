import 'package:postgres/postgres.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

/// `db/schema.sql` (06 Bản 2 ED2-18): tạo được từ database trống và CHECK khớp
/// quy tắc. Phần Bản 1 giữ nguyên các kiểm tra của migration 0001 → 0005 cũ.
void main() {
  final violates = throwsA(
    isA<ServerException>().having((e) => e.code, 'code', '23514'),
  );
  final rejected = throwsA(isA<ServerException>());

  Future<String> newUser(
    TestDatabase tdb, [
    String phone = '0911111111',
  ]) async =>
      (await tdb.pool.execute(
            Sql.named(
              "INSERT INTO users (phone, password_hash, display_name) VALUES (@p, 'x', 'An') RETURNING id",
            ),
            parameters: {'p': phone},
          )).single[0]!
          as String;

  group('tạo từ database trống', () {
    late TestDatabase tdb;
    setUpAll(() async => tdb = await TestDatabase.create());
    tearDownAll(() => tdb.dispose());

    test('đủ bảng Bản 1 và Bản 2, có pgcrypto, không có exercise_suggestions '
        '(TD2-13)', () async {
      final rows = await tdb.pool.execute(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY 1",
      );
      final tables = [for (final r in rows) r[0]];
      expect(
        tables,
        containsAll([
          'users',
          'refresh_tokens',
          'processed_mutations',
          'profiles',
          'weights',
          'weekly_templates',
          'month_plans',
          'days',
          'menus',
          'ai_daily_usage',
          'ai_budget_months',
          'ai_requests',
          'dish_images',
          'muscle_regions',
          'exercises',
          'lift_logs',
        ]),
      );
      expect(tables, isNot(contains('exercise_suggestions')));
      final ext = await tdb.pool.execute(
        "SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'",
      );
      expect(ext, hasLength(1));
    });

    test('sequence tăng, replaced_by ON DELETE SET NULL', () async {
      final a =
          (await tdb.pool.execute(
                "SELECT nextval('sync_version_seq')",
              )).single[0]!
              as int;
      final b =
          (await tdb.pool.execute(
                "SELECT nextval('sync_version_seq')",
              )).single[0]!
              as int;
      expect(b, greaterThan(a));
      final rule = await tdb.pool.execute(
        "SELECT confdeltype::text FROM pg_constraint WHERE conname = 'refresh_tokens_replaced_by_fkey'",
      );
      expect(rule.single[0], 'n');
    });

    test('05 Bản 2 §6.10.4: 16 vùng cơ nạp sẵn, đúng nhóm, đúng mặt, '
        'đúng thứ tự', () async {
      final rows = await tdb.pool.execute(
        'SELECT id, muscle_group::text, view::text FROM muscle_regions ORDER BY sort_order',
      );
      expect(
        [for (final r in rows) r.toList()],
        [
          ['chest_upper', 'chest', 'front'],
          ['chest_mid', 'chest', 'front'],
          ['chest_lower', 'chest', 'front'],
          ['lats', 'back', 'back'],
          ['back_mid', 'back', 'back'],
          ['back_lower', 'back', 'back'],
          ['delt_front', 'shoulders', 'front'],
          ['delt_side', 'shoulders', 'front'],
          ['delt_rear', 'shoulders', 'back'],
          ['biceps', 'biceps', 'front'],
          ['brachialis_forearm', 'biceps', 'front'],
          ['triceps_long', 'triceps', 'back'],
          ['triceps_lateral_medial', 'triceps', 'back'],
          ['abs_lower', 'abs', 'front'],
          ['abs_mid', 'abs', 'front'],
          ['obliques', 'abs', 'front'],
        ],
      );
    });
  });

  group('users (UA-20, UA-21)', () {
    late TestDatabase tdb;
    setUpAll(() async => tdb = await TestDatabase.create());
    tearDownAll(() => tdb.dispose());

    Future<void> insertUser(String phone, String name) => tdb.pool.execute(
      Sql.named(
        "INSERT INTO users (phone, password_hash, display_name) VALUES (@p, crypt('x', gen_salt('bf', 4)), @n)",
      ),
      parameters: {'p': phone, 'n': name},
    );

    test('UA-20: CHECK số điện thoại và UNIQUE mỗi số một tài khoản', () async {
      await insertUser('0912345678', 'Minh');
      await expectLater(insertUser('0912345678', 'Lan'), rejected);
      await expectLater(insertUser('912345678', 'Lan'), rejected);
      await expectLater(insertUser('09123456a8', 'Lan'), rejected);
    });

    test(
      'UA-21: CHECK tên 1–30 ký tự, không có khoảng trắng đầu/cuối',
      () async {
        await insertUser('0900000001', 'Nguyễn Thị Ánh Dương Phượng Vy');
        await expectLater(insertUser('0900000002', ''), rejected);
        await expectLater(insertUser('0900000003', ' Minh'), rejected);
        await expectLater(insertUser('0900000004', 'a' * 31), rejected);
      },
    );

    test(
      'user mới có server_version, client_updated_at, deleted = false',
      () async {
        await insertUser('0900000009', 'Bình');
        final row = (await tdb.pool.execute(
          "SELECT server_version, client_updated_at, deleted FROM users WHERE phone = '0900000009'",
        )).single;
        expect(row[0], isA<int>());
        expect(row[1], isA<DateTime>());
        expect(row[2], isFalse);
      },
    );
  });

  group('profiles, weights (VS-03, Bản 2 schedule_started_on)', () {
    late TestDatabase tdb;
    late String user;

    setUp(() async {
      tdb = await TestDatabase.create();
      user = await newUser(tdb);
    });
    tearDown(() => tdb.dispose());

    Future<void> profile(String columns, String values) => tdb.pool.execute(
      Sql.named(
        'INSERT INTO profiles (user_id, server_version, client_updated_at, $columns) VALUES (@u, 1, now(), $values)',
      ),
      parameters: {'u': user},
    );

    Future<void> weight(String week, int? kg) => tdb.pool.execute(
      Sql.named(
        'INSERT INTO weights (user_id, week_start, weight_kg_x10, server_version, client_updated_at) VALUES (@u, @w::date, @kg, 1, now())',
      ),
      parameters: {'u': user, 'w': week, 'kg': kg},
    );

    const complete =
        'onboarding_step, disclaimer_accepted_at, height_cm, birth_year, sex, activity_level, calorie_mode, calorie_kcal, setup_date, onboarding_completed_at';
    const completeValues =
        "5, now(), 175, 1996, 'male', 'moderate', 'auto', 2210, '2026-10-07', now()";

    test('hồ sơ hợp lệ ở các bước', () async {
      await profile('onboarding_step', '1');
      await tdb.pool.execute('DELETE FROM profiles');
      await profile(
        'onboarding_step, disclaimer_accepted_at, height_cm, birth_year, sex, activity_level, calorie_mode, calorie_kcal',
        "4, now(), 175, 1996, 'male', 'moderate', 'manual', 1300",
      );
    });

    test('F10-AC1: qua bước 1 phải đã bấm "Tôi đã hiểu"', () {
      expect(profile('onboarding_step', '2'), violates);
    });

    test('qua bước 2 phải đủ thông tin cơ thể; qua bước 3 phải có mức calo', () {
      expect(
        profile(
          'onboarding_step, disclaimer_accepted_at, height_cm',
          '3, now(), 175',
        ),
        violates,
      );
      expect(
        profile(
          'onboarding_step, disclaimer_accepted_at, height_cm, birth_year, sex, activity_level',
          "4, now(), 175, 1996, 'male', 'moderate'",
        ),
        violates,
      );
    });

    test('F01-V1, F02-V1, đề xuất đang chờ', () {
      expect(profile('onboarding_step, height_cm', '1, 231'), violates);
      expect(
        profile(
          'onboarding_step, calorie_mode, calorie_kcal',
          "1, 'manual', 5001",
        ),
        violates,
      );
      expect(
        profile(
          'onboarding_step, calorie_mode, calorie_kcal, calorie_pending_kcal',
          "1, 'manual', 1900, 2090",
        ),
        violates,
        reason: 'thiếu lý do của đề xuất',
      );
      expect(
        profile(
          'onboarding_step, calorie_mode, calorie_kcal, calorie_pending_kcal, calorie_pending_reason',
          "1, 'auto', 2210, 2090, 'weight'",
        ),
        violates,
        reason: 'đề xuất chỉ có ở chế độ Bạn tự đặt',
      );
    });

    test('Bản 2: ngày bắt đầu lịch chỉ có sau khi hoàn tất thiết lập '
        '(TD2-09)', () async {
      expect(
        profile(
          'onboarding_step, disclaimer_accepted_at, schedule_started_on',
          "2, now(), '2026-10-14'",
        ),
        violates,
      );
      await profile(
        '$complete, schedule_started_on',
        "$completeValues, '2026-10-14'",
      );
    });

    test('FR-11: khóa tuần là thứ 2; F07-V1: 30–250 kg', () async {
      await weight('2026-10-05', 725);
      expect(weight('2026-10-06', 725), violates);
      expect(weight('2026-10-12', 299), violates);
      expect(weight('2026-10-12', 2501), violates);
      expect(weight('2026-10-12', null), violates);
    });
  });

  group('lịch tuần, lịch tháng, ngày (VS-04)', () {
    late TestDatabase tdb;
    late String user;

    setUp(() async {
      tdb = await TestDatabase.create();
      user = await newUser(tdb);
      await tdb.pool.execute(
        Sql.named(
          "INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at, server_version, client_updated_at) VALUES (@u, '2026-10', '2026-10-07', @h, now(), 1, now())",
        ),
        parameters: {'u': user, 'h': 'a' * 64},
      );
    });
    tearDown(() => tdb.dispose());

    Future<void> day(
      String date,
      String columns,
      String values,
    ) => tdb.pool.execute(
      Sql.named(
        'INSERT INTO days (user_id, date, server_version, client_updated_at, $columns) VALUES (@u, @d::date, 1, now(), $values)',
      ),
      parameters: {'u': user, 'd': date},
    );

    test('ngày tập có giờ và nhóm cơ; ngày nghỉ không có', () async {
      await day(
        '2026-10-07',
        'kind, time, muscles',
        "'workout', '18:00', ARRAY['back']::muscle_group[]",
      );
      await day('2026-10-08', 'kind', "'rest'");
      expect(day('2026-10-09', 'kind', "'workout'"), violates);
      expect(
        day(
          '2026-10-09',
          'kind, time, muscles',
          "'workout', '18:00', ARRAY[]::muscle_group[]",
        ),
        violates,
      );
      expect(day('2026-10-09', 'kind, time', "'rest', '18:00'"), violates);
    });

    test('FR-21: không có dòng nào cho chủ nhật', () {
      expect(day('2026-10-11', 'kind', "'rest'"), violates);
    });

    test('buổi tập thêm chỉ ở ngày nghỉ; đánh dấu chỉ ở ngày tập', () async {
      expect(
        day(
          '2026-10-09',
          'kind, time, muscles, extra_muscles',
          "'workout', '18:00', ARRAY['back']::muscle_group[], ARRAY['abs']::muscle_group[]",
        ),
        violates,
      );
      expect(day('2026-10-09', 'kind, mark', "'rest', 'done'"), violates);
      await day(
        '2026-10-10',
        'kind, extra_muscles',
        "'rest', ARRAY['abs']::muscle_group[]",
      );
    });

    test(
      'lịch tuần không có khóa chủ nhật; month_plan bắt đầu trong tháng của nó',
      () {
        expect(
          tdb.pool.execute(
            Sql.named(
              "INSERT INTO weekly_templates (user_id, days, content_hash, server_version, client_updated_at) VALUES (@u, '{\"7\": {\"enabled\": false}}', @h, 1, now())",
            ),
            parameters: {'u': user, 'h': 'a' * 64},
          ),
          violates,
        );
        expect(
          tdb.pool.execute(
            Sql.named(
              "INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at, server_version, client_updated_at) VALUES (@u, '2026-11', '2026-10-31', @h, now(), 1, now())",
            ),
            parameters: {'u': user, 'h': 'a' * 64},
          ),
          violates,
        );
      },
    );
  });

  group('thực đơn và ngân sách AI (VS-12, Bản 2 §6.7.3 (a))', () {
    late TestDatabase tdb;
    late String user;

    setUp(() async {
      tdb = await TestDatabase.create();
      user = await newUser(tdb);
    });
    tearDown(() => tdb.dispose());

    Future<void> insertMenu(String values) => tdb.pool.execute(
      Sql.named('''
        INSERT INTO menus (user_id, date, payload, target_kcal, total_kcal,
                           last_attempt_status, attempt_started_at, server_version)
        VALUES (@u, '2026-10-07', $values, 1)'''),
      parameters: {'u': user},
    );

    Future<void> usage(String feature, int count) => tdb.pool.execute(
      Sql.named(
        "INSERT INTO ai_daily_usage (user_id, date, feature, success_count, server_version) VALUES (@u, '2026-10-07', @f, @c, 1)",
      ),
      parameters: {'u': user, 'f': feature, 'c': count},
    );

    Future<void> request(
      String status,
      String settled, {
      String feature = 'menu',
      String provider = 'fake',
      String id = '8f1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b',
    }) => tdb.pool.execute(
      Sql.named(
        '''
        INSERT INTO ai_requests (user_id, request_id, feature, local_date, month,
                                 provider, model, status, reserved_vnd, settled_at)
        VALUES (@u, @id::uuid, @f, '2026-10-07', '2026-10', @p, 'm', '$status', 450, $settled)''',
      ),
      parameters: {'u': user, 'id': id, 'f': feature, 'p': provider},
    );

    test('thực đơn: có payload thì có tổng calo; đang tạo phải có thời điểm '
        'bắt đầu; mức calo 800–5.000', () async {
      await insertMenu("""'{"meals": []}', 2210, 2200, 'ready', NULL""");
      for (final bad in [
        """'{"meals": []}', 2210, NULL, 'ready', NULL""",
        """NULL, 2210, NULL, 'generating', NULL""",
        """NULL, 700, NULL, 'failed', NULL""",
      ]) {
        await tdb.pool.execute(Sql.named('DELETE FROM menus'));
        await expectLater(insertMenu(bad), rejected, reason: bad);
      }
    });

    test('lượt mỗi ngày 0–3 (F08-R2, F12-R4) cho thực đơn và hình món ăn; '
        'tháng ngân sách dạng YYYY-MM', () async {
      await usage('menu', 3);
      await usage('dish_image', 3);
      await expectLater(usage('exercise:chest', 1), violates);
      await tdb.pool.execute('DELETE FROM ai_daily_usage');
      await expectLater(usage('menu', 4), violates);
      await expectLater(
        tdb.pool.execute(
          "INSERT INTO ai_budget_months (month) VALUES ('2026-13')",
        ),
        rejected,
      );
      await tdb.pool.execute(
        "INSERT INTO ai_budget_months (month) VALUES ('2026-10')",
      );
      expect(
        (await tdb.pool.execute(
          'SELECT cap_vnd, used_vnd::text FROM ai_budget_months',
        )).single,
        [50000, '0.00'],
      );
    });

    test('ai_requests: requestId không trùng trong một tài khoản; đã quyết '
        'toán thì có settled_at; loại và nhà cung cấp của Bản 2', () async {
      await tdb.pool.execute(
        "INSERT INTO ai_budget_months (month) VALUES ('2026-10')",
      );
      await expectLater(request('succeeded', 'NULL'), rejected);
      await request('reserved', 'NULL');
      await expectLater(request('reserved', 'NULL'), rejected);
      await request(
        'succeeded',
        'now()',
        feature: 'dish_image',
        provider: 'openai',
        id: '9f1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b',
      );
      await request(
        'succeeded',
        'now()',
        feature: 'exercise_guide',
        provider: 'manual',
        id: 'af1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b',
      );
      await expectLater(
        request(
          'succeeded',
          'now()',
          feature: 'exercise_suggestion',
          id: 'bf1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b',
        ),
        violates,
      );
      await expectLater(
        request(
          'succeeded',
          'now()',
          provider: 'google',
          id: 'cf1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b',
        ),
        violates,
      );
    });

    test('dish_images: name_key không trùng (FA2-07)', () async {
      Future<void> image(String key) => tdb.pool.execute(
        Sql.named(
          '''
          INSERT INTO dish_images (name_key, display_name, file_path, width, height, bytes,
                                   provider, model, quality, created_by, server_version)
          VALUES (@k, 'Phở bò', 'dish/x.jpg', 768, 768, 90000, 'fake', 'm', 'low', @u, 1)''',
        ),
        parameters: {'k': key, 'u': user},
      );
      await image('phở bò');
      await expectLater(image('phở bò'), rejected);
      await expectLater(image(' phở bò'), violates);
    });
  });

  group('thư viện và mức tạ (Bản 2 §6.7.3 (b), VS20-T11)', () {
    late TestDatabase tdb;
    late String user;

    setUp(() async {
      tdb = await TestDatabase.create();
      user = await newUser(tdb);
      await tdb.pool.execute(
        Sql.named(
          "INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at, server_version, client_updated_at) VALUES (@u, '2026-11', '2026-11-02', @h, now(), 1, now())",
        ),
        parameters: {'u': user, 'h': 'a' * 64},
      );
      await tdb.pool.execute(
        Sql.named(
          "INSERT INTO days (user_id, date, kind, time, muscles, server_version, client_updated_at) VALUES (@u, '2026-11-12', 'workout', '18:00', ARRAY['chest']::muscle_group[], 1, now())",
        ),
        parameters: {'u': user},
      );
    });
    tearDown(() => tdb.dispose());

    Future<void> exercise({
      String id = 'chest-upper-free-weight-incline-dumbbell-press',
      String group = 'chest',
      String region = 'chest_upper',
      String equipment = 'free_weight',
      bool logsWeight = true,
      String name = 'Đẩy ngực trên với tạ đơn',
      int? duration = 48,
      bool available = true,
      String? reason,
      int steps = 3,
      int safety = 2,
      bool active = true,
    }) => tdb.pool.execute(
      Sql.named(
        '''
        INSERT INTO exercises (id, muscle_group, muscle_region, equipment, logs_weight, name_vi,
                               youtube_video_id, video_channel, video_duration_s, video_available,
                               video_unavailable_reason, guide_steps, guide_safety, approved_at,
                               sort_order, active, library_version, server_version)
        VALUES (@id, @g::muscle_group, @r, @e::equipment, @lw, @name, 'PZecKOpWOrk', 'Barbell Logic',
                @d, @a, @reason, @steps, @safety, '2026-10-11', 1, @active, 1, 1)''',
      ),
      parameters: {
        'id': id,
        'g': group,
        'r': region,
        'e': equipment,
        'lw': logsWeight,
        'name': name,
        'd': duration,
        'a': available,
        'reason': reason,
        'steps': TypedValue(Type.textArray, List.filled(steps, 'Bước')),
        'safety': TypedValue(Type.textArray, List.filled(safety, 'Ý')),
        'active': active,
      },
    );

    Future<void> lift(int? start, int? end, {bool deleted = false}) =>
        tdb.pool.execute(
          Sql.named(
            '''
            INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10, logged_at,
                                   server_version, client_updated_at, deleted)
            VALUES (@u, '2026-11-12', 'chest-upper-free-weight-incline-dumbbell-press',
                    @s, @e, CASE WHEN @del THEN NULL ELSE now() END, 1, now(), @del)''',
          ),
          parameters: {'u': user, 's': start, 'e': end, 'del': deleted},
        );

    test('bài hợp lệ; vùng phải đúng nhóm cơ', () async {
      await exercise();
      await expectLater(
        exercise(id: 'x-wrong-region', name: 'Bài sai vùng', region: 'lats'),
        rejected,
      );
    });

    test('không dụng cụ chỉ ở bụng; bài bụng không ghi mức tạ (FR2-12)', () {
      expect(exercise(equipment: 'bodyweight'), violates);
      expect(exercise(logsWeight: false), violates);
      expect(
        exercise(
          id: 'abs-mid-bodyweight-forearm-plank',
          group: 'abs',
          region: 'abs_mid',
          equipment: 'bodyweight',
          name: 'Plank',
        ),
        violates,
        reason: 'bài bụng phải có logs_weight = false',
      );
    });

    test('LIB-R2: video ≤ 60 giây; LIB-R4: 3–6 bước, 2–4 ý', () {
      expect(exercise(duration: 61), violates);
      expect(exercise(steps: 2), violates);
      expect(exercise(steps: 7), violates);
      expect(exercise(safety: 1), violates);
      expect(exercise(safety: 5), violates);
    });

    test('trạng thái video: không khả dụng thì có lý do', () {
      expect(exercise(available: false), violates);
      expect(exercise(reason: 'private'), violates);
      expect(exercise(available: false, reason: 'gone'), violates);
    });

    test('LIB-R1: tên không trùng trong các bài đang có; bài đã rời thư viện '
        'thì được', () async {
      await exercise(active: false);
      await exercise(id: 'chest-upper-free-weight-v2');
      await expectLater(exercise(id: 'chest-upper-free-weight-v3'), rejected);
    });

    test(
      'mức tạ 0,5–300 kg theo bước 0,5 (FA2-03); tombstone không có số',
      () async {
        await exercise();
        await lift(5, 3000);
        await tdb.pool.execute('DELETE FROM lift_logs');
        for (final bad in [(0, 120), (120, 3005), (123, 140), (120, null)]) {
          await expectLater(lift(bad.$1, bad.$2), violates, reason: '$bad');
        }
        await lift(null, null, deleted: true);
      },
    );

    test('mức tạ gắn với một buổi (dòng days) và một bài có thật', () async {
      await exercise();
      await expectLater(
        tdb.pool.execute(
          Sql.named('''
            INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10, logged_at,
                                   server_version, client_updated_at)
            VALUES (@u, '2026-11-13', 'chest-upper-free-weight-incline-dumbbell-press',
                    120, 140, now(), 1, now())'''),
          parameters: {'u': user},
        ),
        rejected,
      );
      await expectLater(
        tdb.pool.execute(
          Sql.named(
            '''
            INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10, logged_at,
                                   server_version, client_updated_at)
            VALUES (@u, '2026-11-12', 'khong-co-bai-nay', 120, 140, now(), 1, now())''',
          ),
          parameters: {'u': user},
        ),
        rejected,
      );
    });
  });
}
