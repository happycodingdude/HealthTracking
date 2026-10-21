import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../server.dart';

/// URL quản trị PostgreSQL cho test, từ biến `TEST_DATABASE_URL` (CI: đặt
/// trong ci.yml; local: tool/check.sh dựng từ `.env` ở gốc repo). Code không
/// chứa tài khoản database.
String get testAdminUrl {
  final url = Platform.environment['TEST_DATABASE_URL'];
  if (url == null || url.isEmpty) {
    throw StateError(
      'Thiếu TEST_DATABASE_URL: chạy test qua tool/check.sh (xem docs/runbook.md)',
    );
  }
  return url;
}

/// File `apps/server/db/schema.sql` (sinh từ migration, tool/gen_schema.sh),
/// dùng được khi chạy test từ `apps/server` lẫn từ `apps/mobile` (sync_e2e).
File serverSchemaFile() {
  for (final path in [
    'db/schema.sql',
    '../server/db/schema.sql',
    'apps/server/db/schema.sql',
  ]) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  throw StateError(
    'Không tìm thấy apps/server/db/schema.sql từ ${Directory.current.path}',
  );
}

/// Thư mục `apps/server/migrations` (05 Bản 3 TR3-05), tìm như
/// [serverSchemaFile].
Directory serverMigrationsDir() {
  for (final path in [
    'migrations',
    '../server/migrations',
    'apps/server/migrations',
  ]) {
    final dir = Directory(path);
    if (File('${dir.path}/0001_baseline.sql').existsSync()) return dir;
  }
  throw StateError(
    'Không tìm thấy apps/server/migrations từ ${Directory.current.path}',
  );
}

/// Database tạm, riêng cho một nhóm test. Tạo bằng [create], xóa bằng [dispose].
final class TestDatabase {
  TestDatabase._(this.name, this.url, this.db);

  /// Tạo database trống. [schema] = true thì tạo cấu trúc bằng chính
  /// [Migrator] của server từ `apps/server/migrations` (05 Bản 3 TR3-05: từ
  /// Bản 3 migration là nguồn duy nhất của cấu trúc).
  static Future<TestDatabase> create({bool schema = true}) async {
    final name = 'test_${const Uuid().v4().replaceAll('-', '')}';
    await _admin((conn) => conn.execute('CREATE DATABASE "$name"'));
    final admin = Uri.parse(testAdminUrl);
    final url = admin.replace(path: '/$name').toString();
    final db = Database.open(url);
    if (schema) {
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
