import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    '0004 chạy trên dữ liệu của phiên bản trước: hồ sơ, cân giữ nguyên',
    () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final log = CapturingLogger();
      final upTo0003 = Directory.systemTemp.createTempSync('m0003_');
      addTearDown(() => upTo0003.deleteSync(recursive: true));
      for (final f in [
        '0001_auth.sql',
        '0002_sync.sql',
        '0003_profile_weight.sql',
      ]) {
        File('migrations/$f').copySync('${upTo0003.path}/$f');
      }
      await Migrator(tdb.pool, upTo0003, log.logger).migrate();
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
        contains('0004_schedule'),
      );
      expect(
        (await tdb.pool.execute('SELECT weight_kg_x10 FROM weights')).single[0],
        725,
      );
      expect(
        (await tdb.pool.execute('SELECT count(*) FROM days')).single[0],
        0,
      );
    },
  );

  group('0004: CHECK khớp quy tắc', () {
    late TestDatabase tdb;
    late String user;

    setUp(() async {
      tdb = await TestDatabase.create();
      user =
          (await tdb.pool.execute(
                "INSERT INTO users (phone, password_hash, display_name) VALUES ('0911111111', 'x', 'An') RETURNING id",
              )).single[0]!
              as String;
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

    final violates = throwsA(
      isA<ServerException>().having((e) => e.code, 'code', '23514'),
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
}
