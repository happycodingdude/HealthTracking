import 'dart:async';

import 'package:postgres/postgres.dart';

/// Kết nối PostgreSQL (TD-07: SQL viết tay, package `postgres` v3).
final class Database {
  Database(this.pool);

  /// Mở pool từ URL. Mặc định `sslmode=disable` vì PostgreSQL chỉ nằm trong
  /// mạng nội bộ Docker (05 §6.12.1).
  factory Database.open(String url) {
    final uri = Uri.parse(url);
    final withSsl = uri.queryParameters.containsKey('sslmode')
        ? uri
        : uri.replace(
            queryParameters: {...uri.queryParameters, 'sslmode': 'disable'},
          );
    return Database(Pool<void>.withUrl(withSsl.toString()));
  }

  final Pool<void> pool;

  /// Kiểm tra database còn trả lời trong [timeout].
  Future<bool> ping({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      await pool.execute('SELECT 1').timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() => pool.close();
}
