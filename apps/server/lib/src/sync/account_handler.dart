import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'sync_entity_handler.dart';

/// Entity `account` (key `me`) = tên hiển thị trong bảng `users` (UA-21).
final class AccountHandler implements SyncEntityHandler {
  const AccountHandler();

  static const _codec = AccountCodec();

  @override
  String get entity => SyncEntities.account;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (m.key != AccountCodec.key) {
      return const ApiError(ErrorCode.validationFailed, field: 'key');
    }
    final data = m.data;
    if (data == null) {
      return const ApiError(ErrorCode.validationFailed, field: 'data');
    }
    final AccountData account;
    try {
      account = _codec.decode(data);
    } on ContractFormatException {
      return const ApiError(ErrorCode.validationFailed, field: 'displayName');
    }
    if (!AccountValidators.isValidDisplayName(account.displayName)) {
      return const ApiError(ErrorCode.validationFailed, field: 'displayName');
    }
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM users WHERE id = @user FOR UPDATE',
      ),
      parameters: {'user': userId},
    );
    if (rows.isEmpty) return null;
    return RowState(
      clientUpdatedAt: rows.first[0]! as DateTime,
      deleted: rows.first[1]! as bool,
    );
  }

  @override
  Future<void> apply(
    Session s,
    String userId,
    SyncMutation m,
    int serverVersion,
  ) async {
    final account = _codec.decode(m.data!);
    await s.execute(
      Sql.named('''
        UPDATE users
        SET display_name = @name, client_updated_at = @clientUpdatedAt, server_version = @version, updated_at = now()
        WHERE id = @user'''),
      parameters: {
        'name': AccountValidators.normalizeDisplayName(account.displayName),
        'clientUpdatedAt': m.clientUpdatedAt,
        'version': serverVersion,
        'user': userId,
      },
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c'),
      parameters: {'user': userId, 'cursor': 0},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String get pullSql => '''
    SELECT 'account'::text AS entity, 'me'::text AS key, deleted, server_version,
           jsonb_build_object('displayName', display_name) AS data
    FROM users
    WHERE id = @user AND server_version > @cursor''';
}
