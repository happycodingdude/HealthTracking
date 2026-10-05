import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    '0003 chạy trên dữ liệu của phiên bản trước: user cũ chưa có hồ sơ',
    () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final log = CapturingLogger();
      final upTo0002 = Directory.systemTemp.createTempSync('m0002_');
      addTearDown(() => upTo0002.deleteSync(recursive: true));
      for (final f in ['0001_auth.sql', '0002_sync.sql']) {
        File('migrations/$f').copySync('${upTo0002.path}/$f');
      }
      await Migrator(tdb.pool, upTo0002, log.logger).migrate();
      await tdb.pool.execute(
        "INSERT INTO users (phone, password_hash, display_name) VALUES ('0911111111', 'x', 'An')",
      );

      expect(
        await Migrator(tdb.pool, Directory('migrations'), log.logger).migrate(),
        contains('0003_profile_weight'),
      );
      final counts = await tdb.pool.execute(
        'SELECT (SELECT count(*) FROM profiles), (SELECT count(*) FROM weights)',
      );
      expect(counts.single, [0, 0]);
    },
  );

  group('0003: CHECK khớp quy tắc', () {
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

    final violates = throwsA(
      isA<ServerException>().having((e) => e.code, 'code', '23514'),
    );

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

    test('FR-11: khóa tuần là thứ 2; F07-V1: 30–250 kg', () async {
      await weight('2026-10-05', 725);
      expect(weight('2026-10-06', 725), violates);
      expect(weight('2026-10-12', 299), violates);
      expect(weight('2026-10-12', 2501), violates);
      expect(weight('2026-10-12', null), violates);
    });
  });
}
