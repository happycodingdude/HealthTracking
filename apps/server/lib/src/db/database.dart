import 'dart:async';

import 'package:postgres/postgres.dart';

/// Kết nối PostgreSQL (TD-07: SQL viết tay, package `postgres` v3).
final class Database {
  Database(this.pool);

  /// Mở pool từ URL `postgres://user:pass@host:port/db?sslmode=…&connect_timeout=…`.
  ///
  /// - Mặc định `sslmode=disable` vì PostgreSQL chỉ nằm trong mạng nội bộ
  ///   Docker (05 §6.12.1).
  /// - Tối đa [maxConnections] kết nối. `Pool.withUrl` của package mặc định
  ///   chỉ 1 kết nối, khiến mọi request phải xếp hàng.
  factory Database.open(String url, {int maxConnections = 10}) {
    final uri = Uri.parse(url);
    final userInfo = uri.userInfo.split(':');
    final query = uri.queryParameters;
    final endpoint = Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: uri.pathSegments.isEmpty ? 'postgres' : uri.pathSegments.first,
      username: userInfo.first.isEmpty
          ? null
          : Uri.decodeComponent(userInfo.first),
      password: userInfo.length > 1
          ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
          : null,
    );
    final timeout = int.tryParse(query['connect_timeout'] ?? '');
    return Database(
      Pool<void>.withEndpoints(
        [endpoint],
        settings: PoolSettings(
          maxConnectionCount: maxConnections,
          sslMode: switch (query['sslmode']) {
            'require' => SslMode.require,
            'verify-ca' || 'verify-full' => SslMode.verifyFull,
            _ => SslMode.disable,
          },
          connectTimeout: timeout == null ? null : Duration(seconds: timeout),
        ),
      ),
    );
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
