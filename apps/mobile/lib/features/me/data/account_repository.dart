import 'package:api_contract/api_contract.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity `account` (tên hiển thị).
final class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  /// Tên hiển thị; cập nhật ngay sau mỗi lần ghi (P6).
  Stream<String?> watchDisplayName() =>
      (_db.select(_db.account)..where((a) => a.key.equals(AccountCodec.key)))
          .watchSingleOrNull()
          .map((row) => row?.displayName);

  /// Ghi bản trên máy (không qua outbox). Dùng trong use case và khi áp dụng
  /// dữ liệu từ server.
  Future<void> put(String displayName) => _db
      .into(_db.account)
      .insertOnConflictUpdate(
        AccountCompanion.insert(
          key: AccountCodec.key,
          displayName: displayName,
        ),
      );
}
