import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:server/src/sync/sync_entity_handler.dart';

/// Entity chỉ dùng trong test (`test_item`): có đủ upsert/ensure/delete để kiểm
/// lớp đồng bộ chung (tombstone, phân trang) trước khi có entity thật.
final class TestItemHandler implements SyncEntityHandler {
  const TestItemHandler();

  static Future<void> createTable(Pool<void> pool) => pool.execute('''
    CREATE TABLE test_items (
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      key text NOT NULL,
      value text CHECK (value IS NULL OR value <> 'boom'),
      server_version bigint NOT NULL,
      client_updated_at timestamptz NOT NULL,
      deleted boolean NOT NULL DEFAULT false,
      PRIMARY KEY (user_id, key)
    )''');

  @override
  String get entity => 'test_item';

  @override
  Set<SyncOp> get ops => SyncOp.values.toSet();

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (m.op != SyncOp.delete && m.data?['value'] is! String) {
      return const ApiError(ErrorCode.validationFailed, field: 'value');
    }
    return null;
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM test_items WHERE user_id = @u AND key = @k FOR UPDATE',
      ),
      parameters: {'u': userId, 'k': key},
    );
    return rows.isEmpty
        ? null
        : RowState(
            clientUpdatedAt: rows.first[0]! as DateTime,
            deleted: rows.first[1]! as bool,
          );
  }

  /// Giá trị `slow`: giữ transaction lâu hơn sau khi đã lấy `server_version`,
  /// để test lộ race giữa thứ tự version và thứ tự commit (ED-03).
  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int version,
  ) async {
    await _write(s, ctx.userId, m, version);
    if (m.data?['value'] == 'slow') await s.execute('SELECT pg_sleep(0.03)');
  }

  Future<void> _write(Session s, String userId, SyncMutation m, int version) =>
      s.execute(
        Sql.named(
          '''
      INSERT INTO test_items (user_id, key, value, server_version, client_updated_at, deleted)
      VALUES (@u, @k, @v, @ver, @c, @d)
      ON CONFLICT (user_id, key) DO UPDATE
      SET value = EXCLUDED.value, server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at, deleted = EXCLUDED.deleted''',
        ),
        parameters: {
          'u': userId,
          'k': m.key,
          'v': m.op == SyncOp.delete ? null : m.data!['value'],
          'ver': version,
          'c': m.clientUpdatedAt,
          'd': m.op == SyncOp.delete,
        },
      );

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE key = @k'),
      parameters: {'user': userId, 'cursor': 0, 'k': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String get pullSql => '''
    SELECT 'test_item'::text AS entity, key, deleted, server_version,
           CASE WHEN deleted THEN NULL ELSE jsonb_build_object('value', value) END AS data
    FROM test_items
    WHERE user_id = @user AND server_version > @cursor''';
}
