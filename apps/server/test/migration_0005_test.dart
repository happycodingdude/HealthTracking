import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    '0005 chạy trên dữ liệu của phiên bản trước: lịch, cân giữ nguyên',
    () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final log = CapturingLogger();
      final upTo0004 = Directory.systemTemp.createTempSync('m0004_');
      addTearDown(() => upTo0004.deleteSync(recursive: true));
      for (final f in [
        '0001_auth.sql',
        '0002_sync.sql',
        '0003_profile_weight.sql',
        '0004_schedule.sql',
      ]) {
        File('migrations/$f').copySync('${upTo0004.path}/$f');
      }
      await Migrator(tdb.pool, upTo0004, log.logger).migrate();
      final user =
          (await tdb.pool.execute(
                "INSERT INTO users (phone, password_hash, display_name) VALUES ('0911111111', 'x', 'An') RETURNING id",
              )).single[0]!
              as String;
      await tdb.pool.execute(
        Sql.named(
          "INSERT INTO weights (user_id, week_start, weight_kg_x10, server_version, client_updated_at) VALUES (@u, '2026-10-05', 725, 1, now())",
        ),
        parameters: {'u': user},
      );

      expect(
        await Migrator(tdb.pool, Directory('migrations'), log.logger).migrate(),
        contains('0005_ai'),
      );
      expect(
        (await tdb.pool.execute('SELECT weight_kg_x10 FROM weights')).single[0],
        725,
      );
      expect(
        (await tdb.pool.execute('SELECT count(*) FROM menus')).single[0],
        0,
      );
    },
  );

  group('0005: CHECK khớp quy tắc', () {
    late TestDatabase tdb;
    late String user;

    setUp(() async {
      tdb = await TestDatabase.create();
      user =
          (await tdb.pool.execute(
                "INSERT INTO users (phone, password_hash, display_name) VALUES ('0911111111', 'x', 'An') RETURNING id",
              )).single[0]!
              as String;
    });
    tearDown(() => tdb.dispose());

    Future<void> insertMenu(String values) => tdb.pool.execute(
      Sql.named('''
        INSERT INTO menus (user_id, date, payload, target_kcal, total_kcal,
                           last_attempt_status, attempt_started_at, server_version)
        VALUES (@u, '2026-10-07', $values, 1)'''),
      parameters: {'u': user},
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
        await expectLater(
          insertMenu(bad),
          throwsA(isA<ServerException>()),
          reason: bad,
        );
      }
    });

    test('lượt mỗi ngày 0–3 (F08-R2); tháng ngân sách dạng YYYY-MM', () async {
      await expectLater(
        tdb.pool.execute(
          Sql.named(
            "INSERT INTO ai_daily_usage (user_id, date, feature, success_count, server_version) VALUES (@u, '2026-10-07', 'menu', 4, 1)",
          ),
          parameters: {'u': user},
        ),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        tdb.pool.execute(
          "INSERT INTO ai_budget_months (month) VALUES ('2026-13')",
        ),
        throwsA(isA<ServerException>()),
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

    test(
      'ai_requests: requestId không trùng trong một tài khoản; đã quyết toán '
      'thì có settled_at',
      () async {
        await tdb.pool.execute(
          "INSERT INTO ai_budget_months (month) VALUES ('2026-10')",
        );
        Future<void> req(String status, String settled) => tdb.pool.execute(
          Sql.named('''
          INSERT INTO ai_requests (user_id, request_id, feature, local_date, month,
                                   provider, model, status, reserved_vnd, settled_at)
          VALUES (@u, '8f1c2b9e-4d4a-4b8e-9f00-1c2d3e4f5a6b', 'menu', '2026-10-07',
                  '2026-10', 'fake', 'm', '$status', 450, $settled)'''),
          parameters: {'u': user},
        );
        await expectLater(
          req('succeeded', 'NULL'),
          throwsA(isA<ServerException>()),
        );
        await req('reserved', 'NULL');
        await expectLater(
          req('reserved', 'NULL'),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });
}
