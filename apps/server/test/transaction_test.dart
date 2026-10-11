import 'package:postgres/postgres.dart';
import 'package:server/src/db/transaction.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

void main() {
  late TestDatabase tdb;
  setUpAll(() async {
    tdb = await TestDatabase.create(schema: false);
    await tdb.pool.execute('CREATE TABLE t (id int PRIMARY KEY)');
  });
  tearDownAll(() => tdb.dispose());
  setUp(() => tdb.pool.execute('TRUNCATE t'));

  Future<List<int>> ids() async => [
    for (final r in await tdb.pool.execute('SELECT id FROM t ORDER BY id'))
      r[0]! as int,
  ];

  test(
    'savepoint: lỗi SQL của một bước chỉ hoàn tác bước đó, phần còn lại được commit',
    () async {
      await inTransaction(tdb.pool, (conn) async {
        await conn.execute('INSERT INTO t VALUES (1)');
        await expectLater(
          inSavepoint(
            conn,
            'm1',
            () => conn.execute('INSERT INTO t VALUES (1)'),
          ),
          throwsA(isA<ServerException>()),
        );
        await inSavepoint(
          conn,
          'm2',
          () => conn.execute('INSERT INTO t VALUES (2)'),
        );
      });
      expect(await ids(), [1, 2]);
    },
  );

  test('lỗi ngoài savepoint → rollback cả transaction', () async {
    await expectLater(
      inTransaction(tdb.pool, (conn) async {
        await conn.execute('INSERT INTO t VALUES (1)');
        throw StateError('x');
      }),
      throwsStateError,
    );
    expect(await ids(), isEmpty);
    // Connection trả về pool ở trạng thái sạch.
    await inTransaction(
      tdb.pool,
      (conn) => conn.execute('INSERT INTO t VALUES (3)'),
    );
    expect(await ids(), [3]);
  });
}
