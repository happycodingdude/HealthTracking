import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../server.dart';

/// URL quản trị PostgreSQL cho test (CI: service container; local:
/// deploy/docker-compose.dev.yml).
String get testAdminUrl =>
    Platform.environment['TEST_DATABASE_URL'] ??
    'postgres://health:***REMOVED***@localhost:55432/postgres';

/// Thư mục `apps/server/migrations`, dùng được khi chạy test từ
/// `apps/server` lẫn từ `apps/mobile` (sync_e2e).
Directory serverMigrationsDir() {
  for (final path in [
    'migrations',
    '../server/migrations',
    'apps/server/migrations',
  ]) {
    final dir = Directory(path);
    if (File('${dir.path}/0001_auth.sql').existsSync()) return dir;
  }
  throw StateError(
    'Không tìm thấy apps/server/migrations từ ${Directory.current.path}',
  );
}

/// Database tạm, riêng cho một nhóm test. Tạo bằng [create], xóa bằng [dispose].
final class TestDatabase {
  TestDatabase._(this.name, this.url, this.db);

  /// Tạo database trống. [migrate] = true thì chạy toàn bộ `migrations/`.
  static Future<TestDatabase> create({bool migrate = true}) async {
    final name = 'test_${const Uuid().v4().replaceAll('-', '')}';
    await _admin((conn) => conn.execute('CREATE DATABASE "$name"'));
    final admin = Uri.parse(testAdminUrl);
    final url = admin.replace(path: '/$name').toString();
    final db = Database.open(url);
    if (migrate) {
      await Migrator(db.pool, serverMigrationsDir(), Logger((_) {})).migrate();
    }
    return TestDatabase._(name, url, db);
  }

  final String name;
  final String url;
  final Database db;

  Pool<void> get pool => db.pool;

  Future<void> dispose() async {
    await db.close();
    await _admin(
      (conn) => conn.execute('DROP DATABASE IF EXISTS "$name" WITH (FORCE)'),
    );
  }

  static Future<void> _admin(Future<void> Function(Connection) fn) async {
    final uri = Uri.parse(testAdminUrl);
    final url = uri.queryParameters.containsKey('sslmode')
        ? testAdminUrl
        : uri
              .replace(
                queryParameters: {...uri.queryParameters, 'sslmode': 'disable'},
              )
              .toString();
    final conn = await Connection.openFromUrl(url);
    try {
      await fn(conn);
    } finally {
      await conn.close();
    }
  }
}

/// Logger ghi vào danh sách để test kiểm tra nội dung log.
final class CapturingLogger {
  final lines = <String>[];
  late final logger = Logger(lines.add);
}
