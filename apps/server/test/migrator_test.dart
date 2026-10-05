import 'dart:io';

import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  late TestDatabase tdb;
  late Directory dir;
  final log = CapturingLogger();

  setUp(() async {
    tdb = await TestDatabase.create(migrate: false);
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

  test('migration thật của repo chạy được từ database trống', () async {
    final applied = await Migrator(
      tdb.pool,
      Directory('migrations'),
      log.logger,
    ).migrate();
    expect(applied, isA<List<String>>());
  });
}
