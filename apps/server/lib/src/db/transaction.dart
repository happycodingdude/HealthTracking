import 'package:postgres/postgres.dart';

/// Transaction tự quản lý trên một connection của pool.
///
/// Không dùng `runTx` của package `postgres` (3.5) vì mọi lỗi SQL trong đó
/// đều buộc rollback cả transaction, kể cả khi đã `ROLLBACK TO SAVEPOINT`.
/// Đồng bộ cần savepoint cho từng mutation (06 VS02-T04).
Future<T> inTransaction<T>(
  Pool<void> pool,
  Future<T> Function(Connection conn) fn, {
  String begin = 'BEGIN',
}) {
  return pool.withConnection((conn) async {
    await conn.execute(begin);
    try {
      final result = await fn(conn);
      await conn.execute('COMMIT');
      return result;
    } catch (_) {
      try {
        await conn.execute('ROLLBACK');
      } catch (_) {
        // Lỗi ban đầu quan trọng hơn.
      }
      rethrow;
    }
  });
}

/// Chạy [fn] trong savepoint [name]: lỗi (SQL hoặc từ chối của handler) chỉ
/// hoàn tác phần của [fn], phần trước đó của transaction vẫn giữ. Lỗi được ném
/// lại cho nơi gọi xử lý.
Future<T> inSavepoint<T>(
  Connection conn,
  String name,
  Future<T> Function() fn,
) async {
  await conn.execute('SAVEPOINT $name');
  try {
    final result = await fn();
    await conn.execute('RELEASE SAVEPOINT $name');
    return result;
  } catch (_) {
    await conn.execute('ROLLBACK TO SAVEPOINT $name');
    await conn.execute('RELEASE SAVEPOINT $name');
    rethrow;
  }
}
