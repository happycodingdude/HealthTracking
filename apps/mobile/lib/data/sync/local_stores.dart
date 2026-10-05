import 'package:api_contract/api_contract.dart';

import '../../features/me/data/account_repository.dart';

/// Ghi bản ghi từ server vào bảng trên máy của một entity.
abstract interface class LocalEntityStore {
  String get entity;

  /// Áp dụng bản ghi server (pull, hoặc bản server trả về khi push không
  /// `applied`). [change] = null hoặc tombstone → xóa bản trên máy.
  Future<void> apply(String key, SyncChange? change);
}

final class AccountStore implements LocalEntityStore {
  AccountStore(this._repo);

  final AccountRepository _repo;
  static const _codec = AccountCodec();

  @override
  String get entity => SyncEntities.account;

  @override
  Future<void> apply(String key, SyncChange? change) async {
    final data = change?.data;
    // Tài khoản không bị xóa qua đồng bộ; bỏ qua tombstone.
    if (change == null || change.deleted || data == null) return;
    await _repo.put(_codec.decode(data).displayName);
  }
}
