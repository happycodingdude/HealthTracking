import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../data/account_repository.dart';

/// Đổi tên hiển thị (S-56, UA-21). Ghi bản trên máy + outbox trong một
/// transaction: giao diện đổi ngay, không chờ mạng (P6, TAC-01).
final class UpdateDisplayName {
  UpdateDisplayName(this._db, this._accounts, this._outbox);

  final AppDatabase _db;
  final AccountRepository _accounts;
  final OutboxWriter _outbox;

  /// false = tên không hợp lệ (1–30 ký tự), không ghi gì.
  Future<bool> call(String input) async {
    if (!AccountValidators.isValidDisplayName(input)) return false;
    final name = AccountValidators.normalizeDisplayName(input);
    await _db.transaction(() async {
      await _accounts.put(name);
      await _outbox.enqueue(
        SyncEntities.account,
        AccountCodec.key,
        SyncOp.upsert,
        const AccountCodec().encode(AccountData(displayName: name)),
      );
    });
    return true;
  }
}

final updateDisplayNameProvider = Provider<UpdateDisplayName>(
  (ref) => UpdateDisplayName(
    ref.watch(databaseProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(outboxWriterProvider),
  ),
);

/// Tên hiển thị trên máy (null khi chưa có).
final displayNameProvider = StreamProvider<String?>(
  (ref) => ref.watch(accountRepositoryProvider).watchDisplayName(),
);
