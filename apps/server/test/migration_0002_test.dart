import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    '0002 chạy trên dữ liệu của phiên bản trước: user cũ có server_version, client_updated_at',
    () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final log = CapturingLogger();
      final only0001 = Directory.systemTemp.createTempSync('m0001_');
      addTearDown(() => only0001.deleteSync(recursive: true));
      File(
        'migrations/0001_auth.sql',
      ).copySync('${only0001.path}/0001_auth.sql');
      await Migrator(tdb.pool, only0001, log.logger).migrate();
      await tdb.pool.execute(
        "INSERT INTO users (phone, password_hash, display_name) VALUES ('0911111111', 'x', 'An'), ('0922222222', 'x', 'Bình')",
      );

      expect(
        await Migrator(tdb.pool, Directory('migrations'), log.logger).migrate(),
        contains('0002_sync'),
      );

      final rows = await tdb.pool.execute(
        'SELECT server_version, client_updated_at, deleted FROM users ORDER BY phone',
      );
      expect(rows, hasLength(2));
      final versions = [for (final r in rows) r[0]! as int];
      expect(
        versions.toSet(),
        hasLength(2),
        reason: 'mỗi dòng một version riêng',
      );
      for (final r in rows) {
        expect(r[1], isA<DateTime>());
        expect(r[2], isFalse);
      }
    },
  );

  test(
    '0002 từ database trống: sequence tăng, processed_mutations có, replaced_by ON DELETE SET NULL',
    () async {
      final tdb = await TestDatabase.create();
      addTearDown(tdb.dispose);
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
        Sql.named(
          "SELECT confdeltype::text FROM pg_constraint WHERE conname = 'refresh_tokens_replaced_by_fkey'",
        ),
      );
      expect(rule.single[0], 'n');
      final pm = await tdb.pool.execute(
        "SELECT 1 FROM information_schema.tables WHERE table_name = 'processed_mutations'",
      );
      expect(pm, hasLength(1));
    },
  );
}
