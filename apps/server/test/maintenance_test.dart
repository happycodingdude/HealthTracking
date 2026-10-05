import 'package:postgres/postgres.dart';
import 'package:server/src/jobs/maintenance.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  test(
    'VS02-T06: dọn processed_mutations > 30 ngày, refresh token hết hạn > 30 ngày; giữ phần còn lại',
    () async {
      final app = await TestApp.create();
      addTearDown(app.dispose);
      final pair = await app.register();
      final now = app.clock.now().toUtc();
      final userId = app.deps.tokens.verifyAccessToken(pair.accessToken)!;

      Future<void> mutationAt(String id, DateTime at) => app.tdb.pool.execute(
        Sql.named(
          "INSERT INTO processed_mutations (mutation_id, user_id, result, created_at) VALUES (@id::uuid, @u, '{}', @at)",
        ),
        parameters: {'id': id, 'u': userId, 'at': at},
      );
      await mutationAt(
        '00000000-0000-4000-8000-000000000001',
        now.subtract(const Duration(days: 31)),
      );
      await mutationAt(
        '00000000-0000-4000-8000-000000000002',
        now.subtract(const Duration(days: 29)),
      );

      // Token cũ: hết hạn 31 ngày trước; token mới (của lần đăng ký) còn hạn.
      await app.tdb.pool.execute(
        Sql.named(
          '''
        INSERT INTO refresh_tokens (user_id, token_hash, family_id, expires_at)
        VALUES (@u, decode(repeat('ab', 32), 'hex'), gen_random_uuid(), @exp)''',
        ),
        parameters: {
          'u': userId,
          'exp': now.subtract(const Duration(days: 31)),
        },
      );

      final removed = await Maintenance(app.tdb.pool, app.clock).dailyCleanup();
      expect(removed.mutations, 1);
      expect(removed.refreshTokens, 1);
      expect(
        (await app.tdb.pool.execute(
          'SELECT count(*) FROM processed_mutations',
        )).single[0],
        1,
      );
      final refresh = await app.post('/v1/auth/refresh', {
        'refreshToken': pair.refreshToken,
      });
      expect(refresh.status, 200, reason: 'token còn hạn không bị xóa');
    },
  );

  test(
    'xóa được token đã xoay vòng (replaced_by ON DELETE SET NULL)',
    () async {
      final app = await TestApp.create();
      addTearDown(app.dispose);
      final first = await app.register();
      await app.post('/v1/auth/refresh', {'refreshToken': first.refreshToken});
      app.clock.advance(const Duration(days: 180 + 31));
      final removed = await Maintenance(app.tdb.pool, app.clock).dailyCleanup();
      expect(removed.refreshTokens, 2);
    },
  );
}
