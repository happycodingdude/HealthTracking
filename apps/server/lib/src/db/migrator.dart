import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../logging/logger.dart';

/// Lỗi migration: file đã chạy bị sửa, hoặc tên file sai quy ước.
final class MigrationException implements Exception {
  MigrationException(this.message);
  final String message;
  @override
  String toString() => 'MigrationException: $message';
}

/// Chạy các file `NNNN_<tên>.sql` theo thứ tự, mỗi file trong 1 transaction
/// (05 §6.7.5). Khóa advisory bảo đảm hai tiến trình không chạy cùng lúc.
/// Lưu checksum: file đã chạy mà bị sửa thì dừng khởi động.
final class Migrator {
  Migrator(this._pool, this._directory, this._logger);

  /// Khóa advisory cố định cho migration.
  static const lockKey = 7426001;

  static final _fileName = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');

  final Pool<void> _pool;
  final Directory _directory;
  final Logger _logger;

  /// Trả về danh sách version vừa được áp dụng.
  Future<List<String>> migrate() async {
    final files = _migrationFiles();
    return _pool.withConnection((conn) async {
      await conn.execute(
        Sql.named('SELECT pg_advisory_lock(@k)'),
        parameters: {'k': lockKey},
      );
      try {
        await conn.execute('''
          CREATE TABLE IF NOT EXISTS schema_migrations (
            version text PRIMARY KEY,
            checksum text NOT NULL,
            applied_at timestamptz NOT NULL DEFAULT now()
          )''');
        final rows = await conn.execute(
          'SELECT version, checksum FROM schema_migrations',
        );
        final applied = {
          for (final r in rows) r[0]! as String: r[1]! as String,
        };

        final done = <String>[];
        for (final file in files) {
          final version = file.uri.pathSegments.last.replaceAll('.sql', '');
          final sql = file.readAsStringSync();
          final checksum = sha256.convert(utf8.encode(sql)).toString();
          final previous = applied[version];
          if (previous != null) {
            if (previous != checksum) {
              throw MigrationException(
                '$version đã chạy nhưng nội dung file bị sửa',
              );
            }
            continue;
          }
          await conn.runTx((tx) async {
            await tx.execute(sql, queryMode: QueryMode.simple);
            await tx.execute(
              Sql.named(
                'INSERT INTO schema_migrations (version, checksum) VALUES (@v, @c)',
              ),
              parameters: {'v': version, 'c': checksum},
            );
          });
          _logger.info('migration_applied', {'version': version});
          done.add(version);
        }
        return done;
      } finally {
        await conn.execute(
          Sql.named('SELECT pg_advisory_unlock(@k)'),
          parameters: {'k': lockKey},
        );
      }
    });
  }

  List<File> _migrationFiles() {
    if (!_directory.existsSync()) {
      throw MigrationException(
        'Không tìm thấy thư mục migration ${_directory.path}',
      );
    }
    final files = _directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList();
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      if (!_fileName.hasMatch(name)) {
        throw MigrationException('Tên file migration sai quy ước: $name');
      }
    }
    files.sort(
      (a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
    );
    return files;
  }
}
