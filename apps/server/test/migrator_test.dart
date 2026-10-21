import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  late TestDatabase tdb;
  late Directory dir;
  final log = CapturingLogger();

  setUp(() async {
    tdb = await TestDatabase.create(schema: false);
    dir = Directory.systemTemp.createTempSync('migrations_');
  });

  tearDown(() async {
    await tdb.dispose();
    dir.deleteSync(recursive: true);
  });

  void write(String name, String sql) =>
      File('${dir.path}/$name').writeAsStringSync(sql);

  Future<List<String>> tables() async {
    final rows = await tdb.pool.execute(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY 1",
    );
    return [for (final r in rows) r[0]! as String];
  }

  test(
    'chạy theo thứ tự số, ghi schema_migrations, lần 2 không chạy lại',
    () async {
      write('0002_b.sql', 'CREATE TABLE b (id int REFERENCES a(id));');
      write(
        '0001_a.sql',
        'CREATE TABLE a (id int PRIMARY KEY); INSERT INTO a VALUES (1);',
      );
      final m = Migrator(tdb.pool, dir, log.logger);
      expect(await m.migrate(), ['0001_a', '0002_b']);
      expect(await tables(), ['a', 'b', 'schema_migrations']);
      expect(await m.migrate(), isEmpty);
    },
  );

  test('file lỗi → rollback cả file, không ghi version', () async {
    write('0001_a.sql', 'CREATE TABLE a (id int); SELECT * FROM khong_co;');
    final m = Migrator(tdb.pool, dir, log.logger);
    await expectLater(m.migrate(), throwsA(anything));
    expect(await tables(), ['schema_migrations']);
  });

  test('05 §6.7.5: file đã chạy bị sửa → dừng', () async {
    write('0001_a.sql', 'CREATE TABLE a (id int);');
    await Migrator(tdb.pool, dir, log.logger).migrate();
    write('0001_a.sql', 'CREATE TABLE a (id int, x int);');
    await expectLater(
      Migrator(tdb.pool, dir, log.logger).migrate(),
      throwsA(isA<MigrationException>()),
    );
  });

  test('tên file sai quy ước → dừng', () async {
    write('init.sql', 'SELECT 1;');
    await expectLater(
      Migrator(tdb.pool, dir, log.logger).migrate(),
      throwsA(isA<MigrationException>()),
    );
  });

  test(
    'advisory lock: hai tiến trình chạy cùng lúc không áp dụng 2 lần',
    () async {
      write('0001_a.sql', 'CREATE TABLE a (id int); SELECT pg_sleep(0.3);');
      final second = Database.open(tdb.url);
      addTearDown(second.close);
      final results = await Future.wait([
        Migrator(tdb.pool, dir, log.logger).migrate(),
        Migrator(second.pool, dir, log.logger).migrate(),
      ]);
      expect(results.expand((r) => r).toList(), ['0001_a']);
    },
  );

  test('dòng `-- migrate:commit`: giá trị enum mới dùng được ở đoạn sau; '
      'đoạn sau lỗi thì đoạn trước đã commit, version chưa ghi, chạy lại '
      'được', () async {
    write('0001_a.sql', """
CREATE TYPE g AS ENUM ('a');
CREATE TABLE r (id text, g g);
""");
    write('0002_b.sql', """
ALTER TYPE g ADD VALUE IF NOT EXISTS 'b';
-- migrate:commit
INSERT INTO r VALUES ('x', 'b');
SELECT * FROM khong_co;
""");
    final m = Migrator(tdb.pool, dir, log.logger);
    await expectLater(m.migrate(), throwsA(anything));
    final versions = await tdb.pool.execute(
      'SELECT version FROM schema_migrations ORDER BY 1',
    );
    expect([for (final r in versions) r[0]], ['0001_a']);
    expect(await tdb.pool.execute('SELECT * FROM r'), isEmpty);
    write('0002_b.sql', """
ALTER TYPE g ADD VALUE IF NOT EXISTS 'b';
-- migrate:commit
INSERT INTO r VALUES ('x', 'b');
""");
    expect(await Migrator(tdb.pool, dir, log.logger).migrate(), ['0002_b']);
    expect((await tdb.pool.execute('SELECT g::text FROM r')).single[0], 'b');
  });

  test('SqlScript: tách đoạn đúng dòng đánh dấu, bỏ đoạn chỉ có ghi chú', () {
    expect(SqlScript.segments('SELECT 1;'), hasLength(1));
    expect(
      SqlScript.segments(
        'A;\n  -- migrate:commit  \nB;\n-- migrate:commit\n-- chỉ ghi chú\n',
      ).map((s) => s.trim()),
      ['A;', 'B;'],
    );
    expect(
      SqlScript.segments('-- nhắc tới `-- migrate:commit` trong câu\nA;'),
      hasLength(1),
    );
  });

  group('migration của repo (05 Bản 3 TR3-05, TA3-10)', () {
    final repo = Directory('migrations');

    test(
      'database trống → 0001_baseline, 0002_v3; lần 2 không chạy gì',
      () async {
        final m = Migrator(tdb.pool, repo, log.logger);
        expect(await m.migrate(), ['0001_baseline', '0002_v3']);
        expect(await m.migrate(), isEmpty);
      },
    );

    test('0001_baseline không bao giờ bị sửa (checksum cố định, khớp '
        'production Bản 2)', () {
      final sql = File('migrations/0001_baseline.sql').readAsStringSync();
      expect(
        sha256.convert(utf8.encode(sql)).toString(),
        '7dd9d9a5d3061d68def6b62aa68e82654e1f22022c0e482e5134848782e809c6',
      );
    });

    test(
      'database tạo từ schema.sql Bản 2 (production, chưa có '
      'schema_migrations) → ghi nhận 0001 là đã chạy, chỉ chạy 0002',
      () async {
        await tdb.pool.execute(
          File('migrations/0001_baseline.sql').readAsStringSync(),
          queryMode: QueryMode.simple,
        );
        final logs = CapturingLogger();
        expect(await Migrator(tdb.pool, repo, logs.logger).migrate(), [
          '0002_v3',
        ]);
        expect(logs.lines.join(), contains('migration_baseline_adopted'));
        final versions = await tdb.pool.execute(
          'SELECT version FROM schema_migrations ORDER BY 1',
        );
        expect([for (final r in versions) r[0]], ['0001_baseline', '0002_v3']);
      },
    );
  });
}
