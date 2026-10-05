import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support/test_database.dart';

void main() {
  late TestDatabase tdb;
  setUpAll(() async => tdb = await TestDatabase.create());
  tearDownAll(() => tdb.dispose());

  Future<void> insertUser(String phone, String name) => tdb.pool.execute(
    Sql.named(
      "INSERT INTO users (phone, password_hash, display_name) VALUES (@p, crypt('x', gen_salt('bf', 4)), @n)",
    ),
    parameters: {'p': phone, 'n': name},
  );

  test('0001: tạo users, refresh_tokens, pgcrypto từ database trống', () async {
    final rows = await tdb.pool.execute(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY 1",
    );
    expect([
      for (final r in rows) r[0],
    ], containsAll(['users', 'refresh_tokens', 'schema_migrations']));
    final ext = await tdb.pool.execute(
      "SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'",
    );
    expect(ext, hasLength(1));
  });

  test('UA-20: CHECK số điện thoại và UNIQUE mỗi số một tài khoản', () async {
    await insertUser('0912345678', 'Minh');
    await expectLater(
      insertUser('0912345678', 'Lan'),
      throwsA(isA<ServerException>()),
    );
    await expectLater(
      insertUser('912345678', 'Lan'),
      throwsA(isA<ServerException>()),
    );
    await expectLater(
      insertUser('09123456a8', 'Lan'),
      throwsA(isA<ServerException>()),
    );
  });

  test('UA-21: CHECK tên 1–30 ký tự, không có khoảng trắng đầu/cuối', () async {
    await insertUser('0900000001', 'Nguyễn Thị Ánh Dương Phượng Vy');
    await expectLater(
      insertUser('0900000002', ''),
      throwsA(isA<ServerException>()),
    );
    await expectLater(
      insertUser('0900000003', ' Minh'),
      throwsA(isA<ServerException>()),
    );
    await expectLater(
      insertUser('0900000004', 'a' * 31),
      throwsA(isA<ServerException>()),
    );
  });
}
